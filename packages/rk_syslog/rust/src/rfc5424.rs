//! RFC 5424 message framing.
//!
//! ```text
//! SYSLOG-MSG      = HEADER SP STRUCTURED-DATA [SP MSG]
//! HEADER          = PRI VERSION SP TIMESTAMP SP HOSTNAME SP APP-NAME
//!                                SP PROCID SP MSGID
//! ```
//!
//! The rule this module exists to keep: **a record that cannot be framed is
//! reported, never dropped.** Every refusal comes back as a [`Failure`] with
//! the offending field named, at the moment the caller submits it, on the
//! caller's own thread — not later, from a worker, into a log the caller
//! cannot see.
//!
//! Oversize is the one case where refusing costs more than it is worth: a
//! stack trace that exceeds the receiver's limit is still the most useful
//! thing in the journal. Under the default rule it is truncated on a
//! character boundary and the record says so in its own structured data
//! (`truncated="1" originalBytes="N"`), so the loss is written into the
//! evidence rather than into a counter nobody reads.

use crate::severity::{prival, Facility, Severity};
use crate::status::{Failure, Fallible, Status};
use crate::time::format_timestamp;

/// RFC 5424 §6: the value that stands in for a field with nothing in it.
pub const NILVALUE: &str = "-";

/// The UTF-8 byte order mark RFC 5424 §6.4 asks for in front of a UTF-8 MSG.
pub const BOM: [u8; 3] = [0xEF, 0xBB, 0xBF];

/// What to do with a record that will not fit inside the size limit.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Oversize {
    /// Cut the MSG on a character boundary and mark the record as truncated.
    Truncate,
    /// Refuse the record and tell the caller.
    Reject,
}

impl Oversize {
    pub const fn name(self) -> &'static str {
        match self {
            Oversize::Truncate => "truncate",
            Oversize::Reject => "reject",
        }
    }

    pub fn from_name(name: &str) -> Option<Oversize> {
        match name {
            "truncate" => Some(Oversize::Truncate),
            "reject" => Some(Oversize::Reject),
            _ => None,
        }
    }
}

/// The SD-ID this library uses for the notes it adds to somebody else's
/// record. The `@` form is what RFC 5424 §7.2.2 requires for anything that is
/// not an IANA-registered name; 0 is a placeholder private enterprise number
/// and is documented as such.
pub const RK_SD_ID: &str = "rkSyslog@0";

/// The fields that are the same for every record from one sink.
///
/// Validated once, when the sink opens, so a bad hostname fails loudly at
/// startup instead of failing every record forever.
#[derive(Debug, Clone)]
pub struct SinkIdentity {
    pub hostname: String,
    pub app_name: String,
    pub proc_id: String,
}

impl SinkIdentity {
    pub fn validate(&self) -> Fallible<()> {
        check_field("host_name", &self.hostname, 255)?;
        check_field("app_name", &self.app_name, 48)?;
        check_field("proc_id", &self.proc_id, 128)?;
        Ok(())
    }
}

/// A header field: NILVALUE, or 1..=max bytes of PRINTUSASCII (%d33-126).
fn check_field(field: &str, value: &str, max: usize) -> Fallible<()> {
    if value == NILVALUE {
        return Ok(());
    }
    if value.is_empty() {
        return Err(Failure::new(
            Status::InvalidHeaderField,
            format!("{field} is empty; use \"-\" for the RFC 5424 NILVALUE"),
        ));
    }
    if value.len() > max {
        return Err(Failure::new(
            Status::InvalidHeaderField,
            format!(
                "{field} is {} bytes, RFC 5424 allows at most {max}",
                value.len()
            ),
        ));
    }
    for (i, b) in value.bytes().enumerate() {
        if !(33..=126).contains(&b) {
            return Err(Failure::new(
                Status::InvalidHeaderField,
                format!(
                    "{field} byte {i} is 0x{b:02x}, outside PRINTUSASCII (%d33-126); \
                     spaces and non-ASCII are not allowed in this field"
                ),
            ));
        }
    }
    Ok(())
}

/// SD-NAME: 1..=32 bytes of PRINTUSASCII, minus `=`, space, `]` and `"`.
fn check_sd_name(what: &str, value: &str) -> Fallible<()> {
    if value.is_empty() || value.len() > 32 {
        return Err(Failure::new(
            Status::InvalidStructuredData,
            format!(
                "{what} is {} bytes, RFC 5424 SD-NAME allows 1..=32",
                value.len()
            ),
        ));
    }
    for (i, b) in value.bytes().enumerate() {
        let printable = (33..=126).contains(&b);
        if !printable || b == b'=' || b == b']' || b == b'"' {
            return Err(Failure::new(
                Status::InvalidStructuredData,
                format!(
                    "{what} byte {i} is 0x{b:02x}; SD-NAME excludes '=', ']', '\"', \
                     space and everything outside %d33-126"
                ),
            ));
        }
    }
    Ok(())
}

/// PARAM-VALUE is UTF-8, but control characters are refused.
///
/// The grammar would tolerate them. A newline inside a parameter survives our
/// octet-counted framing and then breaks the next hop that uses the
/// newline-terminated framing of RFC 6587 — the record splits in two and one
/// half is read as a new message with a forged priority. Refusing here is
/// cheap; that failure is not, and it is exactly the shape a log-injection
/// attempt takes.
fn check_param_value(name: &str, value: &str) -> Fallible<()> {
    for (i, c) in value.char_indices() {
        if (c as u32) < 0x20 || c as u32 == 0x7F {
            return Err(Failure::new(
                Status::InvalidStructuredData,
                format!(
                    "parameter '{name}' has a control character U+{:04X} at byte {i}; \
                     escape it before submitting",
                    c as u32
                ),
            ));
        }
    }
    Ok(())
}

/// One `[SD-ID param="value" ...]` element.
#[derive(Debug, Clone, Default)]
pub struct SdElement {
    pub id: String,
    pub params: Vec<(String, String)>,
}

/// The STRUCTURED-DATA field: zero or more elements.
///
/// Built through checked calls rather than accepted as pre-formatted text.
/// Handing this library a finished SD string would mean trusting the caller
/// to have escaped it, and the failure of that trust is silent — a stray `]`
/// ends the element early and the rest of the record becomes free-form MSG.
#[derive(Debug, Clone, Default)]
pub struct StructuredData {
    pub elements: Vec<SdElement>,
}

impl StructuredData {
    pub fn new() -> StructuredData {
        StructuredData::default()
    }

    pub fn is_empty(&self) -> bool {
        self.elements.is_empty()
    }

    /// Starts a new element. Later params attach to it.
    pub fn push_element(&mut self, id: &str) -> Fallible<()> {
        // An SD-ID may be `name@enterprise`; both halves are SD-NAMEs, and
        // the whole thing still has to fit in 32 bytes.
        check_sd_name("SD-ID", id)?;
        if id.matches('@').count() > 1 {
            return Err(Failure::new(
                Status::InvalidStructuredData,
                format!("SD-ID '{id}' has more than one '@'"),
            ));
        }
        self.elements.push(SdElement {
            id: id.to_string(),
            params: Vec::new(),
        });
        Ok(())
    }

    /// Adds a parameter to the element most recently pushed.
    pub fn push_param(&mut self, name: &str, value: &str) -> Fallible<()> {
        check_sd_name("PARAM-NAME", name)?;
        check_param_value(name, value)?;
        let element = self.elements.last_mut().ok_or_else(|| {
            Failure::new(
                Status::InvalidStructuredData,
                format!("parameter '{name}' has no element; push an SD-ID first"),
            )
        })?;
        element.params.push((name.to_string(), value.to_string()));
        Ok(())
    }

    fn write_into(&self, out: &mut Vec<u8>) {
        if self.elements.is_empty() {
            out.extend_from_slice(NILVALUE.as_bytes());
            return;
        }
        for element in &self.elements {
            out.push(b'[');
            out.extend_from_slice(element.id.as_bytes());
            for (name, value) in &element.params {
                out.push(b' ');
                out.extend_from_slice(name.as_bytes());
                out.extend_from_slice(b"=\"");
                escape_param_value(value, out);
                out.push(b'"');
            }
            out.push(b']');
        }
    }
}

/// RFC 5424 §6.3.3: inside PARAM-VALUE, `"`, `\` and `]` are escaped with a
/// backslash and nothing else is.
fn escape_param_value(value: &str, out: &mut Vec<u8>) {
    for b in value.bytes() {
        if b == b'"' || b == b'\\' || b == b']' {
            out.push(b'\\');
        }
        out.push(b);
    }
}

/// Everything that changes from one record to the next.
#[derive(Debug, Clone)]
pub struct Record {
    pub facility: Facility,
    pub severity: Severity,
    pub epoch_micros: i64,
    pub utc_offset_minutes: i32,
    /// `None` becomes NILVALUE.
    pub msgid: Option<String>,
    pub structured_data: StructuredData,
    /// `None` means the record is header and structured data only, which the
    /// grammar allows.
    pub message: Option<String>,
}

/// How a record was framed, so the counters can be honest about it.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Framed {
    pub bytes: Vec<u8>,
    /// Set when the MSG had to be cut to fit.
    pub truncated_from: Option<usize>,
}

/// Turns a record into the octets of one SYSLOG-MSG.
pub fn frame(
    identity: &SinkIdentity,
    record: &Record,
    max_bytes: usize,
    oversize: Oversize,
    emit_bom: bool,
) -> Fallible<Framed> {
    if let Some(msgid) = &record.msgid {
        check_field("msgid", msgid, 32)?;
    }
    let timestamp = format_timestamp(record.epoch_micros, record.utc_offset_minutes)?;

    let build = |sd: &StructuredData, msg: Option<&str>| -> Vec<u8> {
        let mut out = Vec::with_capacity(160 + msg.map_or(0, str::len));
        out.push(b'<');
        out.extend_from_slice(
            prival(record.facility, record.severity)
                .to_string()
                .as_bytes(),
        );
        out.extend_from_slice(b">1 ");
        out.extend_from_slice(timestamp.as_bytes());
        out.push(b' ');
        out.extend_from_slice(identity.hostname.as_bytes());
        out.push(b' ');
        out.extend_from_slice(identity.app_name.as_bytes());
        out.push(b' ');
        out.extend_from_slice(identity.proc_id.as_bytes());
        out.push(b' ');
        out.extend_from_slice(record.msgid.as_deref().unwrap_or(NILVALUE).as_bytes());
        out.push(b' ');
        sd.write_into(&mut out);
        if let Some(msg) = msg {
            out.push(b' ');
            if emit_bom {
                out.extend_from_slice(&BOM);
            }
            out.extend_from_slice(msg.as_bytes());
        }
        out
    };

    let whole = build(&record.structured_data, record.message.as_deref());
    if whole.len() <= max_bytes {
        return Ok(Framed {
            bytes: whole,
            truncated_from: None,
        });
    }

    let original = whole.len();
    if oversize == Oversize::Reject {
        return Err(Failure::new(
            Status::InvalidMessage,
            format!(
                "record is {original} bytes, limit is {max_bytes}, and the oversize \
                 rule is 'reject'"
            ),
        ));
    }

    // Truncating: re-frame with a marker element so the record carries the
    // fact, then cut MSG to whatever budget is left.
    let mut marked = record.structured_data.clone();
    marked.push_element(RK_SD_ID)?;
    marked.push_param("truncated", "1")?;
    marked.push_param("originalBytes", &original.to_string())?;

    let prefix = build(&marked, None);
    // 1 for the SP before MSG, plus the BOM if we emit one.
    let overhead = 1 + if emit_bom { BOM.len() } else { 0 };
    if prefix.len() + overhead >= max_bytes {
        return Err(Failure::new(
            Status::InvalidMessage,
            format!(
                "the header and structured data alone are {} bytes and the limit is \
                 {max_bytes}; there is no room for any message, so nothing can be \
                 truncated to fit",
                prefix.len()
            ),
        ));
    }
    let budget = max_bytes - prefix.len() - overhead;

    let message = record.message.as_deref().unwrap_or("");
    let mut cut = budget.min(message.len());
    while cut > 0 && !message.is_char_boundary(cut) {
        cut -= 1;
    }
    Ok(Framed {
        bytes: build(&marked, Some(&message[..cut])),
        truncated_from: Some(original),
    })
}

#[cfg(test)]
mod tests {
    use super::*;

    fn identity() -> SinkIdentity {
        SinkIdentity {
            hostname: "till-01.shop.example".into(),
            app_name: "telepos".into(),
            proc_id: "4711".into(),
        }
    }

    fn record() -> Record {
        Record {
            facility: Facility::Local0,
            severity: Severity::Informational,
            epoch_micros: 1_065_910_455_003_000,
            utc_offset_minutes: 0,
            msgid: Some("SALE".into()),
            structured_data: StructuredData::new(),
            message: Some("sale closed".into()),
        }
    }

    fn framed_text(r: &Record) -> String {
        let f = frame(&identity(), r, 8192, Oversize::Truncate, false).unwrap();
        String::from_utf8(f.bytes).unwrap()
    }

    #[test]
    fn frames_a_whole_record_in_the_order_the_grammar_gives() {
        assert_eq!(
            framed_text(&record()),
            concat!(
                "<134>1 2003-10-11T22:14:15.003000Z ",
                "till-01.shop.example telepos 4711 SALE - sale closed"
            )
        );
    }

    #[test]
    fn pri_is_facility_times_eight_plus_severity() {
        let mut r = record();
        r.facility = Facility::Audit; // 13
        r.severity = Severity::Warning; // 4
        assert!(framed_text(&r).starts_with("<108>1 "));
    }

    #[test]
    fn absent_fields_become_the_nilvalue() {
        let mut r = record();
        r.msgid = None;
        r.message = None;
        let text = framed_text(&r);
        // ... PROCID MSGID SD, and nothing after.
        assert!(text.ends_with("4711 - -"), "{text}");
    }

    #[test]
    fn emits_the_byte_order_mark_when_asked() {
        let f = frame(&identity(), &record(), 8192, Oversize::Truncate, true).unwrap();
        let idx = f.bytes.windows(3).position(|w| w == BOM).unwrap();
        assert_eq!(&f.bytes[idx + 3..], b"sale closed");
    }

    #[test]
    fn writes_structured_data_and_escapes_the_three_characters_the_rfc_names() {
        let mut r = record();
        r.structured_data.push_element("exampleSDID@32473").unwrap();
        r.structured_data.push_param("iut", "3").unwrap();
        r.structured_data
            .push_param("eventSource", r#"a"b\c]d"#)
            .unwrap();
        let text = framed_text(&r);
        assert!(
            text.contains(r#"[exampleSDID@32473 iut="3" eventSource="a\"b\\c\]d"]"#),
            "{text}"
        );
    }

    #[test]
    fn writes_several_elements_back_to_back() {
        let mut r = record();
        r.structured_data.push_element("a@1").unwrap();
        r.structured_data.push_param("x", "1").unwrap();
        r.structured_data.push_element("b@1").unwrap();
        r.structured_data.push_param("y", "2").unwrap();
        assert!(framed_text(&r).contains(r#"[a@1 x="1"][b@1 y="2"]"#));
    }

    #[test]
    fn a_field_that_cannot_be_framed_is_reported_with_the_field_named() {
        // A space in APP-NAME is the mistake somebody actually makes.
        let bad = SinkIdentity {
            hostname: "till".into(),
            app_name: "tele pos".into(),
            proc_id: "1".into(),
        };
        let err = bad.validate().unwrap_err();
        assert_eq!(err.status, Status::InvalidHeaderField);
        assert!(err.detail.contains("app_name"), "{}", err.detail);
        assert!(err.detail.contains("PRINTUSASCII"), "{}", err.detail);
    }

    #[test]
    fn an_overlong_msgid_is_reported_not_cut() {
        let mut r = record();
        r.msgid = Some("M".repeat(33));
        let err = frame(&identity(), &r, 8192, Oversize::Truncate, false).unwrap_err();
        assert_eq!(err.status, Status::InvalidHeaderField);
        assert!(err.detail.contains("32"), "{}", err.detail);
    }

    #[test]
    fn a_control_character_in_a_parameter_is_refused() {
        let mut sd = StructuredData::new();
        sd.push_element("a@1").unwrap();
        let err = sd.push_param("note", "line\nbreak").unwrap_err();
        assert_eq!(err.status, Status::InvalidStructuredData);
        assert!(err.detail.contains("U+000A"), "{}", err.detail);
    }

    #[test]
    fn a_parameter_without_an_element_is_refused() {
        let mut sd = StructuredData::new();
        let err = sd.push_param("x", "1").unwrap_err();
        assert_eq!(err.status, Status::InvalidStructuredData);
        assert!(err.detail.contains("push an SD-ID first"));
    }

    #[test]
    fn bad_sd_names_are_refused() {
        let mut sd = StructuredData::new();
        assert_eq!(
            sd.push_element("has space").unwrap_err().status,
            Status::InvalidStructuredData
        );
        assert_eq!(
            sd.push_element(&"x".repeat(33)).unwrap_err().status,
            Status::InvalidStructuredData
        );
        assert_eq!(
            sd.push_element("a@b@c").unwrap_err().status,
            Status::InvalidStructuredData
        );
        sd.push_element("ok@1").unwrap();
        assert_eq!(
            sd.push_param("a=b", "1").unwrap_err().status,
            Status::InvalidStructuredData
        );
    }

    #[test]
    fn oversize_truncates_within_the_limit_and_says_so_in_the_record() {
        let mut r = record();
        r.message = Some("x".repeat(4000));
        let f = frame(&identity(), &r, 512, Oversize::Truncate, true).unwrap();
        assert!(f.bytes.len() <= 512, "framed {} bytes", f.bytes.len());
        let text = String::from_utf8_lossy(&f.bytes).into_owned();
        assert!(text.contains(r#"truncated="1""#), "{text}");
        assert!(text.contains("originalBytes="), "{text}");
        assert!(f.truncated_from.unwrap() > 4000);
    }

    #[test]
    fn truncation_never_splits_a_character() {
        // Every cut point around the limit must still be valid UTF-8. A
        // byte-wise cut through a multi-byte character produces a record no
        // collector can read, and the bug only shows up in the languages
        // this product actually ships in.
        for limit in 200..320 {
            let mut r = record();
            r.message = Some("тенге ₸ ".repeat(200));
            let f = frame(&identity(), &r, limit, Oversize::Truncate, true).unwrap();
            assert!(f.bytes.len() <= limit);
            String::from_utf8(f.bytes).expect("truncated record must stay valid UTF-8");
        }
    }

    #[test]
    fn oversize_under_the_reject_rule_is_reported() {
        let mut r = record();
        r.message = Some("x".repeat(4000));
        let err = frame(&identity(), &r, 512, Oversize::Reject, false).unwrap_err();
        assert_eq!(err.status, Status::InvalidMessage);
        assert!(err.detail.contains("512"), "{}", err.detail);
    }

    #[test]
    fn a_limit_too_small_for_the_header_is_reported_rather_than_silently_empty() {
        let mut r = record();
        r.message = Some("hello".into());
        let err = frame(&identity(), &r, 40, Oversize::Truncate, true).unwrap_err();
        assert_eq!(err.status, Status::InvalidMessage);
        assert!(err.detail.contains("no room"), "{}", err.detail);
    }

    #[test]
    fn framing_is_deterministic() {
        let r = record();
        assert_eq!(framed_text(&r), framed_text(&r));
    }
}

//! Weighing scales: the request, the frame, and the rule for calling a reading
//! settled.
//!
//! Three protocols, measured off the implementation this crate replaces
//! (`lib/hardware/scales/scales_service.dart` in TelePOS): a CAS-style
//! comma-separated line, the Massa-K line, and the loose "find a number in it"
//! reading that a great many serial scales are compatible with.
//!
//! Nothing here waits, sleeps, retries or holds a port. A weight arrives when
//! the scale sends it; a scale settles when its load cell settles, which takes
//! hundreds of milliseconds of *mechanics* that no software can shorten. This
//! module frames and parses. The waiting belongs to whoever owns the wire.

use crate::status::{Result, Status};

/// The dialects this build knows.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Protocol {
    /// No framing of its own: a line, somewhere in which there is a number.
    /// Motion is signalled by a `~` or an `M` anywhere in the line.
    Generic,
    /// `ST,GS,+  1.234kg` — a status field, a gross/net field, and a weight
    /// field. CAS and the many scales that copy it.
    Cas,
    /// `$  1.234` — a leading `$` for a settled reading, anything else for a
    /// moving one.
    MassaK,
}

impl Protocol {
    pub fn from_name(name: &str) -> Result<Self> {
        match name {
            "generic" => Ok(Protocol::Generic),
            "cas" => Ok(Protocol::Cas),
            "massa_k" => Ok(Protocol::MassaK),
            _ => Err(Status::UnknownName),
        }
    }

    pub const fn name(self) -> &'static str {
        match self {
            Protocol::Generic => "generic",
            Protocol::Cas => "cas",
            Protocol::MassaK => "massa_k",
        }
    }

    /// "Send me the weight." `W\r` for the CAS family and its compatibles,
    /// `N\r` for Massa-K.
    pub const fn weight_request(self) -> &'static [u8] {
        match self {
            Protocol::Generic | Protocol::Cas => b"W\r",
            Protocol::MassaK => b"N\r",
        }
    }

    /// "Zero the pan." `T\r` on all three.
    pub const fn tare_request(self) -> &'static [u8] {
        b"T\r"
    }
}

/// What the scale said about its own motion.
///
/// The implementation this replaces collapsed everything that was not `ST`
/// into "unstable", which silently turned an overload into a reading that had
/// simply not settled yet — a scale with 200 kg on a 30 kg pan would have been
/// waited on forever rather than reported. Splitting the two loses nothing:
/// `Overload` and `Underload` are still not `Stable`, so any caller that only
/// asks "may I use this number" behaves exactly as before.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Stability {
    Stable,
    Unstable,
    Overload,
    Underload,
}

impl Stability {
    pub const fn name(self) -> &'static str {
        match self {
            Stability::Stable => "stable",
            Stability::Unstable => "unstable",
            Stability::Overload => "overload",
            Stability::Underload => "underload",
        }
    }

    pub fn from_name(name: &str) -> Result<Self> {
        match name {
            "stable" => Ok(Stability::Stable),
            "unstable" => Ok(Stability::Unstable),
            "overload" => Ok(Stability::Overload),
            "underload" => Ok(Stability::Underload),
            _ => Err(Status::UnknownName),
        }
    }
}

/// Gross or net, when the protocol says which.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Measure {
    Gross,
    Net,
    Unknown,
}

impl Measure {
    pub const fn name(self) -> &'static str {
        match self {
            Measure::Gross => "gross",
            Measure::Net => "net",
            Measure::Unknown => "unknown",
        }
    }
}

/// The unit the scale itself named. Never converted here.
///
/// A conversion is a rounding decision, and a rounding decision about a
/// quantity that will be multiplied by a price does not belong in a codec.
/// The caller gets the digits the scale sent and the unit it sent them in.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Unit {
    Kilogram,
    Gram,
    Pound,
}

impl Unit {
    pub const fn name(self) -> &'static str {
        match self {
            Unit::Kilogram => "kg",
            Unit::Gram => "g",
            Unit::Pound => "lb",
        }
    }
}

/// One weight, exactly as sent: `scaled` divided by ten to the `decimals`.
///
/// Integer and exponent rather than a float, for the same reason money is not
/// a float in this product: `1.234` has no binary representation, and a weight
/// is about to be multiplied by a price.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct Reading {
    pub scaled: i64,
    pub decimals: u32,
    pub unit: Unit,
    pub stability: Stability,
    pub measure: Measure,
}

/// What one call to [`parse`] found in the buffer it was handed.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum Frame {
    /// A complete, understood line. `consumed` bytes may be dropped.
    Reading(Reading),
    /// A complete line that this protocol cannot read. `consumed` bytes may be
    /// dropped and the caller should keep going: resynchronising is the point
    /// of reporting this separately from [`Frame::Incomplete`].
    Garbage,
    /// No line terminator yet. `consumed` is zero: keep the bytes and add more.
    Incomplete,
}

impl Frame {
    pub const fn kind_name(&self) -> &'static str {
        match self {
            Frame::Reading(_) => "reading",
            Frame::Garbage => "garbage",
            Frame::Incomplete => "incomplete",
        }
    }
}

/// A parse result together with how much of the input it accounted for.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Parsed {
    pub frame: Frame,
    pub consumed: usize,
}

/// Read one line out of `data`.
///
/// Bytes, not text: a scale sends a byte stream, and a partial multi-byte
/// sequence at the end of a read is not an error, it is the middle of a frame.
pub fn parse(protocol: Protocol, data: &[u8]) -> Parsed {
    let Some(end) = data.iter().position(|b| *b == b'\r' || *b == b'\n') else {
        return Parsed {
            frame: Frame::Incomplete,
            consumed: 0,
        };
    };

    // Swallow the whole run of terminators, so a `\r\n` pair does not leave an
    // empty line behind to be reported as garbage on the next call.
    let mut after = end;
    while after < data.len() && (data[after] == b'\r' || data[after] == b'\n') {
        after += 1;
    }

    let line = &data[..end];
    let frame = match parse_line(protocol, line) {
        Some(reading) => Frame::Reading(reading),
        None => Frame::Garbage,
    };

    Parsed {
        frame,
        consumed: after,
    }
}

fn parse_line(protocol: Protocol, line: &[u8]) -> Option<Reading> {
    let text = core::str::from_utf8(line).ok()?;
    let trimmed = text.trim();
    if trimmed.is_empty() {
        return None;
    }
    match protocol {
        Protocol::Generic => parse_generic(trimmed),
        Protocol::Cas => parse_cas(trimmed),
        Protocol::MassaK => parse_massa_k(trimmed),
    }
}

fn parse_generic(line: &str) -> Option<Reading> {
    // Over capacity is looked for *before* the number, because an overloaded
    // scale usually sends the marker with no number behind it at all: `OL`,
    // `-OL-`, `OL kg`. Read number-first, such a line is not a reading, and a
    // caller polling for a settled weight then waits out its whole budget for
    // something that is never going to arrive — the operator is told "the
    // weight did not settle" while the scale has been saying "too heavy" all
    // along.
    //
    // Word-bounded and case-sensitive, so a checkweighing line `TOL 1.500 kg`
    // is a tolerance marker and not an overload.
    if contains_word(line, "OL") {
        // Not a weight, and not read as one. See [`overload_reading`].
        return Some(overload_reading(Stability::Overload, Measure::Unknown));
    }
    // There is deliberately no underload marker here. This dialect has no
    // established one, and inventing it would produce a false refusal on an
    // ordinary line — the same trade this module refuses for Massa-K's
    // overload, and refused for the same reason.

    // A fractional part is *required* here, and only here. This protocol scans
    // a whole line for a number, so accepting a bare integer would let an
    // unrelated field ("ID 7  W 1.234") be read as the weight. The two
    // delimited protocols below do not have that hazard and do accept one.
    let number = scan_number(line, Scan::Line)?;
    let stability = if line.contains('~') || line.contains('M') {
        Stability::Unstable
    } else {
        Stability::Stable
    };
    Some(Reading {
        scaled: number.scaled,
        decimals: number.decimals,
        // The unit the line stated, never assumed. Hard-coding kilograms here
        // read `500.0 g` as five hundred kilograms — a thousandfold error in
        // the quantity a price is about to multiply.
        unit: scan_unit_after(line, number.end),
        stability,
        measure: Measure::Unknown,
    })
}

fn parse_cas(line: &str) -> Option<Reading> {
    // Split into **three** fields at most, so everything after the second
    // comma is the weight slot. This dialect's delimiter is also the decimal
    // separator half of Europe writes with, and a scale sending `+  1,234kg`
    // splits into four otherwise — leaving `+  1` in the weight slot, which a
    // delimited field is entitled to read as a whole kilogram. One kilo
    // reported for 1.234 kg is a wrong number on a receipt, and worse than
    // either refusing the frame or reading it right; read it right.
    let parts: Vec<&str> = line.splitn(3, ',').collect();
    let stability = match parts[0].trim() {
        s if s.eq_ignore_ascii_case("ST") => Stability::Stable,
        s if s.eq_ignore_ascii_case("OL") => Stability::Overload,
        s if s.eq_ignore_ascii_case("UL") => Stability::Underload,
        // "US" and anything else: moving. Same collapse the previous
        // implementation made, minus the two cases named above.
        _ => Stability::Unstable,
    };
    let measure = match parts.get(1).map(|p| p.trim()) {
        Some("GS") => Measure::Gross,
        Some("NT") => Measure::Net,
        _ => Measure::Unknown,
    };

    // Reported before the value field is even looked at. A scale at its limit
    // writes the full-scale value, blanks or nothing into that slot, so
    // requiring a readable number there loses the one fact the frame carried:
    // `OL,GS,` came back as garbage, and the caller waited out its budget.
    if matches!(stability, Stability::Overload | Stability::Underload) {
        return Some(overload_reading(stability, measure));
    }

    if parts.len() < 3 {
        return None;
    }
    let field = parts[2].trim();
    let number = scan_number(field, Scan::Field)?;
    Some(Reading {
        scaled: number.scaled,
        decimals: number.decimals,
        unit: scan_unit_after(field, number.end),
        stability,
        measure,
    })
}

/// `<marker><padded number>` — `$` settled, anything else moving.
///
/// **No overload state here, on purpose.** This dialect's marker for over
/// capacity is not established, and a guessed marker fires on an ordinary line
/// and stops a sale outright with a false "overload". That is strictly worse
/// than the honest outcome a caller already gets: the frame parses, it never
/// reports itself settled, and the settling rule returns
/// [`Verdict::Expired`] — "the scale answered and never settled" — rather than
/// pretending to know why.
fn parse_massa_k(line: &str) -> Option<Reading> {
    // The marker is cut only when it is actually there. Cutting the first
    // character unconditionally is a money error of the same family as a lost
    // sign: this dialect signals "not settled" with a *blank* in the marker
    // slot, the line is trimmed before it reaches here, and so an unsettled
    // `  12.345` arrives as `12.345` and loses its leading digit — 12.345 kg
    // read as 2.345 kg. Plausible, and wrong by ten kilos.
    let (stability, rest) = match line.strip_prefix('$') {
        Some(rest) => (Stability::Stable, rest),
        None => (Stability::Unstable, line),
    };
    let field = rest.trim();
    let number = scan_number(field, Scan::Field)?;
    Some(Reading {
        scaled: number.scaled,
        decimals: number.decimals,
        unit: scan_unit_after(field, number.end),
        stability,
        measure: Measure::Unknown,
    })
}

/// A frame that says "off the scale" and carries no usable weight.
///
/// Zero rather than whatever digits were in the slot: on an over- or
/// under-capacity line those digits are the full-scale value or the blanks the
/// display shows, not a measurement, and handing them to a caller as a weight
/// invites them onto a receipt. The stability is the whole content of such a
/// frame.
const fn overload_reading(stability: Stability, measure: Measure) -> Reading {
    Reading {
        scaled: 0,
        decimals: 0,
        unit: Unit::Kilogram,
        stability,
        measure,
    }
}

/// Whether `word` appears in `line` on its own, the way a regular
/// expression's `\b` would have it: not touching a letter, digit or
/// underscore on either side.
fn contains_word(line: &str, word: &str) -> bool {
    let bytes = line.as_bytes();
    let needle = word.as_bytes();
    if needle.is_empty() || bytes.len() < needle.len() {
        return false;
    }
    let is_word_byte = |b: u8| b.is_ascii_alphanumeric() || b == b'_';
    for i in 0..=bytes.len() - needle.len() {
        if &bytes[i..i + needle.len()] != needle {
            continue;
        }
        let before_free = i == 0 || !is_word_byte(bytes[i - 1]);
        let after = i + needle.len();
        let after_free = after == bytes.len() || !is_word_byte(bytes[after]);
        if before_free && after_free {
            return true;
        }
    }
    false
}

/// How much freedom the number scanner has, which depends on whether it is
/// looking at a whole line or at one delimited field.
///
/// It does **not** decide whether a sign may be padded away from its digits.
/// All three dialects right-justify the number inside a fixed-width slot and
/// park the sign at the left edge of it, so `-  0.500` is minus half a kilo on
/// a bare line exactly as it is inside a CAS field. Reading it as plus half a
/// kilo — which the implementation this replaces did, and which the first
/// draft of this module still did on whole lines — turns an item handed back
/// over the counter into an item sold.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
enum Scan {
    /// A whole line, with no idea where the weight is. A fractional part is
    /// required — reproducing the previous implementation's regular
    /// expression, which insisted on a decimal point — because a bare integer
    /// anywhere on the line ("ID 7  W 1.234") would otherwise be taken for
    /// the weight.
    Line,
    /// One field a delimiter already isolated. A bare integer is safe here:
    /// the delimiters say where the weight is, so there is nothing else on
    /// hand for it to be confused with.
    Field,
}

/// A number lifted off the wire: the digits as an integer, the decimal
/// exponent, and where in the text it ended — which is where the unit that
/// belongs to it starts.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
struct Number {
    scaled: i64,
    decimals: u32,
    end: usize,
}

/// Find the first number and return it as an integer plus a decimal exponent.
fn scan_number(text: &str, scan: Scan) -> Option<Number> {
    let require_fraction = scan == Scan::Line;
    let bytes = text.as_bytes();
    let mut i = 0usize;
    while i < bytes.len() {
        let start = i;
        let mut j = i;
        let mut negative = false;
        if bytes[j] == b'+' || bytes[j] == b'-' {
            negative = bytes[j] == b'-';
            j += 1;
            while j < bytes.len() && (bytes[j] == b' ' || bytes[j] == b'\t') {
                j += 1;
            }
        }
        let digits_start = j;
        while j < bytes.len() && bytes[j].is_ascii_digit() {
            j += 1;
        }
        if j == digits_start {
            i = start + 1;
            continue;
        }
        let int_part = &text[digits_start..j];
        let mut frac_part = "";
        if j < bytes.len() && (bytes[j] == b'.' || bytes[j] == b',') {
            let frac_start = j + 1;
            let mut k = frac_start;
            while k < bytes.len() && bytes[k].is_ascii_digit() {
                k += 1;
            }
            if k > frac_start {
                frac_part = &text[frac_start..k];
                j = k;
            }
        }
        if require_fraction && frac_part.is_empty() {
            i = j.max(start + 1);
            continue;
        }
        // Reassembled from the sign and the digits separately rather than
        // cleaned out of one slice: the padding between them is not part of
        // any number, and a text like `-  0.500` parses as nothing at all.
        let mut combined = String::with_capacity(int_part.len() + frac_part.len() + 1);
        if negative {
            combined.push('-');
        }
        combined.push_str(int_part);
        combined.push_str(frac_part);
        let scaled = combined.parse::<i64>().ok()?;
        return Some(Number {
            scaled,
            decimals: frac_part.len() as u32,
            end: j,
        });
    }
    None
}

/// The unit written immediately after the number, if the scale wrote one.
///
/// Adjacent to the digits, not merely somewhere on the line: `1.500 kg NET`
/// states kilograms, and a scan of the line's trailing letters would answer
/// `NET`. Only the units a scale names are recognised; anything else — a
/// Cyrillic `кг`, a trailing status word, nothing at all — falls back to
/// kilograms, which is what an unstated unit means on every profile in this
/// product's catalogue.
fn scan_unit_after(text: &str, from: usize) -> Unit {
    let bytes = text.as_bytes();
    let mut i = from.min(bytes.len());
    while i < bytes.len() && (bytes[i] == b' ' || bytes[i] == b'\t') {
        i += 1;
    }
    let start = i;
    while i < bytes.len() && bytes[i].is_ascii_alphabetic() {
        i += 1;
    }
    match text[start..i].to_ascii_lowercase().as_str() {
        "g" | "gs" => Unit::Gram,
        "lb" | "lbs" => Unit::Pound,
        _ => Unit::Kilogram,
    }
}

// ---------------------------------------------------------------------------
// Settling
// ---------------------------------------------------------------------------

/// What the caller heard on the wire since the last offer.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Heard {
    /// A reading came out of [`parse`].
    Reading,
    /// Bytes arrived but produced no reading — noise, a foreign protocol, a
    /// half-configured baud rate. The scale is *there*.
    Noise,
    /// Nothing arrived at all.
    Silence,
}

impl Heard {
    pub fn from_name(name: &str) -> Result<Self> {
        match name {
            "reading" => Ok(Heard::Reading),
            "noise" => Ok(Heard::Noise),
            "silence" => Ok(Heard::Silence),
            _ => Err(Status::UnknownName),
        }
    }

    pub const fn name(self) -> &'static str {
        match self {
            Heard::Reading => "reading",
            Heard::Noise => "noise",
            Heard::Silence => "silence",
        }
    }
}

/// The answer to "may I put this number on a receipt yet".
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Verdict {
    /// Settled, and the last offered reading is the one to use.
    Settled,
    /// Keep asking; the budget has not run out.
    NotYet,
    /// The budget ran out while the scale was talking. It answered — it just
    /// never settled. An operator can be told to take the item off and try
    /// again.
    Expired,
    /// The budget ran out and nothing was ever heard. This is a wiring or a
    /// port problem, not a weighing problem, and the two must not be reported
    /// with the same words: the previous implementation returned the single
    /// message "timed out waiting for a stable weight" for both, which sent
    /// operators looking at the pan when the cable was out.
    NoAnswer,
}

impl Verdict {
    pub const fn name(self) -> &'static str {
        match self {
            Verdict::Settled => "settled",
            Verdict::NotYet => "not_yet",
            Verdict::Expired => "expired",
            Verdict::NoAnswer => "no_answer",
        }
    }
}

const STABILIZER_MAGIC: u32 = 0x524B_5344; // "RKSD"

/// The settling rule, as a value the caller owns.
///
/// It holds no clock, spawns nothing, and never sleeps: the caller supplies
/// the elapsed time on every offer. That is what makes И30 structural here
/// rather than a promise — this type *cannot* block a sale, because it cannot
/// wait at all. The budget is expressed in milliseconds and not in attempts,
/// because a port that answers every 5 ms and a port that answers every 5 s
/// would otherwise get wildly different real deadlines from the same number.
///
/// `repr(C)` and a published size: the caller allocates it, the caller frees
/// it, and this crate allocates nothing on its behalf (И146).
#[repr(C)]
#[derive(Debug, Clone, Copy)]
pub struct Stabilizer {
    magic: u32,
    needed: u32,
    budget_ms: u32,
    repeats: u32,
    last_scaled: i64,
    last_decimals: u32,
    heard_anything: u32,
}

impl Stabilizer {
    /// `needed` consecutive equal settled readings before the verdict is
    /// [`Verdict::Settled`]. One reproduces the behaviour this replaces, which
    /// took the first settled reading it saw.
    pub fn new(needed: u32, budget_ms: u32) -> Self {
        Stabilizer {
            magic: STABILIZER_MAGIC,
            needed: needed.max(1),
            budget_ms,
            repeats: 0,
            last_scaled: 0,
            last_decimals: 0,
            heard_anything: 0,
        }
    }

    fn check(&self) -> Result<()> {
        if self.magic == STABILIZER_MAGIC {
            Ok(())
        } else {
            Err(Status::InvalidArgument)
        }
    }

    pub fn offer(
        &mut self,
        elapsed_ms: u32,
        heard: Heard,
        reading: Option<Reading>,
    ) -> Result<Verdict> {
        self.check()?;

        if heard != Heard::Silence {
            self.heard_anything = 1;
        }

        if heard == Heard::Reading {
            let reading = reading.ok_or(Status::InvalidArgument)?;
            if reading.stability == Stability::Stable {
                if self.repeats > 0
                    && self.last_scaled == reading.scaled
                    && self.last_decimals == reading.decimals
                {
                    self.repeats += 1;
                } else {
                    self.repeats = 1;
                }
                self.last_scaled = reading.scaled;
                self.last_decimals = reading.decimals;
                if self.repeats >= self.needed {
                    return Ok(Verdict::Settled);
                }
            } else {
                // Motion, overload, underload: the run is broken. An overload
                // will never settle, but saying so is the scale's job, not a
                // guess this rule is entitled to make.
                self.repeats = 0;
            }
        }

        // Checked after settling, so a reading that arrives exactly on the
        // deadline still counts. A sale should not be refused a weight the
        // scale actually sent.
        if elapsed_ms >= self.budget_ms {
            return Ok(if self.heard_anything == 1 {
                Verdict::Expired
            } else {
                Verdict::NoAnswer
            });
        }

        Ok(Verdict::NotYet)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    // -----------------------------------------------------------------------
    // The wire corpus
    // -----------------------------------------------------------------------
    //
    // Lines a serial scale actually puts on the wire, each with what it must
    // be read as. Every case goes through `parse`, terminator and all, so the
    // assertions are about bytes off a port rather than about a function
    // having been called.
    //
    // The same corpus is held by the consuming product
    // (`test/fixtures/scale_wire_lines.dart` in TelePOS) and by this package's
    // Dart suite. Deliberately copied rather than shared: a published package
    // cannot depend on an application's test tree, and the three copies are
    // kept honest by the fact that all three name the same defects.

    #[derive(Debug, Clone, Copy)]
    struct WireLine {
        protocol: Protocol,
        line: &'static str,
        what: &'static str,
        /// The value this frame must be read as, as a decimal literal.
        /// `None` is the strongest expectation here: **no reading at all**.
        weight: Option<&'static str>,
        unit: Unit,
        stability: Stability,
    }

    impl WireLine {
        fn reads(
            protocol: Protocol,
            line: &'static str,
            weight: &'static str,
            what: &'static str,
        ) -> Self {
            WireLine {
                protocol,
                line,
                what,
                weight: Some(weight),
                unit: Unit::Kilogram,
                stability: Stability::Stable,
            }
        }

        fn refused(protocol: Protocol, line: &'static str, what: &'static str) -> Self {
            WireLine {
                protocol,
                line,
                what,
                weight: None,
                unit: Unit::Kilogram,
                stability: Stability::Stable,
            }
        }

        fn unit(mut self, unit: Unit) -> Self {
            self.unit = unit;
            self
        }

        fn stability(mut self, stability: Stability) -> Self {
            self.stability = stability;
            self
        }
    }

    /// `scaled` and `decimals` rendered exactly, with no float in between.
    fn decimal_text(scaled: i64, decimals: u32) -> String {
        if decimals == 0 {
            return scaled.to_string();
        }
        let digits = scaled.abs().to_string();
        let padded = format!("{:0>width$}", digits, width = decimals as usize + 1);
        let cut = padded.len() - decimals as usize;
        format!(
            "{}{}.{}",
            if scaled < 0 { "-" } else { "" },
            &padded[..cut],
            &padded[cut..]
        )
    }

    fn corpus() -> Vec<WireLine> {
        use Protocol::{Cas, Generic, MassaK};
        vec![
            // ------------------------------------------------------- CAS ---
            // `<status>,<type>,<sign><right-justified number><unit>`. The sign
            // sits at the left edge of a fixed-width numeric slot, so padding
            // between it and the digits is the ordinary case.
            WireLine::reads(
                Cas,
                "ST,NT,-  0.500kg",
                "-0.500",
                "PADDED NEGATIVE — net weight below zero after a tare, i.e. a \
                 return. The defect: the sign dropped, and half a kilo given \
                 back booked as half a kilo sold",
            )
            .stability(Stability::Stable),
            WireLine::reads(
                Cas,
                "ST,GS,+  1.250kg",
                "1.250",
                "padded positive — same slot, sign the other way",
            ),
            WireLine::reads(
                Cas,
                "ST,GS,   0.000kg",
                "0.000",
                "empty platform — zero, with the sign slot blank",
            ),
            WireLine::reads(
                Cas,
                "US,GS,+  0.732kg",
                "0.732",
                "unstable — the load is still moving",
            )
            .stability(Stability::Unstable),
            WireLine::reads(
                Cas,
                "OL,GS,+  9.999kg",
                "0",
                "OVERLOAD — over capacity; the number in the slot is the \
                 full-scale value, not a weight",
            )
            .stability(Stability::Overload),
            WireLine::reads(
                Cas,
                "OL,GS,",
                "0",
                "OVERLOAD with the value slot blank — the frame this parser \
                 used to throw away entirely, leaving the caller to wait out \
                 its whole budget",
            )
            .stability(Stability::Overload),
            WireLine::reads(
                Cas,
                "UL,GS,",
                "0",
                "under capacity — the pan is missing or the load cell is \
                 below zero; likewise reported without a readable number",
            )
            .stability(Stability::Underload),
            WireLine::reads(
                Cas,
                "ST,GS,+ 1005.0 g",
                "1005.0",
                "gram mode, just over a kilo — the unit slot says «g» and must \
                 be believed; read as kilograms this is 1005 kg",
            )
            .unit(Unit::Gram),
            WireLine::reads(
                Cas,
                "ST,GS,-  500.0 g",
                "-500.0",
                "gram mode AND a padded negative at once — both defects on one \
                 line",
            )
            .unit(Unit::Gram),
            WireLine::reads(
                Cas,
                "ST,GS,+  0.0005kg",
                "0.0005",
                "rounding boundary — half a gram, where the rounding direction \
                 shows",
            ),
            WireLine::reads(
                Cas,
                "ST,GS,+  0.100kg",
                "0.100",
                "one tenth — half of the pair a double would add up wrong",
            ),
            WireLine::reads(
                Cas,
                "ST,GS,+  0.200kg",
                "0.200",
                "two tenths — the other half of that pair",
            ),
            WireLine::refused(
                Cas,
                "ST,GS,",
                "MUST NOT PARSE — a truncated frame carries no weight",
            ),
            WireLine::refused(
                Cas,
                "CAS PD-II  Ver 1.00",
                "MUST NOT PARSE — the power-up banner; «1.00» is a firmware \
                 version, not a kilo",
            ),
            // --------------------------------------------------- Massa-K ---
            WireLine::reads(
                MassaK,
                "$ -  0.500",
                "-0.500",
                "PADDED NEGATIVE — same slot layout, same dropped sign",
            ),
            WireLine::reads(
                MassaK,
                "$    1.250",
                "1.250",
                "padded positive with no sign character at all",
            ),
            WireLine::reads(MassaK, "$    0.000", "0.000", "empty platform"),
            WireLine::reads(
                MassaK,
                "$   1.250 кг",
                "1.250",
                "Cyrillic unit in the unit slot — falls back to kilograms, \
                 which is what «кг» means anyway",
            ),
            WireLine::reads(
                MassaK,
                "   12.345",
                "12.345",
                "unstable — the marker slot is blank, and the line is trimmed \
                 before it gets here. Cutting the first character regardless \
                 read this as 2.345",
            )
            .stability(Stability::Unstable),
            WireLine::refused(
                MassaK,
                "$",
                "MUST NOT PARSE — marker with nothing behind it",
            ),
            WireLine::refused(
                MassaK,
                "#####",
                "MUST NOT PARSE — line noise from a wrong baud rate",
            ),
            // --------------------------------------------------- generic ---
            WireLine::reads(
                Generic,
                "-  0.500 kg",
                "-0.500",
                "PADDED NEGATIVE — bare weight line, sign padded away from the \
                 digits",
            ),
            WireLine::reads(Generic, "   1.250 kg", "1.250", "padded positive"),
            WireLine::reads(Generic, "0.000 kg", "0.000", "zero, unpadded"),
            WireLine::reads(
                Generic,
                "~  0.732 kg",
                "0.732",
                "unstable — «~» is this dialect's motion marker",
            )
            .stability(Stability::Unstable),
            WireLine::reads(
                Generic,
                "OL",
                "0",
                "OVERLOAD — the marker arrives with no number behind it at all",
            )
            .stability(Stability::Overload),
            WireLine::reads(
                Generic,
                "-OL- kg",
                "0",
                "OVERLOAD written the way a display blanks it",
            )
            .stability(Stability::Overload),
            WireLine::reads(
                Generic,
                "TOL 1.500 kg",
                "1.500",
                "a checkweighing tolerance marker — «TOL» contains «OL» and \
                 must not be taken for one",
            ),
            WireLine::reads(
                Generic,
                "ST,+00000.50 g",
                "0.50",
                "zero-padded gram frame — half a gram; read as kilograms it is \
                 half a tonne",
            )
            .unit(Unit::Gram),
            WireLine::reads(
                Generic,
                "  1.500 lbs",
                "1.500",
                "pounds, stated — the third unit a scale can name",
            )
            .unit(Unit::Pound),
            WireLine::refused(
                Generic,
                "ERROR",
                "MUST NOT PARSE — the scale reporting its own fault",
            ),
            WireLine::refused(Generic, "------", "MUST NOT PARSE — a blanked display"),
        ]
    }

    #[test]
    fn every_frame_in_the_corpus_is_read_exactly_as_it_is_meant() {
        // Walked as a whole and every disagreement collected, so one red run
        // names all of them rather than the first.
        let mut wrong: Vec<String> = Vec::new();

        for w in corpus() {
            let mut bytes = w.line.as_bytes().to_vec();
            bytes.extend_from_slice(b"\r\n");
            let parsed = parse(w.protocol, &bytes);

            if parsed.consumed != bytes.len() {
                wrong.push(format!(
                    "{}: \"{}\" — {}\n    consumed expected: {}\n    consumed got: {}",
                    w.protocol.name(),
                    w.line,
                    w.what,
                    bytes.len(),
                    parsed.consumed
                ));
            }

            let head = format!("{}: \"{}\" — {}", w.protocol.name(), w.line, w.what);
            match (w.weight, parsed.frame) {
                (None, Frame::Garbage) => {}
                (None, other) => wrong.push(format!(
                    "{head}\n    expected: no reading\n    got: {other:?}"
                )),
                (Some(expected), Frame::Reading(r)) => {
                    let got = decimal_text(r.scaled, r.decimals);
                    if got != expected {
                        wrong.push(format!(
                            "{head}\n    weight expected: {expected}\n    weight got: {got}"
                        ));
                    }
                    if r.unit != w.unit {
                        wrong.push(format!(
                            "{head}\n    unit expected: {}\n    unit got: {}",
                            w.unit.name(),
                            r.unit.name()
                        ));
                    }
                    if r.stability != w.stability {
                        wrong.push(format!(
                            "{head}\n    stability expected: {}\n    stability got: {}",
                            w.stability.name(),
                            r.stability.name()
                        ));
                    }
                }
                (Some(expected), other) => wrong.push(format!(
                    "{head}\n    expected: {expected}\n    got: {other:?}"
                )),
            }
        }

        assert!(wrong.is_empty(), "\n{}", wrong.join("\n\n"));
    }

    #[test]
    fn the_corpus_itself_still_covers_what_it_claims_to() {
        // A corpus quietly emptied of its hard cases is a green run that
        // proves nothing, so the shape of the set is asserted too.
        for protocol in [Protocol::Generic, Protocol::Cas, Protocol::MassaK] {
            let mine: Vec<WireLine> = corpus()
                .into_iter()
                .filter(|w| w.protocol == protocol)
                .collect();
            assert!(
                mine.iter()
                    .any(|w| w.weight.is_some_and(|v| v.starts_with('-'))),
                "{}: no negative frame to lose the sign of",
                protocol.name()
            );
            assert!(
                mine.iter().any(|w| w.weight.is_none()),
                "{}: no frame that must be refused, so it cannot tell \"read \
                 the weight\" from \"read anything\"",
                protocol.name()
            );
            assert!(
                mine.iter().any(|w| w.weight == Some("0.000")),
                "{}: no reading at zero",
                protocol.name()
            );
        }
        for protocol in [Protocol::Generic, Protocol::Cas] {
            assert!(
                corpus()
                    .iter()
                    .any(|w| w.protocol == protocol && w.stability == Stability::Overload),
                "{}: no overload frame",
                protocol.name()
            );
        }
        for unit in [Unit::Gram, Unit::Pound] {
            assert!(
                corpus().iter().any(|w| w.unit == unit),
                "no frame stating {}",
                unit.name()
            );
        }
    }

    #[test]
    fn a_stated_unit_is_reported_in_every_dialect_that_can_state_one() {
        // The defect this pins: `parse_generic` hard-coded kilograms while
        // the wire carried the unit, so a scale in gram mode reporting half a
        // kilo was read as five hundred kilograms.
        for (protocol, line, unit) in [
            (Protocol::Generic, &b"  500.0 g\r\n"[..], Unit::Gram),
            (Protocol::Generic, &b"  1.500 kg\r\n"[..], Unit::Kilogram),
            (Protocol::Cas, &b"ST,GS,  500.0 g\r\n"[..], Unit::Gram),
            (Protocol::MassaK, &b"$  500.0 g\r\n"[..], Unit::Gram),
        ] {
            match parse(protocol, line).frame {
                Frame::Reading(r) => assert_eq!(
                    r.unit,
                    unit,
                    "{}: {:?}",
                    protocol.name(),
                    core::str::from_utf8(line).unwrap()
                ),
                other => panic!("expected a reading, got {other:?}"),
            }
        }
    }

    #[test]
    fn the_unit_is_the_one_beside_the_number_not_the_last_word_on_the_line() {
        match parse(Protocol::Generic, b"  1.500 kg NET\r\n").frame {
            Frame::Reading(r) => assert_eq!(r.unit, Unit::Kilogram),
            other => panic!("expected a reading, got {other:?}"),
        }
    }

    #[test]
    fn an_overload_is_reported_even_when_the_value_slot_is_blank() {
        // The frame that used to be dropped: three fields are there but the
        // third holds nothing, and a parser that insists on a number returns
        // "garbage" for the one line that says why the scale will never
        // settle.
        for line in [&b"OL,GS,\r\n"[..], &b"OL,GS,   \r\n"[..], &b"OL\r\n"[..]] {
            match parse(Protocol::Cas, line).frame {
                Frame::Reading(r) => {
                    assert_eq!(r.stability, Stability::Overload);
                    assert_eq!((r.scaled, r.decimals), (0, 0));
                }
                other => panic!(
                    "{:?} expected a reading, got {other:?}",
                    core::str::from_utf8(line).unwrap()
                ),
            }
        }
    }

    #[test]
    fn a_generic_overload_marker_is_not_confused_with_a_word_containing_it() {
        for line in [&b"OL\r\n"[..], &b"-OL-\r\n"[..], &b"OL kg\r\n"[..]] {
            match parse(Protocol::Generic, line).frame {
                Frame::Reading(r) => assert_eq!(r.stability, Stability::Overload),
                other => panic!("expected an overload, got {other:?}"),
            }
        }
        for line in [
            &b"TOL 1.500 kg\r\n"[..],
            &b"OLD 1.500 kg\r\n"[..],
            &b"CTRL_OL1 1.500 kg\r\n"[..],
        ] {
            match parse(Protocol::Generic, line).frame {
                Frame::Reading(r) => assert_eq!(
                    r.stability,
                    Stability::Stable,
                    "{:?}",
                    core::str::from_utf8(line).unwrap()
                ),
                other => panic!("expected a reading, got {other:?}"),
            }
        }
    }

    #[test]
    fn massa_k_has_no_overload_state_and_says_so_by_never_settling() {
        // Deliberate, not missing. This dialect's over-capacity marker is not
        // established, and a guessed one produces a false refusal that stops a
        // sale — worse than the honest "answers but never settles" below.
        let frame = parse(Protocol::MassaK, b"   12.345\r\n").frame;
        match frame {
            Frame::Reading(r) => assert_eq!(r.stability, Stability::Unstable),
            other => panic!("expected a reading, got {other:?}"),
        }
        let mut rule = Stabilizer::new(1, 1_000);
        let unsettled = Some(reading(12_345, 3, Stability::Unstable));
        assert_eq!(
            rule.offer(0, Heard::Reading, unsettled).unwrap(),
            Verdict::NotYet
        );
        assert_eq!(
            rule.offer(1_000, Heard::Reading, unsettled).unwrap(),
            Verdict::Expired
        );
    }

    fn reading(scaled: i64, decimals: u32, stability: Stability) -> Reading {
        Reading {
            scaled,
            decimals,
            unit: Unit::Kilogram,
            stability,
            measure: Measure::Unknown,
        }
    }

    #[test]
    fn requests_are_the_bytes_the_scales_expect() {
        assert_eq!(Protocol::Generic.weight_request(), &[0x57, 0x0D]);
        assert_eq!(Protocol::Cas.weight_request(), &[0x57, 0x0D]);
        assert_eq!(Protocol::MassaK.weight_request(), &[0x4E, 0x0D]);
        assert_eq!(Protocol::Cas.tare_request(), &[0x54, 0x0D]);
    }

    #[test]
    fn cas_line_yields_weight_stability_and_measure() {
        let p = parse(Protocol::Cas, b"ST,GS,+  1.234kg\r\n");
        assert_eq!(p.consumed, 18);
        assert_eq!(
            p.frame,
            Frame::Reading(Reading {
                scaled: 1234,
                decimals: 3,
                unit: Unit::Kilogram,
                stability: Stability::Stable,
                measure: Measure::Gross,
            })
        );
    }

    #[test]
    fn cas_overload_is_not_merely_unstable() {
        let p = parse(Protocol::Cas, b"OL,GS,  0.000kg\r\n");
        match p.frame {
            Frame::Reading(r) => assert_eq!(r.stability, Stability::Overload),
            other => panic!("expected a reading, got {other:?}"),
        }
    }

    #[test]
    fn cas_net_is_reported() {
        let p = parse(Protocol::Cas, b"US,NT,-  0.500kg\n");
        match p.frame {
            Frame::Reading(r) => {
                assert_eq!(r.measure, Measure::Net);
                assert_eq!(r.stability, Stability::Unstable);
                assert_eq!(r.scaled, -500);
                assert_eq!(r.decimals, 3);
            }
            other => panic!("expected a reading, got {other:?}"),
        }
    }

    #[test]
    fn cas_reads_grams_when_the_scale_says_grams() {
        let p = parse(Protocol::Cas, b"ST,GS,  250.0g\r\n");
        match p.frame {
            Frame::Reading(r) => {
                assert_eq!(r.unit, Unit::Gram);
                assert_eq!((r.scaled, r.decimals), (2500, 1));
            }
            other => panic!("expected a reading, got {other:?}"),
        }
    }

    #[test]
    fn massa_k_dollar_means_settled() {
        let p = parse(Protocol::MassaK, b"$  12.345\r\n");
        match p.frame {
            Frame::Reading(r) => {
                assert_eq!(r.stability, Stability::Stable);
                assert_eq!((r.scaled, r.decimals), (12345, 3));
            }
            other => panic!("expected a reading, got {other:?}"),
        }
        let moving = parse(Protocol::MassaK, b"?  12.345\r\n");
        match moving.frame {
            Frame::Reading(r) => assert_eq!(r.stability, Stability::Unstable),
            other => panic!("expected a reading, got {other:?}"),
        }
    }

    #[test]
    fn generic_treats_a_tilde_or_an_m_as_motion() {
        match parse(Protocol::Generic, b"  1.500 kg\r\n").frame {
            Frame::Reading(r) => assert_eq!(r.stability, Stability::Stable),
            other => panic!("expected a reading, got {other:?}"),
        }
        match parse(Protocol::Generic, b"~ 1.500 kg\r\n").frame {
            Frame::Reading(r) => assert_eq!(r.stability, Stability::Unstable),
            other => panic!("expected a reading, got {other:?}"),
        }
        match parse(Protocol::Generic, b"M 1.500 kg\r\n").frame {
            Frame::Reading(r) => assert_eq!(r.stability, Stability::Unstable),
            other => panic!("expected a reading, got {other:?}"),
        }
    }

    #[test]
    fn generic_does_not_mistake_a_bare_integer_for_a_weight() {
        match parse(Protocol::Generic, b"ID 7  W 1.234\r\n").frame {
            Frame::Reading(r) => assert_eq!((r.scaled, r.decimals), (1234, 3)),
            other => panic!("expected a reading, got {other:?}"),
        }
    }

    #[test]
    fn a_sign_padded_away_from_its_digits_is_still_a_sign_in_a_field() {
        // How CAS actually pads. The previous implementation's regular
        // expression `([+-]?\d+[.,]\d+)` could not match across the spaces and
        // returned plus half a kilo for minus half a kilo — a returned item
        // read as a sold one.
        match parse(Protocol::Cas, b"ST,NT,-  0.500kg\r\n").frame {
            Frame::Reading(r) => assert_eq!(r.scaled, -500),
            other => panic!("expected a reading, got {other:?}"),
        }
        match parse(Protocol::MassaK, b"$-  1.250\r\n").frame {
            Frame::Reading(r) => assert_eq!(r.scaled, -1250),
            other => panic!("expected a reading, got {other:?}"),
        }
    }

    #[test]
    fn a_delimited_field_may_carry_a_whole_number_of_kilograms() {
        match parse(Protocol::Cas, b"ST,GS,  2kg\r\n").frame {
            Frame::Reading(r) => assert_eq!((r.scaled, r.decimals), (2, 0)),
            other => panic!("expected a reading, got {other:?}"),
        }
        // ...but a whole-line scan still will not, because a bare integer on
        // an unstructured line is as likely to be an identifier as a weight.
        assert_eq!(
            parse(Protocol::Generic, b"  2 kg\r\n").frame,
            Frame::Garbage
        );
    }

    #[test]
    fn a_comma_decimal_is_a_decimal_and_not_a_fourth_field() {
        // The trap a delimited field opens: this dialect delimits with the
        // character half of Europe writes decimals with. Split naively, the
        // weight slot holds `+  1` — a whole kilogram, which a delimited field
        // is entitled to accept — and 1.234 kg goes onto a receipt as 1 kg.
        match parse(Protocol::Cas, b"ST,GS,+  1,234kg\r\n").frame {
            Frame::Reading(r) => {
                assert_eq!((r.scaled, r.decimals), (1234, 3));
                assert_eq!(r.unit, Unit::Kilogram);
            }
            other => panic!("expected a reading, got {other:?}"),
        }
    }

    #[test]
    fn a_line_without_a_terminator_is_incomplete_and_consumes_nothing() {
        let p = parse(Protocol::Cas, b"ST,GS,+  1.2");
        assert_eq!(p.frame, Frame::Incomplete);
        assert_eq!(p.consumed, 0);
    }

    #[test]
    fn an_unreadable_line_is_garbage_and_can_be_skipped() {
        let p = parse(Protocol::Cas, b"hello\r\nST,GS,  2.000kg\r\n");
        assert_eq!(p.frame, Frame::Garbage);
        assert_eq!(p.consumed, 7);
        let next = parse(
            Protocol::Cas,
            &b"hello\r\nST,GS,  2.000kg\r\n"[p.consumed..],
        );
        match next.frame {
            Frame::Reading(r) => assert_eq!(r.scaled, 2000),
            other => panic!("expected a reading, got {other:?}"),
        }
    }

    #[test]
    fn a_split_read_reassembles_without_losing_the_frame() {
        let mut buffer: Vec<u8> = Vec::new();
        buffer.extend_from_slice(b"ST,GS,+  1.2");
        let first = parse(Protocol::Cas, &buffer);
        assert_eq!(first.frame, Frame::Incomplete);
        buffer.extend_from_slice(b"34kg\r\n");
        let second = parse(Protocol::Cas, &buffer);
        match second.frame {
            Frame::Reading(r) => assert_eq!(r.scaled, 1234),
            other => panic!("expected a reading, got {other:?}"),
        }
    }

    #[test]
    fn settles_on_the_first_settled_reading_when_one_is_asked_for() {
        let mut s = Stabilizer::new(1, 10_000);
        assert_eq!(
            s.offer(0, Heard::Reading, Some(reading(1234, 3, Stability::Stable)))
                .unwrap(),
            Verdict::Settled
        );
    }

    #[test]
    fn a_changing_weight_restarts_the_run() {
        let mut s = Stabilizer::new(3, 10_000);
        assert_eq!(
            s.offer(0, Heard::Reading, Some(reading(1000, 3, Stability::Stable)))
                .unwrap(),
            Verdict::NotYet
        );
        assert_eq!(
            s.offer(
                200,
                Heard::Reading,
                Some(reading(1001, 3, Stability::Stable))
            )
            .unwrap(),
            Verdict::NotYet
        );
        assert_eq!(
            s.offer(
                400,
                Heard::Reading,
                Some(reading(1001, 3, Stability::Stable))
            )
            .unwrap(),
            Verdict::NotYet
        );
        assert_eq!(
            s.offer(
                600,
                Heard::Reading,
                Some(reading(1001, 3, Stability::Stable))
            )
            .unwrap(),
            Verdict::Settled
        );
    }

    #[test]
    fn silence_to_the_end_of_the_budget_is_no_answer_not_a_timeout() {
        let mut s = Stabilizer::new(1, 1_000);
        assert_eq!(s.offer(0, Heard::Silence, None).unwrap(), Verdict::NotYet);
        assert_eq!(s.offer(999, Heard::Silence, None).unwrap(), Verdict::NotYet);
        assert_eq!(
            s.offer(1_000, Heard::Silence, None).unwrap(),
            Verdict::NoAnswer
        );
    }

    #[test]
    fn a_scale_that_talks_but_never_settles_expires_rather_than_going_silent() {
        let mut s = Stabilizer::new(1, 1_000);
        assert_eq!(
            s.offer(
                0,
                Heard::Reading,
                Some(reading(1000, 3, Stability::Unstable))
            )
            .unwrap(),
            Verdict::NotYet
        );
        assert_eq!(
            s.offer(
                1_000,
                Heard::Reading,
                Some(reading(1002, 3, Stability::Unstable))
            )
            .unwrap(),
            Verdict::Expired
        );
    }

    #[test]
    fn noise_alone_still_counts_as_the_scale_being_there() {
        let mut s = Stabilizer::new(1, 500);
        assert_eq!(s.offer(0, Heard::Noise, None).unwrap(), Verdict::NotYet);
        assert_eq!(
            s.offer(500, Heard::Silence, None).unwrap(),
            Verdict::Expired
        );
    }

    #[test]
    fn a_reading_arriving_exactly_on_the_deadline_still_settles() {
        let mut s = Stabilizer::new(1, 1_000);
        assert_eq!(
            s.offer(
                1_000,
                Heard::Reading,
                Some(reading(1234, 3, Stability::Stable))
            )
            .unwrap(),
            Verdict::Settled
        );
    }

    #[test]
    fn an_overload_never_settles() {
        let mut s = Stabilizer::new(1, 1_000);
        for t in [0u32, 200, 400, 600, 800] {
            assert_eq!(
                s.offer(t, Heard::Reading, Some(reading(0, 3, Stability::Overload)))
                    .unwrap(),
                Verdict::NotYet
            );
        }
        assert_eq!(
            s.offer(
                1_000,
                Heard::Reading,
                Some(reading(0, 3, Stability::Overload))
            )
            .unwrap(),
            Verdict::Expired
        );
    }
}

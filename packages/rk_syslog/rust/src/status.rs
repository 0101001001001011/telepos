//! Every way this library can fail, as a value.
//!
//! И144: a failure comes back as a returned status, never as a panic escaping
//! into a foreign stack and never as a process abort. Every `extern "C"`
//! entry point in [`crate::ffi`] returns one of these.
//!
//! И147 applies here too. The numeric discriminants are a wire encoding and
//! are **append-only**: a code, once assigned, never changes meaning and is
//! never reused. But the meaning that crosses the boundary is the *name* —
//! [`Status::name`] is exported so a binding maps by name and can tell an
//! unknown code apart from a misread one, instead of trusting a position in a
//! list that a future version might reorder.

/// A result code returned across the C ABI.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
#[repr(i32)]
pub enum Status {
    /// The call did what it said.
    Ok = 0,
    /// A pointer argument that must not be null was null.
    NullArgument = 1,
    /// A string argument was not valid UTF-8.
    InvalidUtf8 = 2,
    /// A configuration key is not one this version knows.
    UnknownConfigKey = 3,
    /// A configuration key was given a value it cannot take.
    InvalidConfigValue = 4,
    /// A configuration key that has no default was not set.
    MissingConfigKey = 5,
    /// A severity name is not one of the eight in RFC 5424.
    UnknownSeverity = 6,
    /// A facility name is not one of the twenty-four in RFC 5424.
    UnknownFacility = 7,
    /// A header field breaks RFC 5424: wrong length, or a byte outside
    /// PRINTUSASCII.
    InvalidHeaderField = 8,
    /// A structured-data name or value breaks RFC 5424.
    InvalidStructuredData = 9,
    /// The message itself cannot be framed — an oversize record under the
    /// `reject` rule, or an invalid timestamp.
    InvalidMessage = 10,
    /// The hand-off queue is full and its rule is `reject`. The record was
    /// not accepted; the caller still has it.
    QueueFull = 11,
    /// The spool is full and its rule is `reject`. The record was not
    /// accepted; the caller still has it.
    SpoolFull = 12,
    /// The spool could not be read or written.
    SpoolIo = 13,
    /// The collector could not be reached or written to. Never returned from
    /// `submit` — submitting does not touch the network.
    TransportIo = 14,
    /// The TLS settings could not be turned into a usable client
    /// configuration.
    TlsConfig = 15,
    /// A bounded wait ran out before the thing it waited for happened.
    Timeout = 16,
    /// The sink has been closed.
    Closed = 17,
    /// A panic was caught at the boundary. This is a defect in this library;
    /// it is reported rather than allowed to unwind into the caller.
    Panicked = 18,
    /// A handle was null, or was not one this library handed out.
    InvalidHandle = 19,
    /// A counter name is not one this version publishes.
    UnknownStat = 20,
}

impl Status {
    /// The stable name of this status. Bindings map by this, not by the
    /// number.
    pub const fn name(self) -> &'static str {
        match self {
            Status::Ok => "ok",
            Status::NullArgument => "nullArgument",
            Status::InvalidUtf8 => "invalidUtf8",
            Status::UnknownConfigKey => "unknownConfigKey",
            Status::InvalidConfigValue => "invalidConfigValue",
            Status::MissingConfigKey => "missingConfigKey",
            Status::UnknownSeverity => "unknownSeverity",
            Status::UnknownFacility => "unknownFacility",
            Status::InvalidHeaderField => "invalidHeaderField",
            Status::InvalidStructuredData => "invalidStructuredData",
            Status::InvalidMessage => "invalidMessage",
            Status::QueueFull => "queueFull",
            Status::SpoolFull => "spoolFull",
            Status::SpoolIo => "spoolIo",
            Status::TransportIo => "transportIo",
            Status::TlsConfig => "tlsConfig",
            Status::Timeout => "timeout",
            Status::Closed => "closed",
            Status::Panicked => "panicked",
            Status::InvalidHandle => "invalidHandle",
            Status::UnknownStat => "unknownStat",
        }
    }

    /// Every status this version defines, for a binding that wants to check
    /// its own table against ours rather than assume they agree.
    pub const ALL: [Status; 21] = [
        Status::Ok,
        Status::NullArgument,
        Status::InvalidUtf8,
        Status::UnknownConfigKey,
        Status::InvalidConfigValue,
        Status::MissingConfigKey,
        Status::UnknownSeverity,
        Status::UnknownFacility,
        Status::InvalidHeaderField,
        Status::InvalidStructuredData,
        Status::InvalidMessage,
        Status::QueueFull,
        Status::SpoolFull,
        Status::SpoolIo,
        Status::TransportIo,
        Status::TlsConfig,
        Status::Timeout,
        Status::Closed,
        Status::Panicked,
        Status::InvalidHandle,
        Status::UnknownStat,
    ];

    /// Look a status up by its wire number.
    pub fn from_code(code: i32) -> Option<Status> {
        Status::ALL.into_iter().find(|s| *s as i32 == code)
    }
}

/// A status plus a sentence saying which value was wrong and why.
///
/// The sentence is the whole point: `invalidHeaderField` on its own sends the
/// reader to the RFC, while "app_name: byte 3 is not PRINTUSASCII" sends them
/// to the line of code that set it.
#[derive(Debug, Clone)]
pub struct Failure {
    pub status: Status,
    pub detail: String,
}

impl Failure {
    pub fn new(status: Status, detail: impl Into<String>) -> Failure {
        Failure {
            status,
            detail: detail.into(),
        }
    }
}

/// The shape every fallible operation in this crate returns.
pub type Fallible<T> = Result<T, Failure>;

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn codes_are_unique_and_names_are_unique() {
        let mut codes: Vec<i32> = Status::ALL.iter().map(|s| *s as i32).collect();
        codes.sort_unstable();
        let before = codes.len();
        codes.dedup();
        assert_eq!(before, codes.len(), "two statuses share a wire code");

        let mut names: Vec<&str> = Status::ALL.iter().map(|s| s.name()).collect();
        names.sort_unstable();
        let before = names.len();
        names.dedup();
        assert_eq!(before, names.len(), "two statuses share a name");
    }

    #[test]
    fn wire_codes_are_pinned() {
        // This test is the append-only rule, written down. Changing a number
        // here means every already-shipped binding starts misreading
        // failures, so the test must be edited only to *add* a line.
        let expected: &[(&str, i32)] = &[
            ("ok", 0),
            ("nullArgument", 1),
            ("invalidUtf8", 2),
            ("unknownConfigKey", 3),
            ("invalidConfigValue", 4),
            ("missingConfigKey", 5),
            ("unknownSeverity", 6),
            ("unknownFacility", 7),
            ("invalidHeaderField", 8),
            ("invalidStructuredData", 9),
            ("invalidMessage", 10),
            ("queueFull", 11),
            ("spoolFull", 12),
            ("spoolIo", 13),
            ("transportIo", 14),
            ("tlsConfig", 15),
            ("timeout", 16),
            ("closed", 17),
            ("panicked", 18),
            ("invalidHandle", 19),
            ("unknownStat", 20),
        ];
        assert_eq!(expected.len(), Status::ALL.len());
        for (name, code) in expected {
            let found = Status::from_code(*code).expect("code missing");
            assert_eq!(found.name(), *name, "wire code {code} changed meaning");
        }
    }
}

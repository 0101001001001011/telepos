//! The one thing every fallible call reports, and it crosses as a name.
//!
//! И147 says enumerations cross the FFI boundary by name and never by number,
//! because a number changes meaning the moment a case is inserted into the
//! middle of a list. That applies to this type more than to any other in the
//! crate: it is the type a caller branches on.

/// Why a call did not produce what it was asked for.
///
/// Deliberately small. Every variant names a mistake the *caller* can act on;
/// none of them describe a device, because this crate never talks to one.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Status {
    Ok,
    /// A protocol / model / command / address / wire name this build does not
    /// know. Never silently substituted for a similar one: substituting would
    /// produce a plausibly working device of the wrong model.
    UnknownName,
    /// The operation exists, but not for the named model — an eight-character
    /// single-line display cannot be told to write its second line.
    UnsupportedOperation,
    /// The caller's output buffer is shorter than the result. `out_len` carries
    /// the length required, so the caller can allocate once and retry.
    BufferTooSmall,
    /// A pointer argument was null, or a length was impossible.
    InvalidArgument,
    /// A byte string that had to be text was not valid UTF-8.
    InvalidUtf8,
    /// A numeric argument was outside the range the protocol can encode — an
    /// ESC/POS drawer pulse longer than 510 ms, for instance.
    OutOfRange,
    /// A panic was caught at the boundary. This is a bug in this crate, not in
    /// the caller; it is reported as a value rather than unwound into a foreign
    /// stack (И144).
    Panic,
}

impl Status {
    pub const fn name(self) -> &'static str {
        match self {
            Status::Ok => "ok",
            Status::UnknownName => "unknown_name",
            Status::UnsupportedOperation => "unsupported_operation",
            Status::BufferTooSmall => "buffer_too_small",
            Status::InvalidArgument => "invalid_argument",
            Status::InvalidUtf8 => "invalid_utf8",
            Status::OutOfRange => "out_of_range",
            Status::Panic => "panic",
        }
    }

    /// The longest name any status has, in bytes, terminator excluded. The C
    /// header publishes this as a buffer size so a caller never has to guess.
    pub fn longest_name() -> usize {
        [
            Status::Ok,
            Status::UnknownName,
            Status::UnsupportedOperation,
            Status::BufferTooSmall,
            Status::InvalidArgument,
            Status::InvalidUtf8,
            Status::OutOfRange,
            Status::Panic,
        ]
        .iter()
        .map(|s| s.name().len())
        .max()
        .unwrap_or(0)
    }
}

pub type Result<T> = core::result::Result<T, Status>;

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn every_status_has_a_distinct_name() {
        let all = [
            Status::Ok,
            Status::UnknownName,
            Status::UnsupportedOperation,
            Status::BufferTooSmall,
            Status::InvalidArgument,
            Status::InvalidUtf8,
            Status::OutOfRange,
            Status::Panic,
        ];
        let mut names: Vec<&str> = all.iter().map(|s| s.name()).collect();
        names.sort_unstable();
        let before = names.len();
        names.dedup();
        assert_eq!(before, names.len(), "two statuses share a name: {names:?}");
    }

    #[test]
    fn longest_name_covers_the_longest_name() {
        assert_eq!(Status::longest_name(), "unsupported_operation".len());
    }
}

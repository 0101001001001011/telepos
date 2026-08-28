//! Statuses, and why they cross the boundary as names.
//!
//! И147: an enumeration crosses FFI **by name, never by index**. An integer
//! discriminant is a shared secret between two languages that no compiler
//! checks; inserting a variant in the middle silently re-labels every call
//! site on the other side. A name cannot be renumbered, and a name the reader
//! does not recognise reads as unknown rather than as the wrong branch.
//!
//! The cost is one pointer instead of one integer, and it is paid from
//! `static` storage — nothing is allocated, so nothing has to be freed
//! (И146).

use std::ffi::c_char;

/// Every way a call into this library can end.
///
/// The set is deliberately small and closed: a caller must be able to write a
/// total `switch` over it. Detail that varies per occurrence — which port,
/// which peer — belongs in the message from `rk_quic_last_error`, not in a new
/// variant.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Status {
    /// The call did what it said.
    Ok,
    /// A required argument was null, empty, or not the shape the call expects.
    InvalidArgument,
    /// The handle is not one this library issued, or has already been stopped.
    UnknownHandle,
    /// The UDP port is already bound by something else.
    PortInUse,
    /// The address could not be bound for a reason other than a taken port —
    /// no permission, no such interface.
    BindFailed,
    /// The certificate or key could not be read, or does not match.
    BadCertificate,
    /// The peer went away mid-session. Not an error of ours; a fact about the
    /// session, and the reason the caller stops writing to it.
    PeerGone,
    /// Nothing to report right now. Distinct from `Ok` so a poll loop can tell
    /// "no event" from "an event, handled".
    WouldBlock,
    /// The endpoint is not running.
    NotRunning,
    /// A panic was caught at the boundary. The process is still alive; the call
    /// did nothing. Seeing this is a bug in this library, and the caller is
    /// entitled to be told rather than to be aborted.
    Panic,
    /// The transport was compiled out of this build.
    Unsupported,
}

impl Status {
    /// The wire name, NUL-terminated, in `static` storage.
    ///
    /// Names are `lowerCamelCase` so they can be matched against Dart enum
    /// names without a translation table that could drift.
    pub const fn name_with_nul(self) -> &'static str {
        match self {
            Status::Ok => "ok\0",
            Status::InvalidArgument => "invalidArgument\0",
            Status::UnknownHandle => "unknownHandle\0",
            Status::PortInUse => "portInUse\0",
            Status::BindFailed => "bindFailed\0",
            Status::BadCertificate => "badCertificate\0",
            Status::PeerGone => "peerGone\0",
            Status::WouldBlock => "wouldBlock\0",
            Status::NotRunning => "notRunning\0",
            Status::Panic => "panic\0",
            Status::Unsupported => "unsupported\0",
        }
    }

    /// The same name without the terminator, for Rust-side tests and messages.
    pub fn name(self) -> &'static str {
        let with_nul = self.name_with_nul();
        &with_nul[..with_nul.len() - 1]
    }

    /// A pointer the caller must not free.
    pub fn as_c_str(self) -> *const c_char {
        self.name_with_nul().as_ptr() as *const c_char
    }

    /// Every variant, so a test can assert the set is closed and the names are
    /// distinct without repeating the list by hand.
    pub const ALL: &'static [Status] = &[
        Status::Ok,
        Status::InvalidArgument,
        Status::UnknownHandle,
        Status::PortInUse,
        Status::BindFailed,
        Status::BadCertificate,
        Status::PeerGone,
        Status::WouldBlock,
        Status::NotRunning,
        Status::Panic,
        Status::Unsupported,
    ];
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::collections::BTreeSet;

    #[test]
    fn every_name_is_nul_terminated() {
        for status in Status::ALL {
            assert!(
                status.name_with_nul().ends_with('\0'),
                "{status:?} is handed to C without a terminator"
            );
        }
    }

    #[test]
    fn names_are_distinct() {
        let names: BTreeSet<&str> = Status::ALL.iter().map(|s| s.name()).collect();
        assert_eq!(
            names.len(),
            Status::ALL.len(),
            "two statuses share a name, so the caller cannot tell them apart"
        );
    }

    #[test]
    fn no_name_contains_an_interior_nul() {
        for status in Status::ALL {
            assert!(
                !status.name().contains('\0'),
                "{status:?} would be truncated on the way out"
            );
        }
    }
}

//! Statuses that cross the C ABI **by name** (И147).
//!
//! Nothing here is ever sent as a number. The discriminants exist only so Rust
//! can match; the boundary sees `&'static CStr` bytes and nothing else. Insert
//! a case in the middle of this enum and no peer changes meaning, which is the
//! whole point of the invariant.

use std::os::raw::c_char;

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Status {
    /// The argument was wrong in a way the caller can see without us: a null
    /// pointer where one is required, a zero dimension, a bad UTF-8 path.
    InvalidArgument,

    // -- models -------------------------------------------------------------
    /// The manifest, or the weights file it names, is not on disk.
    ModelNotFound,
    /// The manifest is on disk but could not be read at all.
    ManifestUnreadable,
    /// The manifest parsed but a required key is missing, empty or malformed.
    /// The detail names the key.
    ManifestMalformed,
    /// The weights on disk are not the weights the manifest describes.
    ModelChecksumMismatch,
    /// The manifest asks for a schema, or a minimum ABI, this build does not
    /// implement.
    ModelIncompatible,
    /// The manifest is valid but is not the version this terminal is pinned
    /// to. A model must not change under a till because a repository moved on.
    ModelPinMismatch,

    // -- engine -------------------------------------------------------------
    /// The inference runtime is not installed, or is not loadable, on this
    /// host. The detail lists what was tried.
    EngineUnavailable,
    /// The runtime loaded but reports an API level this build cannot use.
    EngineIncompatible,
    /// The engine still has models loaded from it.
    EngineBusy,
    /// Reached a path that is specified and not yet implemented. Never
    /// returned alongside a plausible-looking result: the detail names exactly
    /// what is missing.
    NotImplemented,

    // -- frames -------------------------------------------------------------
    /// The pixel format name is not one this build accepts.
    UnsupportedPixelFormat,
    /// The frame does not match the shape the model's manifest declares.
    FrameShapeMismatch,
    /// A run currently borrows this frame.
    FrameInUse,

    // -- running ------------------------------------------------------------
    /// The runtime accepted the call and reported a failure of its own.
    InferenceFailed,
    /// A panic was caught at the boundary. This is a bug in this library, and
    /// it is reported as a value rather than unwinding into a foreign stack
    /// (И144).
    NativeFault,
}

impl Status {
    /// The NUL-terminated name, as the boundary sees it.
    pub const fn c_name(self) -> &'static [u8] {
        match self {
            Status::InvalidArgument => b"InvalidArgument\0",
            Status::ModelNotFound => b"ModelNotFound\0",
            Status::ManifestUnreadable => b"ManifestUnreadable\0",
            Status::ManifestMalformed => b"ManifestMalformed\0",
            Status::ModelChecksumMismatch => b"ModelChecksumMismatch\0",
            Status::ModelIncompatible => b"ModelIncompatible\0",
            Status::ModelPinMismatch => b"ModelPinMismatch\0",
            Status::EngineUnavailable => b"EngineUnavailable\0",
            Status::EngineIncompatible => b"EngineIncompatible\0",
            Status::EngineBusy => b"EngineBusy\0",
            Status::NotImplemented => b"NotImplemented\0",
            Status::UnsupportedPixelFormat => b"UnsupportedPixelFormat\0",
            Status::FrameShapeMismatch => b"FrameShapeMismatch\0",
            Status::FrameInUse => b"FrameInUse\0",
            Status::InferenceFailed => b"InferenceFailed\0",
            Status::NativeFault => b"NativeFault\0",
        }
    }

    /// The same name as a pointer the boundary can return directly. Static
    /// storage: the caller must not free it.
    pub const fn as_ptr(self) -> *const c_char {
        self.c_name().as_ptr() as *const c_char
    }

    /// The name without its NUL, for Rust-side assertions and messages.
    pub fn name(self) -> &'static str {
        let bytes = self.c_name();
        // Every literal above is ASCII and ends in a single NUL.
        std::str::from_utf8(&bytes[..bytes.len() - 1]).expect("status names are ASCII")
    }

    /// Every status this build can return, in declaration order. A binding
    /// that knows this list cannot be surprised by a name it has no case for.
    pub const ALL: &'static [Status] = &[
        Status::InvalidArgument,
        Status::ModelNotFound,
        Status::ManifestUnreadable,
        Status::ManifestMalformed,
        Status::ModelChecksumMismatch,
        Status::ModelIncompatible,
        Status::ModelPinMismatch,
        Status::EngineUnavailable,
        Status::EngineIncompatible,
        Status::EngineBusy,
        Status::NotImplemented,
        Status::UnsupportedPixelFormat,
        Status::FrameShapeMismatch,
        Status::FrameInUse,
        Status::InferenceFailed,
        Status::NativeFault,
    ];
}

/// A failure carrying the name that crosses and the detail that explains it.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Failure {
    pub status: Status,
    pub detail: String,
}

impl Failure {
    pub fn new(status: Status, detail: impl Into<String>) -> Self {
        Failure {
            status,
            detail: detail.into(),
        }
    }
}

pub type Outcome<T> = Result<T, Failure>;

#[cfg(test)]
mod tests {
    use super::*;
    use std::collections::HashSet;

    #[test]
    fn every_name_is_nul_terminated_exactly_once() {
        for s in Status::ALL {
            let bytes = s.c_name();
            assert_eq!(
                bytes.iter().filter(|b| **b == 0).count(),
                1,
                "{:?} must contain exactly one NUL",
                s
            );
            assert_eq!(*bytes.last().unwrap(), 0, "{:?} must end with NUL", s);
        }
    }

    #[test]
    fn names_are_unique_and_ascii() {
        let mut seen = HashSet::new();
        for s in Status::ALL {
            let n = s.name();
            assert!(!n.is_empty(), "{:?} has an empty name", s);
            assert!(n.is_ascii(), "{} is not ASCII", n);
            assert!(seen.insert(n), "duplicate status name {}", n);
        }
    }

    #[test]
    fn all_lists_every_variant() {
        // If a variant is added and not listed in ALL, the list of names the
        // binding validates against goes stale silently. This is the cheapest
        // place to catch that.
        assert_eq!(
            Status::ALL.len(),
            16,
            "Status::ALL must list every variant; update both together"
        );
    }
}

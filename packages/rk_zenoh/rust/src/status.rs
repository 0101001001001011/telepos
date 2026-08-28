//! Failure as a returned value (И144) and enums by name (И147).
//!
//! Every `extern "C"` function in this crate returns [`RkzStatus`], which is
//! `0` on success and non-zero on failure. **The non-zero value carries no
//! meaning.** The caller learns what happened from [`rkz_last_error_kind`],
//! which returns a stable, NUL-terminated *name* — never an index. Adding a
//! failure kind in the middle of the list therefore cannot silently change the
//! meaning of anything already parsed on the Dart side.
//!
//! A panic that reaches the boundary is converted the same way, so no Rust
//! unwind ever crosses into a foreign stack.

use std::cell::RefCell;
use std::ffi::{c_char, CString};
use std::panic::{catch_unwind, AssertUnwindSafe};

/// Success/failure of a call across the boundary. `0` means success.
pub type RkzStatus = i32;

/// The only status value with a meaning. Every other value means "look at
/// [`rkz_last_error_kind`]".
pub const RKZ_OK: RkzStatus = 0;
const RKZ_FAIL: RkzStatus = 1;

/// The kinds of failure this library reports, as names.
///
/// The Dart side parses [`ErrorKind::name`] and never sees the discriminant.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ErrorKind {
    /// A null pointer was passed where a handle was required.
    NullArgument,
    /// A string argument was not valid UTF-8.
    InvalidUtf8,
    /// A configuration document was rejected.
    InvalidConfig,
    /// A key expression was rejected by Zenoh's grammar.
    InvalidKeyExpression,
    /// An enum name crossing the boundary matched no known case.
    UnknownEnumName,
    /// The session could not be opened.
    SessionOpenFailed,
    /// The session is closed; the handle is still valid but useless.
    SessionClosed,
    /// A declaration (publisher, subscriber, queryable, token) failed.
    DeclarationFailed,
    /// A put/delete/reply did not reach the network stack.
    PublishFailed,
    /// A blocking receive ran out of time. Not an error in the usual sense;
    /// the caller normally loops.
    Timeout,
    /// The source of samples or replies is gone and will produce no more.
    Disconnected,
    /// A caller-provided buffer was too small; nothing was written.
    BufferTooSmall,
    /// Rust panicked below the boundary. Caught, never propagated.
    Panic,
    /// Anything Zenoh reported that we do not model more precisely.
    Backend,
}

impl ErrorKind {
    /// The stable name of this kind, NUL-terminated for C.
    pub const fn name(self) -> &'static str {
        match self {
            ErrorKind::NullArgument => "null_argument\0",
            ErrorKind::InvalidUtf8 => "invalid_utf8\0",
            ErrorKind::InvalidConfig => "invalid_config\0",
            ErrorKind::InvalidKeyExpression => "invalid_key_expression\0",
            ErrorKind::UnknownEnumName => "unknown_enum_name\0",
            ErrorKind::SessionOpenFailed => "session_open_failed\0",
            ErrorKind::SessionClosed => "session_closed\0",
            ErrorKind::DeclarationFailed => "declaration_failed\0",
            ErrorKind::PublishFailed => "publish_failed\0",
            ErrorKind::Timeout => "timeout\0",
            ErrorKind::Disconnected => "disconnected\0",
            ErrorKind::BufferTooSmall => "buffer_too_small\0",
            ErrorKind::Panic => "panic\0",
            ErrorKind::Backend => "backend\0",
        }
    }

    /// The name without the trailing NUL, for Rust-side assertions.
    pub fn as_str(self) -> &'static str {
        let n = self.name();
        &n[..n.len() - 1]
    }
}

thread_local! {
    static LAST: RefCell<Option<(ErrorKind, CString)>> = const { RefCell::new(None) };
}

/// A failure carrying its kind and a human-readable detail.
#[derive(Debug)]
pub struct RkzError {
    pub kind: ErrorKind,
    pub detail: String,
}

impl RkzError {
    pub fn new(kind: ErrorKind, detail: impl Into<String>) -> Self {
        RkzError {
            kind,
            detail: detail.into(),
        }
    }
}

/// Result type used by every internal function that can fail.
pub type RkzResult<T> = Result<T, RkzError>;

fn record(err: &RkzError) {
    // A detail containing an interior NUL is the library's own bug; degrade
    // rather than panic inside the error path.
    let detail = CString::new(err.detail.replace('\0', " "))
        .unwrap_or_else(|_| CString::new("<undisplayable>").expect("literal has no NUL"));
    LAST.with(|slot| *slot.borrow_mut() = Some((err.kind, detail)));
}

/// Wrap the body of an `extern "C"` function.
///
/// Catches panics (И144) and turns any failure into a returned status, leaving
/// the kind and detail retrievable from this thread.
pub fn guard<F>(body: F) -> RkzStatus
where
    F: FnOnce() -> RkzResult<()>,
{
    match catch_unwind(AssertUnwindSafe(body)) {
        Ok(Ok(())) => {
            LAST.with(|slot| *slot.borrow_mut() = None);
            RKZ_OK
        }
        Ok(Err(err)) => {
            record(&err);
            RKZ_FAIL
        }
        Err(payload) => {
            let detail = if let Some(s) = payload.downcast_ref::<&str>() {
                (*s).to_string()
            } else if let Some(s) = payload.downcast_ref::<String>() {
                s.clone()
            } else {
                "panic with an unknown payload".to_string()
            };
            record(&RkzError::new(ErrorKind::Panic, detail));
            RKZ_FAIL
        }
    }
}

/// The kind of the last failure **on the calling thread**, as a NUL-terminated
/// name.
///
/// Returns `"ok"` when the last call on this thread succeeded. The pointer is
/// static: the caller must never free it, and it stays valid forever.
#[no_mangle]
pub extern "C" fn rkz_last_error_kind() -> *const c_char {
    LAST.with(|slot| match slot.borrow().as_ref() {
        Some((kind, _)) => kind.name().as_ptr().cast(),
        None => "ok\0".as_ptr().cast(),
    })
}

/// A human-readable detail for the last failure on the calling thread.
///
/// The pointer is owned by this library and stays valid until the next call
/// on the same thread. The caller must never free it and must copy it before
/// calling anything else.
#[no_mangle]
pub extern "C" fn rkz_last_error_message() -> *const c_char {
    LAST.with(|slot| match slot.borrow().as_ref() {
        Some((_, detail)) => detail.as_ptr(),
        None => "\0".as_ptr().cast(),
    })
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::ffi::CStr;

    fn last_kind() -> String {
        // SAFETY: the function returns a static, NUL-terminated name.
        unsafe { CStr::from_ptr(rkz_last_error_kind()) }
            .to_string_lossy()
            .into_owned()
    }

    #[test]
    fn success_clears_the_slot() {
        guard(|| Err(RkzError::new(ErrorKind::Timeout, "x")));
        assert_eq!(last_kind(), "timeout");
        assert_eq!(guard(|| Ok(())), RKZ_OK);
        assert_eq!(last_kind(), "ok");
    }

    #[test]
    fn a_panic_becomes_a_status() {
        let status = guard(|| panic!("boundary must hold"));
        assert_ne!(status, RKZ_OK);
        assert_eq!(last_kind(), "panic");
        // SAFETY: valid until the next call on this thread; copied at once.
        let msg = unsafe { CStr::from_ptr(rkz_last_error_message()) }
            .to_string_lossy()
            .into_owned();
        assert!(msg.contains("boundary must hold"), "detail was {msg}");
    }

    #[test]
    fn every_kind_name_is_nul_terminated_and_unique() {
        let all = [
            ErrorKind::NullArgument,
            ErrorKind::InvalidUtf8,
            ErrorKind::InvalidConfig,
            ErrorKind::InvalidKeyExpression,
            ErrorKind::UnknownEnumName,
            ErrorKind::SessionOpenFailed,
            ErrorKind::SessionClosed,
            ErrorKind::DeclarationFailed,
            ErrorKind::PublishFailed,
            ErrorKind::Timeout,
            ErrorKind::Disconnected,
            ErrorKind::BufferTooSmall,
            ErrorKind::Panic,
            ErrorKind::Backend,
        ];
        let mut seen = std::collections::HashSet::new();
        for kind in all {
            assert!(
                kind.name().ends_with('\0'),
                "{kind:?} is not NUL-terminated"
            );
            assert!(seen.insert(kind.as_str()), "{kind:?} has a duplicate name");
        }
    }
}

//! The C ABI of `rk_quic`, and the three rules it keeps.
//!
//! 1. **И144 — a failure is a returned value.** No `extern "C"` function here
//!    unwinds into the caller and none aborts the process: every body runs
//!    inside `catch_unwind`, and a panic becomes the status `panic`.
//! 2. **И147 — enumerations cross by name.** A status leaves this library as a
//!    NUL-terminated *name* (`"ok"`, `"portInUse"`, …), never as an integer.
//!    Renumbering is therefore impossible, and a name the caller does not know
//!    is a name, not a wrong branch.
//! 3. **И146 — freeing is deterministic and one-sided.** Whoever allocated
//!    frees. Everything this module returns is either a pointer into `static`
//!    storage (never freed, valid for the life of the process) or a buffer
//!    allocated by Rust that the caller returns with
//!    [`rk_quic_string_free`]. Dart never calls `malloc`/`free` on memory
//!    that crossed this boundary.

use std::ffi::{c_char, CStr, CString};
use std::panic::{catch_unwind, AssertUnwindSafe};
use std::ptr;

use crate::status::Status;

/// Generation of this C ABI.
///
/// Bumped whenever a signature or an ownership rule changes — not when the
/// package version changes. The Dart side refuses to use a library whose
/// generation it does not know, which is the "version mismatch" failure path.
///
/// 1 → 2: bidirectional streams. `rk_quic_stream_send` and
/// `rk_quic_stream_close` were added, and three event kinds with them. A Dart
/// side that knows generation 2 would otherwise resolve a missing symbol in a
/// generation-1 library and take the till down with it, which is the one
/// failure this constant exists to turn into a sentence.
pub const RK_QUIC_ABI_VERSION: u32 = 2;

/// Package version, NUL-terminated, in `static` storage.
///
/// Compiled in from `Cargo.toml`, so the string a caller reads is the version
/// of the library actually loaded — which is the whole point of it not being a
/// Dart constant.
static VERSION: &str = concat!(env!("CARGO_PKG_VERSION"), "\0");

/// Returns the ABI generation. Cannot fail and allocates nothing.
#[no_mangle]
pub extern "C" fn rk_quic_abi_version() -> u32 {
    RK_QUIC_ABI_VERSION
}

/// Returns the library version as a NUL-terminated UTF-8 string.
///
/// # Ownership
/// The pointer is into `static` storage. The caller must **not** free it and
/// may hold it for the life of the process.
#[no_mangle]
pub extern "C" fn rk_quic_version() -> *const c_char {
    VERSION.as_ptr() as *const c_char
}

/// Frees a string this library allocated.
///
/// # Ownership
/// Only for pointers handed out by functions documented as "caller frees with
/// `rk_quic_string_free`". Passing null is a no-op; passing anything else —
/// a `static` pointer, a Dart pointer, a pointer already freed — is undefined
/// behaviour, which is why every allocating function says so in one place.
///
/// # Safety
/// `s` must be null or a pointer this library returned and that has not been
/// freed yet.
#[no_mangle]
pub unsafe extern "C" fn rk_quic_string_free(s: *mut c_char) {
    if s.is_null() {
        return;
    }
    // SAFETY: the caller promises `s` came from this library and is unfreed.
    let owned = unsafe { CString::from_raw(s) };
    // A panic while dropping would cross the boundary; swallow it here.
    let _ = catch_unwind(AssertUnwindSafe(move || drop(owned)));
}

/// Turns an owned Rust string into a pointer the caller frees.
pub fn into_owned_c_string(value: String) -> *mut c_char {
    // Interior NULs cannot be represented; a lossy replacement is better than a
    // null return the caller would read as "no message".
    match CString::new(value) {
        Ok(s) => s.into_raw(),
        Err(_) => CString::new("<string contained a NUL>")
            .expect("literal has no NUL")
            .into_raw(),
    }
}

/// Runs `body`, converting any panic into [`Status::Panic`].
///
/// This is the wall required by И144. Every `extern "C"` entry point in this
/// crate goes through it, so a bug in Rust surfaces as a status the caller can
/// branch on rather than as an unwind through a foreign frame — which is
/// undefined behaviour — or an abort, which takes the till down.
pub fn guard<F>(body: F) -> *const c_char
where
    F: FnOnce() -> Status,
{
    match catch_unwind(AssertUnwindSafe(body)) {
        Ok(status) => status.as_c_str(),
        Err(_) => Status::Panic.as_c_str(),
    }
}

/// Reads a borrowed C string, or `None` when it is null or not UTF-8.
///
/// # Safety
/// `s` must be null or a valid NUL-terminated string that outlives the call.
pub unsafe fn borrow_c_string<'a>(s: *const c_char) -> Option<&'a str> {
    if s.is_null() {
        return None;
    }
    // SAFETY: the caller promises a NUL-terminated string.
    unsafe { CStr::from_ptr(s) }.to_str().ok()
}

/// Writes `value` through `out` when `out` is non-null.
///
/// A null out-pointer is accepted rather than refused: a caller that only
/// wants the status should not have to invent somewhere to put a value it will
/// not read.
///
/// # Safety
/// `out` must be null or point to an aligned, writable `T`. Marked `unsafe`
/// rather than hiding the null check behind a safe signature — clippy is right
/// that a safe function which dereferences a caller's pointer is a lie, even
/// when it checks for null first.
pub unsafe fn write_out<T>(out: *mut T, value: T) {
    if !out.is_null() {
        // SAFETY: checked non-null; the caller promises an aligned, writable T.
        unsafe { ptr::write(out, value) };
    }
}

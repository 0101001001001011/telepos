//! The C ABI.
//!
//! # Who frees what (И146)
//!
//! The garbage collector on the other side knows nothing about any of this,
//! so ownership is stated once here and never inferred:
//!
//! | Value | Allocated by | Freed by |
//! | --- | --- | --- |
//! | every `char*` **returned** by this library | this library | the caller, with [`rk_pki_string_free`], exactly once |
//! | the engine handle from [`rk_pki_engine_open`] | this library | the caller, with [`rk_pki_engine_close`], exactly once |
//! | every `const char*` **passed in** | the caller | the caller; this library only borrows for the duration of the call |
//! | the string from [`rk_pki_version`] | static storage | nobody — it must not be freed |
//!
//! There is no allocation the caller can observe and forget: a response is a
//! single string, and an engine is a single handle. Nothing else crosses.
//!
//! # Nothing escapes as a panic (И144)
//!
//! Every entry point runs its body inside `catch_unwind`. A panic unwinding
//! out of `extern "C"` is undefined behaviour, and in this crate it would
//! also be the worst possible moment to abort: the decision being made is
//! whether a machine may be talked to, and the till has to keep selling
//! either way. A caught panic comes back as `{"ok":false,"error":{"kind":
//! "nativeFault",...}}` like any other failure.
//!
//! # No key material crosses
//!
//! There is deliberately no exported symbol that returns a private key, in
//! any encoding. Keys are generated, stored, and used on this side of the
//! boundary; what leaves is a signing request, a certificate, and public
//! metadata.

use std::any::Any;
use std::ffi::{c_char, CStr, CString};
use std::panic::{catch_unwind, AssertUnwindSafe};

use serde_json::Value;

use crate::engine::{call_stateless, envelope, Engine};
use crate::error::{PkiError, PkiResult};

/// The shape of this ABI. A consumer checks it before trusting any other
/// symbol; a change to it is a major version of the package.
pub const RK_PKI_ABI_VERSION: u32 = 1;

/// The ABI version this library was built with.
#[no_mangle]
pub extern "C" fn rk_pki_abi_version() -> u32 {
    RK_PKI_ABI_VERSION
}

/// The crate version, as a static NUL-terminated string. Must not be freed.
#[no_mangle]
pub extern "C" fn rk_pki_version() -> *const c_char {
    concat!(env!("CARGO_PKG_VERSION"), "\0").as_ptr() as *const c_char
}

/// Frees a string this library returned. Passing null is allowed and does
/// nothing; passing anything else twice is a double free, as it would be in
/// any C library.
///
/// # Safety
/// `ptr` must be null or a pointer this library returned and has not freed.
#[no_mangle]
pub unsafe extern "C" fn rk_pki_string_free(ptr: *mut c_char) {
    if ptr.is_null() {
        return;
    }
    let _ = catch_unwind(AssertUnwindSafe(|| {
        drop(CString::from_raw(ptr));
    }));
}

/// Opens an engine over a key store directory.
///
/// Returns null on failure and writes an error envelope to `out_error`, which
/// the caller frees with [`rk_pki_string_free`]. `out_error` may be null if
/// the caller does not want the detail.
///
/// # Safety
/// `config_json` must be a valid NUL-terminated UTF-8 string.
#[no_mangle]
pub unsafe extern "C" fn rk_pki_engine_open(
    config_json: *const c_char,
    out_error: *mut *mut c_char,
) -> *mut Engine {
    if !out_error.is_null() {
        *out_error = std::ptr::null_mut();
    }
    let outcome = catch_unwind(AssertUnwindSafe(|| {
        let config = borrow_str(config_json, "configJson")?;
        Engine::open(config)
    }));
    let result = match outcome {
        Ok(result) => result,
        Err(panic) => Err(PkiError::native(describe_panic(panic))),
    };
    match result {
        Ok(engine) => Box::into_raw(Box::new(engine)),
        Err(error) => {
            if !out_error.is_null() {
                *out_error = into_c_string(envelope(Err(error)));
            }
            std::ptr::null_mut()
        }
    }
}

/// Closes an engine. Passing null is allowed and does nothing.
///
/// # Safety
/// `handle` must be null or a handle from [`rk_pki_engine_open`] that has not
/// been closed.
#[no_mangle]
pub unsafe extern "C" fn rk_pki_engine_close(handle: *mut Engine) {
    if handle.is_null() {
        return;
    }
    let _ = catch_unwind(AssertUnwindSafe(|| {
        drop(Box::from_raw(handle));
    }));
}

/// Runs one named operation against an engine.
///
/// Always returns a NUL-terminated JSON envelope the caller must free with
/// [`rk_pki_string_free`]. It returns null only if the process is out of
/// memory to the point where even the failure string cannot be allocated.
///
/// # Safety
/// `handle` must be a live handle; `op` and `request_json` must be valid
/// NUL-terminated UTF-8 strings.
#[no_mangle]
pub unsafe extern "C" fn rk_pki_call(
    handle: *mut Engine,
    op: *const c_char,
    request_json: *const c_char,
) -> *mut c_char {
    let json = guarded(|| {
        let engine = handle
            .as_ref()
            .ok_or_else(|| PkiError::native("engine handle is null"))?;
        let op = borrow_str(op, "op")?;
        let request = borrow_str(request_json, "requestJson")?;
        engine.call(op, request)
    });
    into_c_string(json)
}

/// Runs one named operation that needs no engine — secret hashing, and the
/// self test a caller uses to prove the library is really there.
///
/// # Safety
/// `op` and `request_json` must be valid NUL-terminated UTF-8 strings.
#[no_mangle]
pub unsafe extern "C" fn rk_pki_call_stateless(
    op: *const c_char,
    request_json: *const c_char,
) -> *mut c_char {
    let json = guarded(|| {
        let op = borrow_str(op, "op")?;
        let request = borrow_str(request_json, "requestJson")?;
        call_stateless(op, request)
    });
    into_c_string(json)
}

/// Runs a body, converting both a returned failure and a panic into the same
/// envelope. This is the whole of И144 in one function.
fn guarded(body: impl FnOnce() -> PkiResult<Value>) -> String {
    match catch_unwind(AssertUnwindSafe(body)) {
        Ok(result) => envelope(result),
        Err(panic) => envelope(Err(PkiError::native(describe_panic(panic)))),
    }
}

fn describe_panic(panic: Box<dyn Any + Send>) -> String {
    let detail = if let Some(text) = panic.downcast_ref::<&str>() {
        (*text).to_string()
    } else if let Some(text) = panic.downcast_ref::<String>() {
        text.clone()
    } else {
        "a panic with no message".to_string()
    };
    format!("caught a panic at the boundary: {detail}")
}

/// Borrows a caller-owned string without taking ownership of it.
///
/// # Safety
/// The pointer must be null or a valid NUL-terminated string.
unsafe fn borrow_str<'a>(ptr: *const c_char, field: &str) -> PkiResult<&'a str> {
    if ptr.is_null() {
        return Err(PkiError::bad_request(format!("{field} is null")));
    }
    CStr::from_ptr(ptr)
        .to_str()
        .map_err(|_| PkiError::bad_request(format!("{field} is not valid UTF-8")))
}

/// Hands a string to the caller. Interior NUL bytes cannot occur in the JSON
/// we produce, but the fallback is an envelope rather than a panic, because
/// this function sits on the far side of the guard.
fn into_c_string(text: String) -> *mut c_char {
    match CString::new(text) {
        Ok(value) => value.into_raw(),
        Err(_) => CString::new(
            r#"{"ok":false,"error":{"kind":"nativeFault","detail":"response held a NUL byte"}}"#,
        )
        .map(CString::into_raw)
        .unwrap_or(std::ptr::null_mut()),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn take(ptr: *mut c_char) -> String {
        assert!(!ptr.is_null());
        let text = unsafe { CStr::from_ptr(ptr) }.to_str().unwrap().to_string();
        unsafe { rk_pki_string_free(ptr) };
        text
    }

    #[test]
    fn a_panic_becomes_a_value_not_an_unwind() {
        let json = guarded(|| panic!("the sky fell"));
        let value: Value = serde_json::from_str(&json).unwrap();
        assert_eq!(value["ok"], false);
        assert_eq!(value["error"]["kind"], "nativeFault");
        assert!(value["error"]["detail"]
            .as_str()
            .unwrap()
            .contains("the sky fell"));
    }

    #[test]
    fn a_null_handle_is_a_value_not_a_segfault() {
        let op = CString::new("ca.info").unwrap();
        let request = CString::new("{}").unwrap();
        let json =
            take(unsafe { rk_pki_call(std::ptr::null_mut(), op.as_ptr(), request.as_ptr()) });
        let value: Value = serde_json::from_str(&json).unwrap();
        assert_eq!(value["ok"], false);
        assert_eq!(value["error"]["kind"], "nativeFault");
    }

    #[test]
    fn a_null_operation_name_is_a_bad_request() {
        let json = take(unsafe { rk_pki_call_stateless(std::ptr::null(), std::ptr::null()) });
        let value: Value = serde_json::from_str(&json).unwrap();
        assert_eq!(value["error"]["kind"], "badRequest");
    }

    #[test]
    fn freeing_null_is_allowed() {
        unsafe { rk_pki_string_free(std::ptr::null_mut()) };
        unsafe { rk_pki_engine_close(std::ptr::null_mut()) };
    }

    #[test]
    fn opening_with_rubbish_reports_and_returns_null() {
        let config = CString::new(r#"{"storeDir":"x"}"#).unwrap();
        let mut error: *mut c_char = std::ptr::null_mut();
        let handle = unsafe { rk_pki_engine_open(config.as_ptr(), &mut error) };
        assert!(handle.is_null());
        let json = take(error);
        let value: Value = serde_json::from_str(&json).unwrap();
        assert_eq!(value["error"]["kind"], "badRequest");
    }

    #[test]
    fn the_version_string_is_static_and_readable() {
        let version = unsafe { CStr::from_ptr(rk_pki_version()) }
            .to_str()
            .unwrap();
        assert_eq!(version, env!("CARGO_PKG_VERSION"));
        assert_eq!(rk_pki_abi_version(), 1);
    }

    #[test]
    fn a_stateless_call_round_trips_through_the_boundary() {
        let op = CString::new("secret.hash").unwrap();
        let request = CString::new(r#"{"secret":"1234"}"#).unwrap();
        let json = take(unsafe { rk_pki_call_stateless(op.as_ptr(), request.as_ptr()) });
        let value: Value = serde_json::from_str(&json).unwrap();
        assert_eq!(value["ok"], true);
        let encoded = value["value"]["encoded"].as_str().unwrap().to_string();

        let op = CString::new("secret.verify").unwrap();
        let request =
            CString::new(serde_json::json!({"secret":"1234","stored":encoded}).to_string())
                .unwrap();
        let json = take(unsafe { rk_pki_call_stateless(op.as_ptr(), request.as_ptr()) });
        let value: Value = serde_json::from_str(&json).unwrap();
        assert_eq!(value["value"]["matches"], true);
    }
}

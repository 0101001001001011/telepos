//! `rk_quic` — the native half.
//!
//! This crate was built in two steps, and the order is the point. The first
//! step was an *empty* library: one function returning a version string, no
//! sockets, no files, no state, so that a red build could only mean the build
//! pipeline was wrong. Only once that was proved on Windows, Linux and Android
//! did the transport go on top.
//!
//! [`ffi`] holds the C ABI and its ownership rules, [`status`] the closed set
//! of statuses, [`transport`] the endpoint, and [`server_ffi`] the endpoint's
//! entry points.

#![deny(unsafe_op_in_unsafe_fn)]

pub mod config;
pub mod event;
pub mod ffi;
pub mod server_ffi;
pub mod status;
pub mod transport;

#[cfg(test)]
mod testing;

use std::cell::RefCell;
use std::ffi::c_char;

pub use ffi::{rk_quic_abi_version, rk_quic_string_free, rk_quic_version, RK_QUIC_ABI_VERSION};
pub use status::Status;

thread_local! {
    /// The last human-readable detail, per thread.
    ///
    /// Per thread and not global on purpose: two calls on two threads must not
    /// overwrite each other's explanation, which is exactly how "the error
    /// message is from some other call" bugs are born.
    static LAST_ERROR: RefCell<Option<String>> = const { RefCell::new(None) };
}

/// Records the detail behind the status about to be returned.
pub fn set_last_error(message: impl Into<String>) {
    let message = message.into();
    LAST_ERROR.with(|slot| *slot.borrow_mut() = Some(message));
}

/// Clears the detail, so a later success cannot be read with an older message.
pub fn clear_last_error() {
    LAST_ERROR.with(|slot| *slot.borrow_mut() = None);
}

/// Returns the detail behind the last failure on **this thread**, or null when
/// there is none.
///
/// # Ownership
/// The caller owns the returned buffer and frees it with
/// [`ffi::rk_quic_string_free`]. Reading it clears the slot, so the same
/// message is never reported twice.
#[no_mangle]
pub extern "C" fn rk_quic_last_error() -> *mut c_char {
    let taken = std::panic::catch_unwind(|| LAST_ERROR.with(|slot| slot.borrow_mut().take()));
    match taken {
        Ok(Some(message)) => ffi::into_owned_c_string(message),
        Ok(None) => std::ptr::null_mut(),
        Err(_) => std::ptr::null_mut(),
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::ffi::{CStr, CString};

    fn take_last_error() -> Option<String> {
        let ptr = rk_quic_last_error();
        if ptr.is_null() {
            return None;
        }
        // SAFETY: the pointer came from `into_owned_c_string`.
        let owned = unsafe { CString::from_raw(ptr) };
        Some(owned.to_string_lossy().into_owned())
    }

    #[test]
    fn version_matches_the_crate_and_is_readable_from_c() {
        let ptr = rk_quic_version();
        assert!(!ptr.is_null());
        // SAFETY: static storage, NUL-terminated by construction.
        let text = unsafe { CStr::from_ptr(ptr) }.to_str().unwrap();
        assert_eq!(text, env!("CARGO_PKG_VERSION"));
    }

    #[test]
    fn abi_version_is_the_declared_generation() {
        assert_eq!(rk_quic_abi_version(), RK_QUIC_ABI_VERSION);
        assert_eq!(RK_QUIC_ABI_VERSION, 2);
    }

    #[test]
    fn last_error_is_null_when_nothing_failed() {
        clear_last_error();
        assert_eq!(take_last_error(), None);
    }

    #[test]
    fn last_error_is_reported_once_then_cleared() {
        set_last_error("port 4433 is taken");
        assert_eq!(take_last_error().as_deref(), Some("port 4433 is taken"));
        assert_eq!(take_last_error(), None, "a message was reported twice");
    }

    #[test]
    fn freeing_null_is_a_no_op() {
        // SAFETY: null is documented as accepted.
        unsafe { rk_quic_string_free(std::ptr::null_mut()) };
    }

    #[test]
    fn a_panic_inside_the_guard_becomes_a_status_and_not_an_unwind() {
        let ptr = ffi::guard(|| panic!("deliberate"));
        // SAFETY: static storage.
        let name = unsafe { CStr::from_ptr(ptr) }.to_str().unwrap();
        assert_eq!(name, Status::Panic.name());
    }

    #[test]
    fn the_guard_passes_a_normal_status_through() {
        let ptr = ffi::guard(|| Status::PortInUse);
        // SAFETY: static storage.
        let name = unsafe { CStr::from_ptr(ptr) }.to_str().unwrap();
        assert_eq!(name, "portInUse");
    }
}

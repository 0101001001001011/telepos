//! `rk_mdns` — the native half.
//!
//! Multicast DNS (RFC 6762) and DNS-SD (RFC 6763), both halves: a **responder**
//! that claims a name and answers for it, and a **browser** that finds what
//! other people have claimed.
//!
//! The responder is why this exists. Dart has `multicast_dns`, which asks; the
//! platform plugins that answer hand the job to a system daemon — Avahi,
//! Bonjour, Android NSD — and that daemon is present on none of the
//! deployments this was written for: the appliance image is a bare Ubuntu with
//! no Avahi, and a Windows till has no Bonjour unless somebody installed
//! iTunes.
//!
//! The layout follows the shape of the protocol:
//!
//! | Module | What |
//! | --- | --- |
//! | [`name`] | domain names, compression pointers, case |
//! | [`record`] | the five record types DNS-SD needs |
//! | [`message`] | header and sections, total parsing |
//! | [`interfaces`] | which interfaces exist — and the measurement behind sending on all of them |
//! | [`socket`] | one socket per interface, and the options that matter |
//! | [`records`] | the record set a responder owns, and what it answers |
//! | [`cache`] | what a resolver remembers, and for how long |
//! | [`responder`] | probe, announce, answer, goodbye |
//! | [`browser`] | browse a type, resolve a name |
//! | [`ffi`] | the C ABI and its ownership rules |
//! | [`api`] | one entry point per thing a caller can do |

#![deny(unsafe_op_in_unsafe_fn)]
#![warn(missing_docs)]

pub mod api;
pub mod browser;
pub mod cache;
pub mod ffi;
pub mod interfaces;
pub mod message;
pub mod name;
pub mod record;
pub mod records;
pub mod registry;
pub mod responder;
pub mod socket;
pub mod status;

use std::cell::RefCell;
use std::ffi::c_char;

pub use ffi::{rk_mdns_abi_version, rk_mdns_string_free, rk_mdns_version, RK_MDNS_ABI_VERSION};
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
/// [`ffi::rk_mdns_string_free`]. Reading it clears the slot, so the same
/// message is never reported twice.
#[no_mangle]
pub extern "C" fn rk_mdns_last_error() -> *mut c_char {
    let taken = std::panic::catch_unwind(|| LAST_ERROR.with(|slot| slot.borrow_mut().take()));
    match taken {
        Ok(Some(message)) => ffi::into_owned_c_string(message),
        Ok(None) => std::ptr::null_mut(),
        Err(_) => std::ptr::null_mut(),
    }
}

/// Reads and clears the last error from Rust. For tests; the C caller uses
/// [`rk_mdns_last_error`].
pub fn take_last_error() -> Option<String> {
    LAST_ERROR.with(|slot| slot.borrow_mut().take())
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::ffi::{CStr, CString};

    fn take_through_c() -> Option<String> {
        let ptr = rk_mdns_last_error();
        if ptr.is_null() {
            return None;
        }
        // SAFETY: the pointer came from `into_owned_c_string`.
        let owned = unsafe { CString::from_raw(ptr) };
        Some(owned.to_string_lossy().into_owned())
    }

    #[test]
    fn version_matches_the_crate_and_is_readable_from_c() {
        let ptr = rk_mdns_version();
        assert!(!ptr.is_null());
        // SAFETY: static storage, NUL-terminated by construction.
        let text = unsafe { CStr::from_ptr(ptr) }.to_str().unwrap();
        assert_eq!(text, env!("CARGO_PKG_VERSION"));
    }

    #[test]
    fn abi_version_is_the_declared_generation() {
        assert_eq!(rk_mdns_abi_version(), RK_MDNS_ABI_VERSION);
        assert_eq!(RK_MDNS_ABI_VERSION, 1);
    }

    #[test]
    fn last_error_is_reported_once_then_cleared() {
        set_last_error("port 5353 is taken");
        assert_eq!(take_through_c().as_deref(), Some("port 5353 is taken"));
        assert_eq!(take_through_c(), None, "a message was reported twice");
    }

    #[test]
    fn freeing_null_is_a_no_op() {
        // SAFETY: null is documented as accepted.
        unsafe { rk_mdns_string_free(std::ptr::null_mut()) };
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

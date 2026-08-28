//! The entry points, one function per thing a caller can do.
//!
//! Every body is inside [`crate::ffi::guard`], so a panic anywhere below
//! becomes the status `panic` and the process stays up (И144). Every status
//! leaves as a name (И147). Every buffer written through an out-parameter is
//! freed by the caller with `rk_mdns_string_free` and by nobody else (И146).

use std::ffi::c_char;
use std::sync::OnceLock;
use std::time::Duration;

use crate::browser::{resolve_host, Browser, BrowserConfig, ResolveConfig};
use crate::ffi::{borrow_c_string, guard, into_owned_c_string, write_out};
use crate::registry::{registry, Registry};
use crate::responder::{Responder, ResponderConfig, StartError};
use crate::socket::SocketError;
use crate::status::Status;
use crate::{clear_last_error, set_last_error};

static RESPONDERS: OnceLock<Registry<Responder>> = OnceLock::new();
static BROWSERS: OnceLock<Registry<Browser>> = OnceLock::new();

/// The longest a poll may park a thread.
///
/// A caller cannot ask to wait an hour: a Dart isolate blocked for an hour is
/// an isolate that cannot be shut down, and the caller who wants that can call
/// again.
const MAX_POLL_MS: u32 = 60_000;

fn status_for(error: &StartError) -> Status {
    match error {
        StartError::InvalidArgument(_) => Status::InvalidArgument,
        StartError::Socket(SocketError::PortInUse { .. }) => Status::PortInUse,
        // A name that matches no interface is a typo in a setting, not a
        // machine without a network — so it is an argument problem, and the
        // detail names the interfaces that do exist.
        StartError::Socket(SocketError::Interfaces(
            crate::interfaces::InterfaceError::NoNameMatched { .. },
        )) => Status::InvalidArgument,
        StartError::Socket(SocketError::Interfaces(_)) => Status::NoInterface,
        StartError::Socket(SocketError::NoInterfaceBound { .. }) => Status::NoInterface,
        StartError::Socket(SocketError::Bind { .. }) => Status::BindFailed,
    }
}

/// Starts a responder and announces a service.
///
/// # Safety
/// `config_json` must be a valid NUL-terminated UTF-8 string; `out_handle`
/// must be null or point to a writable `u64`.
#[no_mangle]
pub unsafe extern "C" fn rk_mdns_responder_start(
    config_json: *const c_char,
    out_handle: *mut u64,
) -> *const c_char {
    guard(|| {
        clear_last_error();
        // SAFETY: the caller promises a NUL-terminated string or null.
        let Some(text) = (unsafe { borrow_c_string(config_json) }) else {
            set_last_error("the configuration is null or not UTF-8");
            return Status::InvalidArgument;
        };
        let config: ResponderConfig = match serde_json::from_str(text) {
            Ok(config) => config,
            Err(error) => {
                set_last_error(format!("the configuration could not be read: {error}"));
                return Status::InvalidArgument;
            }
        };
        match Responder::start(config) {
            Ok(responder) => {
                let handle = registry(&RESPONDERS).insert(responder);
                // SAFETY: the caller promises a writable u64 or null.
                unsafe { write_out(out_handle, handle) };
                Status::Ok
            }
            Err(error) => {
                set_last_error(error.to_string());
                status_for(&error)
            }
        }
    })
}

/// Stops a responder, after its goodbye has gone out.
#[no_mangle]
pub extern "C" fn rk_mdns_responder_stop(handle: u64) -> *const c_char {
    guard(|| {
        clear_last_error();
        match registry(&RESPONDERS).take(handle) {
            Some(responder) => {
                responder.stop();
                Status::Ok
            }
            // Stopping something already stopped is not a failure: during
            // shutdown a double stop is ordinary, and making it an error only
            // teaches callers to ignore the result.
            None => Status::NotRunning,
        }
    })
}

/// Writes what the responder ended up with, as JSON.
///
/// This is where the **name after a conflict** is read. A caller that asked to
/// announce `till-3` and got `till-3-2` has a setup problem, and it must be
/// able to see that rather than infer it from a tablet.
///
/// # Safety
/// `out_json` must be null or point to a writable pointer.
#[no_mangle]
pub unsafe extern "C" fn rk_mdns_responder_state(
    handle: u64,
    out_json: *mut *mut c_char,
) -> *const c_char {
    guard(|| {
        clear_last_error();
        let Some(responder) = registry(&RESPONDERS).get(handle) else {
            set_last_error(format!("no responder {handle}"));
            return Status::UnknownHandle;
        };
        match serde_json::to_string(&responder.state()) {
            Ok(json) => {
                // SAFETY: the caller promises a writable slot or null.
                unsafe { write_out(out_json, into_owned_c_string(json)) };
                Status::Ok
            }
            Err(error) => {
                set_last_error(format!("the state could not be written: {error}"));
                Status::Panic
            }
        }
    })
}

/// Waits up to `timeout_ms` for the responder's next event and writes it as
/// JSON.
///
/// `ok` — an event was written and the caller now owns `*out_json`.
/// `wouldBlock` — the wait expired with nothing to report; `*out_json` is
/// untouched. The two are distinct so a loop can tell "nothing happened" from
/// "something happened and was handled".
///
/// # Safety
/// `out_json` must be null or point to a writable pointer.
#[no_mangle]
pub unsafe extern "C" fn rk_mdns_responder_poll(
    handle: u64,
    timeout_ms: u32,
    out_json: *mut *mut c_char,
) -> *const c_char {
    guard(|| {
        clear_last_error();
        let Some(responder) = registry(&RESPONDERS).get(handle) else {
            set_last_error(format!("no responder {handle}"));
            return Status::UnknownHandle;
        };
        match responder.poll(Duration::from_millis(timeout_ms.min(MAX_POLL_MS) as u64)) {
            Some(event) => match serde_json::to_string(&event) {
                Ok(json) => {
                    // SAFETY: the caller promises a writable slot or null.
                    unsafe { write_out(out_json, into_owned_c_string(json)) };
                    Status::Ok
                }
                Err(error) => {
                    set_last_error(format!("the event could not be written: {error}"));
                    Status::Panic
                }
            },
            None => Status::WouldBlock,
        }
    })
}

/// Starts browsing a DNS-SD service type.
///
/// # Safety
/// `config_json` must be a valid NUL-terminated UTF-8 string; `out_handle`
/// must be null or point to a writable `u64`.
#[no_mangle]
pub unsafe extern "C" fn rk_mdns_browser_start(
    config_json: *const c_char,
    out_handle: *mut u64,
) -> *const c_char {
    guard(|| {
        clear_last_error();
        // SAFETY: the caller promises a NUL-terminated string or null.
        let Some(text) = (unsafe { borrow_c_string(config_json) }) else {
            set_last_error("the configuration is null or not UTF-8");
            return Status::InvalidArgument;
        };
        let config: BrowserConfig = match serde_json::from_str(text) {
            Ok(config) => config,
            Err(error) => {
                set_last_error(format!("the configuration could not be read: {error}"));
                return Status::InvalidArgument;
            }
        };
        match Browser::start(config) {
            Ok(browser) => {
                let handle = registry(&BROWSERS).insert(browser);
                // SAFETY: the caller promises a writable u64 or null.
                unsafe { write_out(out_handle, handle) };
                Status::Ok
            }
            Err(error) => {
                set_last_error(error.to_string());
                status_for(&error)
            }
        }
    })
}

/// Stops a browser.
#[no_mangle]
pub extern "C" fn rk_mdns_browser_stop(handle: u64) -> *const c_char {
    guard(|| {
        clear_last_error();
        match registry(&BROWSERS).take(handle) {
            Some(browser) => {
                browser.stop();
                Status::Ok
            }
            None => Status::NotRunning,
        }
    })
}

/// Waits up to `timeout_ms` for the browser's next event and writes it as
/// JSON.
///
/// # Safety
/// `out_json` must be null or point to a writable pointer.
#[no_mangle]
pub unsafe extern "C" fn rk_mdns_browser_poll(
    handle: u64,
    timeout_ms: u32,
    out_json: *mut *mut c_char,
) -> *const c_char {
    guard(|| {
        clear_last_error();
        let Some(browser) = registry(&BROWSERS).get(handle) else {
            set_last_error(format!("no browser {handle}"));
            return Status::UnknownHandle;
        };
        match browser.poll(Duration::from_millis(timeout_ms.min(MAX_POLL_MS) as u64)) {
            Some(event) => match serde_json::to_string(&event) {
                Ok(json) => {
                    // SAFETY: the caller promises a writable slot or null.
                    unsafe { write_out(out_json, into_owned_c_string(json)) };
                    Status::Ok
                }
                Err(error) => {
                    set_last_error(format!("the event could not be written: {error}"));
                    Status::Panic
                }
            },
            None => Status::WouldBlock,
        }
    })
}

/// Resolves one `<name>.local` and writes the addresses as JSON.
///
/// Blocking, bounded by the timeout in the configuration. `ok` with an empty
/// address list means the question was asked and nothing answered — which is
/// an answer, not a failure: on a network that filters multicast it is the
/// **expected** one, and turning it into an error would make a filtered
/// network indistinguishable from a broken call.
///
/// # Safety
/// `config_json` must be a valid NUL-terminated UTF-8 string; `out_json` must
/// be null or point to a writable pointer.
#[no_mangle]
pub unsafe extern "C" fn rk_mdns_resolve_host(
    config_json: *const c_char,
    out_json: *mut *mut c_char,
) -> *const c_char {
    guard(|| {
        clear_last_error();
        // SAFETY: the caller promises a NUL-terminated string or null.
        let Some(text) = (unsafe { borrow_c_string(config_json) }) else {
            set_last_error("the configuration is null or not UTF-8");
            return Status::InvalidArgument;
        };
        let config: ResolveConfig = match serde_json::from_str(text) {
            Ok(config) => config,
            Err(error) => {
                set_last_error(format!("the configuration could not be read: {error}"));
                return Status::InvalidArgument;
            }
        };
        match resolve_host(config) {
            Ok(resolved) => match serde_json::to_string(&resolved) {
                Ok(json) => {
                    // SAFETY: the caller promises a writable slot or null.
                    unsafe { write_out(out_json, into_owned_c_string(json)) };
                    Status::Ok
                }
                Err(error) => {
                    set_last_error(format!("the answer could not be written: {error}"));
                    Status::Panic
                }
            },
            Err(error) => {
                set_last_error(error.to_string());
                status_for(&error)
            }
        }
    })
}

/// Writes the interfaces this host would announce on, as JSON, without
/// starting anything.
///
/// Exists because "the till is invisible" has two causes that look identical
/// from a tablet — a network that filters multicast, and a host that is
/// announcing out of the wrong door — and only this call tells them apart.
///
/// # Safety
/// `out_json` must be null or point to a writable pointer.
#[no_mangle]
pub unsafe extern "C" fn rk_mdns_interfaces(
    include_loopback: u8,
    out_json: *mut *mut c_char,
) -> *const c_char {
    guard(|| {
        clear_last_error();
        let filter = crate::interfaces::InterfaceFilter {
            loopback: include_loopback != 0,
            ..crate::interfaces::InterfaceFilter::everything()
        };
        match crate::interfaces::usable(&filter) {
            Ok(found) => {
                let described: Vec<_> = found
                    .iter()
                    .map(|i| {
                        // The name, the netmask and the prefix travel with the
                        // address because they are what a caller decides on:
                        // in an announcement a spare address costs a client a
                        // connection timeout, and no rule over the address
                        // itself can tell a Hyper-V switch from a shop's
                        // 172.16/12 network. See ResponderConfig::interfaces.
                        serde_json::json!({
                            "name": i.name,
                            "address": i.address.to_string(),
                            "netmask": i.netmask.to_string(),
                            "prefix": i.prefix,
                            "index": i.index,
                            "loopback": i.loopback,
                        })
                    })
                    .collect();
                match serde_json::to_string(&described) {
                    Ok(json) => {
                        // SAFETY: the caller promises a writable slot or null.
                        unsafe { write_out(out_json, into_owned_c_string(json)) };
                        Status::Ok
                    }
                    Err(error) => {
                        set_last_error(format!("the list could not be written: {error}"));
                        Status::Panic
                    }
                }
            }
            Err(error) => {
                set_last_error(error.to_string());
                Status::NoInterface
            }
        }
    })
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::ffi::{CStr, CString};
    use std::ptr;

    fn status_of(pointer: *const c_char) -> String {
        // SAFETY: every entry point returns a pointer into static storage.
        unsafe { CStr::from_ptr(pointer) }
            .to_str()
            .expect("a status name is ASCII")
            .to_string()
    }

    fn take(pointer: *mut c_char) -> String {
        assert!(!pointer.is_null());
        // SAFETY: the pointer came from into_owned_c_string.
        let owned = unsafe { CString::from_raw(pointer) };
        owned.to_string_lossy().into_owned()
    }

    #[test]
    fn a_null_configuration_is_refused_by_name() {
        // SAFETY: null is documented as accepted and refused.
        let status = unsafe { rk_mdns_responder_start(ptr::null(), ptr::null_mut()) };
        assert_eq!(status_of(status), "invalidArgument");
    }

    #[test]
    fn a_configuration_that_is_not_json_is_refused_by_name() {
        let text = CString::new("not json").expect("no NUL");
        // SAFETY: a valid NUL-terminated string.
        let status = unsafe { rk_mdns_responder_start(text.as_ptr(), ptr::null_mut()) };
        assert_eq!(status_of(status), "invalidArgument");
        assert!(crate::take_last_error().is_some());
    }

    #[test]
    fn stopping_a_handle_that_was_never_issued_is_not_running() {
        let status = rk_mdns_responder_stop(9_999_999);
        assert_eq!(status_of(status), "notRunning");
        let status = rk_mdns_browser_stop(9_999_999);
        assert_eq!(status_of(status), "notRunning");
    }

    #[test]
    fn polling_a_handle_that_was_never_issued_is_unknown_handle() {
        let mut out: *mut c_char = ptr::null_mut();
        // SAFETY: a writable slot.
        let status = unsafe { rk_mdns_responder_poll(9_999_999, 0, &mut out) };
        assert_eq!(status_of(status), "unknownHandle");
        assert!(out.is_null(), "nothing may be written on a failure");
    }

    #[test]
    fn the_interface_list_comes_back_as_json() {
        let mut out: *mut c_char = ptr::null_mut();
        // SAFETY: a writable slot.
        let status = unsafe { rk_mdns_interfaces(1, &mut out) };
        assert_eq!(status_of(status), "ok");
        let json = take(out);
        let parsed: serde_json::Value = serde_json::from_str(&json).expect("json");
        assert!(!parsed.as_array().expect("an array").is_empty());
    }

    #[test]
    fn a_responder_starts_stops_and_reports_the_name_it_claimed() {
        let port = 20000 + (std::process::id() % 10000) as u16;
        let config = serde_json::json!({
            "instanceName": "rk-mdns-ffi",
            "serviceType": "_rkmdnstest._tcp.local",
            "port": 8443,
            "txt": ["quic=4433"],
            "mdnsPort": port,
            "probe": false,
            "ipv6": false,
            "loopbackInterface": true,
        })
        .to_string();
        let text = CString::new(config).expect("no NUL");
        let mut handle: u64 = 0;
        // SAFETY: a valid string and a writable u64.
        let status = unsafe { rk_mdns_responder_start(text.as_ptr(), &mut handle) };
        assert_eq!(status_of(status), "ok");
        assert_ne!(handle, 0, "a handle must never be zero");

        let mut out: *mut c_char = ptr::null_mut();
        // SAFETY: a live handle and a writable slot.
        let status = unsafe { rk_mdns_responder_state(handle, &mut out) };
        assert_eq!(status_of(status), "ok");
        let state: serde_json::Value = serde_json::from_str(&take(out)).expect("json");
        assert_eq!(
            state["instance"], "rk-mdns-ffi._rkmdnstest._tcp.local",
            "the responder did not report the name it claimed"
        );
        assert!(!state["interfaces"].as_array().expect("an array").is_empty());

        assert_eq!(status_of(rk_mdns_responder_stop(handle)), "ok");
        // And a second stop says so rather than failing.
        assert_eq!(status_of(rk_mdns_responder_stop(handle)), "notRunning");
        // The handle is gone from the table, not merely marked.
        let mut out: *mut c_char = ptr::null_mut();
        // SAFETY: a stale handle and a writable slot.
        let status = unsafe { rk_mdns_responder_state(handle, &mut out) };
        assert_eq!(status_of(status), "unknownHandle");
    }
}

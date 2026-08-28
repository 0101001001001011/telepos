//! The endpoint's C ABI.
//!
//! Every function returns a status **name** (И147) and cannot unwind (И144):
//! the body runs inside [`crate::ffi::guard`], so a panic becomes `"panic"`
//! rather than undefined behaviour in a foreign frame or an abort that takes
//! the till down with it.

use std::ffi::c_char;
use std::time::Duration;

use crate::config::ServerConfig;
use crate::ffi::{borrow_c_string, guard, into_owned_c_string, write_out};
use crate::status::Status;
use crate::{clear_last_error, set_last_error, transport};

/// Starts a QUIC/HTTP-3 endpoint serving WebTransport.
///
/// `config_json` is UTF-8 JSON:
/// ```json
/// {
///   "bindAddress": "0.0.0.0:4433",
///   "certificateChainPem": "-----BEGIN CERTIFICATE-----…",
///   "privateKeyPem": "-----BEGIN PRIVATE KEY-----…",
///   "path": "/rk"
/// }
/// ```
///
/// On `"ok"` the handle is written through `out_handle`. On anything else
/// `out_handle` is left alone and `rk_quic_last_error` has the detail.
///
/// # Ownership
/// Nothing is transferred. The handle is a name, not a pointer: it is freed by
/// `rk_quic_server_stop`, and a stale one is `"unknownHandle"` rather than a
/// use-after-free.
///
/// # Safety
/// `config_json` must be a valid NUL-terminated string; `out_handle` must be
/// null or point to a writable `uint64_t`.
#[no_mangle]
pub unsafe extern "C" fn rk_quic_server_start(
    config_json: *const c_char,
    out_handle: *mut u64,
) -> *const c_char {
    // SAFETY: promised by the caller; the borrow does not outlive this call.
    let json = unsafe { borrow_c_string(config_json) };
    guard(move || {
        clear_last_error();
        let Some(json) = json else {
            set_last_error("configJson is null or not UTF-8");
            return Status::InvalidArgument;
        };
        let config: ServerConfig = match serde_json::from_str(json) {
            Ok(config) => config,
            Err(e) => {
                set_last_error(format!("configJson is not the expected shape: {e}"));
                return Status::InvalidArgument;
            }
        };
        let parsed = match config.parse() {
            Ok(parsed) => parsed,
            Err((status, message)) => {
                set_last_error(message);
                return status;
            }
        };
        match transport::start(parsed) {
            Ok(handle) => {
                // SAFETY: the caller promised a writable u64 or null.
                unsafe { write_out(out_handle, handle) };
                Status::Ok
            }
            Err((status, message)) => {
                set_last_error(message);
                status
            }
        }
    })
}

/// Stops an endpoint and frees everything it owns.
///
/// Stopping something already stopped is `"notRunning"`, not a failure: during
/// shutdown a double stop is ordinary, and making it an error only teaches
/// callers to ignore the return value.
#[no_mangle]
pub extern "C" fn rk_quic_server_stop(handle: u64) -> *const c_char {
    guard(move || {
        clear_last_error();
        transport::remove(handle)
    })
}

/// Writes the port the endpoint actually bound.
///
/// Worth asking after `bindAddress: "…:0"`, where the operating system chose.
///
/// # Safety
/// `out_port` must be null or point to a writable `uint16_t`.
#[no_mangle]
pub unsafe extern "C" fn rk_quic_server_local_port(
    handle: u64,
    out_port: *mut u16,
) -> *const c_char {
    guard(move || {
        clear_last_error();
        match transport::lookup(handle) {
            Some(endpoint) => {
                // SAFETY: the caller promised a writable u16 or null.
                unsafe { write_out(out_port, endpoint.local_port()) };
                Status::Ok
            }
            None => Status::UnknownHandle,
        }
    })
}

/// Waits up to `timeout_ms` for the next event and writes it as JSON.
///
/// `"ok"` means an event was written and the caller now owns the string.
/// `"wouldBlock"` means the wait expired with nothing to report, and
/// `*out_json` is left null — distinct from `"ok"` precisely so a loop can
/// tell "nothing happened" from "something happened and was handled".
///
/// This is a queue with a reader, not polling: nothing is asked of the
/// network, and an event arriving during the wait returns immediately.
///
/// # Ownership
/// On `"ok"` the caller owns `*out_json` and must free it with
/// `rk_quic_string_free`. On every other status nothing is allocated.
///
/// # Safety
/// `out_json` must be null or point to a writable `char *`.
#[no_mangle]
pub unsafe extern "C" fn rk_quic_server_poll(
    handle: u64,
    timeout_ms: u32,
    out_json: *mut *mut c_char,
) -> *const c_char {
    guard(move || {
        clear_last_error();
        // SAFETY: the caller promised a writable char* or null.
        unsafe { write_out(out_json, std::ptr::null_mut()) };
        let Some(endpoint) = transport::lookup(handle) else {
            return Status::UnknownHandle;
        };
        // Capped so a caller cannot park a thread for an hour by passing a
        // large number, which on a till would look like a freeze.
        let timeout = Duration::from_millis(timeout_ms.min(60_000) as u64);
        match endpoint.next_event(timeout) {
            Some(event) => match serde_json::to_string(&event) {
                Ok(json) => {
                    // SAFETY: as above.
                    unsafe { write_out(out_json, into_owned_c_string(json)) };
                    Status::Ok
                }
                Err(e) => {
                    set_last_error(format!("event could not be serialised: {e}"));
                    Status::Panic
                }
            },
            None => Status::WouldBlock,
        }
    })
}

/// Sends UTF-8 to one session.
///
/// `reliable` picks the road: non-zero opens a unidirectional stream (ordered,
/// retransmitted — for a change that must not be lost), zero sends a datagram
/// (neither — for the current value of something that will be sent again).
///
/// `"peerGone"` means the session went away; it is a fact about the session
/// rather than a fault, and the reason to stop writing to it.
///
/// # Safety
/// `payload_utf8` must be a valid NUL-terminated string.
#[no_mangle]
pub unsafe extern "C" fn rk_quic_session_send(
    handle: u64,
    session_id: u64,
    payload_utf8: *const c_char,
    reliable: u8,
) -> *const c_char {
    // SAFETY: promised by the caller.
    let payload = unsafe { borrow_c_string(payload_utf8) };
    guard(move || {
        clear_last_error();
        let Some(payload) = payload else {
            set_last_error("payloadUtf8 is null or not UTF-8");
            return Status::InvalidArgument;
        };
        let Some(endpoint) = transport::lookup(handle) else {
            return Status::UnknownHandle;
        };
        match endpoint.send(session_id, payload, reliable != 0) {
            Ok(()) => Status::Ok,
            Err(status) => status,
        }
    })
}

/// Writes UTF-8 into a bidirectional stream a peer opened, without ending it.
///
/// Named `stream` and not `session` because that is the unit: a browser can
/// have several exchanges open on one session at once, and only the stream says
/// which question this answers. The stream ids come from the `streamOpened`,
/// `streamData` and `streamClosed` events.
///
/// The stream is deliberately **not** finished — an exchange may be one answer,
/// a subscription that goes on producing, or a run reporting progress. Ending
/// it is [`rk_quic_stream_close`], and it is a separate decision.
///
/// `"unknownHandle"` means no such endpoint, or no such stream on it — closed,
/// or its session ended. `"peerGone"` means the write itself found the peer
/// absent. Both are facts about the peer, not faults, and both arrive as values
/// (И144).
///
/// # Safety
/// `payload_utf8` must be a valid NUL-terminated string.
#[no_mangle]
pub unsafe extern "C" fn rk_quic_stream_send(
    handle: u64,
    session_id: u64,
    stream_id: u64,
    payload_utf8: *const c_char,
) -> *const c_char {
    // SAFETY: promised by the caller; the borrow does not outlive this call.
    let payload = unsafe { borrow_c_string(payload_utf8) };
    guard(move || {
        clear_last_error();
        let Some(payload) = payload else {
            set_last_error("payloadUtf8 is null or not UTF-8");
            return Status::InvalidArgument;
        };
        let Some(endpoint) = transport::lookup(handle) else {
            return Status::UnknownHandle;
        };
        match endpoint.stream_send(session_id, stream_id, payload) {
            Ok(()) => Status::Ok,
            Err(status) => status,
        }
    })
}

/// Finishes this side of a bidirectional stream and forgets it.
///
/// Closing something already closed is `"unknownHandle"` rather than a failure,
/// for the same reason stopping a stopped endpoint is `"notRunning"`: during
/// teardown a second close is ordinary, and making it an error only teaches
/// callers to ignore the return value.
#[no_mangle]
pub extern "C" fn rk_quic_stream_close(
    handle: u64,
    session_id: u64,
    stream_id: u64,
) -> *const c_char {
    guard(move || {
        clear_last_error();
        let Some(endpoint) = transport::lookup(handle) else {
            return Status::UnknownHandle;
        };
        match endpoint.stream_close(session_id, stream_id) {
            Ok(()) => Status::Ok,
            Err(status) => status,
        }
    })
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::ffi::{CStr, CString};

    fn status_of(ptr: *const c_char) -> &'static str {
        // SAFETY: every entry point returns a pointer into static storage.
        unsafe { CStr::from_ptr(ptr) }.to_str().unwrap()
    }

    fn take_error() -> Option<String> {
        let ptr = crate::rk_quic_last_error();
        if ptr.is_null() {
            return None;
        }
        // SAFETY: allocated by this library.
        Some(
            unsafe { CString::from_raw(ptr) }
                .to_string_lossy()
                .into_owned(),
        )
    }

    fn valid_config(port: u16) -> CString {
        let (chain, key) = crate::testing::self_signed_pem();
        CString::new(
            serde_json::json!({
                "bindAddress": format!("127.0.0.1:{port}"),
                "certificateChainPem": chain,
                "privateKeyPem": key,
            })
            .to_string(),
        )
        .unwrap()
    }

    #[test]
    fn a_null_config_is_invalid_argument_and_says_so() {
        // SAFETY: null is documented as accepted and handled.
        let status = unsafe { rk_quic_server_start(std::ptr::null(), std::ptr::null_mut()) };
        assert_eq!(status_of(status), "invalidArgument");
        assert!(take_error().is_some(), "no detail for the caller");
    }

    #[test]
    fn json_that_is_not_the_expected_shape_is_invalid_argument() {
        let json = CString::new(r#"{"bindAddress":"127.0.0.1:0"}"#).unwrap();
        let mut handle = 0u64;
        // SAFETY: valid string, writable out-pointer.
        let status = unsafe { rk_quic_server_start(json.as_ptr(), &mut handle) };
        assert_eq!(status_of(status), "invalidArgument");
        assert_eq!(handle, 0, "the out-pointer was written on failure");
    }

    #[test]
    fn a_start_stop_round_trip_reports_a_real_port() {
        let json = valid_config(0);
        let mut handle = 0u64;
        // SAFETY: valid string, writable out-pointer.
        let status = unsafe { rk_quic_server_start(json.as_ptr(), &mut handle) };
        assert_eq!(status_of(status), "ok", "{:?}", take_error());
        assert_ne!(handle, 0);

        let mut port = 0u16;
        // SAFETY: writable out-pointer.
        assert_eq!(
            status_of(unsafe { rk_quic_server_local_port(handle, &mut port) }),
            "ok"
        );
        assert_ne!(port, 0);

        assert_eq!(status_of(rk_quic_server_stop(handle)), "ok");
        assert_eq!(status_of(rk_quic_server_stop(handle)), "notRunning");
    }

    #[test]
    fn a_taken_port_is_reported_as_port_in_use_across_the_boundary() {
        let first_json = valid_config(0);
        let mut first = 0u64;
        // SAFETY: valid string, writable out-pointer.
        assert_eq!(
            status_of(unsafe { rk_quic_server_start(first_json.as_ptr(), &mut first) }),
            "ok"
        );
        let mut port = 0u16;
        // SAFETY: writable out-pointer.
        unsafe { rk_quic_server_local_port(first, &mut port) };

        let second_json = valid_config(port);
        let mut second = 0u64;
        // SAFETY: valid string, writable out-pointer.
        let status = unsafe { rk_quic_server_start(second_json.as_ptr(), &mut second) };

        assert_eq!(status_of(status), "portInUse");
        assert_eq!(second, 0);
        let detail = take_error().expect("a taken port must come with a message");
        assert!(
            detail.contains(&port.to_string()),
            "message names no port: {detail}"
        );

        assert_eq!(status_of(rk_quic_server_stop(first)), "ok");
    }

    #[test]
    fn polling_an_unknown_handle_is_a_value_and_allocates_nothing() {
        let mut out: *mut c_char = std::ptr::null_mut();
        // SAFETY: writable out-pointer.
        let status = unsafe { rk_quic_server_poll(u64::MAX, 1, &mut out) };
        assert_eq!(status_of(status), "unknownHandle");
        assert!(out.is_null(), "nothing must be allocated on a failed poll");
    }

    #[test]
    fn an_idle_endpoint_polls_would_block_and_leaves_the_out_pointer_null() {
        let json = valid_config(0);
        let mut handle = 0u64;
        // SAFETY: valid string, writable out-pointer.
        unsafe { rk_quic_server_start(json.as_ptr(), &mut handle) };

        let mut out: *mut c_char = std::ptr::null_mut();
        // SAFETY: writable out-pointer.
        let status = unsafe { rk_quic_server_poll(handle, 20, &mut out) };
        assert_eq!(status_of(status), "wouldBlock");
        assert!(out.is_null());

        assert_eq!(status_of(rk_quic_server_stop(handle)), "ok");
    }

    #[test]
    fn sending_on_a_stopped_endpoint_is_unknown_handle_not_a_crash() {
        let json = valid_config(0);
        let mut handle = 0u64;
        // SAFETY: valid string, writable out-pointer.
        unsafe { rk_quic_server_start(json.as_ptr(), &mut handle) };
        assert_eq!(status_of(rk_quic_server_stop(handle)), "ok");

        let payload = CString::new("anything").unwrap();
        // SAFETY: valid string.
        let status = unsafe { rk_quic_session_send(handle, 1, payload.as_ptr(), 1) };
        assert_eq!(status_of(status), "unknownHandle");
    }

    #[test]
    fn the_abi_generation_moved_because_the_surface_grew() {
        // Not politeness. A Dart side that knows about bidirectional streams
        // calls symbols a generation-1 library does not export; without this
        // the process would die resolving a missing symbol instead of saying
        // plainly that the library is the wrong one.
        assert_eq!(crate::RK_QUIC_ABI_VERSION, 2);
    }

    #[test]
    fn writing_to_a_stream_on_an_unknown_handle_is_a_value_and_not_a_crash() {
        let payload = CString::new("{}").unwrap();
        // SAFETY: valid string; the handle is deliberately one never issued.
        let status = unsafe { rk_quic_stream_send(u64::MAX, 1, 1, payload.as_ptr()) };
        assert_eq!(status_of(status), "unknownHandle");

        assert_eq!(
            status_of(rk_quic_stream_close(u64::MAX, 1, 1)),
            "unknownHandle"
        );
    }

    #[test]
    fn a_stream_that_the_session_never_opened_is_unknown_handle() {
        // A live endpoint, a stream nobody opened: the refusal must come from
        // the stream being absent, not from the endpoint being absent, or the
        // test above would pass over a library that ignores its arguments.
        let json = valid_config(0);
        let mut handle = 0u64;
        // SAFETY: valid string, writable out-pointer.
        unsafe { rk_quic_server_start(json.as_ptr(), &mut handle) };

        let payload = CString::new("{}").unwrap();
        // SAFETY: valid string.
        let status = unsafe { rk_quic_stream_send(handle, 7, 3, payload.as_ptr()) };
        assert_eq!(status_of(status), "unknownHandle");

        assert_eq!(status_of(rk_quic_server_stop(handle)), "ok");
    }

    #[test]
    fn every_entry_point_survives_a_null_out_pointer() {
        let json = valid_config(0);
        let mut handle = 0u64;
        // SAFETY: valid string, writable out-pointer.
        unsafe { rk_quic_server_start(json.as_ptr(), &mut handle) };

        // SAFETY: a null out-pointer is documented as accepted.
        unsafe {
            assert_eq!(
                status_of(rk_quic_server_local_port(handle, std::ptr::null_mut())),
                "ok"
            );
            assert_eq!(
                status_of(rk_quic_server_poll(handle, 1, std::ptr::null_mut())),
                "wouldBlock"
            );
            assert_eq!(
                status_of(rk_quic_session_send(handle, 1, std::ptr::null(), 1)),
                "invalidArgument"
            );
            assert_eq!(
                status_of(rk_quic_stream_send(handle, 1, 1, std::ptr::null())),
                "invalidArgument"
            );
        }

        assert_eq!(status_of(rk_quic_server_stop(handle)), "ok");
    }
}

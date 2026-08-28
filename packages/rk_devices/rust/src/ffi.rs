//! The C ABI.
//!
//! Four rules hold everywhere in this file, and they are the invariants the
//! architecture document names:
//!
//! * **И144 — a failure is a returned value.** Every exported function wraps
//!   its work in [`std::panic::catch_unwind`]. A panic becomes the status
//!   name `"panic"`; nothing unwinds into a foreign stack and nothing aborts.
//!   `src/lib.rs` refuses to compile under `panic = "abort"`, which would
//!   turn the same bug back into a process kill.
//! * **И146 — freeing is deterministic, and the answer to "who frees what" is
//!   "the caller frees everything".** This library allocates nothing that
//!   crosses the boundary. Every result is written into a buffer the caller
//!   owns, and every function that can overflow one writes the required
//!   length into `out_len` *before* reporting `buffer_too_small`, so a caller
//!   can size and retry rather than guess.
//! * **И147 — enumerations cross by name.** Every protocol, model, operation,
//!   address, wire, verdict and status is a NUL-terminated UTF-8 name in both
//!   directions. No ordinal ever crosses, so inserting a case into the middle
//!   of a list can never silently change the meaning of a call.
//! * **И30 — nothing here can hold up taking money.** Not "every wait is
//!   bounded" but "there are no waits": this library performs no I/O, opens
//!   nothing, sleeps never, and spawns no thread. Every call is a pure
//!   function of its arguments and returns in bounded time.
//!
//! ## The three return values
//!
//! `0` the call did what it was asked. `1` it did not, and the status buffer
//! holds the name of why. `2` the status buffer was too small to hold even
//! that, so nothing was written — pass at least
//! [`rk_devices_status_capacity`] bytes and this cannot happen.
//!
//! These three are a property of the calling convention, not a domain
//! enumeration: there is no fourth thing a call can do, so there is no list
//! for a case to be inserted into the middle of.

use core::ffi::{c_char, CStr};
use core::panic::AssertUnwindSafe;
use core::ptr;
use std::panic::catch_unwind;

use crate::display;
use crate::drawer;
use crate::mdb;
use crate::scale;
use crate::status::{Result, Status};
use crate::wire;

pub const CALL_OK: i32 = 0;
pub const CALL_FAILED: i32 = 1;
pub const CALL_NO_STATUS_ROOM: i32 = 2;

/// Bumped when an exported signature changes meaning. A consumer that reads a
/// number it does not know must refuse to bind rather than call blind.
pub const ABI_VERSION: u32 = 1;

// ---------------------------------------------------------------------------
// Boundary plumbing
// ---------------------------------------------------------------------------

unsafe fn put_status(out: *mut c_char, cap: usize, status: Status) -> i32 {
    let name = status.name().as_bytes();
    if out.is_null() || cap < name.len() + 1 {
        return CALL_NO_STATUS_ROOM;
    }
    ptr::copy_nonoverlapping(name.as_ptr(), out as *mut u8, name.len());
    *out.add(name.len()) = 0;
    if status == Status::Ok {
        CALL_OK
    } else {
        CALL_FAILED
    }
}

/// Run `body`, catch anything it throws, and report the outcome as a name.
unsafe fn guarded<F>(status: *mut c_char, status_cap: usize, body: F) -> i32
where
    F: FnOnce() -> Status,
{
    let outcome = catch_unwind(AssertUnwindSafe(body)).unwrap_or(Status::Panic);
    put_status(status, status_cap, outcome)
}

/// Copy `src` into a caller-owned buffer, always reporting the length needed.
unsafe fn put_bytes(src: &[u8], out: *mut u8, cap: usize, out_len: *mut usize) -> Status {
    if out_len.is_null() {
        return Status::InvalidArgument;
    }
    *out_len = src.len();
    if src.is_empty() {
        return Status::Ok;
    }
    if out.is_null() || cap < src.len() {
        return Status::BufferTooSmall;
    }
    ptr::copy_nonoverlapping(src.as_ptr(), out, src.len());
    Status::Ok
}

unsafe fn put_words(src: &[u16], out: *mut u16, cap: usize, out_len: *mut usize) -> Status {
    if out_len.is_null() {
        return Status::InvalidArgument;
    }
    *out_len = src.len();
    if src.is_empty() {
        return Status::Ok;
    }
    if out.is_null() || cap < src.len() {
        return Status::BufferTooSmall;
    }
    ptr::copy_nonoverlapping(src.as_ptr(), out, src.len());
    Status::Ok
}

unsafe fn put_name(name: &str, out: *mut c_char, cap: usize) -> Status {
    let bytes = name.as_bytes();
    if out.is_null() || cap < bytes.len() + 1 {
        return Status::BufferTooSmall;
    }
    ptr::copy_nonoverlapping(bytes.as_ptr(), out as *mut u8, bytes.len());
    *out.add(bytes.len()) = 0;
    Status::Ok
}

unsafe fn read_name<'a>(p: *const c_char) -> Result<&'a str> {
    if p.is_null() {
        return Err(Status::InvalidArgument);
    }
    CStr::from_ptr(p).to_str().map_err(|_| Status::InvalidUtf8)
}

unsafe fn read_bytes<'a>(p: *const u8, len: usize) -> Result<&'a [u8]> {
    if len == 0 {
        return Ok(&[]);
    }
    if p.is_null() {
        return Err(Status::InvalidArgument);
    }
    Ok(core::slice::from_raw_parts(p, len))
}

unsafe fn read_words<'a>(p: *const u16, len: usize) -> Result<&'a [u16]> {
    if len == 0 {
        return Ok(&[]);
    }
    if p.is_null() {
        return Err(Status::InvalidArgument);
    }
    Ok(core::slice::from_raw_parts(p, len))
}

fn flatten(r: Result<Status>) -> Status {
    match r {
        Ok(s) => s,
        Err(e) => e,
    }
}

// ---------------------------------------------------------------------------
// Meta
// ---------------------------------------------------------------------------

/// The ABI generation this build speaks. Cannot fail, so it has no status.
#[no_mangle]
pub extern "C" fn rk_devices_abi_version() -> u32 {
    ABI_VERSION
}

/// The smallest status buffer that always works, terminator included.
#[no_mangle]
pub extern "C" fn rk_devices_status_capacity() -> usize {
    Status::longest_name() + 1
}

/// The crate version, as a name.
///
/// # Safety
/// `out` must be writable for `cap` bytes; `status` for `status_cap`.
#[no_mangle]
pub unsafe extern "C" fn rk_devices_version(
    out: *mut c_char,
    cap: usize,
    status: *mut c_char,
    status_cap: usize,
) -> i32 {
    guarded(status, status_cap, || {
        put_name(env!("CARGO_PKG_VERSION"), out, cap)
    })
}

/// Panics on purpose, so a consumer's test can prove И144 rather than assume
/// it. Always returns `1` with the status name `"panic"`.
///
/// # Safety
/// `status` must be writable for `status_cap` bytes.
#[doc(hidden)]
#[no_mangle]
pub unsafe extern "C" fn rk_devices_provoke_panic_for_test(
    status: *mut c_char,
    status_cap: usize,
) -> i32 {
    guarded(status, status_cap, || {
        panic!("deliberate panic: proving the boundary catches it");
    })
}

// ---------------------------------------------------------------------------
// Wire
// ---------------------------------------------------------------------------

/// Whether a named wire can report how much of a buffer it accepted.
///
/// # Safety
/// `wire` must be a NUL-terminated string; `out` writable for one byte.
#[no_mangle]
pub unsafe extern "C" fn rk_devices_wire_reports_partial_writes(
    wire_name: *const c_char,
    out: *mut u8,
    status: *mut c_char,
    status_cap: usize,
) -> i32 {
    guarded(status, status_cap, || {
        flatten((|| {
            let w = wire::Wire::from_name(read_name(wire_name)?)?;
            if out.is_null() {
                return Err(Status::InvalidArgument);
            }
            *out = u8::from(w.reports_partial_writes());
            Ok(Status::Ok)
        })())
    })
}

/// Turn a write report into what the caller may do next.
///
/// `report_name` is `"accepted"` or `"failed"`; `accepted` is read only for
/// the former. `out_action` receives `"done"`, `"continue"` or `"unknown"`,
/// and `out_offset` the byte to continue from (zero unless the action is
/// `"continue"`).
///
/// # Safety
/// All pointers must be valid for the lengths given.
#[no_mangle]
pub unsafe extern "C" fn rk_devices_wire_resolve(
    wire_name: *const c_char,
    total: usize,
    report_name: *const c_char,
    accepted: usize,
    out_action: *mut c_char,
    action_cap: usize,
    out_offset: *mut usize,
    status: *mut c_char,
    status_cap: usize,
) -> i32 {
    guarded(status, status_cap, || {
        flatten((|| {
            let w = wire::Wire::from_name(read_name(wire_name)?)?;
            let report = match read_name(report_name)? {
                "accepted" => wire::Report::Accepted(accepted),
                "failed" => wire::Report::Failed,
                _ => return Err(Status::UnknownName),
            };
            let resume = wire::resolve(w, total, report)?;
            if out_offset.is_null() {
                return Err(Status::InvalidArgument);
            }
            *out_offset = resume.offset();
            Ok(put_name(resume.name(), out_action, action_cap))
        })())
    })
}

// ---------------------------------------------------------------------------
// Scales
// ---------------------------------------------------------------------------

/// The bytes that ask a scale for its weight.
///
/// # Safety
/// All pointers must be valid for the lengths given.
#[no_mangle]
pub unsafe extern "C" fn rk_devices_scale_weight_request(
    protocol_name: *const c_char,
    out: *mut u8,
    cap: usize,
    out_len: *mut usize,
    status: *mut c_char,
    status_cap: usize,
) -> i32 {
    guarded(status, status_cap, || {
        flatten((|| {
            let p = scale::Protocol::from_name(read_name(protocol_name)?)?;
            Ok(put_bytes(p.weight_request(), out, cap, out_len))
        })())
    })
}

/// The bytes that zero a scale's pan.
///
/// # Safety
/// All pointers must be valid for the lengths given.
#[no_mangle]
pub unsafe extern "C" fn rk_devices_scale_tare_request(
    protocol_name: *const c_char,
    out: *mut u8,
    cap: usize,
    out_len: *mut usize,
    status: *mut c_char,
    status_cap: usize,
) -> i32 {
    guarded(status, status_cap, || {
        flatten((|| {
            let p = scale::Protocol::from_name(read_name(protocol_name)?)?;
            Ok(put_bytes(p.tare_request(), out, cap, out_len))
        })())
    })
}

/// Read one line out of a scale's byte stream.
///
/// `out_kind` receives `"reading"`, `"incomplete"` or `"garbage"`. The weight
/// outputs are meaningful only for `"reading"`; `out_consumed` is how many
/// bytes of `data` may be dropped, and is zero for `"incomplete"`.
///
/// # Safety
/// All pointers must be valid for the lengths given.
#[allow(clippy::too_many_arguments)]
#[no_mangle]
pub unsafe extern "C" fn rk_devices_scale_parse(
    protocol_name: *const c_char,
    data: *const u8,
    len: usize,
    out_kind: *mut c_char,
    kind_cap: usize,
    out_scaled: *mut i64,
    out_decimals: *mut u32,
    out_unit: *mut c_char,
    unit_cap: usize,
    out_stability: *mut c_char,
    stability_cap: usize,
    out_measure: *mut c_char,
    measure_cap: usize,
    out_consumed: *mut usize,
    status: *mut c_char,
    status_cap: usize,
) -> i32 {
    guarded(status, status_cap, || {
        flatten((|| {
            let p = scale::Protocol::from_name(read_name(protocol_name)?)?;
            let bytes = read_bytes(data, len)?;
            let parsed = scale::parse(p, bytes);
            if out_consumed.is_null() {
                return Err(Status::InvalidArgument);
            }
            *out_consumed = parsed.consumed;

            let kind = put_name(parsed.frame.kind_name(), out_kind, kind_cap);
            if kind != Status::Ok {
                return Ok(kind);
            }

            if let scale::Frame::Reading(r) = parsed.frame {
                if out_scaled.is_null() || out_decimals.is_null() {
                    return Err(Status::InvalidArgument);
                }
                *out_scaled = r.scaled;
                *out_decimals = r.decimals;
                for (name, buf, cap) in [
                    (r.unit.name(), out_unit, unit_cap),
                    (r.stability.name(), out_stability, stability_cap),
                    (r.measure.name(), out_measure, measure_cap),
                ] {
                    let s = put_name(name, buf, cap);
                    if s != Status::Ok {
                        return Ok(s);
                    }
                }
            }
            Ok(Status::Ok)
        })())
    })
}

/// Bytes a caller must allocate for a settling rule.
#[no_mangle]
pub extern "C" fn rk_devices_stabilizer_size() -> usize {
    core::mem::size_of::<scale::Stabilizer>()
}

/// Alignment a caller must respect for a settling rule.
#[no_mangle]
pub extern "C" fn rk_devices_stabilizer_align() -> usize {
    core::mem::align_of::<scale::Stabilizer>()
}

/// Prepare a caller-owned settling rule.
///
/// `budget_ms` bounds the wait **in time**, not in attempts: a port that
/// answers every five milliseconds and one that answers every five seconds
/// must not get different real deadlines from the same number (И30).
///
/// # Safety
/// `state` must point at [`rk_devices_stabilizer_size`] writable bytes,
/// aligned to [`rk_devices_stabilizer_align`].
#[no_mangle]
pub unsafe extern "C" fn rk_devices_stabilizer_init(
    state: *mut u8,
    needed_repeats: u32,
    budget_ms: u32,
    status: *mut c_char,
    status_cap: usize,
) -> i32 {
    guarded(status, status_cap, || {
        if state.is_null() || (state as usize) % rk_devices_stabilizer_align() != 0 {
            return Status::InvalidArgument;
        }
        let value = scale::Stabilizer::new(needed_repeats, budget_ms);
        ptr::write(state as *mut scale::Stabilizer, value);
        Status::Ok
    })
}

/// Offer one poll's worth of evidence and read the verdict.
///
/// `heard_name` is `"reading"`, `"noise"` or `"silence"`; the weight and
/// stability arguments are read only for `"reading"`. `out_verdict` receives
/// `"settled"`, `"not_yet"`, `"expired"` or `"no_answer"` — and the last two
/// are different facts: one scale answered and never settled, the other never
/// said anything at all.
///
/// # Safety
/// `state` must have been initialised by [`rk_devices_stabilizer_init`].
#[allow(clippy::too_many_arguments)]
#[no_mangle]
pub unsafe extern "C" fn rk_devices_stabilizer_offer(
    state: *mut u8,
    elapsed_ms: u32,
    heard_name: *const c_char,
    scaled: i64,
    decimals: u32,
    stability_name: *const c_char,
    out_verdict: *mut c_char,
    verdict_cap: usize,
    status: *mut c_char,
    status_cap: usize,
) -> i32 {
    guarded(status, status_cap, || {
        flatten((|| {
            if state.is_null() || (state as usize) % rk_devices_stabilizer_align() != 0 {
                return Err(Status::InvalidArgument);
            }
            let heard = scale::Heard::from_name(read_name(heard_name)?)?;
            let reading = if heard == scale::Heard::Reading {
                Some(scale::Reading {
                    scaled,
                    decimals,
                    unit: scale::Unit::Kilogram,
                    stability: scale::Stability::from_name(read_name(stability_name)?)?,
                    measure: scale::Measure::Unknown,
                })
            } else {
                None
            };
            let rule = &mut *(state as *mut scale::Stabilizer);
            let verdict = rule.offer(elapsed_ms, heard, reading)?;
            Ok(put_name(verdict.name(), out_verdict, verdict_cap))
        })())
    })
}

// ---------------------------------------------------------------------------
// Customer displays
// ---------------------------------------------------------------------------

/// Lines and columns a model has, as fixed by its manufacturer.
///
/// # Safety
/// `out_lines` and `out_columns` must be writable.
#[no_mangle]
pub unsafe extern "C" fn rk_devices_display_geometry(
    model_name: *const c_char,
    out_lines: *mut u32,
    out_columns: *mut u32,
    status: *mut c_char,
    status_cap: usize,
) -> i32 {
    guarded(status, status_cap, || {
        flatten((|| {
            let m = display::Model::from_name(read_name(model_name)?)?;
            if out_lines.is_null() || out_columns.is_null() {
                return Err(Status::InvalidArgument);
            }
            *out_lines = m.lines();
            *out_columns = m.columns();
            Ok(Status::Ok)
        })())
    })
}

/// Build the bytes for one display operation.
///
/// `text` is UTF-8 and is used only by `"write_line"`. `out_substitutions`
/// receives the number of characters that had no byte in the model's code
/// page — non-zero means the customer is being shown something other than
/// what was asked for, which CP866 guarantees for Kazakh, Kyrgyz and `₸`.
///
/// # Safety
/// All pointers must be valid for the lengths given.
#[allow(clippy::too_many_arguments)]
#[no_mangle]
pub unsafe extern "C" fn rk_devices_display_encode(
    model_name: *const c_char,
    op_name: *const c_char,
    line: u32,
    column: u32,
    brightness: u32,
    text: *const u8,
    text_len: usize,
    out: *mut u8,
    cap: usize,
    out_len: *mut usize,
    out_substitutions: *mut usize,
    status: *mut c_char,
    status_cap: usize,
) -> i32 {
    guarded(status, status_cap, || {
        flatten((|| {
            let m = display::Model::from_name(read_name(model_name)?)?;
            let op = display::Op::from_name(read_name(op_name)?)?;
            let raw = read_bytes(text, text_len)?;
            let text = core::str::from_utf8(raw).map_err(|_| Status::InvalidUtf8)?;
            let encoded = display::encode(m, op, line, column, brightness, text)?;
            if out_substitutions.is_null() {
                return Err(Status::InvalidArgument);
            }
            *out_substitutions = encoded.substitutions;
            Ok(put_bytes(&encoded.bytes, out, cap, out_len))
        })())
    })
}

// ---------------------------------------------------------------------------
// Cash drawers
// ---------------------------------------------------------------------------

/// The kick pulse, as bytes.
///
/// # Safety
/// All pointers must be valid for the lengths given.
#[allow(clippy::too_many_arguments)]
#[no_mangle]
pub unsafe extern "C" fn rk_devices_drawer_pulse(
    model_name: *const c_char,
    pin_name: *const c_char,
    on_ms: u32,
    off_ms: u32,
    out: *mut u8,
    cap: usize,
    out_len: *mut usize,
    status: *mut c_char,
    status_cap: usize,
) -> i32 {
    guarded(status, status_cap, || {
        flatten((|| {
            let m = drawer::Model::from_name(read_name(model_name)?)?;
            let p = drawer::Pin::from_name(read_name(pin_name)?)?;
            let bytes = drawer::pulse(m, p, on_ms, off_ms)?;
            Ok(put_bytes(&bytes, out, cap, out_len))
        })())
    })
}

/// Whether anything can be learned about the drawer over the same wire.
/// Today, for every model, the answer is `"cannot_report"`.
///
/// # Safety
/// All pointers must be valid for the lengths given.
#[no_mangle]
pub unsafe extern "C" fn rk_devices_drawer_reporting(
    model_name: *const c_char,
    out: *mut c_char,
    cap: usize,
    status: *mut c_char,
    status_cap: usize,
) -> i32 {
    guarded(status, status_cap, || {
        flatten((|| {
            let m = drawer::Model::from_name(read_name(model_name)?)?;
            Ok(put_name(drawer::reporting(m).name(), out, cap))
        })())
    })
}

/// The pulse this product has always sent, in milliseconds.
///
/// # Safety
/// Both pointers must be writable.
#[no_mangle]
pub unsafe extern "C" fn rk_devices_drawer_default_pulse_ms(
    out_on_ms: *mut u32,
    out_off_ms: *mut u32,
    status: *mut c_char,
    status_cap: usize,
) -> i32 {
    guarded(status, status_cap, || {
        if out_on_ms.is_null() || out_off_ms.is_null() {
            return Status::InvalidArgument;
        }
        *out_on_ms = drawer::DEFAULT_ON_MS;
        *out_off_ms = drawer::DEFAULT_OFF_MS;
        Status::Ok
    })
}

// ---------------------------------------------------------------------------
// MDB
// ---------------------------------------------------------------------------

/// The window a peripheral has to begin replying, in milliseconds.
///
/// A number to configure a bridge with. This library holds no deadline and
/// cannot: it never waits.
#[no_mangle]
pub extern "C" fn rk_devices_mdb_response_window_ms() -> u32 {
    mdb::RESPONSE_WINDOW_MS
}

/// One bit time at 9600 baud, in microseconds. Same caveat as above.
#[no_mangle]
pub extern "C" fn rk_devices_mdb_bit_time_us() -> u32 {
    mdb::BIT_TIME_US
}

/// The ninth-bit mask used in every word this module produces and consumes.
#[no_mangle]
pub extern "C" fn rk_devices_mdb_mode_bit() -> u16 {
    mdb::MODE_BIT
}

/// The command byte for a named command on a named peripheral.
///
/// # Safety
/// All pointers must be valid.
#[no_mangle]
pub unsafe extern "C" fn rk_devices_mdb_command_byte(
    address_name: *const c_char,
    command_name: *const c_char,
    out: *mut u8,
    status: *mut c_char,
    status_cap: usize,
) -> i32 {
    guarded(status, status_cap, || {
        flatten((|| {
            let a = mdb::Address::from_name(read_name(address_name)?)?;
            let b = mdb::command_byte(a, read_name(command_name)?)?;
            if out.is_null() {
                return Err(Status::InvalidArgument);
            }
            *out = b;
            Ok(Status::Ok)
        })())
    })
}

/// The eight-bit sum that closes an MDB block.
///
/// # Safety
/// All pointers must be valid for the lengths given.
#[no_mangle]
pub unsafe extern "C" fn rk_devices_mdb_checksum(
    data: *const u8,
    len: usize,
    out: *mut u8,
    status: *mut c_char,
    status_cap: usize,
) -> i32 {
    guarded(status, status_cap, || {
        flatten((|| {
            let bytes = read_bytes(data, len)?;
            if out.is_null() {
                return Err(Status::InvalidArgument);
            }
            *out = mdb::checksum(bytes);
            Ok(Status::Ok)
        })())
    })
}

/// A master-to-peripheral frame as nine-bit words: bit 8 is the mode bit.
///
/// # Safety
/// All pointers must be valid for the lengths given.
#[allow(clippy::too_many_arguments)]
#[no_mangle]
pub unsafe extern "C" fn rk_devices_mdb_encode(
    address_name: *const c_char,
    command_name: *const c_char,
    data: *const u8,
    data_len: usize,
    out: *mut u16,
    cap: usize,
    out_len: *mut usize,
    status: *mut c_char,
    status_cap: usize,
) -> i32 {
    guarded(status, status_cap, || {
        flatten((|| {
            let a = mdb::Address::from_name(read_name(address_name)?)?;
            let words = mdb::encode(a, read_name(command_name)?, read_bytes(data, data_len)?)?;
            Ok(put_words(&words, out, cap, out_len))
        })())
    })
}

/// The same, from a command byte the caller supplies — the way out of this
/// crate's transcribed command table.
///
/// # Safety
/// All pointers must be valid for the lengths given.
#[no_mangle]
pub unsafe extern "C" fn rk_devices_mdb_encode_raw(
    command: u8,
    data: *const u8,
    data_len: usize,
    out: *mut u16,
    cap: usize,
    out_len: *mut usize,
    status: *mut c_char,
    status_cap: usize,
) -> i32 {
    guarded(status, status_cap, || {
        flatten((|| {
            let words = mdb::encode_raw(command, read_bytes(data, data_len)?)?;
            Ok(put_words(&words, out, cap, out_len))
        })())
    })
}

/// Read one peripheral-to-master frame.
///
/// `out_kind` receives `"block"`, `"ack"`, `"nak"`, `"ret"`, `"incomplete"`
/// or `"bad_checksum"`. The payload is written only for `"block"`, and never
/// includes the checksum word.
///
/// # Safety
/// All pointers must be valid for the lengths given.
#[allow(clippy::too_many_arguments)]
#[no_mangle]
pub unsafe extern "C" fn rk_devices_mdb_decode(
    words: *const u16,
    words_len: usize,
    out_kind: *mut c_char,
    kind_cap: usize,
    out_payload: *mut u8,
    payload_cap: usize,
    out_payload_len: *mut usize,
    out_consumed: *mut usize,
    status: *mut c_char,
    status_cap: usize,
) -> i32 {
    guarded(status, status_cap, || {
        flatten((|| {
            let input = read_words(words, words_len)?;
            let decoded = mdb::decode(input);
            if out_consumed.is_null() || out_payload_len.is_null() {
                return Err(Status::InvalidArgument);
            }
            *out_consumed = decoded.consumed;
            *out_payload_len = 0;
            let kind = put_name(decoded.reply.kind_name(), out_kind, kind_cap);
            if kind != Status::Ok {
                return Ok(kind);
            }
            if let mdb::Reply::Block(payload) = decoded.reply {
                return Ok(put_bytes(
                    &payload,
                    out_payload,
                    payload_cap,
                    out_payload_len,
                ));
            }
            Ok(Status::Ok)
        })())
    })
}

#[cfg(test)]
mod tests {
    use super::*;

    fn status_buf() -> Vec<c_char> {
        vec![0; rk_devices_status_capacity()]
    }

    #[test]
    fn a_panic_becomes_a_named_value_and_never_leaves_the_boundary() {
        let mut st = status_buf();
        let rc = unsafe { rk_devices_provoke_panic_for_test(st.as_mut_ptr(), st.len()) };
        assert_eq!(rc, CALL_FAILED);
        let name = unsafe { CStr::from_ptr(st.as_ptr()) }.to_str().unwrap();
        assert_eq!(name, "panic");
    }

    #[test]
    fn a_status_buffer_too_small_says_so_instead_of_writing_past_it() {
        let mut st: Vec<c_char> = vec![0; 2];
        let mut out = [0u8; 8];
        let mut len = 0usize;
        let name = std::ffi::CString::new("cas").unwrap();
        let rc = unsafe {
            rk_devices_scale_weight_request(
                name.as_ptr(),
                out.as_mut_ptr(),
                out.len(),
                &mut len,
                st.as_mut_ptr(),
                st.len(),
            )
        };
        assert_eq!(rc, CALL_NO_STATUS_ROOM);
        assert_eq!(st, vec![0, 0]);
    }

    #[test]
    fn a_short_output_buffer_reports_the_length_it_needed() {
        let mut st = status_buf();
        let mut out = [0u8; 1];
        let mut len = 0usize;
        let name = std::ffi::CString::new("cas").unwrap();
        let rc = unsafe {
            rk_devices_scale_weight_request(
                name.as_ptr(),
                out.as_mut_ptr(),
                out.len(),
                &mut len,
                st.as_mut_ptr(),
                st.len(),
            )
        };
        assert_eq!(rc, CALL_FAILED);
        assert_eq!(
            unsafe { CStr::from_ptr(st.as_ptr()) }.to_str().unwrap(),
            "buffer_too_small"
        );
        assert_eq!(len, 2);
    }

    #[test]
    fn the_weight_request_crosses_the_boundary_as_the_right_bytes() {
        let mut st = status_buf();
        let mut out = [0u8; 8];
        let mut len = 0usize;
        let name = std::ffi::CString::new("massa_k").unwrap();
        let rc = unsafe {
            rk_devices_scale_weight_request(
                name.as_ptr(),
                out.as_mut_ptr(),
                out.len(),
                &mut len,
                st.as_mut_ptr(),
                st.len(),
            )
        };
        assert_eq!(rc, CALL_OK);
        assert_eq!(&out[..len], &[0x4E, 0x0D]);
    }

    #[test]
    fn an_unknown_name_is_refused_by_name() {
        let mut st = status_buf();
        let mut out = [0u8; 8];
        let mut len = 0usize;
        let name = std::ffi::CString::new("toledo").unwrap();
        let rc = unsafe {
            rk_devices_scale_weight_request(
                name.as_ptr(),
                out.as_mut_ptr(),
                out.len(),
                &mut len,
                st.as_mut_ptr(),
                st.len(),
            )
        };
        assert_eq!(rc, CALL_FAILED);
        assert_eq!(
            unsafe { CStr::from_ptr(st.as_ptr()) }.to_str().unwrap(),
            "unknown_name"
        );
    }

    #[test]
    fn a_null_name_is_an_argument_error_not_a_crash() {
        let mut st = status_buf();
        let mut out = [0u8; 8];
        let mut len = 0usize;
        let rc = unsafe {
            rk_devices_scale_weight_request(
                ptr::null(),
                out.as_mut_ptr(),
                out.len(),
                &mut len,
                st.as_mut_ptr(),
                st.len(),
            )
        };
        assert_eq!(rc, CALL_FAILED);
        assert_eq!(
            unsafe { CStr::from_ptr(st.as_ptr()) }.to_str().unwrap(),
            "invalid_argument"
        );
    }

    #[test]
    fn the_stabilizer_is_sized_for_the_caller_to_allocate() {
        assert_eq!(
            rk_devices_stabilizer_size(),
            core::mem::size_of::<scale::Stabilizer>()
        );
        assert!(rk_devices_stabilizer_align() >= 8);

        let mut st = status_buf();
        let mut state: Vec<u64> = vec![0; rk_devices_stabilizer_size().div_ceil(8)];
        let ptr = state.as_mut_ptr() as *mut u8;
        assert_eq!(
            unsafe { rk_devices_stabilizer_init(ptr, 1, 1_000, st.as_mut_ptr(), st.len()) },
            CALL_OK
        );

        let mut verdict: Vec<c_char> = vec![0; 16];
        let silence = std::ffi::CString::new("silence").unwrap();
        let rc = unsafe {
            rk_devices_stabilizer_offer(
                ptr,
                1_000,
                silence.as_ptr(),
                0,
                0,
                ptr::null(),
                verdict.as_mut_ptr(),
                verdict.len(),
                st.as_mut_ptr(),
                st.len(),
            )
        };
        assert_eq!(rc, CALL_OK);
        assert_eq!(
            unsafe { CStr::from_ptr(verdict.as_ptr()) }
                .to_str()
                .unwrap(),
            "no_answer"
        );
    }

    #[test]
    fn an_uninitialised_stabilizer_is_refused_rather_than_read() {
        let mut st = status_buf();
        let mut state: Vec<u64> = vec![0; rk_devices_stabilizer_size().div_ceil(8)];
        let ptr = state.as_mut_ptr() as *mut u8;
        let mut verdict: Vec<c_char> = vec![0; 16];
        let silence = std::ffi::CString::new("silence").unwrap();
        let rc = unsafe {
            rk_devices_stabilizer_offer(
                ptr,
                0,
                silence.as_ptr(),
                0,
                0,
                ptr::null(),
                verdict.as_mut_ptr(),
                verdict.len(),
                st.as_mut_ptr(),
                st.len(),
            )
        };
        assert_eq!(rc, CALL_FAILED);
        assert_eq!(
            unsafe { CStr::from_ptr(st.as_ptr()) }.to_str().unwrap(),
            "invalid_argument"
        );
    }
}

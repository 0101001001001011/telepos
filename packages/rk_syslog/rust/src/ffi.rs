//! The C ABI.
//!
//! # Rules that hold for every function here
//!
//! **Failure is a returned value (И144).** Every entry point returns an
//! `int32_t` from the [`Status`] table. Nothing panics out of this module:
//! each body runs inside `catch_unwind`, and a panic that would have unwound
//! into the caller comes back as `panicked` (18) instead. A panic is a defect
//! in this library, but it is a defect the caller survives.
//!
//! **Who frees what (И146).**
//!
//! | Thing | Made by | Freed by |
//! | --- | --- | --- |
//! | `RkSyslogConfig*` | `rk_syslog_config_new` | `rk_syslog_config_free` |
//! | `RkSyslogSd*` | `rk_syslog_sd_new` | `rk_syslog_sd_free` |
//! | `RkSyslogSink*` | `rk_syslog_open` | `rk_syslog_close` |
//! | `char*` out-parameter | any call that sets one | `rk_syslog_string_free` |
//! | `const char*` return | `rk_syslog_status_name`, `rk_syslog_version`, `rk_syslog_key_at`, … | **nobody** — static, never freed |
//!
//! Every `const char*` **argument** is borrowed for the duration of the call.
//! This library copies whatever it keeps, so the caller may free its string
//! the moment the call returns.
//!
//! `rk_syslog_close` joins the worker thread before it frees anything, so a
//! sink that has been closed has finished writing. That is what makes the
//! freeing deterministic rather than eventual.
//!
//! **Enums cross by name (И147).** Severity, facility and every
//! configuration value are strings. The `int32_t` status is a wire code, and
//! `rk_syslog_status_name` turns it into the name a binding should switch on.

use std::ffi::{c_char, CStr, CString};
use std::panic::{catch_unwind, AssertUnwindSafe};
use std::time::Duration;

use crate::config::{ConfigBuilder, KEYS};
use crate::rfc5424::{Record, StructuredData};
use crate::severity::{Facility, Severity};
use crate::sink::{Sink, COUNTER_NAMES};
use crate::status::{Failure, Fallible, Status};

/// A configuration under construction.
#[derive(Debug)]
pub struct RkSyslogConfig {
    builder: ConfigBuilder,
}

/// Structured data under construction.
#[derive(Debug)]
pub struct RkSyslogSd {
    data: StructuredData,
}

/// A running sink.
#[derive(Debug)]
pub struct RkSyslogSink {
    sink: Sink,
}

/// Runs a body, turning a panic into a status instead of letting it unwind
/// into a foreign stack.
fn guard<F: FnOnce() -> Fallible<()>>(out_error: *mut *mut c_char, body: F) -> i32 {
    if !out_error.is_null() {
        // SAFETY: checked non-null just above. Every entry point documents
        // that out_error, when given, points at writable storage for one
        // pointer; clearing it first means a caller who forgets to check the
        // status still sees a null rather than a stale error from an earlier
        // call.
        unsafe { *out_error = std::ptr::null_mut() };
    }
    let outcome = catch_unwind(AssertUnwindSafe(body));
    match outcome {
        Ok(Ok(())) => Status::Ok as i32,
        Ok(Err(failure)) => {
            set_error(out_error, &failure.detail);
            failure.status as i32
        }
        Err(payload) => {
            let detail = panic_detail(payload.as_ref());
            set_error(out_error, &detail);
            Status::Panicked as i32
        }
    }
}

fn panic_detail(payload: &(dyn std::any::Any + Send)) -> String {
    if let Some(text) = payload.downcast_ref::<&str>() {
        format!("rk_syslog panicked: {text}")
    } else if let Some(text) = payload.downcast_ref::<String>() {
        format!("rk_syslog panicked: {text}")
    } else {
        "rk_syslog panicked".to_string()
    }
}

fn set_error(out_error: *mut *mut c_char, detail: &str) {
    if out_error.is_null() {
        return;
    }
    // A detail with an interior NUL cannot become a C string; the status is
    // still returned, so the caller is told what happened even if not why.
    let Ok(owned) = CString::new(detail) else {
        return;
    };
    // SAFETY: out_error was checked non-null at the top of this function.
    // Ownership of the string passes to the caller here, who frees it with
    // rk_syslog_string_free (И146).
    unsafe { *out_error = owned.into_raw() };
}

/// Borrows a C string for the duration of a call.
fn borrow<'a>(what: &str, pointer: *const c_char) -> Fallible<&'a str> {
    if pointer.is_null() {
        return Err(Failure::new(
            Status::NullArgument,
            format!("{what} must not be null"),
        ));
    }
    // SAFETY: checked non-null above. The contract on every entry point is
    // that a non-null string argument is NUL-terminated and stays valid for
    // the duration of the call; the borrow does not outlive it, because
    // anything kept is copied.
    unsafe { CStr::from_ptr(pointer) }
        .to_str()
        .map_err(|_| Failure::new(Status::InvalidUtf8, format!("{what} is not valid UTF-8")))
}

/// Same, but a null pointer means "absent".
fn borrow_optional<'a>(what: &str, pointer: *const c_char) -> Fallible<Option<&'a str>> {
    if pointer.is_null() {
        return Ok(None);
    }
    borrow(what, pointer).map(Some)
}

fn handle<'a, T>(what: &str, pointer: *mut T) -> Fallible<&'a mut T> {
    if pointer.is_null() {
        return Err(Failure::new(
            Status::InvalidHandle,
            format!("{what} is null"),
        ));
    }
    // SAFETY: checked non-null above. The pointer is one this library handed
    // out from a Box, and the C ABI is single-threaded per handle: nothing
    // here hands the same handle to two callers at once.
    Ok(unsafe { &mut *pointer })
}

// ---------------------------------------------------------------- version

/// The version of this library, as `MAJOR.MINOR.PATCH`. Static; never freed.
///
/// # Safety
/// The returned pointer is valid for the lifetime of the loaded library.
#[no_mangle]
pub extern "C" fn rk_syslog_version() -> *const c_char {
    concat!(env!("CARGO_PKG_VERSION"), "\0").as_ptr() as *const c_char
}

/// The name of a status code. Static; never freed. Null for a code this
/// version does not define, which is itself the answer a binding needs.
#[no_mangle]
pub extern "C" fn rk_syslog_status_name(code: i32) -> *const c_char {
    macro_rules! nul {
        ($s:expr) => {
            concat!($s, "\0").as_ptr() as *const c_char
        };
    }
    match Status::from_code(code) {
        None => std::ptr::null(),
        Some(status) => match status {
            Status::Ok => nul!("ok"),
            Status::NullArgument => nul!("nullArgument"),
            Status::InvalidUtf8 => nul!("invalidUtf8"),
            Status::UnknownConfigKey => nul!("unknownConfigKey"),
            Status::InvalidConfigValue => nul!("invalidConfigValue"),
            Status::MissingConfigKey => nul!("missingConfigKey"),
            Status::UnknownSeverity => nul!("unknownSeverity"),
            Status::UnknownFacility => nul!("unknownFacility"),
            Status::InvalidHeaderField => nul!("invalidHeaderField"),
            Status::InvalidStructuredData => nul!("invalidStructuredData"),
            Status::InvalidMessage => nul!("invalidMessage"),
            Status::QueueFull => nul!("queueFull"),
            Status::SpoolFull => nul!("spoolFull"),
            Status::SpoolIo => nul!("spoolIo"),
            Status::TransportIo => nul!("transportIo"),
            Status::TlsConfig => nul!("tlsConfig"),
            Status::Timeout => nul!("timeout"),
            Status::Closed => nul!("closed"),
            Status::Panicked => nul!("panicked"),
            Status::InvalidHandle => nul!("invalidHandle"),
            Status::UnknownStat => nul!("unknownStat"),
        },
    }
}

/// Frees a string this library handed out through an out-parameter.
///
/// # Safety
/// `text` must be a pointer this library returned and must not be freed twice.
#[no_mangle]
pub unsafe extern "C" fn rk_syslog_string_free(text: *mut c_char) {
    if text.is_null() {
        return;
    }
    let _ = catch_unwind(AssertUnwindSafe(|| {
        drop(CString::from_raw(text));
    }));
}

// -------------------------------------------------- names, for a binding
// A binding can check its own tables against ours instead of assuming they
// agree — which is the whole point of crossing by name. Position here is an
// iteration order for discovery, never a meaning.

/// The PRI number of a severity name. Returns `ok`, or `unknownSeverity`.
///
/// # Safety
/// `name` must be a NUL-terminated string.
#[no_mangle]
pub unsafe extern "C" fn rk_syslog_severity_value(name: *const c_char, out: *mut i32) -> i32 {
    guard(std::ptr::null_mut(), || {
        let name = borrow("severity name", name)?;
        let out = handle("out", out)?;
        *out = Severity::from_name(name)? as i32;
        Ok(())
    })
}

/// The PRI number of a facility name. Returns `ok`, or `unknownFacility`.
///
/// # Safety
/// `name` must be a NUL-terminated string.
#[no_mangle]
pub unsafe extern "C" fn rk_syslog_facility_value(name: *const c_char, out: *mut i32) -> i32 {
    guard(std::ptr::null_mut(), || {
        let name = borrow("facility name", name)?;
        let out = handle("out", out)?;
        *out = Facility::from_name(name)? as i32;
        Ok(())
    })
}

/// Every name table, NUL-terminated, built once and kept for the lifetime of
/// the library. Built lazily rather than written out twice, so the lists
/// here cannot drift from the enums they come from.
fn name_table(kind: &str) -> Option<&'static [CString]> {
    use std::sync::OnceLock;
    fn build(source: Vec<&'static str>) -> Vec<CString> {
        source
            .into_iter()
            .filter_map(|s| CString::new(s).ok())
            .collect()
    }
    static SEVERITY: OnceLock<Vec<CString>> = OnceLock::new();
    static FACILITY: OnceLock<Vec<CString>> = OnceLock::new();
    static CONFIG_KEY: OnceLock<Vec<CString>> = OnceLock::new();
    static COUNTER: OnceLock<Vec<CString>> = OnceLock::new();
    static STATUS: OnceLock<Vec<CString>> = OnceLock::new();
    Some(match kind {
        "severity" => {
            SEVERITY.get_or_init(|| build(Severity::ALL.iter().map(|s| s.name()).collect()))
        }
        "facility" => {
            FACILITY.get_or_init(|| build(Facility::ALL.iter().map(|f| f.name()).collect()))
        }
        "config_key" => CONFIG_KEY.get_or_init(|| build(KEYS.iter().map(|(k, _)| *k).collect())),
        "counter" => COUNTER.get_or_init(|| build(COUNTER_NAMES.to_vec())),
        "status" => STATUS.get_or_init(|| build(Status::ALL.iter().map(|s| s.name()).collect())),
        _ => return None,
    })
}

/// Names this library knows, for discovery. `kind` is `"severity"`,
/// `"facility"`, `"config_key"`, `"counter"` or `"status"`. Returns null past
/// the end of the list, and for an unknown kind. Static; never freed.
///
/// The index is an iteration order for walking a list, never a meaning: a
/// binding compares the **names** it gets here with the names it knows, and
/// says so if they differ.
///
/// # Safety
/// `kind` must be a NUL-terminated string.
#[no_mangle]
pub unsafe extern "C" fn rk_syslog_name_at(kind: *const c_char, index: i32) -> *const c_char {
    let outcome = catch_unwind(AssertUnwindSafe(|| {
        let Ok(kind) = borrow("kind", kind) else {
            return std::ptr::null();
        };
        if index < 0 {
            return std::ptr::null();
        }
        match name_table(kind).and_then(|table| table.get(index as usize)) {
            Some(name) => name.as_ptr(),
            None => std::ptr::null(),
        }
    }));
    outcome.unwrap_or(std::ptr::null())
}

// ----------------------------------------------------------- configuration

/// A new, empty configuration. Free with `rk_syslog_config_free`.
#[no_mangle]
pub extern "C" fn rk_syslog_config_new() -> *mut RkSyslogConfig {
    match catch_unwind(|| {
        Box::into_raw(Box::new(RkSyslogConfig {
            builder: ConfigBuilder::new(),
        }))
    }) {
        Ok(pointer) => pointer,
        Err(_) => std::ptr::null_mut(),
    }
}

/// Sets one named key. An unknown key returns `unknownConfigKey`.
///
/// # Safety
/// `config` must come from `rk_syslog_config_new`; `key` and `value` must be
/// NUL-terminated strings, borrowed only for this call.
#[no_mangle]
pub unsafe extern "C" fn rk_syslog_config_set(
    config: *mut RkSyslogConfig,
    key: *const c_char,
    value: *const c_char,
    out_error: *mut *mut c_char,
) -> i32 {
    guard(out_error, || {
        let config = handle("config", config)?;
        let key = borrow("key", key)?;
        let value = borrow("value", value)?;
        config.builder.set(key, value)
    })
}

/// Frees a configuration.
///
/// # Safety
/// `config` must come from `rk_syslog_config_new` and must not be freed twice.
#[no_mangle]
pub unsafe extern "C" fn rk_syslog_config_free(config: *mut RkSyslogConfig) {
    if config.is_null() {
        return;
    }
    let _ = catch_unwind(AssertUnwindSafe(|| drop(Box::from_raw(config))));
}

// -------------------------------------------------------- structured data

/// New, empty structured data. Free with `rk_syslog_sd_free`.
#[no_mangle]
pub extern "C" fn rk_syslog_sd_new() -> *mut RkSyslogSd {
    match catch_unwind(|| {
        Box::into_raw(Box::new(RkSyslogSd {
            data: StructuredData::new(),
        }))
    }) {
        Ok(pointer) => pointer,
        Err(_) => std::ptr::null_mut(),
    }
}

/// Starts an SD-ELEMENT. Later parameters attach to it.
///
/// # Safety
/// `sd` must come from `rk_syslog_sd_new`; `sd_id` must be NUL-terminated.
#[no_mangle]
pub unsafe extern "C" fn rk_syslog_sd_element(
    sd: *mut RkSyslogSd,
    sd_id: *const c_char,
    out_error: *mut *mut c_char,
) -> i32 {
    guard(out_error, || {
        let sd = handle("sd", sd)?;
        let sd_id = borrow("sd_id", sd_id)?;
        sd.data.push_element(sd_id)
    })
}

/// Adds a parameter to the current element. The value is escaped here; do not
/// escape it before calling.
///
/// # Safety
/// `sd` must come from `rk_syslog_sd_new`; `name` and `value` must be
/// NUL-terminated.
#[no_mangle]
pub unsafe extern "C" fn rk_syslog_sd_param(
    sd: *mut RkSyslogSd,
    name: *const c_char,
    value: *const c_char,
    out_error: *mut *mut c_char,
) -> i32 {
    guard(out_error, || {
        let sd = handle("sd", sd)?;
        let name = borrow("name", name)?;
        let value = borrow("value", value)?;
        sd.data.push_param(name, value)
    })
}

/// Empties structured data so one allocation can be reused between records.
///
/// # Safety
/// `sd` must come from `rk_syslog_sd_new`.
#[no_mangle]
pub unsafe extern "C" fn rk_syslog_sd_clear(sd: *mut RkSyslogSd) -> i32 {
    guard(std::ptr::null_mut(), || {
        let sd = handle("sd", sd)?;
        sd.data.elements.clear();
        Ok(())
    })
}

/// Frees structured data.
///
/// # Safety
/// `sd` must come from `rk_syslog_sd_new` and must not be freed twice.
#[no_mangle]
pub unsafe extern "C" fn rk_syslog_sd_free(sd: *mut RkSyslogSd) {
    if sd.is_null() {
        return;
    }
    let _ = catch_unwind(AssertUnwindSafe(|| drop(Box::from_raw(sd))));
}

// -------------------------------------------------------------- the sink

/// Opens a sink from a configuration. The configuration is only read, and
/// remains the caller's to free.
///
/// # Safety
/// `config` must come from `rk_syslog_config_new`; `out_sink` must point at
/// writable storage for one pointer.
#[no_mangle]
pub unsafe extern "C" fn rk_syslog_open(
    config: *mut RkSyslogConfig,
    out_sink: *mut *mut RkSyslogSink,
    out_error: *mut *mut c_char,
) -> i32 {
    guard(out_error, || {
        let config = handle("config", config)?;
        let out_sink = handle("out_sink", out_sink)?;
        let settings = config.builder.build()?;
        let sink = Sink::open(settings)?;
        *out_sink = Box::into_raw(Box::new(RkSyslogSink { sink }));
        Ok(())
    })
}

/// Frames a record and hands it to the worker. Does not touch the network or
/// the disk on this thread.
///
/// `facility_name` may be null, meaning the sink's default. `msgid`,
/// `structured_data` and `message` may all be null. Every string is borrowed
/// for this call only.
///
/// # Safety
/// `sink` must come from `rk_syslog_open`; every non-null string must be
/// NUL-terminated.
#[no_mangle]
#[allow(clippy::too_many_arguments)]
pub unsafe extern "C" fn rk_syslog_submit(
    sink: *mut RkSyslogSink,
    severity_name: *const c_char,
    facility_name: *const c_char,
    epoch_micros: i64,
    utc_offset_minutes: i32,
    msgid: *const c_char,
    structured_data: *const RkSyslogSd,
    message: *const c_char,
    out_error: *mut *mut c_char,
) -> i32 {
    guard(out_error, || {
        let sink = handle("sink", sink)?;
        let severity = Severity::from_name(borrow("severity_name", severity_name)?)?;
        let facility = match borrow_optional("facility_name", facility_name)? {
            Some(name) => Facility::from_name(name)?,
            None => sink.sink.settings().facility,
        };
        let data = if structured_data.is_null() {
            StructuredData::new()
        } else {
            (*structured_data).data.clone()
        };
        let record = Record {
            facility,
            severity,
            epoch_micros,
            utc_offset_minutes,
            msgid: borrow_optional("msgid", msgid)?.map(str::to_string),
            structured_data: data,
            message: borrow_optional("message", message)?.map(str::to_string),
        };
        sink.sink.submit(&record)
    })
}

/// Blocks the calling thread until everything submitted so far has reached
/// the spool, or `timeout_ms` elapses. Says nothing about delivery.
///
/// # Safety
/// `sink` must come from `rk_syslog_open`.
#[no_mangle]
pub unsafe extern "C" fn rk_syslog_flush(
    sink: *mut RkSyslogSink,
    timeout_ms: i32,
    out_error: *mut *mut c_char,
) -> i32 {
    guard(out_error, || {
        let sink = handle("sink", sink)?;
        sink.sink
            .flush(Duration::from_millis(timeout_ms.max(0) as u64))
    })
}

/// Reads a counter by name. An unknown name returns `unknownStat` rather than
/// zero, so a binding cannot mistake "not measured" for "measured, and none".
///
/// # Safety
/// `sink` must come from `rk_syslog_open`; `name` must be NUL-terminated;
/// `out_value` must point at writable storage.
#[no_mangle]
pub unsafe extern "C" fn rk_syslog_stat(
    sink: *mut RkSyslogSink,
    name: *const c_char,
    out_value: *mut i64,
    out_error: *mut *mut c_char,
) -> i32 {
    guard(out_error, || {
        let sink = handle("sink", sink)?;
        let name = borrow("name", name)?;
        let out_value = handle("out_value", out_value)?;
        match sink.sink.stat(name) {
            Some(value) => {
                *out_value = value as i64;
                Ok(())
            }
            None => Err(Failure::new(
                Status::UnknownStat,
                format!("'{name}' is not a counter this version publishes"),
            )),
        }
    })
}

/// Closes a sink: stops accepting, waits for the worker to finish writing
/// what it accepted, then frees. Deterministic — nothing is left for a
/// garbage collector to notice later.
///
/// # Safety
/// `sink` must come from `rk_syslog_open` and must not be closed twice.
#[no_mangle]
pub unsafe extern "C" fn rk_syslog_close(sink: *mut RkSyslogSink) {
    if sink.is_null() {
        return;
    }
    let _ = catch_unwind(AssertUnwindSafe(|| drop(Box::from_raw(sink))));
}

/// Provokes a panic behind the boundary, so a caller can prove for itself
/// that a panic comes back as `panicked` (18) rather than killing the
/// process. Present in every build on purpose: a safety net nobody can test
/// in the build they ship is a safety net nobody has tested.
///
/// # Safety
/// Always safe to call. Takes no arguments and keeps nothing.
#[no_mangle]
pub unsafe extern "C" fn rk_syslog_provoke_panic(out_error: *mut *mut c_char) -> i32 {
    guard(out_error, || {
        panic!("deliberate panic from rk_syslog_provoke_panic");
    })
}

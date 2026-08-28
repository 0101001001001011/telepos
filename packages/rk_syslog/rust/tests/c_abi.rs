//! The C ABI, exercised the way a binding uses it.
//!
//! These are the invariants a Dart binding cannot check for itself without a
//! built library, so they are checked here: a panic returns rather than
//! aborts, enums cross by name, and everything freed is freed by the side
//! that made it.

use std::ffi::{c_char, CStr, CString};

use rk_syslog::ffi::*;
use rk_syslog::status::Status;

fn c(text: &str) -> CString {
    CString::new(text).unwrap()
}

fn take_error(pointer: *mut c_char) -> String {
    if pointer.is_null() {
        return String::new();
    }
    let text = unsafe { CStr::from_ptr(pointer) }
        .to_string_lossy()
        .into_owned();
    // Freed by this library, because this library made it (И146).
    unsafe { rk_syslog_string_free(pointer) };
    text
}

struct TempDir(std::path::PathBuf);

impl TempDir {
    fn new(tag: &str) -> TempDir {
        let mut path = std::env::temp_dir();
        let nanos = std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .unwrap()
            .as_nanos();
        path.push(format!("rk_syslog-abi-{tag}-{nanos}"));
        std::fs::create_dir_all(&path).unwrap();
        TempDir(path)
    }
}

impl Drop for TempDir {
    fn drop(&mut self) {
        let _ = std::fs::remove_dir_all(&self.0);
    }
}

#[test]
fn a_panic_behind_the_boundary_comes_back_as_a_value() {
    // И144. If this ever aborts instead, the test binary dies and the
    // failure is unmistakable — which is the point.
    let mut error: *mut c_char = std::ptr::null_mut();
    let code = unsafe { rk_syslog_provoke_panic(&mut error) };
    assert_eq!(code, Status::Panicked as i32);
    let detail = take_error(error);
    assert!(detail.contains("panicked"), "{detail}");

    // And the library still works afterwards.
    let config = rk_syslog_config_new();
    assert!(!config.is_null());
    unsafe { rk_syslog_config_free(config) };
}

#[test]
fn a_status_code_can_be_turned_into_its_name() {
    for status in Status::ALL {
        let pointer = rk_syslog_status_name(status as i32);
        assert!(!pointer.is_null(), "{status:?} has no name");
        let name = unsafe { CStr::from_ptr(pointer) }.to_str().unwrap();
        assert_eq!(name, status.name());
    }
    // A code from a future version is null, not a wrong name.
    assert!(rk_syslog_status_name(9999).is_null());
    assert!(rk_syslog_status_name(-1).is_null());
}

#[test]
fn severities_and_facilities_cross_by_name() {
    // И147. A binding asks for the number that goes with a name; it never
    // sends a position and hopes the lists agree.
    let mut value = -1i32;
    assert_eq!(
        unsafe { rk_syslog_severity_value(c("warning").as_ptr(), &mut value) },
        Status::Ok as i32
    );
    assert_eq!(value, 4);

    assert_eq!(
        unsafe { rk_syslog_facility_value(c("audit").as_ptr(), &mut value) },
        Status::Ok as i32
    );
    assert_eq!(value, 13);

    // A name this version does not know is refused, not defaulted to zero.
    assert_eq!(
        unsafe { rk_syslog_severity_value(c("warn").as_ptr(), &mut value) },
        Status::UnknownSeverity as i32
    );
    assert_eq!(
        unsafe { rk_syslog_facility_value(c("local8").as_ptr(), &mut value) },
        Status::UnknownFacility as i32
    );
}

#[test]
fn a_binding_can_walk_every_name_table() {
    for (kind, least) in [
        ("severity", 8),
        ("facility", 24),
        ("config_key", 20),
        ("counter", 10),
        ("status", 21),
    ] {
        let mut count = 0;
        loop {
            let pointer = unsafe { rk_syslog_name_at(c(kind).as_ptr(), count) };
            if pointer.is_null() {
                break;
            }
            let name = unsafe { CStr::from_ptr(pointer) }.to_str().unwrap();
            assert!(!name.is_empty(), "{kind}[{count}] is empty");
            count += 1;
            assert!(count < 1000, "{kind} never ended");
        }
        assert!(count >= least, "{kind} listed only {count} names");
    }
    // An unknown kind is null at the first index rather than a wrong list.
    assert!(unsafe { rk_syslog_name_at(c("colour").as_ptr(), 0) }.is_null());
    // The pointers are stable, so a caller may keep them.
    let first = unsafe { rk_syslog_name_at(c("severity").as_ptr(), 0) };
    let again = unsafe { rk_syslog_name_at(c("severity").as_ptr(), 0) };
    assert_eq!(first, again);
}

#[test]
fn a_misspelled_configuration_key_stops_the_sink_rather_than_being_ignored() {
    let config = rk_syslog_config_new();
    let mut error: *mut c_char = std::ptr::null_mut();
    let code = unsafe {
        rk_syslog_config_set(
            config,
            c("spool_max_byte").as_ptr(),
            c("1000").as_ptr(),
            &mut error,
        )
    };
    assert_eq!(code, Status::UnknownConfigKey as i32);
    let detail = take_error(error);
    assert!(detail.contains("spool_max_bytes"), "{detail}");
    unsafe { rk_syslog_config_free(config) };
}

#[test]
fn a_null_handle_is_a_status_not_a_crash() {
    let mut error: *mut c_char = std::ptr::null_mut();
    let code = unsafe {
        rk_syslog_config_set(
            std::ptr::null_mut(),
            c("app_name").as_ptr(),
            c("x").as_ptr(),
            &mut error,
        )
    };
    assert_eq!(code, Status::InvalidHandle as i32);
    take_error(error);

    // Freeing null is a no-op, not a fault.
    unsafe { rk_syslog_config_free(std::ptr::null_mut()) };
    unsafe { rk_syslog_sd_free(std::ptr::null_mut()) };
    unsafe { rk_syslog_close(std::ptr::null_mut()) };
    unsafe { rk_syslog_string_free(std::ptr::null_mut()) };
}

#[test]
fn a_null_string_argument_is_a_status_not_a_crash() {
    let config = rk_syslog_config_new();
    let mut error: *mut c_char = std::ptr::null_mut();
    let code =
        unsafe { rk_syslog_config_set(config, std::ptr::null(), c("x").as_ptr(), &mut error) };
    assert_eq!(code, Status::NullArgument as i32);
    take_error(error);
    unsafe { rk_syslog_config_free(config) };
}

#[test]
fn the_whole_round_trip_works_through_the_abi() {
    let dir = TempDir::new("roundtrip");
    let config = rk_syslog_config_new();
    let mut error: *mut c_char = std::ptr::null_mut();

    for (key, value) in [
        ("spool_dir", dir.0.to_str().unwrap()),
        ("host_name", "till-01"),
        ("app_name", "telepos"),
        ("proc_id", "99"),
        ("facility", "audit"),
    ] {
        let code =
            unsafe { rk_syslog_config_set(config, c(key).as_ptr(), c(value).as_ptr(), &mut error) };
        assert_eq!(code, Status::Ok as i32, "{key}: {}", take_error(error));
    }

    let mut sink: *mut RkSyslogSink = std::ptr::null_mut();
    let code = unsafe { rk_syslog_open(config, &mut sink, &mut error) };
    assert_eq!(code, Status::Ok as i32, "{}", take_error(error));
    assert!(!sink.is_null());
    // The configuration is only read; it is still ours to free.
    unsafe { rk_syslog_config_free(config) };

    let sd = rk_syslog_sd_new();
    assert_eq!(
        unsafe { rk_syslog_sd_element(sd, c("sale@0").as_ptr(), &mut error) },
        Status::Ok as i32
    );
    assert_eq!(
        unsafe { rk_syslog_sd_param(sd, c("total").as_ptr(), c("1250.00").as_ptr(), &mut error) },
        Status::Ok as i32
    );

    let code = unsafe {
        rk_syslog_submit(
            sink,
            c("informational").as_ptr(),
            std::ptr::null(), // the sink's own facility
            1_065_910_455_003_000,
            0,
            c("SALE").as_ptr(),
            sd,
            c("sale closed").as_ptr(),
            &mut error,
        )
    };
    assert_eq!(code, Status::Ok as i32, "{}", take_error(error));
    unsafe { rk_syslog_sd_free(sd) };

    assert_eq!(
        unsafe { rk_syslog_flush(sink, 5000, &mut error) },
        Status::Ok as i32,
        "{}",
        take_error(error)
    );

    let mut value = -1i64;
    assert_eq!(
        unsafe { rk_syslog_stat(sink, c("spooled").as_ptr(), &mut value, &mut error) },
        Status::Ok as i32
    );
    assert_eq!(value, 1);

    // An unknown counter is refused rather than answered with zero.
    assert_eq!(
        unsafe { rk_syslog_stat(sink, c("spoooled").as_ptr(), &mut value, &mut error) },
        Status::UnknownStat as i32
    );
    take_error(error);

    unsafe { rk_syslog_close(sink) };
}

#[test]
fn an_unusable_severity_stops_the_record_at_the_boundary() {
    let dir = TempDir::new("severity");
    let config = rk_syslog_config_new();
    let mut error: *mut c_char = std::ptr::null_mut();
    unsafe {
        rk_syslog_config_set(
            config,
            c("spool_dir").as_ptr(),
            c(dir.0.to_str().unwrap()).as_ptr(),
            &mut error,
        )
    };
    let mut sink: *mut RkSyslogSink = std::ptr::null_mut();
    assert_eq!(
        unsafe { rk_syslog_open(config, &mut sink, &mut error) },
        Status::Ok as i32
    );
    unsafe { rk_syslog_config_free(config) };

    let code = unsafe {
        rk_syslog_submit(
            sink,
            c("WARNING").as_ptr(), // wrong case is a different name
            std::ptr::null(),
            0,
            0,
            std::ptr::null(),
            std::ptr::null(),
            c("x").as_ptr(),
            &mut error,
        )
    };
    assert_eq!(code, Status::UnknownSeverity as i32);
    let detail = take_error(error);
    assert!(detail.contains("WARNING"), "{detail}");
    unsafe { rk_syslog_close(sink) };
}

#[test]
fn the_version_is_reported_and_is_a_semantic_version() {
    let pointer = rk_syslog_version();
    assert!(!pointer.is_null());
    let text = unsafe { CStr::from_ptr(pointer) }.to_str().unwrap();
    assert_eq!(text, rk_syslog::VERSION);
    assert_eq!(
        text.split('.').count(),
        3,
        "{text} is not MAJOR.MINOR.PATCH"
    );
}

#[test]
fn the_c_header_matches_the_library() {
    // A hand-written header is a document, and a document drifts. This is
    // what stops it: every status constant it declares must still mean what
    // the library says it means, and every exported function must still be
    // declared under that name.
    let header = include_str!("../include/rk_syslog.h");

    let mut declared = 0;
    for line in header.lines() {
        let Some(rest) = line.strip_prefix("#define RK_SYSLOG_") else {
            continue;
        };
        let mut parts = rest.split_whitespace();
        let (Some(name), Some(value)) = (parts.next(), parts.next()) else {
            continue;
        };
        let Ok(code) = value.parse::<i32>() else {
            continue;
        };
        declared += 1;

        let expected = Status::from_code(code)
            .unwrap_or_else(|| panic!("the header declares code {code}, the library does not"));
        // SCREAMING_SNAKE in C, lowerCamel in the library.
        let flattened: String = expected
            .name()
            .chars()
            .flat_map(|c| {
                if c.is_ascii_uppercase() {
                    vec!['_', c]
                } else {
                    vec![c.to_ascii_uppercase()]
                }
            })
            .collect();
        assert_eq!(
            name,
            flattened,
            "the header calls code {code} RK_SYSLOG_{name}; the library calls it '{}'",
            expected.name()
        );
    }
    assert_eq!(
        declared,
        Status::ALL.len(),
        "the header declares {declared} statuses, the library has {}",
        Status::ALL.len()
    );

    // Every exported function is declared. That they exist is proved by this
    // file linking against them at all.
    for symbol in [
        "rk_syslog_version",
        "rk_syslog_status_name",
        "rk_syslog_string_free",
        "rk_syslog_severity_value",
        "rk_syslog_facility_value",
        "rk_syslog_name_at",
        "rk_syslog_config_new",
        "rk_syslog_config_set",
        "rk_syslog_config_free",
        "rk_syslog_sd_new",
        "rk_syslog_sd_element",
        "rk_syslog_sd_param",
        "rk_syslog_sd_clear",
        "rk_syslog_sd_free",
        "rk_syslog_open",
        "rk_syslog_submit",
        "rk_syslog_flush",
        "rk_syslog_stat",
        "rk_syslog_close",
        "rk_syslog_provoke_panic",
    ] {
        assert!(
            header.contains(symbol),
            "{symbol} is exported but the header does not declare it"
        );
    }
}

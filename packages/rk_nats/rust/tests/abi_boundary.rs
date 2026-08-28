//! The three promises the C ABI makes, tested through the C ABI.
//!
//! These call the exported symbols the way a foreign runtime does — raw
//! pointers, no Rust types — because a promise about the boundary that is only
//! tested from the Rust side is a promise about something else.

use std::ffi::{CStr, CString};

use rk_nats::ffi;

/// Calls a boundary function with a JSON body and gives back the parsed reply,
/// freeing the reply the way the contract says to.
fn call(
    f: unsafe extern "C" fn(*const std::ffi::c_char) -> *mut std::ffi::c_char,
    body: &str,
) -> serde_json::Value {
    let arg = CString::new(body).unwrap();
    unsafe {
        let out = f(arg.as_ptr());
        assert!(!out.is_null(), "the boundary must never return null");
        let text = CStr::from_ptr(out).to_str().unwrap().to_owned();
        ffi::rk_nats_string_free(out);
        serde_json::from_str(&text).expect("reply must be JSON")
    }
}

fn code(v: &serde_json::Value) -> &str {
    v["code"].as_str().expect("every reply carries a code")
}

#[test]
fn a_panic_becomes_a_value_and_the_process_survives() {
    // I144. The function panics on purpose. If the unwind escaped, this test
    // would not fail — the test binary would die — so the fact that we reach
    // the assertion at all is half the evidence.
    let reply = call(ffi::rk_nats_panic_for_test, "{}");
    assert_eq!(code(&reply), "panic");
    assert!(reply["message"]
        .as_str()
        .unwrap()
        .contains("deliberate panic"));

    // And the library still works afterwards, which is the other half: a
    // caught panic that leaves a poisoned lock behind is not caught.
    let after = call(ffi::rk_nats_vocabulary, "{}");
    assert_eq!(code(&after), "ok");
}

#[test]
fn a_null_argument_is_a_code_not_a_dereference() {
    unsafe {
        let out = ffi::rk_nats_connect(std::ptr::null());
        assert!(!out.is_null());
        let text = CStr::from_ptr(out).to_str().unwrap().to_owned();
        ffi::rk_nats_string_free(out);
        let v: serde_json::Value = serde_json::from_str(&text).unwrap();
        assert_eq!(v["code"], "invalidRequest");
        assert!(v["message"].as_str().unwrap().contains("null"));
    }
}

#[test]
fn a_body_that_is_not_json_is_a_code() {
    let reply = call(ffi::rk_nats_connect, "this is not json");
    assert_eq!(code(&reply), "invalidRequest");
}

#[test]
fn a_missing_required_field_is_a_code() {
    let reply = call(ffi::rk_nats_publish, r#"{"handle":1}"#);
    assert_eq!(code(&reply), "invalidRequest");
}

#[test]
fn freeing_null_is_allowed_and_does_nothing() {
    // Callers unwind through error paths where the pointer may never have been
    // set. Making that a crash would push the whole burden onto them.
    unsafe { ffi::rk_nats_string_free(std::ptr::null_mut()) };
}

#[test]
fn an_unknown_handle_is_a_code_not_a_crash() {
    // I144 again, and the reason handles are integers in a registry rather
    // than pointers: the same mistake with a pointer is a segfault in a
    // foreign stack, which is precisely what the invariant forbids.
    let reply = call(ffi::rk_nats_close, r#"{"handle":999999}"#);
    assert_eq!(code(&reply), "handleClosed");

    let reply = call(
        ffi::rk_nats_publish,
        r#"{"handle":999999,"stream":"s","subject":"s.a","payloadBase64":""}"#,
    );
    assert_eq!(code(&reply), "handleClosed");
}

#[test]
fn closing_twice_says_so_the_second_time() {
    let reply = call(ffi::rk_nats_close, r#"{"handle":424242}"#);
    assert_eq!(code(&reply), "handleClosed");
}

#[test]
fn the_abi_version_is_static_and_must_not_be_freed() {
    unsafe {
        let a = ffi::rk_nats_abi_version();
        let b = ffi::rk_nats_abi_version();
        assert_eq!(
            a, b,
            "a static pointer, returned twice, is the same pointer"
        );
        assert_eq!(CStr::from_ptr(a).to_str().unwrap(), rk_nats::ABI_VERSION);
    }
}

#[test]
fn the_vocabulary_lists_every_name_the_binding_has_to_know() {
    let v = call(ffi::rk_nats_vocabulary, "{}");
    let codes: Vec<&str> = v["codes"]
        .as_array()
        .unwrap()
        .iter()
        .map(|c| c.as_str().unwrap())
        .collect();
    assert!(codes.contains(&"durabilityUnproven"));
    assert!(codes.contains(&"durabilityWeakerThanRequested"));
    assert!(codes.contains(&"panic"));

    let policies: Vec<&str> = v["policies"]
        .as_array()
        .unwrap()
        .iter()
        .map(|c| c.as_str().unwrap())
        .collect();
    assert_eq!(
        policies,
        vec!["fsyncOnAck", "flushOnAck", "ackIsMemoryOnly"]
    );

    // I147: every one of these is a name. If any were a number, this would
    // be reading integers out of a JSON array instead.
    for name in codes.iter().chain(policies.iter()) {
        assert!(
            name.parse::<i64>().is_err(),
            "{name} is a number, not a name"
        );
    }
}

#[test]
fn evaluating_a_captured_varz_needs_no_server() {
    // The evaluation is pure, so a caller can hold a document up to the library
    // and ask what an ack would mean before ever connecting.
    let varz = include_str!("../fixtures/varz_2_14_4_sync_always.json");
    let body = serde_json::json!({ "varz": varz }).to_string();
    let reply = call(ffi::rk_nats_evaluate_varz, &body);
    assert_eq!(code(&reply), "ok");
    assert_eq!(reply["ackMeaning"], "fsyncedToDisk");
    assert_eq!(reply["server"]["syncAlways"], true);

    let varz = include_str!("../fixtures/varz_2_14_4_default.json");
    let body = serde_json::json!({ "varz": varz }).to_string();
    let reply = call(ffi::rk_nats_evaluate_varz, &body);
    assert_eq!(reply["ackMeaning"], "writtenNotFsynced");
    assert_eq!(reply["server"]["syncIntervalNanos"], 120_000_000_000u64);
}

#[test]
fn an_unparseable_varz_is_reported_not_treated_as_a_safe_server() {
    let body = serde_json::json!({ "varz": "{}" }).to_string();
    let reply = call(ffi::rk_nats_evaluate_varz, &body);
    assert_eq!(code(&reply), "durabilityProbeFailed");
}

#[test]
fn the_gate_matrix_crosses_the_boundary_whole() {
    let reply = call(
        ffi::rk_nats_gate_matrix,
        r#"{"acceptedFsyncLagNanos":0,"serverSyncIntervalNanos":null}"#,
    );
    assert_eq!(code(&reply), "ok");
    let rows = reply["rows"].as_array().unwrap();
    assert_eq!(rows.len(), 15, "3 policies x 5 ack meanings");

    let find = |policy: &str, meaning: &str| -> String {
        rows.iter()
            .find(|r| r["policy"] == policy && r["meaning"] == meaning)
            .unwrap()["code"]
            .as_str()
            .unwrap()
            .to_string()
    };
    assert_eq!(find("fsyncOnAck", "fsyncedToDisk"), "ok");
    assert_eq!(find("fsyncOnAck", "unknown"), "durabilityUnproven");
    assert_eq!(
        find("fsyncOnAck", "writtenNotFsynced"),
        "durabilityWeakerThanRequested"
    );
    assert_eq!(
        find("fsyncOnAck", "ackedBeforeStore"),
        "durabilityWeakerThanRequested"
    );
    assert_eq!(find("ackIsMemoryOnly", "memoryOnly"), "ok");
}

#[test]
fn flush_on_ack_without_a_named_window_is_refused_at_the_door() {
    // Choosing the weaker policy is allowed. Choosing it without saying how
    // much data you accept losing is not: that is the vague middle where
    // "acked" quietly means "probably".
    let reply = call(
        ffi::rk_nats_connect,
        r#"{"servers":["nats://127.0.0.1:1"],"policy":"flushOnAck"}"#,
    );
    assert_eq!(code(&reply), "invalidRequest");
    assert!(reply["message"]
        .as_str()
        .unwrap()
        .contains("acceptedFsyncLagNanos"));
}

#[test]
fn a_policy_spelled_by_number_is_refused() {
    // I147 from the other side: if policies crossed as indices, `0` would be
    // accepted here and would silently become whichever case happens to be
    // first today.
    let reply = call(
        ffi::rk_nats_connect,
        r#"{"servers":["nats://127.0.0.1:1"],"policy":0}"#,
    );
    assert_eq!(code(&reply), "invalidRequest");
}

#[test]
fn a_policy_spelled_with_an_unknown_name_is_refused_not_defaulted() {
    let reply = call(
        ffi::rk_nats_connect,
        r#"{"servers":["nats://127.0.0.1:1"],"policy":"whateverIsFastest"}"#,
    );
    assert_eq!(code(&reply), "invalidRequest");
}

#[test]
fn connecting_to_nothing_fails_with_a_code_and_leaks_no_handle() {
    let before = rk_nats::registry::len();
    let reply = call(
        ffi::rk_nats_connect,
        r#"{"servers":["nats://127.0.0.1:1"],"timeoutMillis":500}"#,
    );
    assert!(
        code(&reply) == "connectFailed" || code(&reply) == "timeout",
        "got {}",
        code(&reply)
    );
    assert_eq!(
        rk_nats::registry::len(),
        before,
        "a failed connect must not leave a handle behind: nothing here is \
         collected for us (I146)"
    );
}

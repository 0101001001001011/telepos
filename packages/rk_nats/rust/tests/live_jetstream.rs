//! End to end against real nats-servers.
//!
//! Ignored by default, because a test that silently passes when there is no
//! server is worse than no test: it reports that durability was checked when
//! nothing was checked. Run them deliberately:
//!
//! ```text
//! nats-server -js -sd ./a -p 14222 -m 18222
//! nats-server -c sync_always.conf          # port 14223, http 18223
//! nats-server-2.11 -js -sd ./c -p 14224 -m 18224
//! cargo test --test live_jetstream -- --ignored --test-threads=1
//! ```
//!
//! Ports come from the environment when set: `RK_NATS_LIVE_DEFAULT`,
//! `RK_NATS_LIVE_SYNC_ALWAYS`, `RK_NATS_LIVE_OLD`, each `host:port`, and
//! `RK_NATS_LIVE_*_HTTP` for the matching monitoring endpoints.

use std::ffi::{CStr, CString};
use std::io::{Read, Write};
use std::net::TcpStream;

use rk_nats::ffi;

fn env(name: &str, fallback: &str) -> String {
    std::env::var(name).unwrap_or_else(|_| fallback.to_string())
}

fn call(
    f: unsafe extern "C" fn(*const std::ffi::c_char) -> *mut std::ffi::c_char,
    body: serde_json::Value,
) -> serde_json::Value {
    let arg = CString::new(body.to_string()).unwrap();
    unsafe {
        let out = f(arg.as_ptr());
        assert!(!out.is_null());
        let text = CStr::from_ptr(out).to_str().unwrap().to_owned();
        ffi::rk_nats_string_free(out);
        serde_json::from_str(&text).unwrap()
    }
}

fn code(v: &serde_json::Value) -> String {
    v["code"].as_str().unwrap().to_string()
}

/// A monitoring GET without an HTTP crate. Enough for one small JSON document
/// on a loopback, and it keeps a TLS stack out of the test dependencies.
fn varz(host_port: &str) -> String {
    let mut s = TcpStream::connect(host_port).expect("monitoring port");
    write!(s, "GET /varz HTTP/1.0\r\nHost: {host_port}\r\n\r\n").unwrap();
    let mut buf = String::new();
    s.read_to_string(&mut buf).unwrap();
    let body = buf.split("\r\n\r\n").nth(1).expect("http body").to_string();
    assert!(body.starts_with('{'), "varz was not JSON: {body}");
    body
}

fn connect(
    server: &str,
    policy: serde_json::Value,
    evidence: serde_json::Value,
) -> serde_json::Value {
    call(
        ffi::rk_nats_connect,
        serde_json::json!({
            "servers": [format!("nats://{server}")],
            "name": "rk_nats live test",
            "timeoutMillis": 5000,
            "evidence": evidence,
        })
        .as_object()
        .unwrap()
        .clone()
        .into_iter()
        .chain(policy.as_object().unwrap().clone())
        .collect::<serde_json::Map<_, _>>()
        .into(),
    )
}

fn fsync_policy() -> serde_json::Value {
    serde_json::json!({ "policy": "fsyncOnAck" })
}

fn unique(prefix: &str) -> String {
    let nanos = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .unwrap()
        .as_nanos();
    format!("{prefix}_{nanos}")
}

// --- the server that does not fsync -----------------------------------------

#[test]
#[ignore = "needs a live nats-server"]
fn a_default_server_cannot_satisfy_the_default_policy() {
    let server = env("RK_NATS_LIVE_DEFAULT", "127.0.0.1:14222");
    let http = env("RK_NATS_LIVE_DEFAULT_HTTP", "127.0.0.1:18222");
    let reply = connect(
        &server,
        fsync_policy(),
        serde_json::json!({ "kind": "varzJson", "varz": varz(&http) }),
    );
    assert_eq!(code(&reply), "ok");
    assert_eq!(reply["durability"]["ackMeaning"], "writtenNotFsynced");
    let handle = reply["handle"].as_u64().unwrap();

    // The stream is refused before it is created, so a refusal leaves nothing
    // behind on the server.
    let name = unique("rk_refused");
    let reply = call(
        ffi::rk_nats_ensure_stream,
        serde_json::json!({ "handle": handle, "name": name, "subjects": [format!("{name}.>")] }),
    );
    assert_eq!(code(&reply), "streamRefusedWeakerThanPolicy");

    call(ffi::rk_nats_close, serde_json::json!({ "handle": handle }));
}

#[test]
#[ignore = "needs a live nats-server"]
fn without_evidence_the_default_policy_refuses_and_says_which_way_out_there_is() {
    let server = env("RK_NATS_LIVE_DEFAULT", "127.0.0.1:14222");
    let reply = connect(
        &server,
        fsync_policy(),
        serde_json::json!({ "kind": "none" }),
    );
    assert_eq!(
        code(&reply),
        "ok",
        "connecting is allowed; publishing is not"
    );
    assert_eq!(reply["durability"]["code"], "durabilityUnproven");
    assert_eq!(reply["durability"]["ackMeaning"], "unknown");

    let handle = reply["handle"].as_u64().unwrap();
    let name = unique("rk_unproven");
    let reply = call(
        ffi::rk_nats_ensure_stream,
        serde_json::json!({ "handle": handle, "name": name }),
    );
    assert_eq!(code(&reply), "durabilityUnproven");
    call(ffi::rk_nats_close, serde_json::json!({ "handle": handle }));
}

#[test]
#[ignore = "needs a live nats-server"]
fn a_named_window_shorter_than_the_servers_own_is_refused() {
    let server = env("RK_NATS_LIVE_DEFAULT", "127.0.0.1:14222");
    let http = env("RK_NATS_LIVE_DEFAULT_HTTP", "127.0.0.1:18222");
    let reply = connect(
        &server,
        serde_json::json!({ "policy": "flushOnAck", "acceptedFsyncLagNanos": 1_000_000_000u64 }),
        serde_json::json!({ "kind": "varzJson", "varz": varz(&http) }),
    );
    let handle = reply["handle"].as_u64().unwrap();
    let name = unique("rk_lag");
    let reply = call(
        ffi::rk_nats_ensure_stream,
        serde_json::json!({ "handle": handle, "name": name }),
    );
    assert_eq!(code(&reply), "fsyncLagTooLong");
    call(ffi::rk_nats_close, serde_json::json!({ "handle": handle }));
}

#[test]
#[ignore = "needs a live nats-server"]
fn a_named_window_longer_than_the_servers_own_publishes_and_says_what_the_ack_meant() {
    let server = env("RK_NATS_LIVE_DEFAULT", "127.0.0.1:14222");
    let http = env("RK_NATS_LIVE_DEFAULT_HTTP", "127.0.0.1:18222");
    let reply = connect(
        &server,
        serde_json::json!({ "policy": "flushOnAck", "acceptedFsyncLagNanos": 300_000_000_000u64 }),
        serde_json::json!({ "kind": "varzJson", "varz": varz(&http) }),
    );
    let handle = reply["handle"].as_u64().unwrap();
    let name = unique("rk_flush");
    let reply = call(
        ffi::rk_nats_ensure_stream,
        serde_json::json!({ "handle": handle, "name": name, "subjects": [format!("{name}.>")] }),
    );
    assert_eq!(code(&reply), "ok");
    assert_eq!(reply["ackMeaning"], "writtenNotFsynced");

    let reply = call(
        ffi::rk_nats_publish,
        serde_json::json!({
            "handle": handle, "stream": name, "subject": format!("{name}.sale"),
            "payloadBase64": "aGVsbG8=", "messageId": "sale-1",
        }),
    );
    assert_eq!(code(&reply), "ok");
    // Even the weaker policy is told, on every single ack, what it bought.
    assert_eq!(reply["ackMeaning"], "writtenNotFsynced");
    assert_eq!(reply["duplicate"], false);
    let first = reply["sequence"].as_u64().unwrap();

    // The same message id inside the duplicate window is the same message.
    let reply = call(
        ffi::rk_nats_publish,
        serde_json::json!({
            "handle": handle, "stream": name, "subject": format!("{name}.sale"),
            "payloadBase64": "aGVsbG8=", "messageId": "sale-1",
        }),
    );
    assert_eq!(code(&reply), "ok");
    assert_eq!(
        reply["duplicate"], true,
        "a retry must not be a second sale"
    );
    assert_eq!(reply["sequence"].as_u64().unwrap(), first);

    call(ffi::rk_nats_close, serde_json::json!({ "handle": handle }));
}

// --- the server that does fsync ---------------------------------------------

#[test]
#[ignore = "needs a live nats-server started with sync_interval: always"]
fn a_fsync_always_server_satisfies_the_default_policy() {
    let server = env("RK_NATS_LIVE_SYNC_ALWAYS", "127.0.0.1:14223");
    let http = env("RK_NATS_LIVE_SYNC_ALWAYS_HTTP", "127.0.0.1:18223");
    let reply = connect(
        &server,
        fsync_policy(),
        serde_json::json!({ "kind": "varzJson", "varz": varz(&http) }),
    );
    assert_eq!(code(&reply), "ok");
    assert_eq!(reply["durability"]["ackMeaning"], "fsyncedToDisk");
    assert_eq!(reply["durability"]["server"]["syncAlways"], true);
    let handle = reply["handle"].as_u64().unwrap();

    let name = unique("rk_fsync");
    let reply = call(
        ffi::rk_nats_ensure_stream,
        serde_json::json!({ "handle": handle, "name": name, "subjects": [format!("{name}.>")] }),
    );
    assert_eq!(code(&reply), "ok");
    assert_eq!(reply["ackMeaning"], "fsyncedToDisk");
    assert_eq!(reply["persistModeHonoured"], true);

    let reply = call(
        ffi::rk_nats_publish,
        serde_json::json!({
            "handle": handle, "stream": name, "subject": format!("{name}.sale"),
            "payloadBase64": "MTIzLjQ1", "messageId": "receipt-1",
        }),
    );
    assert_eq!(code(&reply), "ok");
    assert_eq!(reply["ackMeaning"], "fsyncedToDisk");

    // And it comes back out of a durable consumer, and the ack for it is
    // confirmed by the server rather than fired and forgotten.
    let reply = call(
        ffi::rk_nats_fetch,
        serde_json::json!({
            "handle": handle, "stream": name, "consumer": "shop-server",
            "batch": 8, "expiresMillis": 2000,
        }),
    );
    assert_eq!(code(&reply), "ok");
    let messages = reply["messages"].as_array().unwrap();
    assert_eq!(messages.len(), 1);
    assert_eq!(messages[0]["payloadBase64"], "MTIzLjQ1");
    let reply_subject = messages[0]["replySubject"].as_str().unwrap().to_string();

    let reply = call(
        ffi::rk_nats_ack,
        serde_json::json!({ "handle": handle, "replySubject": reply_subject }),
    );
    assert_eq!(code(&reply), "ok");
    assert_eq!(reply["doubleAck"], true);

    // Acknowledged means acknowledged: the next pull is empty.
    let reply = call(
        ffi::rk_nats_fetch,
        serde_json::json!({
            "handle": handle, "stream": name, "consumer": "shop-server",
            "batch": 8, "expiresMillis": 1000,
        }),
    );
    assert_eq!(reply["messages"].as_array().unwrap().len(), 0);

    call(ffi::rk_nats_close, serde_json::json!({ "handle": handle }));
}

#[test]
#[ignore = "needs a live nats-server started with sync_interval: always"]
fn async_persistence_is_refused_even_on_a_fsync_always_server() {
    // The trap this package exists for. The server is configured to fsync every
    // write, so everything about it looks safe — and a stream in async
    // persistence mode acks before storing anyway. Measured: 4 198 msg/s on
    // this server in async mode against 158 msg/s in default mode, which is the
    // speed of a server that is not syncing at all.
    let server = env("RK_NATS_LIVE_SYNC_ALWAYS", "127.0.0.1:14223");
    let http = env("RK_NATS_LIVE_SYNC_ALWAYS_HTTP", "127.0.0.1:18223");
    let reply = connect(
        &server,
        fsync_policy(),
        serde_json::json!({ "kind": "varzJson", "varz": varz(&http) }),
    );
    let handle = reply["handle"].as_u64().unwrap();

    let name = unique("rk_async_refused");
    let reply = call(
        ffi::rk_nats_ensure_stream,
        serde_json::json!({
            "handle": handle, "name": name, "subjects": [format!("{name}.>")],
            "persistMode": "async",
        }),
    );
    assert_eq!(code(&reply), "streamRefusedWeakerThanPolicy");
    assert!(reply["message"]
        .as_str()
        .unwrap()
        .contains("ackedBeforeStore"));

    // Memory storage is refused for the same reason and by the same rule.
    let name = unique("rk_memory_refused");
    let reply = call(
        ffi::rk_nats_ensure_stream,
        serde_json::json!({
            "handle": handle, "name": name, "subjects": [format!("{name}.>")],
            "storage": "memory",
        }),
    );
    assert_eq!(code(&reply), "streamRefusedWeakerThanPolicy");

    call(ffi::rk_nats_close, serde_json::json!({ "handle": handle }));
}

#[test]
#[ignore = "needs a live nats-server started with sync_interval: always"]
fn asking_for_async_out_loud_is_allowed_and_reported_on_every_ack() {
    // Nothing here forbids the fast path. It forbids getting it by accident.
    let server = env("RK_NATS_LIVE_SYNC_ALWAYS", "127.0.0.1:14223");
    let http = env("RK_NATS_LIVE_SYNC_ALWAYS_HTTP", "127.0.0.1:18223");
    let reply = connect(
        &server,
        serde_json::json!({ "policy": "ackIsMemoryOnly" }),
        serde_json::json!({ "kind": "varzJson", "varz": varz(&http) }),
    );
    let handle = reply["handle"].as_u64().unwrap();
    let name = unique("rk_async_named");
    let reply = call(
        ffi::rk_nats_ensure_stream,
        serde_json::json!({
            "handle": handle, "name": name, "subjects": [format!("{name}.>")],
            "persistMode": "async",
        }),
    );
    assert_eq!(code(&reply), "ok");
    assert_eq!(reply["effectivePersistMode"], "async");
    assert_eq!(reply["ackMeaning"], "ackedBeforeStore");

    let reply = call(
        ffi::rk_nats_publish,
        serde_json::json!({
            "handle": handle, "stream": name, "subject": format!("{name}.telemetry"),
            "payloadBase64": "b2s=",
        }),
    );
    assert_eq!(code(&reply), "ok");
    assert_eq!(
        reply["ackMeaning"], "ackedBeforeStore",
        "the ack must keep saying what it means, not just at setup"
    );
    call(ffi::rk_nats_close, serde_json::json!({ "handle": handle }));
}

// --- the server too old to know ---------------------------------------------

#[test]
#[ignore = "needs a live nats-server 2.11"]
fn a_server_that_drops_persist_mode_is_reported_not_believed() {
    // Measured on 2.11.0: a stream created with persist_mode "async" comes back
    // with the field absent and no error. Believing the request rather than the
    // echo is how a package ends up describing a configuration the server never
    // applied.
    let server = env("RK_NATS_LIVE_OLD", "127.0.0.1:14224");
    let http = env("RK_NATS_LIVE_OLD_HTTP", "127.0.0.1:18224");
    let reply = connect(
        &server,
        serde_json::json!({ "policy": "ackIsMemoryOnly" }),
        serde_json::json!({ "kind": "varzJson", "varz": varz(&http) }),
    );
    let handle = reply["handle"].as_u64().unwrap();
    let name = unique("rk_old");
    let reply = call(
        ffi::rk_nats_ensure_stream,
        serde_json::json!({
            "handle": handle, "name": name, "subjects": [format!("{name}.>")],
            "persistMode": "async",
        }),
    );
    assert_eq!(code(&reply), "ok");
    assert_eq!(reply["requestedPersistMode"], "async");
    assert_eq!(reply["effectivePersistMode"], "default");
    assert_eq!(reply["persistModeHonoured"], false);
    call(ffi::rk_nats_close, serde_json::json!({ "handle": handle }));
}

#[test]
#[ignore = "needs a live nats-server with a system account"]
fn the_system_account_path_reaches_the_same_answer_as_the_monitoring_port() {
    // On an appliance the monitoring port should not be open, so the evidence
    // has to be obtainable over NATS itself.
    let server = env("RK_NATS_LIVE_SYS", "127.0.0.1:14225");
    let user = env("RK_NATS_LIVE_SYS_USER", "sysuser");
    let password = env("RK_NATS_LIVE_SYS_PASSWORD", "syspass");
    let app_user = env("RK_NATS_LIVE_SYS_APP_USER", "app");
    let app_password = env("RK_NATS_LIVE_SYS_APP_PASSWORD", "apppass");
    let reply = call(
        ffi::rk_nats_connect,
        serde_json::json!({
            "servers": [format!("nats://{server}")],
            "credentials": { "kind": "userPassword", "user": app_user, "password": app_password },
            "policy": "fsyncOnAck",
            "evidence": { "kind": "systemAccount", "user": user, "password": password },
            "timeoutMillis": 5000,
        }),
    );
    assert_eq!(code(&reply), "ok");
    assert_eq!(
        reply["durability"]["ackMeaning"], "fsyncedToDisk",
        "probe said: {}",
        reply["durability"]
    );
    assert_eq!(reply["durability"]["server"]["syncAlways"], true);
    let handle = reply["handle"].as_u64().unwrap();
    call(ffi::rk_nats_close, serde_json::json!({ "handle": handle }));
}

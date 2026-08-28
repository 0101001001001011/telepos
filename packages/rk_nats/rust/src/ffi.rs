//! The C ABI.
//!
//! Every exported function has the same shape: one NUL-terminated JSON string
//! in, one NUL-terminated JSON string out. The reply is always an object with a
//! `code` field naming the outcome, and either the operation's own fields or a
//! `message`.
//!
//! Three rules hold for every function here, and the tests in
//! `tests/abi_boundary.rs` hold them to it.
//!
//! **Failure is a value (I144).** Nothing panics out of this module. Every body
//! runs inside `catch_unwind`, and a caught unwind becomes `{"code":"panic"}`.
//! A null or non-UTF-8 argument becomes `{"code":"invalidRequest"}` rather than
//! a dereference.
//!
//! **Who frees what (I146).** Every `char *` returned by a function whose name
//! ends in anything other than `abi_version` is owned by the caller and must be
//! released with [`rk_nats_string_free`], exactly once. `rk_nats_abi_version`
//! returns a pointer to static storage and must never be freed. Nothing else
//! crosses the boundary as a pointer, so there is nothing else to get wrong.
//!
//! **Names, not numbers (I147).** Codes, policies, storage kinds, persistence
//! modes and ack meanings are all JSON strings. There is no integer whose
//! meaning can drift when a case is inserted in the middle of an enum.

use std::ffi::{c_char, CStr, CString};
use std::panic::{catch_unwind, AssertUnwindSafe};

use crate::client::{
    self, AckRequest, ApplyVarzRequest, ConnectRequest, EnsureStreamRequest, FetchRequest,
    HandleRequest, PublishRequest,
};
use crate::codes::Code;
use crate::durability;

/// The ABI version, as a static string. **Never pass this to
/// [`rk_nats_string_free`].**
///
/// # Safety
/// The returned pointer is valid for the lifetime of the process.
#[no_mangle]
pub extern "C" fn rk_nats_abi_version() -> *const c_char {
    // A trailing NUL in the literal, so no allocation and nothing to free.
    concat!("1", "\0").as_ptr() as *const c_char
}

/// Releases a string returned by any other function in this module.
///
/// Passing null is a no-op. Passing the same pointer twice, or a pointer this
/// library did not return, is undefined — that is the one thing the caller has
/// to get right, and it is why there is only one such rule.
///
/// # Safety
/// `ptr` must be null, or a pointer previously returned by one of the `char *`
/// returning functions in this module and not yet freed.
#[no_mangle]
pub unsafe extern "C" fn rk_nats_string_free(ptr: *mut c_char) {
    if ptr.is_null() {
        return;
    }
    // Reclaims the CString allocated in `reply`. Dart's collector knows nothing
    // about this memory, which is exactly why the call is explicit (I146).
    drop(CString::from_raw(ptr));
}

/// Opens a connection.
///
/// # Safety
/// `json` must be null or a valid NUL-terminated string.
#[no_mangle]
pub unsafe extern "C" fn rk_nats_connect(json: *const c_char) -> *mut c_char {
    guarded(json, |body| {
        let req: ConnectRequest = parse(body)?;
        block_on(client::connect(req))
    })
}

/// Closes a connection. Closing an unknown handle answers `handleClosed`.
///
/// # Safety
/// `json` must be null or a valid NUL-terminated string.
#[no_mangle]
pub unsafe extern "C" fn rk_nats_close(json: *const c_char) -> *mut c_char {
    guarded(json, |body| {
        let req: HandleRequest = parse(body)?;
        if crate::registry::remove(req.handle) {
            Ok(serde_json::json!({ "closed": true }))
        } else {
            Err(client::Failure {
                code: Code::HandleClosed,
                message: format!("handle {} is not open", req.handle),
            })
        }
    })
}

/// Asks the server what an ack will mean, through the evidence path configured
/// at connect.
///
/// # Safety
/// `json` must be null or a valid NUL-terminated string.
#[no_mangle]
pub unsafe extern "C" fn rk_nats_probe_durability(json: *const c_char) -> *mut c_char {
    guarded(json, |body| {
        let req: HandleRequest = parse(body)?;
        let conn = conn(req.handle)?;
        block_on(async move { conn.probe(req.timeout_millis).await })
    })
}

/// Hands the library a `varz` document the caller fetched itself.
///
/// # Safety
/// `json` must be null or a valid NUL-terminated string.
#[no_mangle]
pub unsafe extern "C" fn rk_nats_apply_varz(json: *const c_char) -> *mut c_char {
    guarded(json, |body| {
        let req: ApplyVarzRequest = parse(body)?;
        let conn = conn(req.handle)?;
        conn.apply_varz(&req.varz)
    })
}

/// Creates a stream or brings an existing one to the requested shape.
///
/// # Safety
/// `json` must be null or a valid NUL-terminated string.
#[no_mangle]
pub unsafe extern "C" fn rk_nats_ensure_stream(json: *const c_char) -> *mut c_char {
    guarded(json, |body| {
        let req: EnsureStreamRequest = parse(body)?;
        let conn = conn(req.handle)?;
        block_on(async move { conn.ensure_stream(req).await })
    })
}

/// Publishes one message, after checking what its ack will mean.
///
/// # Safety
/// `json` must be null or a valid NUL-terminated string.
#[no_mangle]
pub unsafe extern "C" fn rk_nats_publish(json: *const c_char) -> *mut c_char {
    guarded(json, |body| {
        let req: PublishRequest = parse(body)?;
        let conn = conn(req.handle)?;
        block_on(async move { conn.publish(req).await })
    })
}

/// Pulls a batch from a durable consumer.
///
/// # Safety
/// `json` must be null or a valid NUL-terminated string.
#[no_mangle]
pub unsafe extern "C" fn rk_nats_fetch(json: *const c_char) -> *mut c_char {
    guarded(json, |body| {
        let req: FetchRequest = parse(body)?;
        let conn = conn(req.handle)?;
        block_on(async move { conn.fetch(req).await })
    })
}

/// Acknowledges a delivered message.
///
/// # Safety
/// `json` must be null or a valid NUL-terminated string.
#[no_mangle]
pub unsafe extern "C" fn rk_nats_ack(json: *const c_char) -> *mut c_char {
    guarded(json, |body| {
        let req: AckRequest = parse(body)?;
        let conn = conn(req.handle)?;
        block_on(async move { conn.ack(req).await })
    })
}

/// Reads a `varz` document and says what an ack would mean on that server.
/// Pure: no connection, no handle, no network.
///
/// # Safety
/// `json` must be null or a valid NUL-terminated string.
#[no_mangle]
pub unsafe extern "C" fn rk_nats_evaluate_varz(json: *const c_char) -> *mut c_char {
    guarded(json, |body| {
        #[derive(serde::Deserialize)]
        struct Req {
            varz: String,
        }
        let req: Req = parse(body)?;
        let facts = durability::parse_varz(&req.varz).map_err(|e| client::Failure {
            code: Code::DurabilityProbeFailed,
            message: e,
        })?;
        let meaning = durability::ack_meaning(
            Some(&facts),
            durability::Storage::File,
            durability::PersistMode::Default,
        );
        Ok(serde_json::json!({
            "server": facts,
            "ackMeaning": meaning.as_str(),
        }))
    })
}

/// The whole policy-against-meaning decision table, as data.
///
/// Exists so that the mirror of these rules in the Dart binding can be checked
/// against the rules themselves, rather than against someone's memory of them.
///
/// # Safety
/// `json` must be null or a valid NUL-terminated string.
#[no_mangle]
pub unsafe extern "C" fn rk_nats_gate_matrix(json: *const c_char) -> *mut c_char {
    guarded(json, |body| {
        #[derive(serde::Deserialize)]
        #[serde(rename_all = "camelCase")]
        struct Req {
            #[serde(default)]
            accepted_fsync_lag_nanos: u64,
            #[serde(default)]
            server_sync_interval_nanos: Option<u64>,
        }
        let req: Req = parse(body)?;
        let server = req
            .server_sync_interval_nanos
            .map(|nanos| durability::ServerDurability {
                version: "matrix".into(),
                sync_always: false,
                sync_interval_nanos: nanos,
                store_dir: String::new(),
            });
        Ok(serde_json::json!({
            "rows": durability::gate_matrix(req.accepted_fsync_lag_nanos, server.as_ref()),
        }))
    })
}

/// Every name this build can return in a `code` field, and every policy and ack
/// meaning it knows. The binding checks its own lists against these instead of
/// discovering a mismatch at a customer's till.
///
/// # Safety
/// `json` is ignored and may be null.
#[no_mangle]
pub unsafe extern "C" fn rk_nats_vocabulary(_json: *const c_char) -> *mut c_char {
    let value = catch_unwind(|| {
        serde_json::json!({
            "code": Code::Ok.as_str(),
            "abiVersion": crate::ABI_VERSION,
            "codes": Code::all().iter().map(|c| c.as_str()).collect::<Vec<_>>(),
            "policies": durability::Policy::all().iter().map(|p| p.as_str()).collect::<Vec<_>>(),
            "ackMeanings": durability::AckMeaning::all().iter().map(|m| m.as_str()).collect::<Vec<_>>(),
        })
    })
    .unwrap_or_else(|_| serde_json::json!({ "code": Code::Panic.as_str() }));
    into_c_string(value)
}

// --- the machinery that makes the three rules true --------------------------

fn conn(handle: u64) -> Result<std::sync::Arc<client::Conn>, client::Failure> {
    crate::registry::get(handle).ok_or_else(|| client::Failure {
        code: Code::HandleClosed,
        message: format!("handle {handle} is not open"),
    })
}

fn parse<T: serde::de::DeserializeOwned>(body: &str) -> Result<T, client::Failure> {
    serde_json::from_str(body).map_err(|e| client::Failure {
        code: Code::InvalidRequest,
        // serde's message names the field and the offending value, including
        // the case of an enum spelled with a name this build does not know —
        // which is the failure I147 is there to make visible.
        message: e.to_string(),
    })
}

fn block_on<F: std::future::Future<Output = client::Outcome>>(fut: F) -> client::Outcome {
    runtime().block_on(fut)
}

/// One runtime for the process. Built once, on first use, and never torn down:
/// dropping a tokio runtime from inside a foreign call is a deadlock waiting
/// for a quiet afternoon.
fn runtime() -> &'static tokio::runtime::Runtime {
    static RT: std::sync::OnceLock<tokio::runtime::Runtime> = std::sync::OnceLock::new();
    RT.get_or_init(|| {
        tokio::runtime::Builder::new_multi_thread()
            .worker_threads(2)
            .thread_name("rk-nats")
            .enable_all()
            .build()
            .expect("tokio runtime")
    })
}

/// Wraps a body so that no failure of any kind leaves as anything but a value.
fn guarded<F>(json: *const c_char, body: F) -> *mut c_char
where
    F: FnOnce(&str) -> client::Outcome,
{
    let outcome = catch_unwind(AssertUnwindSafe(|| {
        let text = unsafe { read_argument(json) }?;
        body(&text)
    }));

    let value = match outcome {
        Ok(Ok(mut value)) => {
            // The code goes in last so an operation cannot accidentally
            // overwrite it with one of its own fields.
            value["code"] = serde_json::Value::String(Code::Ok.as_str().to_string());
            value
        }
        Ok(Err(failure)) => serde_json::json!({
            "code": failure.code.as_str(),
            "message": failure.message,
        }),
        Err(payload) => {
            // The unwind stopped here. The process is alive and the caller gets
            // a code (I144).
            let detail = payload
                .downcast_ref::<&str>()
                .map(|s| (*s).to_string())
                .or_else(|| payload.downcast_ref::<String>().cloned())
                .unwrap_or_else(|| "panic with no message".to_string());
            serde_json::json!({
                "code": Code::Panic.as_str(),
                "message": detail,
            })
        }
    };
    into_c_string(value)
}

unsafe fn read_argument(json: *const c_char) -> Result<String, client::Failure> {
    if json.is_null() {
        return Err(client::Failure {
            code: Code::InvalidRequest,
            message: "request pointer was null".into(),
        });
    }
    CStr::from_ptr(json)
        .to_str()
        .map(|s| s.to_owned())
        .map_err(|e| client::Failure {
            code: Code::InvalidRequest,
            message: format!("request was not UTF-8: {e}"),
        })
}

fn into_c_string(value: serde_json::Value) -> *mut c_char {
    let text = value.to_string();
    // An interior NUL cannot come from serde_json, but if it ever did, a
    // truncated reply is a lie. Fall back to a fixed, NUL-free message.
    match CString::new(text) {
        Ok(s) => s.into_raw(),
        Err(_) => CString::new(r#"{"code":"panic","message":"reply contained a NUL"}"#)
            .expect("static string has no NUL")
            .into_raw(),
    }
}

/// Deliberately panics, so the boundary's promise can be tested rather than
/// asserted. Not part of the supported surface; it exists because a
/// `catch_unwind` nobody ever triggers is a `catch_unwind` nobody knows works.
///
/// # Safety
/// `json` is ignored and may be null.
#[no_mangle]
pub unsafe extern "C" fn rk_nats_panic_for_test(json: *const c_char) -> *mut c_char {
    guarded(json, |_| {
        panic!("deliberate panic from rk_nats_panic_for_test");
    })
}

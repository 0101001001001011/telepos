//! Publishers, subscribers, samples and liveliness.
//!
//! Delivery is **pulled, never pushed**. Zenoh would happily call a closure on
//! its own runtime thread, but a closure that has to reach Dart means a
//! native callback into an isolate, and a callback into an isolate means the
//! interface isolate is one mistake away from being the one that runs it
//! (И145). A bounded queue plus `rkz_subscriber_recv(timeout_ms)` keeps the
//! blocking on a worker isolate where it belongs, and makes back-pressure
//! visible instead of unbounded.

use std::ffi::{c_char, CString};
use std::time::Duration;

use zenoh::handlers::{FifoChannel, FifoChannelHandler};
use zenoh::pubsub::{Publisher, Subscriber};
use zenoh::sample::{Sample, SampleKind};
use zenoh::Wait;

use crate::handle::{as_ref, from_raw, into_raw, Boxed, Tagged};
use crate::names;
use crate::session::{key_expr_arg, payload_slice, str_arg, RkzSession};
use crate::status::{guard, ErrorKind, RkzError, RkzStatus};

/// How deep a subscriber's queue is before Zenoh starts dropping.
///
/// Chosen, not defaulted: a till that loses network for a minute and then
/// reconnects should catch up rather than block the publisher, and 1024
/// samples is roughly a minute of the heaviest traffic we send.
const QUEUE_DEPTH: usize = 1024;

// ------------------------------------------------------------- subscriber --

/// A live subscription. Freed by `rkz_subscriber_drop`, and by nothing else.
pub struct RkzSubscriber {
    inner: Subscriber<FifoChannelHandler<Sample>>,
}

impl Tagged for RkzSubscriber {
    const TAG: u64 = 0x726B_7A5F_7375_6273; // "rkz_subs"
    const NAME: &'static str = "subscriber";
}

/// A received sample. Freed by `rkz_sample_drop`, and by nothing else.
///
/// The strings and bytes it lends out stay valid exactly as long as it does.
pub struct RkzSample {
    key: CString,
    kind: SampleKind,
    payload: Vec<u8>,
}

impl Tagged for RkzSample {
    const TAG: u64 = 0x726B_7A5F_7361_6D70; // "rkz_samp"
    const NAME: &'static str = "sample";
}

impl RkzSample {
    fn from_zenoh(sample: Sample) -> RkzSample {
        let key = sample.key_expr().as_str().replace('\0', "");
        RkzSample {
            key: CString::new(key).expect("interior NULs were just removed"),
            kind: sample.kind(),
            payload: sample.payload().to_bytes().into_owned(),
        }
    }
}

/// Declare a subscription.
///
/// # Safety
/// `session` is live; `key` is NUL-terminated; `out` is writable for one
/// pointer.
#[no_mangle]
pub unsafe extern "C" fn rkz_subscriber_declare(
    session: *const Boxed<RkzSession>,
    key: *const c_char,
    out: *mut *mut Boxed<RkzSubscriber>,
) -> RkzStatus {
    guard(|| {
        if out.is_null() {
            return Err(RkzError::new(ErrorKind::NullArgument, "out was null"));
        }
        // SAFETY: contract above.
        let session = unsafe { as_ref::<RkzSession>(session) }?;
        // SAFETY: contract above.
        let key = unsafe { key_expr_arg(key) }?;
        let inner = session
            .inner
            .declare_subscriber(key)
            .with(FifoChannel::new(QUEUE_DEPTH))
            .wait()
            .map_err(|e| RkzError::new(ErrorKind::DeclarationFailed, e.to_string()))?;
        // SAFETY: checked non-null above.
        unsafe { *out = into_raw(RkzSubscriber { inner }) };
        Ok(())
    })
}

/// Wait up to `timeout_ms` for the next sample.
///
/// Reports `timeout` when nothing arrived — an ordinary outcome, and the one
/// the caller loops on — and `disconnected` when the subscription will never
/// produce anything again.
///
/// # Safety
/// `sub` is live; `out` is writable for one pointer.
#[no_mangle]
pub unsafe extern "C" fn rkz_subscriber_recv(
    sub: *const Boxed<RkzSubscriber>,
    timeout_ms: u64,
    out: *mut *mut Boxed<RkzSample>,
) -> RkzStatus {
    guard(|| {
        if out.is_null() {
            return Err(RkzError::new(ErrorKind::NullArgument, "out was null"));
        }
        // SAFETY: contract above.
        let sub = unsafe { as_ref::<RkzSubscriber>(sub) }?;
        match sub.inner.recv_timeout(Duration::from_millis(timeout_ms)) {
            Ok(Some(sample)) => {
                // SAFETY: checked non-null above.
                unsafe { *out = into_raw(RkzSample::from_zenoh(sample)) };
                Ok(())
            }
            Ok(None) => Err(RkzError::new(
                ErrorKind::Timeout,
                format!("no sample within {timeout_ms} ms"),
            )),
            Err(e) => Err(RkzError::new(
                ErrorKind::Disconnected,
                format!("the subscription will produce no further samples: {e}"),
            )),
        }
    })
}

/// Free a subscription.
///
/// # Safety
/// `sub` came from a declare call and has not been dropped.
#[no_mangle]
pub unsafe extern "C" fn rkz_subscriber_drop(sub: *mut Boxed<RkzSubscriber>) -> RkzStatus {
    // SAFETY: contract above.
    guard(|| unsafe { from_raw(sub) }.map(|_| ()))
}

/// The key expression a sample arrived on.
///
/// The pointer is owned by the sample and dies with it. The caller must never
/// free it.
///
/// # Safety
/// `sample` is live.
#[no_mangle]
pub unsafe extern "C" fn rkz_sample_key(sample: *const Boxed<RkzSample>) -> *const c_char {
    // SAFETY: contract above.
    match unsafe { as_ref::<RkzSample>(sample) } {
        Ok(sample) => sample.key.as_ptr(),
        Err(_) => std::ptr::null(),
    }
}

/// Whether a sample is a `put` or a `delete`, by name (И147).
///
/// The pointer is static and must never be freed.
///
/// # Safety
/// `sample` is live.
#[no_mangle]
pub unsafe extern "C" fn rkz_sample_kind(sample: *const Boxed<RkzSample>) -> *const c_char {
    // SAFETY: contract above.
    match unsafe { as_ref::<RkzSample>(sample) } {
        Ok(sample) => names::sample_kind_name(sample.kind).as_ptr().cast(),
        Err(_) => std::ptr::null(),
    }
}

/// Lend the sample's payload. The bytes die with the sample.
///
/// # Safety
/// `sample` is live; `out_ptr` and `out_len` are writable.
#[no_mangle]
pub unsafe extern "C" fn rkz_sample_payload(
    sample: *const Boxed<RkzSample>,
    out_ptr: *mut *const u8,
    out_len: *mut usize,
) -> RkzStatus {
    guard(|| {
        if out_ptr.is_null() || out_len.is_null() {
            return Err(RkzError::new(
                ErrorKind::NullArgument,
                "an out parameter was null",
            ));
        }
        // SAFETY: contract above.
        let sample = unsafe { as_ref::<RkzSample>(sample) }?;
        // SAFETY: checked non-null above.
        unsafe {
            *out_ptr = sample.payload.as_ptr();
            *out_len = sample.payload.len();
        }
        Ok(())
    })
}

/// Free a sample, and with it every pointer it lent out.
///
/// # Safety
/// `sample` came from `rkz_subscriber_recv` and has not been dropped.
#[no_mangle]
pub unsafe extern "C" fn rkz_sample_drop(sample: *mut Boxed<RkzSample>) -> RkzStatus {
    // SAFETY: contract above.
    guard(|| unsafe { from_raw(sample) }.map(|_| ()))
}

// -------------------------------------------------------------- publisher --

/// A declared publisher. Freed by `rkz_publisher_drop`, and by nothing else.
pub struct RkzPublisher {
    inner: Publisher<'static>,
}

impl Tagged for RkzPublisher {
    const TAG: u64 = 0x726B_7A5F_7075_626C; // "rkz_publ"
    const NAME: &'static str = "publisher";
}

/// Declare a publisher, so the key expression is resolved once instead of per
/// message.
///
/// # Safety
/// `session` is live; `key`, `congestion` and `priority` are NUL-terminated;
/// `out` is writable for one pointer.
#[no_mangle]
pub unsafe extern "C" fn rkz_publisher_declare(
    session: *const Boxed<RkzSession>,
    key: *const c_char,
    congestion: *const c_char,
    priority: *const c_char,
    out: *mut *mut Boxed<RkzPublisher>,
) -> RkzStatus {
    guard(|| {
        if out.is_null() {
            return Err(RkzError::new(ErrorKind::NullArgument, "out was null"));
        }
        // SAFETY: contract above.
        let session = unsafe { as_ref::<RkzSession>(session) }?;
        // SAFETY: contract above.
        let key = unsafe { key_expr_arg(key) }?;
        // SAFETY: contract above.
        let congestion =
            names::congestion_control(unsafe { str_arg(congestion, "congestion control") }?)?;
        // SAFETY: contract above.
        let priority = names::priority(unsafe { str_arg(priority, "priority") }?)?;
        let inner = session
            .inner
            .declare_publisher(key)
            .congestion_control(congestion)
            .priority(priority)
            .wait()
            .map_err(|e| RkzError::new(ErrorKind::DeclarationFailed, e.to_string()))?;
        // SAFETY: checked non-null above.
        unsafe { *out = into_raw(RkzPublisher { inner }) };
        Ok(())
    })
}

/// Publish a payload.
///
/// # Safety
/// `publisher` is live; `payload` is readable for `payload_len` bytes.
#[no_mangle]
pub unsafe extern "C" fn rkz_publisher_put(
    publisher: *const Boxed<RkzPublisher>,
    payload: *const u8,
    payload_len: usize,
) -> RkzStatus {
    guard(|| {
        // SAFETY: contract above.
        let publisher = unsafe { as_ref::<RkzPublisher>(publisher) }?;
        // SAFETY: contract above.
        let bytes = unsafe { payload_slice(payload, payload_len) }?;
        publisher
            .inner
            .put(bytes.to_vec())
            .wait()
            .map_err(|e| RkzError::new(ErrorKind::PublishFailed, e.to_string()))
    })
}

/// Free a publisher.
///
/// # Safety
/// `publisher` came from `rkz_publisher_declare` and has not been dropped.
#[no_mangle]
pub unsafe extern "C" fn rkz_publisher_drop(publisher: *mut Boxed<RkzPublisher>) -> RkzStatus {
    // SAFETY: contract above.
    guard(|| unsafe { from_raw(publisher) }.map(|_| ()))
}

// ------------------------------------------------------------ liveliness --

/// A liveliness token. Freed by `rkz_liveliness_token_drop`, and by nothing
/// else — dropping it is how a peer announces it is gone.
pub struct RkzLivelinessToken {
    _inner: zenoh::liveliness::LivelinessToken,
}

impl Tagged for RkzLivelinessToken {
    const TAG: u64 = 0x726B_7A5F_6C69_766B; // "rkz_livk"
    const NAME: &'static str = "liveliness token";
}

/// Declare that this session is alive at a key expression.
///
/// This is how a durable identity is announced: the key expression carries the
/// terminal identity, so peers learn *who* is present rather than *which
/// ephemeral Zenoh ID* is present.
///
/// # Safety
/// `session` is live; `key` is NUL-terminated; `out` is writable for one
/// pointer.
#[no_mangle]
pub unsafe extern "C" fn rkz_liveliness_declare_token(
    session: *const Boxed<RkzSession>,
    key: *const c_char,
    out: *mut *mut Boxed<RkzLivelinessToken>,
) -> RkzStatus {
    guard(|| {
        if out.is_null() {
            return Err(RkzError::new(ErrorKind::NullArgument, "out was null"));
        }
        // SAFETY: contract above.
        let session = unsafe { as_ref::<RkzSession>(session) }?;
        // SAFETY: contract above.
        let key = unsafe { key_expr_arg(key) }?;
        let inner = session
            .inner
            .liveliness()
            .declare_token(key)
            .wait()
            .map_err(|e| RkzError::new(ErrorKind::DeclarationFailed, e.to_string()))?;
        // SAFETY: checked non-null above.
        unsafe { *out = into_raw(RkzLivelinessToken { _inner: inner }) };
        Ok(())
    })
}

/// Free a liveliness token, announcing that this session is gone.
///
/// # Safety
/// `token` came from `rkz_liveliness_declare_token` and has not been dropped.
#[no_mangle]
pub unsafe extern "C" fn rkz_liveliness_token_drop(
    token: *mut Boxed<RkzLivelinessToken>,
) -> RkzStatus {
    // SAFETY: contract above.
    guard(|| unsafe { from_raw(token) }.map(|_| ()))
}

/// Subscribe to liveliness changes: a `put` when a peer appears, a `delete`
/// when it goes.
///
/// The samples arrive through the same `rkz_subscriber_recv` as ordinary ones,
/// so there is one queue discipline in this library rather than two.
///
/// **History is not available here.** Replaying the tokens that already exist
/// is `.history(true)`, which upstream gates behind its unstable API; a late
/// joiner therefore learns about peers only as they change, and must ask.
///
/// # Safety
/// `session` is live; `key` is NUL-terminated; `out` is writable for one
/// pointer.
#[no_mangle]
pub unsafe extern "C" fn rkz_liveliness_declare_subscriber(
    session: *const Boxed<RkzSession>,
    key: *const c_char,
    out: *mut *mut Boxed<RkzSubscriber>,
) -> RkzStatus {
    guard(|| {
        if out.is_null() {
            return Err(RkzError::new(ErrorKind::NullArgument, "out was null"));
        }
        // SAFETY: contract above.
        let session = unsafe { as_ref::<RkzSession>(session) }?;
        // SAFETY: contract above.
        let key = unsafe { key_expr_arg(key) }?;
        let inner = session
            .inner
            .liveliness()
            .declare_subscriber(key)
            .with(FifoChannel::new(QUEUE_DEPTH))
            .wait()
            .map_err(|e| RkzError::new(ErrorKind::DeclarationFailed, e.to_string()))?;
        // SAFETY: checked non-null above.
        unsafe { *out = into_raw(RkzSubscriber { inner }) };
        Ok(())
    })
}

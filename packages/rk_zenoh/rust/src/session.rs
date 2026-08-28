//! Configuration and session handles, and the C ABI over them.

use std::ffi::{c_char, CStr};
use std::sync::Mutex;

use zenoh::Wait;

use crate::config::{RkzConfigBuilder, Zid};
use crate::handle::{as_ref, from_raw, into_raw, Boxed, Tagged};
use crate::names;
use crate::status::{guard, ErrorKind, RkzError, RkzResult, RkzStatus};

// ---------------------------------------------------------------- helpers --

/// Read a NUL-terminated argument.
///
/// # Safety
/// `ptr` must be null or point at a NUL-terminated string that outlives the
/// call.
pub(crate) unsafe fn str_arg<'a>(ptr: *const c_char, what: &str) -> RkzResult<&'a str> {
    if ptr.is_null() {
        return Err(RkzError::new(
            ErrorKind::NullArgument,
            format!("{what} was null"),
        ));
    }
    // SAFETY: non-null and NUL-terminated by the contract above.
    unsafe { CStr::from_ptr(ptr) }
        .to_str()
        .map_err(|e| RkzError::new(ErrorKind::InvalidUtf8, format!("{what} is not utf-8: {e}")))
}

/// Read and validate a key expression argument.
///
/// Validated here rather than left to the call that uses it, so a malformed
/// key comes back as `invalid_key_expression` with the offending text instead
/// of as a generic declaration failure. Zenoh's grammar is not obvious — `**`
/// has to be a whole chunk, `//` is not allowed — and "declaration failed" is
/// not enough to fix a typo by.
///
/// # Safety
/// `ptr` must be null or point at a NUL-terminated string.
pub(crate) unsafe fn key_expr_arg(ptr: *const c_char) -> RkzResult<String> {
    // SAFETY: contract above.
    let text = unsafe { str_arg(ptr, "key expression") }?;
    zenoh::key_expr::KeyExpr::try_from(text).map_err(|e| {
        RkzError::new(
            ErrorKind::InvalidKeyExpression,
            format!("{text:?} is not a key expression: {e}"),
        )
    })?;
    Ok(text.to_string())
}

/// Copy a string into a caller-provided buffer, NUL-terminated.
///
/// # Safety
/// `buf` must be writable for `cap` bytes.
pub(crate) unsafe fn write_out(text: &str, buf: *mut c_char, cap: usize) -> RkzResult<()> {
    if buf.is_null() {
        return Err(RkzError::new(
            ErrorKind::NullArgument,
            "the output buffer was null",
        ));
    }
    let needed = text.len() + 1;
    if cap < needed {
        return Err(RkzError::new(
            ErrorKind::BufferTooSmall,
            format!("{needed} bytes are needed, {cap} were offered"),
        ));
    }
    // SAFETY: the buffer is writable for `cap` >= `needed` bytes.
    unsafe {
        std::ptr::copy_nonoverlapping(text.as_ptr().cast::<c_char>(), buf, text.len());
        *buf.add(text.len()) = 0;
    }
    Ok(())
}

// ----------------------------------------------------------------- config --

/// The configuration handle. Freed by `rkz_config_drop`, and by nothing else.
pub struct RkzConfig(Mutex<RkzConfigBuilder>);

impl Tagged for RkzConfig {
    const TAG: u64 = 0x726B_7A5F_636F_6E66; // "rkz_conf"
    const NAME: &'static str = "config";
}

/// Create a configuration. The caller owns it until `rkz_config_drop`.
///
/// # Safety
/// `out` must be writable for one pointer.
#[no_mangle]
pub unsafe extern "C" fn rkz_config_new(out: *mut *mut Boxed<RkzConfig>) -> RkzStatus {
    guard(|| {
        if out.is_null() {
            return Err(RkzError::new(ErrorKind::NullArgument, "out was null"));
        }
        let handle = into_raw(RkzConfig(Mutex::new(RkzConfigBuilder::new())));
        // SAFETY: checked non-null just above.
        unsafe { *out = handle };
        Ok(())
    })
}

fn with_config<F>(cfg: *const Boxed<RkzConfig>, body: F) -> RkzResult<()>
where
    F: FnOnce(&mut RkzConfigBuilder) -> RkzResult<()>,
{
    // SAFETY: the caller's contract for every `rkz_config_*` function.
    let handle = unsafe { as_ref::<RkzConfig>(cfg) }?;
    let mut guard = handle
        .0
        .lock()
        .map_err(|_| RkzError::new(ErrorKind::Backend, "the configuration lock was poisoned"))?;
    body(&mut guard)
}

/// Set the session mode by name: `peer`, `client` or `router`.
///
/// # Safety
/// `cfg` is a live configuration handle; `mode` is NUL-terminated.
#[no_mangle]
pub unsafe extern "C" fn rkz_config_set_mode(
    cfg: *const Boxed<RkzConfig>,
    mode: *const c_char,
) -> RkzStatus {
    guard(|| {
        // SAFETY: contract above.
        let mode = unsafe { str_arg(mode, "mode") }?;
        with_config(cfg, |b| b.mode(mode).map(|_| ()))
    })
}

/// Pin the Zenoh ID to the given lowercase hex value.
///
/// # Safety
/// `cfg` is a live configuration handle; `hex` is NUL-terminated.
#[no_mangle]
pub unsafe extern "C" fn rkz_config_pin_zid(
    cfg: *const Boxed<RkzConfig>,
    hex: *const c_char,
) -> RkzStatus {
    guard(|| {
        // SAFETY: contract above.
        let hex = unsafe { str_arg(hex, "zid") }?;
        let zid = Zid::parse(hex)?;
        with_config(cfg, |b| {
            b.pin_zid(zid);
            Ok(())
        })
    })
}

/// Pin the Zenoh ID to a value derived from a durable identity.
///
/// # Safety
/// `cfg` is a live configuration handle; `identity` is NUL-terminated.
#[no_mangle]
pub unsafe extern "C" fn rkz_config_pin_zid_derived(
    cfg: *const Boxed<RkzConfig>,
    identity: *const c_char,
) -> RkzStatus {
    guard(|| {
        // SAFETY: contract above.
        let identity = unsafe { str_arg(identity, "identity") }?;
        if identity.is_empty() {
            return Err(RkzError::new(
                ErrorKind::InvalidConfig,
                "a derived zid needs a non-empty identity",
            ));
        }
        let zid = Zid::derive(identity);
        with_config(cfg, |b| {
            b.pin_zid(zid);
            Ok(())
        })
    })
}

/// Add an endpoint this session dials.
///
/// # Safety
/// `cfg` is a live configuration handle; `endpoint` is NUL-terminated.
#[no_mangle]
pub unsafe extern "C" fn rkz_config_add_connect(
    cfg: *const Boxed<RkzConfig>,
    endpoint: *const c_char,
) -> RkzStatus {
    guard(|| {
        // SAFETY: contract above.
        let endpoint = unsafe { str_arg(endpoint, "endpoint") }?;
        with_config(cfg, |b| {
            b.connect(endpoint);
            Ok(())
        })
    })
}

/// Add an endpoint this session listens on.
///
/// # Safety
/// `cfg` is a live configuration handle; `endpoint` is NUL-terminated.
#[no_mangle]
pub unsafe extern "C" fn rkz_config_add_listen(
    cfg: *const Boxed<RkzConfig>,
    endpoint: *const c_char,
) -> RkzStatus {
    guard(|| {
        // SAFETY: contract above.
        let endpoint = unsafe { str_arg(endpoint, "endpoint") }?;
        with_config(cfg, |b| {
            b.listen(endpoint);
            Ok(())
        })
    })
}

/// Turn multicast scouting on or off.
///
/// # Safety
/// `cfg` is a live configuration handle.
#[no_mangle]
pub unsafe extern "C" fn rkz_config_set_multicast_scouting(
    cfg: *const Boxed<RkzConfig>,
    enabled: bool,
) -> RkzStatus {
    guard(|| {
        with_config(cfg, |b| {
            b.multicast_scouting(enabled);
            Ok(())
        })
    })
}

/// Turn gossip scouting on or off.
///
/// # Safety
/// `cfg` is a live configuration handle.
#[no_mangle]
pub unsafe extern "C" fn rkz_config_set_gossip_scouting(
    cfg: *const Boxed<RkzConfig>,
    enabled: bool,
) -> RkzStatus {
    guard(|| {
        with_config(cfg, |b| {
            b.gossip_scouting(enabled);
            Ok(())
        })
    })
}

/// Merge a JSON5 object underneath everything set through the typed setters.
///
/// # Safety
/// `cfg` is a live configuration handle; `json5` is NUL-terminated.
#[no_mangle]
pub unsafe extern "C" fn rkz_config_set_extra_json5(
    cfg: *const Boxed<RkzConfig>,
    json5: *const c_char,
) -> RkzStatus {
    guard(|| {
        // SAFETY: contract above.
        let json5 = unsafe { str_arg(json5, "json5") }?;
        with_config(cfg, |b| {
            b.extra_json5(json5);
            Ok(())
        })
    })
}

/// Write the JSON5 document this configuration stands for into `buf`.
///
/// # Safety
/// `cfg` is a live configuration handle; `buf` is writable for `cap` bytes.
#[no_mangle]
pub unsafe extern "C" fn rkz_config_render(
    cfg: *const Boxed<RkzConfig>,
    buf: *mut c_char,
    cap: usize,
) -> RkzStatus {
    guard(|| {
        let mut rendered = String::new();
        with_config(cfg, |b| {
            rendered = b.to_json5();
            Ok(())
        })?;
        // SAFETY: contract above.
        unsafe { write_out(&rendered, buf, cap) }
    })
}

/// Free a configuration.
///
/// # Safety
/// `cfg` came from `rkz_config_new` and has not been dropped.
#[no_mangle]
pub unsafe extern "C" fn rkz_config_drop(cfg: *mut Boxed<RkzConfig>) -> RkzStatus {
    // SAFETY: contract above.
    guard(|| unsafe { from_raw(cfg) }.map(|_| ()))
}

// ---------------------------------------------------------------- session --

/// A live Zenoh session. Freed by `rkz_session_drop`, and by nothing else.
pub struct RkzSession {
    /// The Zenoh session itself.
    ///
    /// Public so the integration tests can measure Zenoh's own behaviour under
    /// a configuration this crate produced, rather than under one they invented.
    /// Nothing outside this crate is meant to reach through it in production;
    /// the C ABI is the supported surface.
    pub inner: zenoh::Session,
}

impl Tagged for RkzSession {
    const TAG: u64 = 0x726B_7A5F_7365_7373; // "rkz_sess"
    const NAME: &'static str = "session";
}

impl RkzSession {
    pub(crate) fn open(builder: &RkzConfigBuilder) -> RkzResult<RkzSession> {
        if builder.has_pinned_zid() && !builder.appears_authenticated() {
            return Err(RkzError::new(
                ErrorKind::InvalidConfig,
                "a pinned zid without tls is refused: a pinned identity nobody \
                 authenticates cannot tell a restart from an impostor. Add a \
                 tls/ or quic/ endpoint, or leave the zid ephemeral.",
            ));
        }
        Self::open_unchecked(builder)
    }

    /// Open without the pinned-zid-requires-tls check.
    ///
    /// Exists for the tests that measure ZID behaviour over plain TCP on the
    /// loopback, where there is no network to authenticate against. It is not
    /// reachable from the C ABI on purpose.
    pub fn open_unchecked(builder: &RkzConfigBuilder) -> RkzResult<RkzSession> {
        let config = builder.build()?;
        let inner = zenoh::open(config)
            .wait()
            .map_err(|e| RkzError::new(ErrorKind::SessionOpenFailed, e.to_string()))?;
        Ok(RkzSession { inner })
    }

    /// This session's Zenoh ID as lowercase hex.
    pub fn zid(&self) -> String {
        self.inner.zid().to_string()
    }
}

/// Open a session from a configuration. The configuration stays the caller's
/// and can be dropped independently.
///
/// # Safety
/// `cfg` is a live configuration handle; `out` is writable for one pointer.
#[no_mangle]
pub unsafe extern "C" fn rkz_session_open(
    cfg: *const Boxed<RkzConfig>,
    out: *mut *mut Boxed<RkzSession>,
) -> RkzStatus {
    guard(|| {
        if out.is_null() {
            return Err(RkzError::new(ErrorKind::NullArgument, "out was null"));
        }
        let mut opened = None;
        with_config(cfg, |b| {
            opened = Some(RkzSession::open(b)?);
            Ok(())
        })?;
        let session = opened.expect("with_config either fills this or returns an error");
        // SAFETY: checked non-null above.
        unsafe { *out = into_raw(session) };
        Ok(())
    })
}

/// Write this session's Zenoh ID, lowercase hex, into `buf`.
///
/// 33 bytes are always enough.
///
/// # Safety
/// `session` is live; `buf` is writable for `cap` bytes.
#[no_mangle]
pub unsafe extern "C" fn rkz_session_zid(
    session: *const Boxed<RkzSession>,
    buf: *mut c_char,
    cap: usize,
) -> RkzStatus {
    guard(|| {
        // SAFETY: contract above.
        let session = unsafe { as_ref::<RkzSession>(session) }?;
        let zid = session.zid();
        // SAFETY: contract above.
        unsafe { write_out(&zid, buf, cap) }
    })
}

/// Write the Zenoh IDs this session currently sees, one per line.
///
/// This is the view that goes stale: it is a snapshot of who is reachable
/// *now*, not a directory.
///
/// # Safety
/// `session` is live; `buf` is writable for `cap` bytes.
#[no_mangle]
pub unsafe extern "C" fn rkz_session_peer_zids(
    session: *const Boxed<RkzSession>,
    buf: *mut c_char,
    cap: usize,
) -> RkzStatus {
    guard(|| {
        // SAFETY: contract above.
        let session = unsafe { as_ref::<RkzSession>(session) }?;
        let joined = peer_zids(session).join("\n");
        // SAFETY: contract above.
        unsafe { write_out(&joined, buf, cap) }
    })
}

/// The Zenoh IDs of every peer and router this session is connected to.
pub fn peer_zids(session: &RkzSession) -> Vec<String> {
    let info = session.inner.info();
    let mut ids: Vec<String> = info
        .peers_zid()
        .wait()
        .map(|z| z.to_string())
        .chain(info.routers_zid().wait().map(|z| z.to_string()))
        .collect();
    ids.sort();
    ids.dedup();
    ids
}

/// Put a payload at a key expression.
///
/// # Safety
/// `session` is live; `key` is NUL-terminated; `payload` is readable for
/// `payload_len` bytes; `congestion` and `priority` are NUL-terminated names.
#[no_mangle]
pub unsafe extern "C" fn rkz_session_put(
    session: *const Boxed<RkzSession>,
    key: *const c_char,
    payload: *const u8,
    payload_len: usize,
    congestion: *const c_char,
    priority: *const c_char,
) -> RkzStatus {
    guard(|| {
        // SAFETY: contract above.
        let session = unsafe { as_ref::<RkzSession>(session) }?;
        // SAFETY: contract above.
        let key = unsafe { key_expr_arg(key) }?;
        // SAFETY: contract above.
        let congestion =
            names::congestion_control(unsafe { str_arg(congestion, "congestion control") }?)?;
        // SAFETY: contract above.
        let priority = names::priority(unsafe { str_arg(priority, "priority") }?)?;
        // SAFETY: contract above.
        let bytes = unsafe { payload_slice(payload, payload_len) }?;
        session
            .inner
            .put(key, bytes.to_vec())
            .congestion_control(congestion)
            .priority(priority)
            .wait()
            .map_err(|e| RkzError::new(ErrorKind::PublishFailed, e.to_string()))
    })
}

/// Delete a key expression.
///
/// # Safety
/// `session` is live; `key` is NUL-terminated.
#[no_mangle]
pub unsafe extern "C" fn rkz_session_delete(
    session: *const Boxed<RkzSession>,
    key: *const c_char,
) -> RkzStatus {
    guard(|| {
        // SAFETY: contract above.
        let session = unsafe { as_ref::<RkzSession>(session) }?;
        // SAFETY: contract above.
        let key = unsafe { key_expr_arg(key) }?;
        session
            .inner
            .delete(key)
            .wait()
            .map_err(|e| RkzError::new(ErrorKind::PublishFailed, e.to_string()))
    })
}

/// Close the session's network side while leaving the handle valid.
///
/// Calling this and then dropping is the deterministic order; dropping alone
/// also closes, but does so while the allocation is being freed, which makes a
/// slow close hard to attribute.
///
/// # Safety
/// `session` is live.
#[no_mangle]
pub unsafe extern "C" fn rkz_session_close(session: *const Boxed<RkzSession>) -> RkzStatus {
    guard(|| {
        // SAFETY: contract above.
        let session = unsafe { as_ref::<RkzSession>(session) }?;
        session
            .inner
            .close()
            .wait()
            .map_err(|e| RkzError::new(ErrorKind::Backend, e.to_string()))
    })
}

/// Free a session.
///
/// # Safety
/// `session` came from `rkz_session_open` and has not been dropped. Every
/// publisher, subscriber and token declared on it must be dropped first.
#[no_mangle]
pub unsafe extern "C" fn rkz_session_drop(session: *mut Boxed<RkzSession>) -> RkzStatus {
    // SAFETY: contract above.
    guard(|| unsafe { from_raw(session) }.map(|_| ()))
}

/// # Safety
/// `ptr` is null with `len == 0`, or readable for `len` bytes.
pub(crate) unsafe fn payload_slice<'a>(ptr: *const u8, len: usize) -> RkzResult<&'a [u8]> {
    if len == 0 {
        return Ok(&[]);
    }
    if ptr.is_null() {
        return Err(RkzError::new(
            ErrorKind::NullArgument,
            format!("the payload pointer was null but {len} bytes were promised"),
        ));
    }
    // SAFETY: non-null and readable for `len` bytes by the contract above.
    Ok(unsafe { std::slice::from_raw_parts(ptr, len) })
}

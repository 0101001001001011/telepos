//! The C ABI as a caller sees it: statuses, names, ownership.
//!
//! These tests go through the exported functions rather than the Rust API, so
//! they cover the layer the Dart binding actually talks to. Everything here is
//! `unsafe` for the same reason the Dart side is: pointers cross a boundary.

use std::ffi::{c_char, CStr, CString};
use std::net::TcpListener;
use std::ptr;
use std::time::{Duration, Instant};

use rk_zenoh::handle::Boxed;
use rk_zenoh::pubsub::*;
use rk_zenoh::rkz_native_version;
use rk_zenoh::session::*;
use rk_zenoh::status::{rkz_last_error_kind, rkz_last_error_message, RKZ_OK};

fn last_kind() -> String {
    // SAFETY: the library always returns a static, NUL-terminated name.
    unsafe { CStr::from_ptr(rkz_last_error_kind()) }
        .to_string_lossy()
        .into_owned()
}

fn last_message() -> String {
    // SAFETY: valid until the next call on this thread, and we copy at once.
    unsafe { CStr::from_ptr(rkz_last_error_message()) }
        .to_string_lossy()
        .into_owned()
}

fn cs(s: &str) -> CString {
    CString::new(s).expect("test strings have no interior NUL")
}

fn free_port() -> u16 {
    let listener = TcpListener::bind("127.0.0.1:0").expect("the loopback must be bindable");
    let port = listener
        .local_addr()
        .expect("a bound listener has an address")
        .port();
    drop(listener);
    port
}

/// A configuration handle plus the calls that build it, so each test reads as
/// what it is testing rather than as pointer bookkeeping.
struct Cfg(*mut Boxed<rk_zenoh::session::RkzConfig>);

impl Cfg {
    fn new() -> Cfg {
        let mut raw = ptr::null_mut();
        // SAFETY: `raw` is a live local.
        assert_eq!(unsafe { rkz_config_new(&mut raw) }, RKZ_OK);
        assert!(!raw.is_null());
        Cfg(raw)
    }

    fn mode(&self, name: &str) -> i32 {
        // SAFETY: the handle is live and the string is NUL-terminated.
        unsafe { rkz_config_set_mode(self.0, cs(name).as_ptr()) }
    }

    fn pin(&self, hex: &str) -> i32 {
        // SAFETY: as above.
        unsafe { rkz_config_pin_zid(self.0, cs(hex).as_ptr()) }
    }

    fn pin_derived(&self, identity: &str) -> i32 {
        // SAFETY: as above.
        unsafe { rkz_config_pin_zid_derived(self.0, cs(identity).as_ptr()) }
    }

    fn listen(&self, endpoint: &str) -> i32 {
        // SAFETY: as above.
        unsafe { rkz_config_add_listen(self.0, cs(endpoint).as_ptr()) }
    }

    fn connect(&self, endpoint: &str) -> i32 {
        // SAFETY: as above.
        unsafe { rkz_config_add_connect(self.0, cs(endpoint).as_ptr()) }
    }

    fn quiet(&self) {
        // SAFETY: as above.
        unsafe {
            assert_eq!(rkz_config_set_multicast_scouting(self.0, false), RKZ_OK);
            assert_eq!(rkz_config_set_gossip_scouting(self.0, false), RKZ_OK);
        }
    }

    fn open(&self) -> Option<Session> {
        let mut raw = ptr::null_mut();
        // SAFETY: the handle is live and `raw` is a live local.
        if unsafe { rkz_session_open(self.0, &mut raw) } == RKZ_OK {
            assert!(!raw.is_null());
            Some(Session(raw))
        } else {
            None
        }
    }
}

impl Drop for Cfg {
    fn drop(&mut self) {
        // SAFETY: dropped exactly once, here.
        assert_eq!(unsafe { rkz_config_drop(self.0) }, RKZ_OK);
    }
}

struct Session(*mut Boxed<RkzSession>);

impl Session {
    fn zid(&self) -> String {
        let mut buf = [0 as c_char; 64];
        // SAFETY: the handle is live and the buffer is writable for its length.
        assert_eq!(
            unsafe { rkz_session_zid(self.0, buf.as_mut_ptr(), buf.len()) },
            RKZ_OK
        );
        // SAFETY: the library NUL-terminated it.
        unsafe { CStr::from_ptr(buf.as_ptr()) }
            .to_string_lossy()
            .into_owned()
    }

    fn put(&self, key: &str, payload: &[u8]) -> i32 {
        // SAFETY: the handle is live, the strings are NUL-terminated, and the
        // payload is readable for its length.
        unsafe {
            rkz_session_put(
                self.0,
                cs(key).as_ptr(),
                payload.as_ptr(),
                payload.len(),
                cs("block").as_ptr(),
                cs("data").as_ptr(),
            )
        }
    }

    fn subscribe(&self, key: &str) -> Sub {
        let mut raw = ptr::null_mut();
        // SAFETY: as above.
        assert_eq!(
            unsafe { rkz_subscriber_declare(self.0, cs(key).as_ptr(), &mut raw) },
            RKZ_OK,
            "declaring {key} failed: {}",
            last_message()
        );
        Sub(raw)
    }
}

impl Drop for Session {
    fn drop(&mut self) {
        // SAFETY: dropped exactly once, here.
        assert_eq!(unsafe { rkz_session_drop(self.0) }, RKZ_OK);
    }
}

struct Sub(*mut Boxed<RkzSubscriber>);

impl Sub {
    /// Receive once, returning the key and payload, or `None` on timeout.
    fn recv(&self, timeout: Duration) -> Option<(String, String, Vec<u8>)> {
        let mut raw = ptr::null_mut();
        // SAFETY: the handle is live and `raw` is a live local.
        let status = unsafe { rkz_subscriber_recv(self.0, timeout.as_millis() as u64, &mut raw) };
        if status != RKZ_OK {
            assert!(
                last_kind() == "timeout" || last_kind() == "disconnected",
                "unexpected failure: {} {}",
                last_kind(),
                last_message()
            );
            return None;
        }
        // SAFETY: the sample is live until dropped below.
        let key = unsafe { CStr::from_ptr(rkz_sample_key(raw)) }
            .to_string_lossy()
            .into_owned();
        // SAFETY: as above.
        let kind = unsafe { CStr::from_ptr(rkz_sample_kind(raw)) }
            .to_string_lossy()
            .into_owned();
        let mut ptr_out: *const u8 = ptr::null();
        let mut len_out: usize = 0;
        // SAFETY: as above; both out parameters are live locals.
        assert_eq!(
            unsafe { rkz_sample_payload(raw, &mut ptr_out, &mut len_out) },
            RKZ_OK
        );
        // SAFETY: the library promises these bytes live as long as the sample.
        let payload = unsafe { std::slice::from_raw_parts(ptr_out, len_out) }.to_vec();
        // SAFETY: dropped exactly once, and after the borrows above are copied.
        assert_eq!(unsafe { rkz_sample_drop(raw) }, RKZ_OK);
        Some((key, kind, payload))
    }
}

impl Drop for Sub {
    fn drop(&mut self) {
        // SAFETY: dropped exactly once, here.
        assert_eq!(unsafe { rkz_subscriber_drop(self.0) }, RKZ_OK);
    }
}

// ---------------------------------------------------------------------------

#[test]
fn the_library_reports_its_version() {
    // SAFETY: the pointer is static and NUL-terminated.
    let version = unsafe { CStr::from_ptr(rkz_native_version()) }
        .to_string_lossy()
        .into_owned();
    assert_eq!(version, env!("CARGO_PKG_VERSION"));
}

#[test]
fn a_null_handle_is_a_status_not_a_crash() {
    // SAFETY: passing null is exactly what is under test.
    assert_ne!(
        unsafe { rkz_config_set_mode(ptr::null(), cs("peer").as_ptr()) },
        RKZ_OK
    );
    assert_eq!(last_kind(), "null_argument");

    let cfg = Cfg::new();
    // SAFETY: the handle is live; the string argument is null on purpose.
    assert_ne!(unsafe { rkz_config_set_mode(cfg.0, ptr::null()) }, RKZ_OK);
    assert_eq!(last_kind(), "null_argument");
}

#[test]
fn an_unknown_enum_name_is_refused_by_name() {
    let cfg = Cfg::new();
    assert_ne!(cfg.mode("gateway"), RKZ_OK);
    assert_eq!(last_kind(), "unknown_enum_name");
    assert!(last_message().contains("gateway"), "got {}", last_message());
    assert_eq!(cfg.mode("peer"), RKZ_OK);
    assert_eq!(last_kind(), "ok");
}

#[test]
fn a_malformed_zid_is_refused_before_anything_opens() {
    let cfg = Cfg::new();
    assert_ne!(cfg.pin("not-hex"), RKZ_OK);
    assert_eq!(last_kind(), "invalid_config");
    assert_ne!(cfg.pin("0a0b"), RKZ_OK, "a leading zero is not a zenoh id");
    assert_eq!(last_kind(), "invalid_config");
    assert_eq!(cfg.pin("a0b"), RKZ_OK);
}

#[test]
fn a_buffer_too_small_writes_nothing_and_says_so() {
    let cfg = Cfg::new();
    assert_eq!(cfg.mode("peer"), RKZ_OK);
    let mut tiny = [0x7f as c_char; 4];
    // SAFETY: the handle is live and the buffer is writable for its length.
    let status = unsafe { rkz_config_render(cfg.0, tiny.as_mut_ptr(), tiny.len()) };
    assert_ne!(status, RKZ_OK);
    assert_eq!(last_kind(), "buffer_too_small");
    assert!(
        tiny.iter().all(|b| *b == 0x7f),
        "nothing may be written on failure"
    );
}

/// The pin-without-TLS refusal, which is the ABI's whole opinion about the
/// stale-ZID problem: a pinned identity that nobody authenticates is refused
/// rather than quietly accepted. See `tests/stale_zid.rs` for what happens
/// when it is not.
#[test]
fn a_pinned_zid_without_tls_is_refused_at_the_boundary() {
    let cfg = Cfg::new();
    assert_eq!(cfg.mode("peer"), RKZ_OK);
    cfg.quiet();
    assert_eq!(
        cfg.listen(&format!("tcp/127.0.0.1:{}", free_port())),
        RKZ_OK
    );
    assert_eq!(cfg.pin_derived("till-17.shop-3.telepos"), RKZ_OK);

    assert!(
        cfg.open().is_none(),
        "a pinned zid over plain tcp must not open"
    );
    assert_eq!(last_kind(), "invalid_config");
    assert!(
        last_message().contains("tls"),
        "the message must say what is missing, got {}",
        last_message()
    );
}

#[test]
fn an_unpinned_session_over_plain_tcp_opens_and_carries_a_message() {
    let port = free_port();

    let server_cfg = Cfg::new();
    assert_eq!(server_cfg.mode("peer"), RKZ_OK);
    server_cfg.quiet();
    assert_eq!(server_cfg.listen(&format!("tcp/127.0.0.1:{port}")), RKZ_OK);
    let server = server_cfg.open().expect("the server must open");

    let till_cfg = Cfg::new();
    assert_eq!(till_cfg.mode("peer"), RKZ_OK);
    till_cfg.quiet();
    assert_eq!(till_cfg.connect(&format!("tcp/127.0.0.1:{port}")), RKZ_OK);
    let till = till_cfg.open().expect("the till must open");

    assert_ne!(server.zid(), till.zid());
    // A zid prints as an integer without leading zeros, so its length varies
    // and an odd number of digits is normal. Anything that pads or splits it
    // into byte pairs is wrong.
    assert!(!server.zid().is_empty() && server.zid().len() <= 32);
    assert!(!server.zid().starts_with('0'));

    let sub = till.subscribe("telepos/till/till-17/cmd");

    let deadline = Instant::now() + Duration::from_secs(20);
    let received = loop {
        assert!(Instant::now() < deadline, "the message never arrived");
        assert_eq!(
            server.put("telepos/till/till-17/cmd", b"open-drawer"),
            RKZ_OK,
            "a put must succeed even when nothing matches yet"
        );
        if let Some(got) = sub.recv(Duration::from_millis(100)) {
            break got;
        }
    };

    let (key, kind, payload) = received;
    assert_eq!(key, "telepos/till/till-17/cmd");
    assert_eq!(kind, "put", "the kind crosses by name, not by index");
    assert_eq!(payload, b"open-drawer");
}

/// A malformed key must be named as such. Zenoh's grammar is not obvious, and
/// `declaration_failed` on a typo sends the reader looking at the network.
#[test]
fn a_malformed_key_expression_is_named_and_leaves_the_session_usable() {
    let port = free_port();
    let cfg = Cfg::new();
    assert_eq!(cfg.mode("peer"), RKZ_OK);
    cfg.quiet();
    assert_eq!(cfg.listen(&format!("tcp/127.0.0.1:{port}")), RKZ_OK);
    let session = cfg.open().expect("the session must open");

    for bad in ["a/**b", "a//b", "", "a/*x"] {
        let mut raw = ptr::null_mut();
        // SAFETY: the handle is live and the string is NUL-terminated.
        let status = unsafe { rkz_subscriber_declare(session.0, cs(bad).as_ptr(), &mut raw) };
        assert_ne!(status, RKZ_OK, "{bad:?} was accepted as a key expression");
        assert_eq!(last_kind(), "invalid_key_expression", "for {bad:?}");
        assert!(raw.is_null(), "nothing may be handed back on failure");
    }

    // И144: the failures were values, so the session is still good.
    let sub = session.subscribe("telepos/till/till-17/cmd");
    drop(sub);
}

#[test]
fn a_liveliness_token_appears_and_disappears_by_name() {
    let port = free_port();

    let server_cfg = Cfg::new();
    assert_eq!(server_cfg.mode("peer"), RKZ_OK);
    server_cfg.quiet();
    assert_eq!(server_cfg.listen(&format!("tcp/127.0.0.1:{port}")), RKZ_OK);
    let server = server_cfg.open().expect("the server must open");

    let mut watcher = ptr::null_mut();
    // SAFETY: the handles are live and the string is NUL-terminated.
    assert_eq!(
        unsafe {
            rkz_liveliness_declare_subscriber(
                server.0,
                cs("telepos/alive/**").as_ptr(),
                &mut watcher,
            )
        },
        RKZ_OK,
        "declaring the liveliness subscriber failed: {}",
        last_message()
    );
    let watcher = Sub(watcher);

    let till_cfg = Cfg::new();
    assert_eq!(till_cfg.mode("peer"), RKZ_OK);
    till_cfg.quiet();
    assert_eq!(till_cfg.connect(&format!("tcp/127.0.0.1:{port}")), RKZ_OK);
    let till = till_cfg.open().expect("the till must open");

    let mut token = ptr::null_mut();
    // SAFETY: as above.
    assert_eq!(
        unsafe {
            rkz_liveliness_declare_token(till.0, cs("telepos/alive/till-17").as_ptr(), &mut token)
        },
        RKZ_OK,
        "declaring the token failed: {}",
        last_message()
    );

    let appeared = watcher
        .recv(Duration::from_secs(20))
        .expect("the token must be announced");
    assert_eq!(appeared.0, "telepos/alive/till-17");
    assert_eq!(appeared.1, "put", "a peer appearing is a put");

    // Dropping the token is how a peer says it is gone.
    // SAFETY: dropped exactly once, here.
    assert_eq!(unsafe { rkz_liveliness_token_drop(token) }, RKZ_OK);

    let vanished = watcher
        .recv(Duration::from_secs(20))
        .expect("the token going away must be announced");
    assert_eq!(vanished.0, "telepos/alive/till-17");
    assert_eq!(vanished.1, "delete", "a peer leaving is a delete");
}

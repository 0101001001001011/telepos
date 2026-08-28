//! Shared scaffolding for the integration tests.
//!
//! Every suite here talks over a **real socket on a real interface**, on a
//! private port. The private port is not tidiness: on 5353 the machine's own
//! responder — Windows has one, macOS has one, a Linux with Avahi has one —
//! answers questions meant for these tests, and a suite that passed because
//! `mDNSResponder` replied would be proving nothing about this crate.

// Each integration test binary compiles this module separately and uses only
// part of it, so anything the current binary does not call reads as dead. The
// alternative is a helper per binary, which is the same code three times.
#![allow(dead_code)]

use std::time::{Duration, Instant};

use rk_mdns::browser::{Browser, BrowserConfig, BrowserEvent};
use rk_mdns::responder::{Responder, ResponderConfig, ResponderEvent};

/// A port nothing else on this machine is using.
///
/// Derived from the process id so that two `cargo test` runs at once do not
/// collide, and offset per suite so that two suites in the same run do not.
pub fn port(offset: u16) -> u16 {
    20000 + (std::process::id() % 4000) as u16 * 2 + offset
}

/// A responder configured for a same-host test.
///
/// IPv6 off and loopback on, and both for the same reason: these tests have to
/// pass on a segment that does not carry multicast between machines, so the
/// only place a resolver and a responder can meet is one host.
pub fn responder_config(instance: &str, service: &str, port: u16) -> ResponderConfig {
    responder_config_serving(instance, service, port, 8443)
}

/// The same, with the port that goes in the `SRV` record chosen.
///
/// Two responders that differ only in this are what a real name collision
/// looks like, and it is the only shape RFC 6762 §8.1 calls a conflict:
/// **identical** rdata under one name is explicitly *not* one, because it
/// describes the same service. A test that gave both responders the same port
/// would therefore be asserting the opposite of the RFC — and the first
/// version of the conflict test below did exactly that, and failed for that
/// reason rather than for a defect.
pub fn responder_config_serving(
    instance: &str,
    service: &str,
    port: u16,
    service_port: u16,
) -> ResponderConfig {
    serde_json::from_value(serde_json::json!({
        "instanceName": instance,
        "serviceType": service,
        "port": service_port,
        "txt": ["quic=4433", "path=/rk", "scheme=https"],
        "mdnsPort": port,
        "ipv6": false,
        "loopbackInterface": true,
        "multicastLoopback": true,
    }))
    .expect("the test configuration parses")
}

/// A browser for the same service on the same private port.
pub fn browser_config(service: &str, port: u16) -> BrowserConfig {
    serde_json::from_value(serde_json::json!({
        "serviceType": service,
        "mdnsPort": port,
        "ipv6": false,
        "loopbackInterface": true,
        "multicastLoopback": true,
    }))
    .expect("the test configuration parses")
}

/// Waits for the first responder event `want` accepts, or fails saying what
/// did arrive.
///
/// It never returns `None`: a test that shrugged at a missing event would be a
/// test that passes when the responder does nothing at all.
pub fn wait_for_responder<T>(
    responder: &Responder,
    within: Duration,
    want: impl Fn(&ResponderEvent) -> Option<T>,
) -> T {
    let deadline = Instant::now() + within;
    let mut seen = Vec::new();
    while Instant::now() < deadline {
        let Some(event) = responder.poll(Duration::from_millis(200)) else {
            continue;
        };
        if let Some(found) = want(&event) {
            return found;
        }
        seen.push(format!("{event:?}"));
    }
    panic!(
        "the responder never produced the event this test is about, within {within:?}. \
         What it did produce: {seen:#?}"
    );
}

/// The same, for a browser.
pub fn wait_for_browser<T>(
    browser: &Browser,
    within: Duration,
    want: impl Fn(&BrowserEvent) -> Option<T>,
) -> T {
    let deadline = Instant::now() + within;
    let mut seen = Vec::new();
    while Instant::now() < deadline {
        let Some(event) = browser.poll(Duration::from_millis(200)) else {
            continue;
        };
        if let Some(found) = want(&event) {
            return found;
        }
        seen.push(format!("{event:?}"));
    }
    panic!(
        "the browser never produced the event this test is about, within {within:?}. \
         What it did produce: {seen:#?}"
    );
}

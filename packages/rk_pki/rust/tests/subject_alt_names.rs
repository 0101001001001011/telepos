//! Names and addresses in a leaf, and why both have to be there.
//!
//! A till is reached by name — `till-17.local` over mDNS — and mDNS is
//! filtered on a fair number of guest networks. The address is what keeps a
//! terminal working on those, and a TLS client matching `https://192.168.1.50/`
//! reads `iPAddress` entries and nothing else. A leaf carrying the address as
//! a *DNS name* therefore fails the handshake while looking, to anyone reading
//! the certificate, exactly like one that should work.
//!
//! These tests hold both ends of that: what goes in comes back out, in the
//! right list, through enrolment and through rotation.

mod common;

use common::{self_enrolled_till, DAY, T0};
use serde_json::{json, Value};

/// Issues the browser-facing leaf for a till that is already its own root.
fn browser_leaf(till: &common::Machine, request: Value, now: i64) -> Value {
    let invite = till.text("ca.invite.create", json!({ "nowUnix": now }), "invite");
    let mut body = request;
    body["invite"] = json!(invite);
    body["profile"] = json!("browserFacing");
    body["nowUnix"] = json!(now);
    till.ok("identity.enroll", body);

    till.ok(
        "certificate.current",
        json!({ "profile": "browserFacing", "nowUnix": now }),
    )["info"]
        .clone()
}

fn strings(value: &Value) -> Vec<String> {
    value
        .as_array()
        .unwrap()
        .iter()
        .map(|v| v.as_str().unwrap().to_string())
        .collect()
}

#[test]
fn a_leaf_carries_the_name_and_the_address_it_was_asked_for() {
    let till = self_enrolled_till("inst-1", "till-17", T0);
    let info = browser_leaf(
        &till,
        json!({
            "dnsNames": ["till-17.local", "localhost"],
            "ipAddresses": ["192.168.1.50", "127.0.0.1"]
        }),
        T0,
    );

    assert_eq!(strings(&info["dnsNames"]), ["till-17.local", "localhost"]);
    assert_eq!(strings(&info["ipAddresses"]), ["192.168.1.50", "127.0.0.1"]);
}

#[test]
fn the_two_lists_stay_apart() {
    // The point of two arguments rather than one: an address asked for as an
    // address becomes an `iPAddress` entry, and it must not leak into the DNS
    // list, because a client matching an address URL never looks there. If
    // these merged, the certificate would satisfy this test's spelling and
    // fail the browser's.
    let till = self_enrolled_till("inst-1", "till-17", T0);
    let info = browser_leaf(
        &till,
        json!({ "dnsNames": ["till-17.local"], "ipAddresses": ["10.0.0.7"] }),
        T0,
    );

    assert_eq!(strings(&info["dnsNames"]), ["till-17.local"]);
    assert_eq!(strings(&info["ipAddresses"]), ["10.0.0.7"]);
}

#[test]
fn an_address_that_is_not_one_is_refused_by_name() {
    // Dropped silently, this would issue a certificate that omits exactly the
    // fallback it was asked for, and the omission would surface days later on
    // a terminal, as a handshake nobody can explain.
    let till = self_enrolled_till("inst-1", "till-17", T0);
    let invite = till.text("ca.invite.create", json!({ "nowUnix": T0 }), "invite");
    let error = till.err(
        "identity.enroll",
        json!({
            "invite": invite,
            "profile": "browserFacing",
            "ipAddresses": ["till-17.local"],
            "nowUnix": T0
        }),
    );

    assert_eq!(error["kind"], "badRequest");
    assert!(
        error["detail"]
            .as_str()
            .unwrap()
            .contains("is not an IP address"),
        "the reason has to name the thing that was wrong: {error}"
    );
}

#[test]
fn ipv6_survives_the_round_trip() {
    // Sixteen octets rather than four, and the reading side has to tell them
    // apart by length: a v6 address read as v4 would come back as a different
    // address entirely rather than as an error.
    let till = self_enrolled_till("inst-1", "till-17", T0);
    let info = browser_leaf(
        &till,
        json!({ "dnsNames": ["till-17.local"], "ipAddresses": ["fe80::1"] }),
        T0,
    );

    assert_eq!(strings(&info["ipAddresses"]), ["fe80::1"]);
}

#[test]
fn rotation_keeps_the_address_it_is_given_and_drops_the_one_it_is_not() {
    // Rotation happens without a human (И53), so the caller states the names
    // and addresses again every time. That is deliberate: a till whose address
    // changed by DHCP must be able to say so at renewal, and a renewal that
    // silently kept yesterday's address would present a certificate for a
    // machine that is no longer at it.
    let till = self_enrolled_till("inst-1", "till-17", T0);
    browser_leaf(
        &till,
        json!({ "dnsNames": ["till-17.local"], "ipAddresses": ["192.168.1.50"] }),
        T0,
    );

    let at = T0 + 6 * DAY;
    let renewed = till.ok(
        "identity.renew",
        json!({
            "profile": "browserFacing",
            "dnsNames": ["till-17.local"],
            "ipAddresses": ["192.168.1.77"],
            "nowUnix": at
        }),
    )["info"]
        .clone();

    assert_eq!(strings(&renewed["dnsNames"]), ["till-17.local"]);
    assert_eq!(strings(&renewed["ipAddresses"]), ["192.168.1.77"]);
}

#[test]
fn asking_for_nothing_still_leaves_the_identity_urn() {
    // The URN is what makes a certificate one of ours, and it is not one of
    // the optional lists. A leaf with no names and no addresses still has to
    // describe its machine, or `certificate.current` would answer about a
    // certificate it cannot identify.
    let till = self_enrolled_till("inst-1", "till-17", T0);
    let info = browser_leaf(&till, json!({}), T0);

    assert_eq!(info["subjectMachineId"], "till-17");
    assert_eq!(info["profile"], "browserFacing");
    assert!(strings(&info["dnsNames"]).is_empty());
    assert!(strings(&info["ipAddresses"]).is_empty());
}

//! The one export of key material, and the fence around it.
//!
//! Everywhere else this library refuses to hand out a private key, and that
//! refusal is what makes a machine identity worth holding. The exception is
//! `certificate.serverCredential`, which exists because a QUIC server has to
//! terminate TLS and terminating TLS means holding the key — and `rk_quic`
//! will not mint a certificate of its own, so without this the two packages
//! together could not stand up a WebTransport server at all.
//!
//! What these tests hold in place is the *narrowness* of the exception: the
//! browser-facing leaf comes out, the machine identity does not, and the
//! refusal is a value rather than a panic.

mod common;

use serde_json::json;

const NOW: i64 = 1_800_000_000;

#[test]
fn the_browser_facing_credential_comes_out_whole() {
    let till = common::self_enrolled_till("inst-1", "till-1", NOW);
    till.ok(
        "identity.enroll",
        json!({
            "invite": till.text("ca.invite.create", json!({ "nowUnix": NOW }), "invite"),
            "profile": "browserFacing",
            "dnsNames": ["localhost"],
            "nowUnix": NOW,
        }),
    );

    let value = till.ok(
        "certificate.serverCredential",
        json!({ "profile": "browserFacing", "nowUnix": NOW }),
    );

    let chain = value["chainPem"].as_str().unwrap();
    let key = value["privateKeyPem"].as_str().unwrap();

    assert!(
        chain.contains("BEGIN CERTIFICATE"),
        "the chain must be PEM a TLS server can load, got: {chain:.60}"
    );
    assert!(
        key.contains("BEGIN PRIVATE KEY"),
        "the key must be PKCS#8 PEM, which is what QuicServerConfig takes, \
         got: {key:.60}"
    );
}

#[test]
fn the_machine_identity_key_still_never_crosses() {
    let till = common::self_enrolled_till("inst-2", "till-2", NOW);

    let error = till.err(
        "certificate.serverCredential",
        json!({ "profile": "machine", "nowUnix": NOW }),
    );

    assert_eq!(
        error["kind"], "badRequest",
        "refusing must be an answer, not a crash"
    );
    let detail = error["detail"].as_str().unwrap_or_default();
    assert!(
        detail.contains("browserFacing"),
        "the refusal must say which profile is allowed, got: {detail}"
    );
}

#[test]
fn asking_before_enrolling_is_certificate_not_found_not_a_silent_empty() {
    let till = common::self_enrolled_till("inst-3", "till-3", NOW);

    let error = till.err(
        "certificate.serverCredential",
        json!({ "profile": "browserFacing", "nowUnix": NOW }),
    );

    assert_eq!(
        error["kind"], "certificateNotFound",
        "a server told 'here are your credentials' with empty strings would \
         bind a listener that refuses every handshake"
    );
}

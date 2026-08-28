//! The two behaviours everything else rests on: a certificate we refuse, and
//! a certificate that has run out.
//!
//! Both were checked by breaking the implementation on purpose and confirming
//! the test goes red — a test that passes against a broken verifier proves
//! nothing at all.

mod common;

use common::{self_enrolled_till, Machine, DAY, T0};
use serde_json::json;

/// A machine's own leaf, as it would be presented to a peer.
fn leaf_pem(machine: &Machine) -> String {
    machine.text(
        "certificate.export",
        json!({ "profile": "machine" }),
        "certPem",
    )
}

/// Two installations, each its own root, neither knowing the other. This is
/// the one thing an installation's own authority exists to do.
#[test]
fn a_certificate_from_a_foreign_authority_is_rejected() {
    let ours = self_enrolled_till("inst-1", "till-17", T0);
    let theirs = self_enrolled_till("inst-2", "till-17", T0);

    // The peer certificate is well-formed, in date, and names a plausible
    // machine. It is simply not signed by anything we trust.
    let error = ours.err(
        "peer.verify",
        json!({ "certPem": leaf_pem(&theirs), "nowUnix": T0 }),
    );

    assert_eq!(
        error["kind"], "certificateRejected",
        "a certificate from an authority we do not know must be refused"
    );
    assert!(
        error["detail"]
            .as_str()
            .unwrap()
            .to_lowercase()
            .contains("unknownissuer"),
        "the reason must be the issuer, not something incidental: {}",
        error["detail"]
    );
}

#[test]
fn our_own_certificate_verifies_against_our_own_authority() {
    // The control for the test above: same code path, an issuer we know.
    let ours = self_enrolled_till("inst-1", "till-17", T0);
    let value = ours.ok(
        "peer.verify",
        json!({ "certPem": leaf_pem(&ours), "nowUnix": T0 }),
    );
    assert_eq!(value["trusted"], true);
    assert_eq!(value["info"]["subjectMachineId"], "till-17");
}

#[test]
fn a_tampered_certificate_is_rejected() {
    let ours = self_enrolled_till("inst-1", "till-17", T0);
    let leaf = leaf_pem(&ours);

    // Flip one base64 character in the middle of the body. The signature no
    // longer covers what is there.
    let body_start = leaf.find("\n").unwrap() + 40;
    let mut tampered: Vec<char> = leaf.chars().collect();
    tampered[body_start] = if tampered[body_start] == 'A' {
        'B'
    } else {
        'A'
    };
    let tampered: String = tampered.into_iter().collect();

    let error = ours.err("peer.verify", json!({ "certPem": tampered, "nowUnix": T0 }));
    assert_eq!(error["kind"], "certificateRejected");
}

#[test]
fn a_revoked_certificate_is_refused_even_though_it_is_in_date() {
    let ours = self_enrolled_till("inst-1", "till-17", T0);
    let leaf = leaf_pem(&ours);
    let fingerprint = ours.ok("peer.verify", json!({ "certPem": leaf, "nowUnix": T0 }))["info"]
        ["fingerprintSha256"]
        .as_str()
        .unwrap()
        .to_string();

    let revoked = ours.ok(
        "certificate.revoke",
        json!({ "fingerprintSha256": fingerprint, "reason": "device stolen", "nowUnix": T0 }),
    );
    assert_eq!(revoked["securityEvent"], "certificateRevoked");

    let error = ours.err("peer.verify", json!({ "certPem": leaf, "nowUnix": T0 }));
    assert_eq!(error["kind"], "certificateRejected");
    assert!(error["detail"].as_str().unwrap().contains("revoked"));
}

/// The offline rule, as assertions rather than prose.
#[test]
fn an_expired_certificate_degrades_exactly_like_an_absent_network() {
    let till = self_enrolled_till("inst-1", "till-17", T0);
    let a_day_after_expiry = T0 + 31 * DAY;

    // Asking for the current certificate is an honest failure carrying facts.
    let error = till.err(
        "certificate.current",
        json!({ "profile": "machine", "nowUnix": a_day_after_expiry }),
    );
    assert_eq!(error["kind"], "certificateExpired");
    assert_eq!(error["expiredAt"].as_i64().unwrap(), T0 + 30 * DAY);
    assert_eq!(error["info"]["subjectMachineId"], "till-17");

    // Asking for status never fails, and says what still works.
    let status = till.ok(
        "certificate.status",
        json!({ "profile": "machine", "nowUnix": a_day_after_expiry }),
    );
    assert_eq!(status["present"], true);
    assert_eq!(status["expired"], true);
    assert_eq!(
        status["stopsSelling"], false,
        "no level above the till stops a sale"
    );
    assert_eq!(
        status["blocksNewSessions"], true,
        "only what needs this certificate stops"
    );
    assert_eq!(
        status["tearsDownOpenSessions"], false,
        "a session already established is not torn down by the wall clock"
    );
    assert!(status["secondsRemaining"].as_i64().unwrap() < 0);
}

#[test]
fn an_expired_peer_is_told_apart_from_a_peer_we_refuse() {
    // These two must not collapse into one answer: expiry degrades like a
    // missing network and is worth retrying; rejection is a decision.
    let till = self_enrolled_till("inst-1", "till-17", T0);
    let leaf = leaf_pem(&till);

    let expired = till.err(
        "peer.verify",
        json!({ "certPem": leaf, "nowUnix": T0 + 31 * DAY }),
    );
    assert_eq!(expired["kind"], "certificateExpired");
    assert_eq!(expired["expiredAt"].as_i64().unwrap(), T0 + 30 * DAY);

    let foreign = self_enrolled_till("inst-2", "till-17", T0);
    let rejected = till.err(
        "peer.verify",
        json!({ "certPem": leaf_pem(&foreign), "nowUnix": T0 }),
    );
    assert_eq!(rejected["kind"], "certificateRejected");
}

#[test]
fn a_certificate_that_is_still_in_date_is_not_expired() {
    // The control for the expiry test: one second before the end.
    let till = self_enrolled_till("inst-1", "till-17", T0);
    let info = till.ok(
        "certificate.current",
        json!({ "profile": "machine", "nowUnix": T0 + 30 * DAY - 1 }),
    );
    assert_eq!(info["info"]["subjectMachineId"], "till-17");
}

#[test]
fn rotation_falls_due_with_a_third_of_the_life_left() {
    let till = self_enrolled_till("inst-1", "till-17", T0);

    let before = till.ok(
        "certificate.status",
        json!({ "profile": "machine", "nowUnix": T0 + 19 * DAY }),
    );
    assert_eq!(before["rotationDue"], false);
    assert_eq!(before["rotateAt"].as_i64().unwrap(), T0 + 20 * DAY);

    let after = till.ok(
        "certificate.status",
        json!({ "profile": "machine", "nowUnix": T0 + 21 * DAY }),
    );
    assert_eq!(after["rotationDue"], true);
    assert_eq!(after["expired"], false);
    assert_eq!(
        after["blocksNewSessions"], false,
        "rotation being due blocks nothing; it is a reminder, not a failure"
    );
}

#[test]
fn rotation_reissues_and_the_new_certificate_starts_a_new_life() {
    let till = self_enrolled_till("inst-1", "till-17", T0);
    let first = leaf_pem(&till);

    let rotate_at = T0 + 21 * DAY;
    let invite = till.text(
        "ca.invite.create",
        json!({ "nowUnix": rotate_at }),
        "invite",
    );
    till.ok(
        "identity.enroll",
        json!({ "invite": invite, "profile": "machine", "nowUnix": rotate_at }),
    );

    assert_ne!(first, leaf_pem(&till));
    let status = till.ok(
        "certificate.status",
        json!({ "profile": "machine", "nowUnix": rotate_at }),
    );
    assert_eq!(status["rotationDue"], false);
    assert_eq!(
        status["info"]["notAfter"].as_i64().unwrap(),
        rotate_at + 30 * DAY
    );
}

#[test]
fn a_missing_certificate_blocks_sessions_and_still_does_not_stop_selling() {
    let till = Machine::new("inst-1", "till-17", "till");
    let status = till.ok(
        "certificate.status",
        json!({ "profile": "machine", "nowUnix": T0 }),
    );
    assert_eq!(status["present"], false);
    assert_eq!(status["blocksNewSessions"], true);
    assert_eq!(status["stopsSelling"], false);

    let error = till.err(
        "certificate.current",
        json!({ "profile": "machine", "nowUnix": T0 }),
    );
    assert_eq!(error["kind"], "certificateNotFound");
}

#[test]
fn revoking_our_own_profile_forgets_the_key_that_moment() {
    let till = self_enrolled_till("inst-1", "till-17", T0);
    till.ok(
        "certificate.revoke",
        json!({ "profile": "machine", "reason": "reissue", "nowUnix": T0 }),
    );
    let error = till.err(
        "certificate.current",
        json!({ "profile": "machine", "nowUnix": T0 }),
    );
    assert_eq!(error["kind"], "certificateNotFound");
}

#[test]
fn nothing_reachable_from_the_boundary_returns_key_material() {
    // The rule that private keys do not cross, checked rather than asserted
    // in a comment: every operation's answer is searched for the PEM header a
    // private key would carry.
    let till = self_enrolled_till("inst-1", "till-17", T0);
    let answers = [
        till.call("ca.info", json!({})),
        till.call("ca.init", json!({ "nowUnix": T0 })),
        till.call("ca.invite.create", json!({ "nowUnix": T0 })),
        till.call("identity.csr", json!({ "profile": "machine" })),
        till.call(
            "certificate.current",
            json!({ "profile": "machine", "nowUnix": T0 }),
        ),
        till.call(
            "certificate.status",
            json!({ "profile": "machine", "nowUnix": T0 }),
        ),
        till.call("certificate.export", json!({ "profile": "machine" })),
        till.call(
            "peer.verify",
            json!({ "certPem": leaf_pem(&till), "nowUnix": T0 }),
        ),
        // The one operation that *can* return key material, asked for the one
        // profile it must never return it for. Listing it here is the point:
        // the exception granted to `browserFacing` must not quietly widen to
        // the identity every mutual-TLS decision rests on.
        till.call(
            "certificate.serverCredential",
            json!({ "profile": "machine", "nowUnix": T0 }),
        ),
    ];
    for answer in answers {
        let text = answer.to_string();
        assert!(
            !text.contains("PRIVATE KEY"),
            "an answer carried key material: {text}"
        );
    }
}

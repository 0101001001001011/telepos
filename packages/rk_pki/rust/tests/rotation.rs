//! Rotation: automatic, without a human, and only for a machine that still
//! holds a certificate this authority issued.

mod common;

use common::{self_enrolled_till, Machine, DAY, T0};
use serde_json::json;

fn leaf_pem(machine: &Machine) -> String {
    machine.text(
        "certificate.export",
        json!({ "profile": "machine" }),
        "certPem",
    )
}

#[test]
fn rotation_needs_no_human_and_no_invite() {
    // И53 wants rotation to happen by itself. An invite is a person reading
    // out a code, so rotation cannot use one: what authorises the reissue is
    // the certificate the machine already holds.
    let till = self_enrolled_till("inst-1", "till-17", T0);
    let first = leaf_pem(&till);

    let at = T0 + 21 * DAY;
    let renewed = till.ok(
        "identity.renew",
        json!({ "profile": "machine", "nowUnix": at }),
    );
    assert_eq!(renewed["info"]["subjectMachineId"], "till-17");
    assert_ne!(first, leaf_pem(&till));

    let status = till.ok(
        "certificate.status",
        json!({ "profile": "machine", "nowUnix": at }),
    );
    assert_eq!(status["rotationDue"], false);
    assert_eq!(status["info"]["notAfter"].as_i64().unwrap(), at + 30 * DAY);
}

#[test]
fn rotation_after_expiry_is_refused_and_falls_back_to_enrolment() {
    // An expired certificate cannot open the session a renewal would travel
    // over, so pretending it can renew would be a lie told locally.
    let till = self_enrolled_till("inst-1", "till-17", T0);
    let error = till.err(
        "identity.renew",
        json!({ "profile": "machine", "nowUnix": T0 + 31 * DAY }),
    );
    assert_eq!(error["kind"], "certificateExpired");

    // Enrolment by invite still works, which is the way back.
    let at = T0 + 31 * DAY;
    let invite = till.text("ca.invite.create", json!({ "nowUnix": at }), "invite");
    till.ok(
        "identity.enroll",
        json!({ "invite": invite, "profile": "machine", "nowUnix": at }),
    );
    let info = till.ok(
        "certificate.current",
        json!({ "profile": "machine", "nowUnix": at }),
    );
    assert_eq!(info["info"]["notAfter"].as_i64().unwrap(), at + 30 * DAY);
}

#[test]
fn a_revoked_machine_cannot_renew_itself_back_into_trust() {
    let till = self_enrolled_till("inst-1", "till-17", T0);
    let fingerprint = till.ok("certificate.export", json!({ "profile": "machine" }))["info"]
        ["fingerprintSha256"]
        .as_str()
        .unwrap()
        .to_string();
    till.ok(
        "certificate.revoke",
        json!({ "fingerprintSha256": fingerprint, "reason": "stolen", "nowUnix": T0 }),
    );

    let error = till.err(
        "identity.renew",
        json!({ "profile": "machine", "nowUnix": T0 + 21 * DAY }),
    );
    assert_eq!(error["kind"], "certificateRejected");
    assert!(error["detail"].as_str().unwrap().contains("revoked"));
}

#[test]
fn a_renewal_presenting_another_machines_certificate_is_refused() {
    let server = Machine::new("inst-1", "shop-1", "shopServer");
    let root = server.text("ca.init", json!({ "nowUnix": T0 }), "rootPem");
    let invite = server.text("ca.invite.create", json!({ "nowUnix": T0 }), "invite");

    let till = Machine::new("inst-1", "till-17", "till");
    till.ok("ca.trust", json!({ "rootPem": root }));
    let csr = till.text("identity.csr", json!({ "profile": "machine" }), "csrPem");
    let issued = server.ok(
        "ca.issue",
        json!({
            "invite": invite, "csrPem": csr, "machineId": "till-17",
            "machineKind": "till", "profile": "machine", "nowUnix": T0
        }),
    );
    till.ok(
        "certificate.install",
        json!({
            "profile": "machine",
            "certPem": issued["certPem"],
            "chainPem": issued["chainPem"],
            "nowUnix": T0
        }),
    );

    // till-17's certificate, presented in a renewal that asks to be till-18.
    let error = server.err(
        "ca.renew",
        json!({
            "csrPem": csr,
            "currentCertPem": issued["certPem"],
            "machineId": "till-18",
            "machineKind": "till",
            "profile": "machine",
            "nowUnix": T0 + 21 * DAY
        }),
    );
    assert_eq!(error["kind"], "certificateRejected");
}

#[test]
fn a_renewal_from_a_foreign_authority_is_refused() {
    let ours = self_enrolled_till("inst-1", "till-17", T0);
    let theirs = self_enrolled_till("inst-2", "till-17", T0);

    let error = ours.err(
        "ca.renew",
        json!({
            "csrPem": ours.text("identity.csr", json!({ "profile": "machine" }), "csrPem"),
            "currentCertPem": leaf_pem(&theirs),
            "machineId": "till-17",
            "machineKind": "till",
            "profile": "machine",
            "nowUnix": T0 + 21 * DAY
        }),
    );
    assert_eq!(error["kind"], "certificateRejected");
}

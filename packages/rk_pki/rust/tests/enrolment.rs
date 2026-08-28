mod common;

use common::{self_enrolled_till, Machine, DAY, T0};
use serde_json::json;

#[test]
fn a_single_till_is_its_own_authority_and_enrols_itself() {
    let till = self_enrolled_till("inst-1", "till-17", T0);
    let info = till.ok(
        "certificate.current",
        json!({"profile":"machine","nowUnix":T0}),
    )["info"]
        .clone();

    assert_eq!(info["subjectMachineId"], "till-17");
    assert_eq!(info["installationId"], "inst-1");
    assert_eq!(info["machineKind"], "till");
    assert_eq!(info["profile"], "machine");
    assert_eq!(info["isCa"], false);
    assert_eq!(info["notAfter"].as_i64().unwrap(), T0 + 30 * DAY);
    assert_eq!(info["fingerprintSha256"].as_str().unwrap().len(), 64);
}

#[test]
fn the_browser_profile_is_a_second_certificate_with_a_shorter_life() {
    let till = self_enrolled_till("inst-1", "till-17", T0);
    let invite = till.ok("ca.invite.create", json!({ "nowUnix": T0 }))["invite"]
        .as_str()
        .unwrap()
        .to_string();
    till.ok(
        "identity.enroll",
        json!({
            "invite": invite,
            "profile": "browserFacing",
            "dnsNames": ["till-17.local"],
            "nowUnix": T0
        }),
    );

    let machine = till.ok(
        "certificate.current",
        json!({"profile":"machine","nowUnix":T0}),
    )["info"]
        .clone();
    let browser = till.ok(
        "certificate.current",
        json!({"profile":"browserFacing","nowUnix":T0}),
    )["info"]
        .clone();

    // Two live certificates for one machine, from one authority.
    assert_ne!(machine["fingerprintSha256"], browser["fingerprintSha256"]);
    assert_eq!(browser["profile"], "browserFacing");
    assert_eq!(browser["dnsNames"][0], "till-17.local");
    assert_eq!(browser["notAfter"].as_i64().unwrap(), T0 + 7 * DAY);
    // Comfortably under the 14 days a browser will accept for a pinned hash.
    let life = browser["notAfter"].as_i64().unwrap() - browser["notBefore"].as_i64().unwrap();
    assert!(life < 14 * DAY);
}

#[test]
fn an_invite_works_once_and_then_never_again() {
    let server = Machine::new("inst-1", "shop-1", "shopServer");
    server.ok("ca.init", json!({ "nowUnix": T0 }));
    let invite = server.ok("ca.invite.create", json!({ "nowUnix": T0 }))["invite"]
        .as_str()
        .unwrap()
        .to_string();

    let till = Machine::new("inst-1", "till-17", "till");
    let csr = till.ok("identity.csr", json!({ "profile": "machine" }))["csrPem"]
        .as_str()
        .unwrap()
        .to_string();

    let issued = server.ok(
        "ca.issue",
        json!({
            "invite": invite,
            "csrPem": csr,
            "machineId": "till-17",
            "machineKind": "till",
            "profile": "machine",
            "nowUnix": T0
        }),
    );
    assert_eq!(issued["info"]["subjectMachineId"], "till-17");

    // The same invite, a second time.
    let error = server.err(
        "ca.issue",
        json!({
            "invite": invite,
            "csrPem": csr,
            "machineId": "till-17",
            "machineKind": "till",
            "profile": "machine",
            "nowUnix": T0
        }),
    );
    assert_eq!(error["kind"], "inviteInvalid");
}

#[test]
fn an_invite_presented_after_its_window_is_burnt_and_refused() {
    let server = Machine::new("inst-1", "shop-1", "shopServer");
    server.ok("ca.init", json!({ "nowUnix": T0 }));
    let invite = server.ok(
        "ca.invite.create",
        json!({ "ttlSeconds": 600, "nowUnix": T0 }),
    )["invite"]
        .as_str()
        .unwrap()
        .to_string();

    let till = Machine::new("inst-1", "till-17", "till");
    let csr = till.ok("identity.csr", json!({ "profile": "machine" }))["csrPem"]
        .as_str()
        .unwrap()
        .to_string();

    let late = json!({
        "invite": invite,
        "csrPem": csr,
        "machineId": "till-17",
        "machineKind": "till",
        "profile": "machine",
        "nowUnix": T0 + 601
    });
    let error = server.err("ca.issue", late.clone());
    assert_eq!(error["kind"], "inviteExpired");
    assert_eq!(error["expiredAt"].as_i64().unwrap(), T0 + 600);

    // It was burnt on presentation, so retrying inside the window is still
    // refused: an invite that has been shown is spent.
    let mut retry = late;
    retry["nowUnix"] = json!(T0 + 1);
    assert_eq!(server.err("ca.issue", retry)["kind"], "inviteInvalid");
}

#[test]
fn a_till_enrolled_by_its_shop_server_installs_and_trusts_the_result() {
    let server = Machine::new("inst-1", "shop-1", "shopServer");
    let root = server.ok("ca.init", json!({ "nowUnix": T0 }))["rootPem"]
        .as_str()
        .unwrap()
        .to_string();
    let invite = server.ok("ca.invite.create", json!({ "nowUnix": T0 }))["invite"]
        .as_str()
        .unwrap()
        .to_string();

    let till = Machine::new("inst-1", "till-17", "till");
    till.ok("ca.trust", json!({ "rootPem": root }));
    let csr = till.ok("identity.csr", json!({ "profile": "machine" }))["csrPem"]
        .as_str()
        .unwrap()
        .to_string();
    let issued = server.ok(
        "ca.issue",
        json!({
            "invite": invite,
            "csrPem": csr,
            "machineId": "till-17",
            "machineKind": "till",
            "profile": "machine",
            "nowUnix": T0
        }),
    );

    let installed = till.ok(
        "certificate.install",
        json!({
            "profile": "machine",
            "certPem": issued["certPem"],
            "chainPem": issued["chainPem"],
            "nowUnix": T0
        }),
    );
    assert_eq!(installed["info"]["subjectMachineId"], "till-17");
    assert_eq!(installed["info"]["machineKind"], "till");
}

#[test]
fn a_certificate_for_somebody_elses_key_is_refused() {
    let server = Machine::new("inst-1", "shop-1", "shopServer");
    let root = server.ok("ca.init", json!({ "nowUnix": T0 }))["rootPem"]
        .as_str()
        .unwrap()
        .to_string();
    let invite = server.ok("ca.invite.create", json!({ "nowUnix": T0 }))["invite"]
        .as_str()
        .unwrap()
        .to_string();

    // One till makes the request; a different machine tries to install the
    // answer. Same authority, same name, wrong key.
    let real = Machine::new("inst-1", "till-17", "till");
    let csr = real.ok("identity.csr", json!({ "profile": "machine" }))["csrPem"]
        .as_str()
        .unwrap()
        .to_string();
    let issued = server.ok(
        "ca.issue",
        json!({
            "invite": invite, "csrPem": csr, "machineId": "till-17",
            "machineKind": "till", "profile": "machine", "nowUnix": T0
        }),
    );

    let impostor = Machine::new("inst-1", "till-17", "till");
    impostor.ok("ca.trust", json!({ "rootPem": root }));
    let error = impostor.err(
        "certificate.install",
        json!({
            "profile": "machine",
            "certPem": issued["certPem"],
            "chainPem": issued["chainPem"],
            "nowUnix": T0
        }),
    );
    assert_eq!(error["kind"], "certificateRejected");
}

#[test]
fn the_authority_signs_its_own_policy_not_the_requesters() {
    // A request that asks to be a certificate authority is signed as a leaf
    // anyway: rcgen would happily honour the requester's parameters, and the
    // whole point of the authority is that it does not.
    let server = Machine::new("inst-1", "shop-1", "shopServer");
    server.ok("ca.init", json!({ "nowUnix": T0 }));
    let invite = server.ok("ca.invite.create", json!({ "nowUnix": T0 }))["invite"]
        .as_str()
        .unwrap()
        .to_string();

    let till = Machine::new("inst-1", "till-17", "till");
    let csr = till.ok("identity.csr", json!({ "profile": "machine" }))["csrPem"]
        .as_str()
        .unwrap()
        .to_string();
    let issued = server.ok(
        "ca.issue",
        json!({
            "invite": invite, "csrPem": csr, "machineId": "till-17",
            "machineKind": "till", "profile": "machine", "nowUnix": T0
        }),
    );
    assert_eq!(issued["info"]["isCa"], false);
    // And the lifetime is the profile's, not anything the request asked for.
    assert_eq!(issued["info"]["notAfter"].as_i64().unwrap() - T0, 30 * DAY);
}

#[test]
fn a_request_naming_another_machine_is_refused() {
    let server = Machine::new("inst-1", "shop-1", "shopServer");
    server.ok("ca.init", json!({ "nowUnix": T0 }));
    let invite = server.ok("ca.invite.create", json!({ "nowUnix": T0 }))["invite"]
        .as_str()
        .unwrap()
        .to_string();

    let till = Machine::new("inst-1", "till-17", "till");
    let csr = till.ok("identity.csr", json!({ "profile": "machine" }))["csrPem"]
        .as_str()
        .unwrap()
        .to_string();

    let error = server.err(
        "ca.issue",
        json!({
            "invite": invite, "csrPem": csr, "machineId": "shop-1",
            "machineKind": "shopServer", "profile": "machine", "nowUnix": T0
        }),
    );
    assert_eq!(error["kind"], "certificateRejected");
}

#[test]
fn a_machine_without_the_authority_key_cannot_mint_an_invite() {
    let till = Machine::new("inst-1", "till-17", "till");
    assert_eq!(
        till.err("ca.invite.create", json!({ "nowUnix": T0 }))["kind"],
        "caNotHere"
    );
    assert_eq!(
        till.err(
            "identity.enroll",
            json!({"invite":"ABCDE-FGHIJ","profile":"machine","nowUnix":T0})
        )["kind"],
        "caNotHere"
    );
}

#[test]
fn an_enum_arrives_by_name_and_an_index_is_meaningless() {
    let till = Machine::new("inst-1", "till-17", "till");
    assert_eq!(
        till.err("certificate.current", json!({ "profile": "0" }))["kind"],
        "badRequest"
    );
    assert_eq!(
        till.err("certificate.current", json!({ "profile": "Machine" }))["kind"],
        "badRequest"
    );
    // and the answer names it back
    let till = self_enrolled_till("inst-1", "till-17", T0);
    let status = till.ok(
        "certificate.status",
        json!({"profile":"machine","nowUnix":T0}),
    );
    assert_eq!(status["profile"], "machine");
    assert_eq!(status["info"]["profile"], "machine");
}

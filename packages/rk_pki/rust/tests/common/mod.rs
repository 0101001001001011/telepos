//! A machine, driven exactly the way the Dart side drives it: an operation
//! name and a JSON request in, an envelope out.

use rk_pki::{envelope, Engine};
use serde_json::{json, Value};

// This module is compiled *into each test binary separately*, so anything a
// given binary does not touch reads as dead code there — and CI runs clippy
// with `-D warnings`, which turns that into a build failure for whichever test
// file happens not to need a constant. The items are used; they are just not
// all used by all of them.
#[allow(dead_code)]
pub const DAY: i64 = 24 * 60 * 60;
#[allow(dead_code)]
pub const T0: i64 = 1_800_000_000;

pub struct Machine {
    engine: Engine,
    _dir: tempfile::TempDir,
}

impl Machine {
    pub fn new(installation: &str, machine_id: &str, kind: &str) -> Self {
        let dir = tempfile::tempdir().unwrap();
        let config = json!({
            "storeDir": dir.path().to_str().unwrap(),
            "installationId": installation,
            "machineId": machine_id,
            "machineKind": kind,
        });
        let engine = Engine::open(&config.to_string()).unwrap();
        Self { engine, _dir: dir }
    }

    pub fn call(&self, op: &str, request: Value) -> Value {
        let json = envelope(self.engine.call(op, &request.to_string()));
        serde_json::from_str(&json).unwrap()
    }

    pub fn ok(&self, op: &str, request: Value) -> Value {
        let response = self.call(op, request);
        assert_eq!(
            response["ok"],
            true,
            "{op} failed: {}",
            serde_json::to_string_pretty(&response).unwrap()
        );
        response["value"].clone()
    }

    pub fn err(&self, op: &str, request: Value) -> Value {
        let response = self.call(op, request);
        assert_eq!(
            response["ok"],
            false,
            "{op} unexpectedly succeeded: {}",
            serde_json::to_string_pretty(&response).unwrap()
        );
        response["error"].clone()
    }

    pub fn text(&self, op: &str, request: Value, field: &str) -> String {
        self.ok(op, request)[field].as_str().unwrap().to_string()
    }
}

/// A single till that is its own root, enrolled at `now`.
pub fn self_enrolled_till(installation: &str, machine_id: &str, now: i64) -> Machine {
    let till = Machine::new(installation, machine_id, "till");
    till.ok("ca.init", json!({ "nowUnix": now }));
    let invite = till.text("ca.invite.create", json!({ "nowUnix": now }), "invite");
    till.ok(
        "identity.enroll",
        json!({ "invite": invite, "profile": "machine", "nowUnix": now }),
    );
    till
}

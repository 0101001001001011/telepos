//! The operations, selected by name.
//!
//! There is one entry point taking an operation **name** and a JSON request,
//! rather than one exported symbol per operation. Two reasons, both about not
//! breaking a consumer later: adding an operation is not an ABI change, and
//! И147's rule that enumerations cross by name applies just as much to the
//! selector as to the values inside it.

use std::sync::Mutex;

use serde::{Deserialize, Serialize};
use serde_json::{json, Value};

use crate::error::{PkiError, PkiResult};
use crate::identity::AltNames;
use crate::model::{MachineKind, MachineSubject};
use crate::profile::CertProfile;
use crate::store::{RevocationRecord, Store};
use crate::verify::PeerUsage;
use crate::{ca, identity, secret, verify};

/// What an engine needs to know about the machine it belongs to.
#[derive(Debug, Clone, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub struct EngineConfig {
    pub store_dir: String,
    pub installation_id: String,
    pub machine_id: String,
    /// A name — `till`, `shopServer`, `chainServer`, `clusterNode`,
    /// `relayClient` — never an index.
    pub machine_kind: String,
}

/// One machine's PKI state and the lock that serialises access to it.
pub struct Engine {
    subject: MachineSubject,
    store: Mutex<Store>,
}

impl Engine {
    pub fn open(config_json: &str) -> PkiResult<Self> {
        let config: EngineConfig = serde_json::from_str(config_json)
            .map_err(|e| PkiError::bad_request(format!("engine configuration: {e}")))?;
        let kind = MachineKind::from_wire_name(&config.machine_kind)?;
        let subject = MachineSubject::new(&config.installation_id, &config.machine_id, kind)?;
        let store = Store::open(&config.store_dir)?;
        Ok(Self {
            subject,
            store: Mutex::new(store),
        })
    }

    pub fn subject(&self) -> &MachineSubject {
        &self.subject
    }

    fn with_store<T>(&self, body: impl FnOnce(&Store) -> PkiResult<T>) -> PkiResult<T> {
        let guard = self
            .store
            .lock()
            .map_err(|_| PkiError::native("the key store lock is poisoned"))?;
        body(&guard)
    }

    /// Runs one operation. The returned value is the `value` of a successful
    /// envelope; failures come back as [`PkiError`] and are turned into an
    /// envelope by the caller.
    pub fn call(&self, op: &str, request: &str) -> PkiResult<Value> {
        match op {
            "ca.init" => self.ca_init(request),
            "ca.info" => self.ca_info(request),
            "ca.trust" => self.ca_trust(request),
            "ca.invite.create" => self.invite_create(request),
            "ca.issue" => self.ca_issue(request),
            "ca.renew" => self.ca_renew(request),
            "identity.csr" => self.identity_csr(request),
            "identity.enroll" => self.identity_enroll(request),
            "identity.renew" => self.identity_renew(request),
            "identity.forget" => self.identity_forget(request),
            "certificate.install" => self.certificate_install(request),
            "certificate.current" => self.certificate_current(request),
            "certificate.export" => self.certificate_export(request),
            "certificate.serverCredential" => self.certificate_server_credential(request),
            "certificate.status" => self.certificate_status(request),
            "certificate.revoke" => self.certificate_revoke(request),
            "peer.verify" => self.peer_verify(request),
            other => Err(PkiError::bad_request(format!(
                "unknown operation name: {other:?}"
            ))),
        }
    }

    fn ca_init(&self, request: &str) -> PkiResult<Value> {
        let req: NowOnly = parse(request)?;
        self.with_store(|store| {
            let info = ca::init(store, &self.subject.installation_id, req.now())?;
            Ok(json!({ "info": info, "rootPem": ca::root_pem(store)? }))
        })
    }

    fn ca_info(&self, request: &str) -> PkiResult<Value> {
        let _req: NowOnly = parse(request)?;
        self.with_store(|store| {
            Ok(json!({
                "info": ca::root_info(store)?,
                "rootPem": ca::root_pem(store)?,
                "authorityIsHere": ca::is_here(store)?,
            }))
        })
    }

    fn ca_trust(&self, request: &str) -> PkiResult<Value> {
        #[derive(Deserialize)]
        #[serde(rename_all = "camelCase", deny_unknown_fields)]
        struct Req {
            root_pem: String,
            #[serde(default)]
            now_unix: Option<i64>,
        }
        let req: Req = parse(request)?;
        let _ = req.now_unix;
        self.with_store(|store| Ok(json!({ "info": ca::trust_root(store, &req.root_pem)? })))
    }

    fn invite_create(&self, request: &str) -> PkiResult<Value> {
        #[derive(Deserialize)]
        #[serde(rename_all = "camelCase", deny_unknown_fields)]
        struct Req {
            #[serde(default)]
            ttl_seconds: Option<i64>,
            #[serde(default)]
            now_unix: Option<i64>,
        }
        let req: Req = parse(request)?;
        let now = now_or_system(req.now_unix);
        self.with_store(|store| {
            let outcome = ca::create_invite(store, now, req.ttl_seconds)?;
            serde_json::to_value(outcome).map_err(encoding)
        })
    }

    /// The authority side of enrolment for a machine that is not this one.
    fn ca_issue(&self, request: &str) -> PkiResult<Value> {
        #[derive(Deserialize)]
        #[serde(rename_all = "camelCase", deny_unknown_fields)]
        struct Req {
            invite: String,
            csr_pem: String,
            machine_id: String,
            machine_kind: String,
            profile: String,
            #[serde(default)]
            dns_names: Vec<String>,
            #[serde(default)]
            ip_addresses: Vec<String>,
            #[serde(default)]
            now_unix: Option<i64>,
        }
        let req: Req = parse(request)?;
        let now = now_or_system(req.now_unix);
        let profile = CertProfile::from_wire_name(&req.profile)?;
        let kind = MachineKind::from_wire_name(&req.machine_kind)?;
        let subject = MachineSubject::new(&self.subject.installation_id, &req.machine_id, kind)?;
        self.with_store(|store| {
            ca::redeem_invite(store, &req.invite, now)?;
            let outcome = ca::issue_from_csr(
                store,
                &req.csr_pem,
                &subject,
                profile,
                AltNames::new(&req.dns_names, &req.ip_addresses),
                now,
            )?;
            serde_json::to_value(outcome).map_err(encoding)
        })
    }

    fn identity_csr(&self, request: &str) -> PkiResult<Value> {
        let req: ProfileAndNames = parse(request)?;
        let profile = req.profile()?;
        self.with_store(|store| {
            let outcome = identity::create_csr(
                store,
                &self.subject,
                profile,
                AltNames::new(&req.dns_names, &req.ip_addresses),
            )?;
            serde_json::to_value(outcome).map_err(encoding)
        })
    }

    /// Enrolment when this machine is also the authority — the single till
    /// that is its own root. It takes exactly the same path as a remote
    /// machine: build a request, redeem the invite, sign, install. There is
    /// no shortcut for the simple case, which is the whole of И154.
    fn identity_enroll(&self, request: &str) -> PkiResult<Value> {
        #[derive(Deserialize)]
        #[serde(rename_all = "camelCase", deny_unknown_fields)]
        struct Req {
            invite: String,
            profile: String,
            #[serde(default)]
            dns_names: Vec<String>,
            #[serde(default)]
            ip_addresses: Vec<String>,
            #[serde(default)]
            now_unix: Option<i64>,
        }
        let req: Req = parse(request)?;
        let now = now_or_system(req.now_unix);
        let profile = CertProfile::from_wire_name(&req.profile)?;
        self.with_store(|store| {
            if !ca::is_here(store)? {
                return Err(PkiError::CaNotHere {
                    detail: "this machine holds no authority key; ask the authority to issue, then install the answer".to_string(),
                });
            }
            let names = AltNames::new(&req.dns_names, &req.ip_addresses);
            let csr = identity::create_csr(store, &self.subject, profile, names)?;
            ca::redeem_invite(store, &req.invite, now)?;
            let issued =
                ca::issue_from_csr(store, &csr.csr_pem, &self.subject, profile, names, now)?;
            let info = identity::install_certificate(
                store,
                profile,
                &issued.cert_pem,
                Some(&issued.chain_pem),
                now,
            )?;
            Ok(json!({ "info": info }))
        })
    }

    /// Rotation for a machine that is its own authority. No invite, because
    /// rotation must happen without a human (И53): what authorises it is the
    /// certificate this machine already holds.
    fn identity_renew(&self, request: &str) -> PkiResult<Value> {
        let req: ProfileAndNames = parse(request)?;
        let profile = req.profile()?;
        let now = req.now();
        self.with_store(|store| {
            if !ca::is_here(store)? {
                return Err(PkiError::CaNotHere {
                    detail: "this machine holds no authority key; send a renewal request to the authority over its authenticated session".to_string(),
                });
            }
            let current = store
                .read_text(&store.cert_path(profile))?
                .ok_or(PkiError::CertificateNotFound)?;
            // A new key for the new certificate: rotation that reuses the key
            // rotates nothing that matters if the key is what leaked.
            identity::forget_key_only(store, profile)?;
            let names = AltNames::new(&req.dns_names, &req.ip_addresses);
            let csr = identity::create_csr(store, &self.subject, profile, names)?;
            let issued = ca::renew_from_csr(
                store,
                &csr.csr_pem,
                &current,
                &self.subject,
                profile,
                names,
                now,
            )?;
            let info = identity::install_certificate(
                store,
                profile,
                &issued.cert_pem,
                Some(&issued.chain_pem),
                now,
            )?;
            Ok(json!({ "info": info }))
        })
    }

    /// The authority side of a renewal for another machine. The caller has
    /// already authenticated the peer through the mutual TLS session the
    /// request arrived over; the certificate presented here is what that
    /// session was authenticated with.
    fn ca_renew(&self, request: &str) -> PkiResult<Value> {
        #[derive(Deserialize)]
        #[serde(rename_all = "camelCase", deny_unknown_fields)]
        struct Req {
            csr_pem: String,
            current_cert_pem: String,
            machine_id: String,
            machine_kind: String,
            profile: String,
            #[serde(default)]
            dns_names: Vec<String>,
            #[serde(default)]
            ip_addresses: Vec<String>,
            #[serde(default)]
            now_unix: Option<i64>,
        }
        let req: Req = parse(request)?;
        let now = now_or_system(req.now_unix);
        let profile = CertProfile::from_wire_name(&req.profile)?;
        let kind = MachineKind::from_wire_name(&req.machine_kind)?;
        let subject = MachineSubject::new(&self.subject.installation_id, &req.machine_id, kind)?;
        self.with_store(|store| {
            let outcome = ca::renew_from_csr(
                store,
                &req.csr_pem,
                &req.current_cert_pem,
                &subject,
                profile,
                AltNames::new(&req.dns_names, &req.ip_addresses),
                now,
            )?;
            serde_json::to_value(outcome).map_err(encoding)
        })
    }

    fn identity_forget(&self, request: &str) -> PkiResult<Value> {
        let req: ProfileAndNames = parse(request)?;
        let profile = req.profile()?;
        self.with_store(|store| {
            identity::forget(store, profile)?;
            Ok(json!({ "forgotten": profile.wire_name() }))
        })
    }

    fn certificate_install(&self, request: &str) -> PkiResult<Value> {
        #[derive(Deserialize)]
        #[serde(rename_all = "camelCase", deny_unknown_fields)]
        struct Req {
            profile: String,
            cert_pem: String,
            #[serde(default)]
            chain_pem: Option<String>,
            #[serde(default)]
            now_unix: Option<i64>,
        }
        let req: Req = parse(request)?;
        let now = now_or_system(req.now_unix);
        let profile = CertProfile::from_wire_name(&req.profile)?;
        self.with_store(|store| {
            let info = identity::install_certificate(
                store,
                profile,
                &req.cert_pem,
                req.chain_pem.as_deref(),
                now,
            )?;
            Ok(json!({ "info": info }))
        })
    }

    fn certificate_current(&self, request: &str) -> PkiResult<Value> {
        let req: ProfileAndNames = parse(request)?;
        let profile = req.profile()?;
        let now = req.now();
        self.with_store(|store| {
            let info = identity::current(store, profile, now)?;
            Ok(json!({ "info": info }))
        })
    }

    /// The public certificate itself, for handing to a peer or pinning in a
    /// browser. Public by definition — a certificate is what one shows.
    /// Expiry is not an obstacle here: an expired certificate is still the
    /// thing the health screen has to display.
    fn certificate_export(&self, request: &str) -> PkiResult<Value> {
        let req: ProfileAndNames = parse(request)?;
        let profile = req.profile()?;
        self.with_store(|store| {
            let pem = store
                .read_text(&store.cert_path(profile))?
                .ok_or(PkiError::CertificateNotFound)?;
            let info = identity::current_regardless(store, profile)?
                .ok_or(PkiError::CertificateNotFound)?;
            Ok(json!({ "certPem": pem, "info": info }))
        })
    }

    /// The one place key material is allowed to leave this library, and the
    /// only profile it is allowed to leave for.
    ///
    /// # Why this exists at all
    ///
    /// The rule everywhere else in this package — no call returns key material
    /// — is what makes a machine's identity worth something: a key that never
    /// crosses cannot be copied out of a collector's heap. That rule is kept.
    ///
    /// But a QUIC server has to *terminate* TLS, and terminating TLS means
    /// holding the private key. `rk_quic` cannot mint its own certificate (two
    /// authorities in one installation is one too many), and this package
    /// would not hand one over, so between the two of them a WebTransport
    /// server was impossible to stand up at all. Something had to give, and
    /// this is the narrowest place to give it.
    ///
    /// # Why giving here is not giving everywhere
    ///
    /// * **`BrowserFacing` only.** `Machine` — the identity used for mutual
    ///   TLS between till, shop server and relay — is refused here, loudly.
    ///   That key still never crosses.
    /// * **Seven days.** The browser-facing profile exists because a browser
    ///   pinning `serverCertificateHashes` refuses anything at or over
    ///   fourteen. A leaked copy is worth less than a week.
    /// * **It proves nothing about identity.** A browser pinning a hash never
    ///   walks the chain, so this certificate authenticates a *session*, not a
    ///   machine. Presenting it elsewhere buys an attacker no standing.
    ///
    /// The authority is still one and still here: this hands out a leaf it
    /// already issued, it does not let anyone else issue.
    fn certificate_server_credential(&self, request: &str) -> PkiResult<Value> {
        let req: ProfileAndNames = parse(request)?;
        let profile = req.profile()?;
        if profile != CertProfile::BrowserFacing {
            return Err(PkiError::bad_request(format!(
                "server credentials are exported for the browserFacing profile \
                 only; {} keeps its key inside this library, which is the whole \
                 point of it",
                profile.wire_name()
            )));
        }
        self.with_store(|store| {
            let chain_pem = store
                .read_text(&store.cert_path(profile))?
                .ok_or(PkiError::CertificateNotFound)?;
            let key_pem = store
                .read_secret(&store.key_path(profile))?
                .ok_or(PkiError::CertificateNotFound)?;
            let info = identity::current_regardless(store, profile)?
                .ok_or(PkiError::CertificateNotFound)?;
            Ok(json!({
                "chainPem": chain_pem,
                "privateKeyPem": key_pem.to_string(),
                "info": info,
            }))
        })
    }

    /// Everything the caller needs to decide what still works, in one answer
    /// that never fails because of expiry. The rule this serves: an expired
    /// certificate degrades no harder than an absent network — it blocks the
    /// new sessions that need it and nothing else, and it does not tear down
    /// a session already established.
    fn certificate_status(&self, request: &str) -> PkiResult<Value> {
        let req: ProfileAndNames = parse(request)?;
        let profile = req.profile()?;
        let now = req.now();
        self.with_store(|store| {
            let info = identity::current_regardless(store, profile)?;
            let Some(info) = info else {
                return Ok(json!({
                    "present": false,
                    "profile": profile.wire_name(),
                    "expired": false,
                    "rotationDue": true,
                    "blocksNewSessions": true,
                    "tearsDownOpenSessions": false,
                    "stopsSelling": false,
                }));
            };
            let expired = info.expired_at(now).is_some();
            let revoked = store
                .load_revocations()?
                .entries
                .iter()
                .any(|entry| entry.fingerprint_sha256 == info.fingerprint_sha256);
            let rotate_at = profile.rotate_at(info.not_after);
            Ok(json!({
                "present": true,
                "profile": profile.wire_name(),
                "info": info,
                "expired": expired,
                "revoked": revoked,
                "notYetValid": info.not_yet_valid(now),
                "rotateAt": rotate_at,
                "rotationDue": now >= rotate_at,
                "secondsRemaining": info.not_after - now,
                // A new session that needs this certificate cannot start.
                "blocksNewSessions": expired || revoked,
                // Wall-clock expiry never tears down a session that already
                // completed its handshake; an explicit revocation does.
                "tearsDownOpenSessions": revoked,
                // Nothing here ever stops a sale.
                "stopsSelling": false,
            }))
        })
    }

    fn certificate_revoke(&self, request: &str) -> PkiResult<Value> {
        #[derive(Deserialize)]
        #[serde(rename_all = "camelCase", deny_unknown_fields)]
        struct Req {
            #[serde(default)]
            profile: Option<String>,
            #[serde(default)]
            fingerprint_sha256: Option<String>,
            #[serde(default)]
            reason: Option<String>,
            #[serde(default)]
            now_unix: Option<i64>,
        }
        let req: Req = parse(request)?;
        let now = now_or_system(req.now_unix);
        self.with_store(|store| {
            let (fingerprint, forget_profile) = match (&req.profile, &req.fingerprint_sha256) {
                (Some(name), _) => {
                    let profile = CertProfile::from_wire_name(name)?;
                    let info = identity::current_regardless(store, profile)?
                        .ok_or(PkiError::CertificateNotFound)?;
                    (info.fingerprint_sha256, Some(profile))
                }
                (None, Some(fingerprint)) => (fingerprint.clone(), None),
                (None, None) => {
                    return Err(PkiError::bad_request(
                        "revoke needs either a profile name or a fingerprint",
                    ))
                }
            };

            let mut revocations = store.load_revocations()?;
            if !revocations
                .entries
                .iter()
                .any(|entry| entry.fingerprint_sha256 == fingerprint)
            {
                revocations.entries.push(RevocationRecord {
                    fingerprint_sha256: fingerprint.clone(),
                    revoked_at: now,
                    reason: req.reason.clone().unwrap_or_else(|| "unstated".to_string()),
                });
                store.save_revocations(&revocations)?;
            }
            // Our own revoked identity stops existing now, not at some later
            // sweep: the key is removed from disk in the same operation.
            if let Some(profile) = forget_profile {
                identity::forget(store, profile)?;
            }
            Ok(json!({
                "fingerprintSha256": fingerprint,
                "revokedAt": now,
                "securityEvent": "certificateRevoked",
            }))
        })
    }

    fn peer_verify(&self, request: &str) -> PkiResult<Value> {
        #[derive(Deserialize)]
        #[serde(rename_all = "camelCase", deny_unknown_fields)]
        struct Req {
            cert_pem: String,
            #[serde(default)]
            chain_pem: Option<String>,
            #[serde(default)]
            usage: Option<String>,
            #[serde(default)]
            dns_name: Option<String>,
            #[serde(default)]
            now_unix: Option<i64>,
        }
        let req: Req = parse(request)?;
        let now = now_or_system(req.now_unix);
        let usage = match req.usage.as_deref() {
            None => PeerUsage::ClientAuth,
            Some(name) => PeerUsage::from_wire_name(name)?,
        };
        self.with_store(|store| {
            let leaf = crate::pem::certificate_from_pem(&req.cert_pem)?;
            let intermediates = match req.chain_pem.as_deref() {
                Some(pem) if !pem.trim().is_empty() => crate::pem::certificates_from_pem(pem)?,
                _ => Vec::new(),
            };
            let roots = identity::trusted_roots(store)?;
            let revoked: Vec<String> = store
                .load_revocations()?
                .entries
                .into_iter()
                .map(|entry| entry.fingerprint_sha256)
                .collect();
            verify::check_not_revoked(&crate::model::fingerprint_sha256(&leaf), &revoked)?;
            let info = verify::verify_chain(
                &leaf,
                &roots,
                &intermediates,
                now,
                usage,
                req.dns_name.as_deref(),
            )?;
            Ok(json!({ "trusted": true, "info": info }))
        })
    }
}

/// Operations that need no engine: they touch no key store and no identity.
pub fn call_stateless(op: &str, request: &str) -> PkiResult<Value> {
    match op {
        "secret.hash" => {
            #[derive(Deserialize)]
            #[serde(deny_unknown_fields)]
            struct Req {
                secret: String,
            }
            let req: Req = parse(request)?;
            Ok(json!({ "encoded": secret::hash_secret(&req.secret)? }))
        }
        "secret.verify" => {
            #[derive(Deserialize)]
            #[serde(deny_unknown_fields)]
            struct Req {
                secret: String,
                stored: String,
            }
            let req: Req = parse(request)?;
            Ok(json!({ "matches": secret::verify_secret(&req.secret, &req.stored)? }))
        }
        "selftest" => Ok(json!({
            "ok": true,
            "profiles": CertProfile::all().map(|p| p.wire_name()),
            "machineKinds": MachineKind::all().map(|k| k.wire_name()),
        })),
        // Not an operation, and deliberately not a silent success: a caller
        // that asks for something we do not have must be told so.
        other => Err(PkiError::bad_request(format!(
            "unknown stateless operation name: {other:?}"
        ))),
    }
}

/// A response envelope. `ok` decides which of the other two fields is present,
/// so no caller has to guess from the shape.
#[derive(Debug, Serialize)]
struct Envelope {
    ok: bool,
    #[serde(skip_serializing_if = "Option::is_none")]
    value: Option<Value>,
    #[serde(skip_serializing_if = "Option::is_none")]
    error: Option<PkiError>,
}

/// Turns a result into the JSON string that crosses the boundary. Encoding
/// itself cannot fail visibly: if it did, the caller would get nothing at
/// all, so the fallback is a hand-written envelope with the same shape.
pub fn envelope(result: PkiResult<Value>) -> String {
    let envelope = match result {
        Ok(value) => Envelope {
            ok: true,
            value: Some(value),
            error: None,
        },
        Err(error) => Envelope {
            ok: false,
            value: None,
            error: Some(error),
        },
    };
    serde_json::to_string(&envelope).unwrap_or_else(|e| {
        format!(
            r#"{{"ok":false,"error":{{"kind":"nativeFault","detail":"cannot encode the response: {}"}}}}"#,
            e.to_string().replace('"', "'")
        )
    })
}

fn parse<'a, T: Deserialize<'a>>(request: &'a str) -> PkiResult<T> {
    let request = if request.trim().is_empty() {
        "{}"
    } else {
        request
    };
    serde_json::from_str(request).map_err(|e| PkiError::bad_request(format!("request: {e}")))
}

fn encoding(e: serde_json::Error) -> PkiError {
    PkiError::native(format!("cannot encode the response: {e}"))
}

pub fn now_or_system(now: Option<i64>) -> i64 {
    now.unwrap_or_else(|| {
        std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .map(|d| d.as_secs() as i64)
            .unwrap_or(0)
    })
}

#[derive(Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
struct NowOnly {
    #[serde(default)]
    now_unix: Option<i64>,
}

impl NowOnly {
    fn now(&self) -> i64 {
        now_or_system(self.now_unix)
    }
}

#[derive(Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
struct ProfileAndNames {
    profile: String,
    #[serde(default)]
    dns_names: Vec<String>,
    /// Empty by default, which is what every caller before 0.4.0 sent. An
    /// absent list means "no addresses", never "figure out my addresses":
    /// the native library sees one network interface list and the machine may
    /// have five, and guessing here would put an address into a certificate
    /// that nothing reaches the till on.
    #[serde(default)]
    ip_addresses: Vec<String>,
    #[serde(default)]
    now_unix: Option<i64>,
}

impl ProfileAndNames {
    fn profile(&self) -> PkiResult<CertProfile> {
        CertProfile::from_wire_name(&self.profile)
    }

    fn now(&self) -> i64 {
        now_or_system(self.now_unix)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn an_unknown_operation_name_is_a_bad_request_not_a_crash() {
        let json = envelope(call_stateless("secret.shred", "{}"));
        let value: Value = serde_json::from_str(&json).unwrap();
        assert_eq!(value["ok"], false);
        assert_eq!(value["error"]["kind"], "badRequest");
    }

    #[test]
    fn a_successful_envelope_carries_a_value_and_no_error() {
        let json = envelope(call_stateless("selftest", ""));
        let value: Value = serde_json::from_str(&json).unwrap();
        assert_eq!(value["ok"], true);
        assert_eq!(value["value"]["ok"], true);
        assert!(value.get("error").is_none());
    }

    #[test]
    fn a_request_with_an_unexpected_field_is_refused_rather_than_ignored() {
        let json = envelope(call_stateless(
            "secret.hash",
            r#"{"secret":"1234","rounds":1}"#,
        ));
        let value: Value = serde_json::from_str(&json).unwrap();
        assert_eq!(value["ok"], false);
        assert_eq!(value["error"]["kind"], "badRequest");
    }
}

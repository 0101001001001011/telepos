//! What a certificate says about a machine, and how to read it back.
//!
//! Identity lives in the certificate as **names**, never as numbers, and the
//! certificate answers "which machine is this" and nothing else. Rights are a
//! separate subsystem (И55): putting them here would make a change of rights
//! require a reissue.

use serde::{Deserialize, Serialize};
use sha2::{Digest, Sha256};
use x509_parser::prelude::{FromDer, X509Certificate};

use crate::error::{PkiError, PkiResult};
use crate::profile::CertProfile;

/// What kind of machine this is. A fact about topology, not a permission.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub enum MachineKind {
    Till,
    ShopServer,
    ChainServer,
    ClusterNode,
    RelayClient,
}

impl MachineKind {
    pub const fn wire_name(self) -> &'static str {
        match self {
            Self::Till => "till",
            Self::ShopServer => "shopServer",
            Self::ChainServer => "chainServer",
            Self::ClusterNode => "clusterNode",
            Self::RelayClient => "relayClient",
        }
    }

    pub fn from_wire_name(name: &str) -> PkiResult<Self> {
        match name {
            "till" => Ok(Self::Till),
            "shopServer" => Ok(Self::ShopServer),
            "chainServer" => Ok(Self::ChainServer),
            "clusterNode" => Ok(Self::ClusterNode),
            "relayClient" => Ok(Self::RelayClient),
            other => Err(PkiError::bad_request(format!(
                "unknown machine kind name: {other:?}"
            ))),
        }
    }

    pub const fn all() -> [Self; 5] {
        [
            Self::Till,
            Self::ShopServer,
            Self::ChainServer,
            Self::ClusterNode,
            Self::RelayClient,
        ]
    }
}

/// Identifiers are restricted so that the identity URN below parses back
/// unambiguously — a colon inside a machine id would make the URN lie.
pub fn check_identifier(field: &str, value: &str) -> PkiResult<()> {
    if value.is_empty() || value.len() > 64 {
        return Err(PkiError::bad_request(format!(
            "{field} must be 1..64 characters"
        )));
    }
    if !value
        .chars()
        .all(|c| c.is_ascii_alphanumeric() || c == '-' || c == '_' || c == '.')
    {
        return Err(PkiError::bad_request(format!(
            "{field} accepts only ASCII letters, digits, '-', '_' and '.'"
        )));
    }
    Ok(())
}

/// The subject of a leaf certificate: who, where, what kind, which profile.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct MachineSubject {
    pub installation_id: String,
    pub machine_id: String,
    pub machine_kind: MachineKind,
}

impl MachineSubject {
    pub fn new(
        installation_id: impl Into<String>,
        machine_id: impl Into<String>,
        machine_kind: MachineKind,
    ) -> PkiResult<Self> {
        let installation_id = installation_id.into();
        let machine_id = machine_id.into();
        check_identifier("installationId", &installation_id)?;
        check_identifier("machineId", &machine_id)?;
        Ok(Self {
            installation_id,
            machine_id,
            machine_kind,
        })
    }

    /// The URI SAN that carries the identity in one readable, parseable
    /// string. Every component is a name.
    pub fn urn(&self, profile: CertProfile) -> String {
        format!(
            "urn:telepos:v1:installation:{}:machine:{}:kind:{}:profile:{}",
            self.installation_id,
            self.machine_id,
            self.machine_kind.wire_name(),
            profile.wire_name()
        )
    }

    /// Reads back what `urn` wrote. Returns `None` for anything that is not
    /// one of ours rather than guessing.
    pub fn parse_urn(urn: &str) -> Option<(Self, CertProfile)> {
        let parts: Vec<&str> = urn.split(':').collect();
        if parts.len() != 11 {
            return None;
        }
        let expected_labels = [
            (0, "urn"),
            (1, "telepos"),
            (2, "v1"),
            (3, "installation"),
            (5, "machine"),
            (7, "kind"),
            (9, "profile"),
        ];
        for (index, label) in expected_labels {
            if parts[index] != label {
                return None;
            }
        }
        let kind = MachineKind::from_wire_name(parts[8]).ok()?;
        let profile = CertProfile::from_wire_name(parts[10]).ok()?;
        let subject = Self::new(parts[4], parts[6], kind).ok()?;
        Some((subject, profile))
    }
}

/// The public part of a certificate — everything the caller is allowed to
/// see. No key material appears here, by construction (И152 of the design
/// spec): the private key never leaves the native side in any shape.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct CertificateInfo {
    pub subject_machine_id: String,
    pub installation_id: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub machine_kind: Option<MachineKind>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub profile: Option<CertProfile>,
    pub not_before: i64,
    pub not_after: i64,
    pub fingerprint_sha256: String,
    pub serial: String,
    pub dns_names: Vec<String>,
    /// The `iPAddress` entries, rendered the way they are written — dotted
    /// quad for v4, colon form for v6. Separate from `dns_names` because a
    /// client matching an address URL looks only here, and a reader deciding
    /// whether a till is reachable by address has to be able to see the
    /// difference.
    pub ip_addresses: Vec<String>,
    pub is_ca: bool,
}

impl CertificateInfo {
    pub fn expired_at(&self, now: i64) -> Option<i64> {
        (now > self.not_after).then_some(self.not_after)
    }

    pub fn not_yet_valid(&self, now: i64) -> bool {
        now < self.not_before
    }
}

/// Lower-case hex SHA-256 of the DER, the same fingerprint a browser pins
/// through `serverCertificateHashes` and the same one shown in the interface.
pub fn fingerprint_sha256(der: &[u8]) -> String {
    let digest = Sha256::digest(der);
    let mut out = String::with_capacity(64);
    for byte in digest {
        use std::fmt::Write;
        let _ = write!(out, "{byte:02x}");
    }
    out
}

/// Reads a DER certificate into the public description above.
pub fn describe(der: &[u8]) -> PkiResult<CertificateInfo> {
    let (_rest, cert) = X509Certificate::from_der(der)
        .map_err(|e| PkiError::rejected(format!("certificate does not parse: {e}")))?;

    let common_name = cert
        .subject()
        .iter_common_name()
        .next()
        .and_then(|cn| cn.as_str().ok())
        .unwrap_or_default()
        .to_string();
    let organisation = cert
        .subject()
        .iter_organization()
        .next()
        .and_then(|o| o.as_str().ok())
        .unwrap_or_default()
        .to_string();

    let mut dns_names = Vec::new();
    let mut ip_addresses = Vec::new();
    let mut identity = None;
    if let Ok(Some(san)) = cert.subject_alternative_name() {
        for name in &san.value.general_names {
            match name {
                x509_parser::extensions::GeneralName::DNSName(dns) => {
                    dns_names.push((*dns).to_string())
                }
                // An `iPAddress` is four octets or sixteen; anything else is
                // malformed. Skipped rather than rejected, because this
                // function also reads certificates we did not issue, and a
                // peer with one bad extension is a peer to be judged by the
                // chain — not a reason to refuse to describe it at all.
                x509_parser::extensions::GeneralName::IPAddress(octets) => {
                    if let Some(text) = ip_from_octets(octets) {
                        ip_addresses.push(text);
                    }
                }
                // The first URN that parses wins; later ones are ignored rather
                // than overwriting it, so a certificate carrying two of ours
                // does not silently change identity depending on SAN order.
                x509_parser::extensions::GeneralName::URI(uri) if identity.is_none() => {
                    identity = MachineSubject::parse_urn(uri);
                }
                _ => {}
            }
        }
    }

    let (installation_id, machine_id, machine_kind, profile) = match identity {
        Some((subject, profile)) => (
            subject.installation_id,
            subject.machine_id,
            Some(subject.machine_kind),
            Some(profile),
        ),
        // A certificate without our URN is still describable — it is simply
        // not one of ours, and we say so by leaving the fields empty rather
        // than by inventing them.
        None => (organisation, common_name, None, None),
    };

    Ok(CertificateInfo {
        subject_machine_id: machine_id,
        installation_id,
        machine_kind,
        profile,
        not_before: cert.validity().not_before.timestamp(),
        not_after: cert.validity().not_after.timestamp(),
        fingerprint_sha256: fingerprint_sha256(der),
        serial: cert.raw_serial_as_string().replace(':', "").to_lowercase(),
        dns_names,
        ip_addresses,
        is_ca: cert.is_ca(),
    })
}

/// Renders an `iPAddress` SAN. `None` for any length but 4 or 16.
fn ip_from_octets(octets: &[u8]) -> Option<String> {
    match octets.len() {
        4 => {
            let mut v4 = [0u8; 4];
            v4.copy_from_slice(octets);
            Some(std::net::Ipv4Addr::from(v4).to_string())
        }
        16 => {
            let mut v6 = [0u8; 16];
            v6.copy_from_slice(octets);
            Some(std::net::Ipv6Addr::from(v6).to_string())
        }
        _ => None,
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn machine_kind_names_round_trip() {
        for kind in MachineKind::all() {
            assert_eq!(MachineKind::from_wire_name(kind.wire_name()).unwrap(), kind);
            let json = serde_json::to_value(kind).unwrap();
            assert_eq!(json.as_str().unwrap(), kind.wire_name());
        }
        assert!(MachineKind::from_wire_name("2").is_err());
    }

    #[test]
    fn the_identity_urn_round_trips() {
        let subject = MachineSubject::new("inst-1", "till_17", MachineKind::Till).unwrap();
        let urn = subject.urn(CertProfile::BrowserFacing);
        let (back, profile) = MachineSubject::parse_urn(&urn).unwrap();
        assert_eq!(back, subject);
        assert_eq!(profile, CertProfile::BrowserFacing);
    }

    #[test]
    fn a_foreign_urn_is_not_guessed_at() {
        assert!(MachineSubject::parse_urn("urn:example:whatever").is_none());
        assert!(MachineSubject::parse_urn(
            "urn:telepos:v1:installation:a:machine:b:kind:nonesuch:profile:machine"
        )
        .is_none());
    }

    #[test]
    fn identifiers_that_would_break_the_urn_are_refused() {
        assert!(MachineSubject::new("inst:1", "till", MachineKind::Till).is_err());
        assert!(MachineSubject::new("inst", "", MachineKind::Till).is_err());
        assert!(MachineSubject::new("inst", "a b", MachineKind::Till).is_err());
        assert!(MachineSubject::new("inst", "a.b-c_1", MachineKind::Till).is_ok());
    }
}

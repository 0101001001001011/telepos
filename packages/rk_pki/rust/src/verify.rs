//! Judging somebody else's certificate.
//!
//! The verifier is `rustls-webpki` over `aws-lc-rs` — the same path
//! `rk_quic`'s TLS handshake takes, on the same `CertificateDer` type. There
//! is deliberately no second implementation of chain checking here: if this
//! module said yes where the handshake says no, the two answers would drift
//! and nobody would know which one decided.

use rustls_pki_types::{CertificateDer, ServerName, UnixTime};
use serde::{Deserialize, Serialize};
use webpki::{anchor_from_trusted_cert, EndEntityCert, KeyUsage};

use crate::error::{PkiError, PkiResult};
use crate::model::{describe, CertificateInfo};

/// What the peer is being asked to be. Crosses the boundary by name.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub enum PeerUsage {
    ServerAuth,
    ClientAuth,
}

impl PeerUsage {
    pub const fn wire_name(self) -> &'static str {
        match self {
            Self::ServerAuth => "serverAuth",
            Self::ClientAuth => "clientAuth",
        }
    }

    pub fn from_wire_name(name: &str) -> PkiResult<Self> {
        match name {
            "serverAuth" => Ok(Self::ServerAuth),
            "clientAuth" => Ok(Self::ClientAuth),
            other => Err(PkiError::bad_request(format!(
                "unknown peer usage name: {other:?}"
            ))),
        }
    }

    fn key_usage(self) -> KeyUsage {
        match self {
            Self::ServerAuth => KeyUsage::server_auth(),
            Self::ClientAuth => KeyUsage::client_auth(),
        }
    }
}

/// The algorithms we accept. One curve, deliberately: both profiles are
/// ECDSA P-256, so anything else arriving is a certificate from a system we
/// did not issue and should not be widening our surface for.
const SUPPORTED_ALGS: &[&dyn rustls_pki_types::SignatureVerificationAlgorithm] =
    &[webpki::aws_lc_rs::ECDSA_P256_SHA256];

fn unix_time(seconds: i64) -> PkiResult<UnixTime> {
    let seconds = u64::try_from(seconds)
        .map_err(|_| PkiError::bad_request("time before the Unix epoch is not a valid instant"))?;
    Ok(UnixTime::since_unix_epoch(std::time::Duration::from_secs(
        seconds,
    )))
}

/// Verifies a leaf against a set of roots at a moment in time.
///
/// Returns the description of the certificate on success. Expiry comes back
/// as [`PkiError::CertificateExpired`] and not as a rejection, because the
/// caller has to tell those two apart: one degrades like a missing network,
/// the other is a decision that this peer is not ours.
pub fn verify_chain(
    end_entity: &[u8],
    roots: &[Vec<u8>],
    intermediates: &[Vec<u8>],
    now: i64,
    usage: PeerUsage,
    dns_name: Option<&str>,
) -> PkiResult<CertificateInfo> {
    if roots.is_empty() {
        return Err(PkiError::TrustAnchorMissing);
    }
    let info = describe(end_entity)?;

    let leaf = CertificateDer::from(end_entity);
    let cert = EndEntityCert::try_from(&leaf)
        .map_err(|e| PkiError::rejected(format!("certificate does not parse: {e:?}")))?;

    let root_ders: Vec<CertificateDer<'_>> =
        roots.iter().map(|r| CertificateDer::from(&r[..])).collect();
    let anchors = root_ders
        .iter()
        .map(|der| {
            anchor_from_trusted_cert(der)
                .map_err(|e| PkiError::rejected(format!("trust anchor is unusable: {e:?}")))
        })
        .collect::<PkiResult<Vec<_>>>()?;
    let intermediate_ders: Vec<CertificateDer<'_>> = intermediates
        .iter()
        .map(|r| CertificateDer::from(&r[..]))
        .collect();

    cert.verify_for_usage(
        SUPPORTED_ALGS,
        &anchors,
        &intermediate_ders,
        unix_time(now)?,
        usage.key_usage(),
        None,
        None,
    )
    .map_err(|e| map_webpki_error(e, &info))?;

    if let Some(name) = dns_name {
        let server_name = ServerName::try_from(name.to_string())
            .map_err(|_| PkiError::bad_request(format!("{name:?} is not a server name")))?;
        cert.verify_is_valid_for_subject_name(&server_name)
            .map_err(|e| {
                PkiError::rejected(format!("certificate is not valid for {name}: {e:?}"))
            })?;
    }

    Ok(info)
}

fn map_webpki_error(error: webpki::Error, info: &CertificateInfo) -> PkiError {
    match error {
        webpki::Error::CertExpired { not_after, .. } => PkiError::CertificateExpired {
            expired_at: not_after.as_secs() as i64,
            info: Some(Box::new(info.clone())),
        },
        other => PkiError::rejected(format!("{other:?}")),
    }
}

/// A revoked fingerprint is refused before anything else is considered.
/// Section 12 wants revocation to take effect immediately; the short lifetime
/// is the passive mechanism, this list is the active one.
pub fn check_not_revoked(fingerprint: &str, revoked: &[String]) -> PkiResult<()> {
    if revoked.iter().any(|f| f == fingerprint) {
        return Err(PkiError::rejected(format!(
            "certificate {fingerprint} is revoked"
        )));
    }
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn peer_usage_crosses_by_name() {
        assert_eq!(
            PeerUsage::from_wire_name("clientAuth").unwrap(),
            PeerUsage::ClientAuth
        );
        assert!(PeerUsage::from_wire_name("1").is_err());
    }

    #[test]
    fn nothing_verifies_without_a_trust_anchor() {
        let error = verify_chain(&[0u8; 4], &[], &[], 0, PeerUsage::ClientAuth, None).unwrap_err();
        assert_eq!(error.kind_name(), "trustAnchorMissing");
        assert!(error.degrades_like_offline());
    }

    #[test]
    fn a_revoked_fingerprint_is_refused() {
        let revoked = vec!["abc".to_string()];
        assert!(check_not_revoked("def", &revoked).is_ok());
        let error = check_not_revoked("abc", &revoked).unwrap_err();
        assert_eq!(error.kind_name(), "certificateRejected");
        assert!(!error.degrades_like_offline());
    }
}

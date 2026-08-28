//! The installation's own certificate authority.
//!
//! One implementation, used identically by a chain server with a cluster
//! behind it and by a single till that is its own root (И2/И40 applied to
//! section 12: there is no "simple case" branch). The authority is
//! deliberately small — no ACME, no OCSP responder, no public registry. The
//! short lifetime is the revocation mechanism; the list in the store is the
//! immediate one.

use aws_lc_rs::rand::{SecureRandom, SystemRandom};
use rcgen::{
    BasicConstraints, CertificateParams, CertificateSigningRequestParams, DistinguishedName,
    DnType, ExtendedKeyUsagePurpose, IsCa, Issuer, KeyPair, KeyUsagePurpose, SerialNumber,
};
use serde::Serialize;
use time::OffsetDateTime;
use zeroize::Zeroizing;

use crate::error::{PkiError, PkiResult};
use crate::identity::{subject_alt_names, subject_dn, AltNames};
use crate::model::{describe, CertificateInfo, MachineSubject};
use crate::pem::certificate_from_pem;
use crate::profile::CertProfile;
use crate::store::{InviteRecord, Store};

/// A root lasts far longer than any leaf: replacing it means re-enrolling
/// every machine, which is exactly the disruption short leaf lifetimes exist
/// to avoid.
const ROOT_LIFETIME_SECS: i64 = 10 * 365 * 24 * 60 * 60;

/// Certificates are dated a minute into the past so that a machine whose
/// clock is a few seconds behind the authority's does not reject a
/// certificate that was just issued to it.
const CLOCK_SKEW_ALLOWANCE_SECS: i64 = 60;

const DEFAULT_INVITE_TTL_SECS: i64 = 30 * 60;

#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct IssueOutcome {
    pub cert_pem: String,
    pub chain_pem: String,
    pub info: CertificateInfo,
}

#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct InviteOutcome {
    /// Shown once, as a string and as a QR code. Only its digest is stored,
    /// so it cannot be recovered from the machine afterwards.
    pub invite: String,
    pub expires_at: i64,
}

fn timestamp(seconds: i64) -> PkiResult<OffsetDateTime> {
    OffsetDateTime::from_unix_timestamp(seconds)
        .map_err(|e| PkiError::bad_request(format!("{seconds} is not a valid instant: {e}")))
}

fn random_bytes(len: usize) -> PkiResult<Vec<u8>> {
    let mut buf = vec![0u8; len];
    SystemRandom::new()
        .fill(&mut buf)
        .map_err(|_| PkiError::native("the system random source refused"))?;
    Ok(buf)
}

fn random_serial() -> PkiResult<SerialNumber> {
    let mut bytes = random_bytes(16)?;
    // Positive, and never zero: a DER INTEGER is signed, and RFC 5280 wants a
    // positive serial.
    bytes[0] &= 0x7f;
    bytes[0] |= 0x01;
    Ok(SerialNumber::from_slice(&bytes))
}

/// Creates this installation's root. Idempotent: a second call returns the
/// root that already exists rather than quietly replacing every machine's
/// trust anchor.
pub fn init(store: &Store, installation_id: &str, now: i64) -> PkiResult<CertificateInfo> {
    crate::model::check_identifier("installationId", installation_id)?;
    if let Some(existing) = store.read_text(&store.ca_cert_path())? {
        return describe(&certificate_from_pem(&existing)?);
    }

    let key = KeyPair::generate_for(&rcgen::PKCS_ECDSA_P256_SHA256)
        .map_err(|e| PkiError::native(format!("cannot generate a P-256 key: {e}")))?;

    let mut params = CertificateParams::default();
    let mut dn = DistinguishedName::new();
    dn.push(
        DnType::CommonName,
        format!("TelePOS installation authority {installation_id}"),
    );
    dn.push(DnType::OrganizationName, installation_id.to_string());
    params.distinguished_name = dn;
    // Path length zero: this root signs machines, never another authority.
    params.is_ca = IsCa::Ca(BasicConstraints::Constrained(0));
    params.key_usages = vec![
        KeyUsagePurpose::KeyCertSign,
        KeyUsagePurpose::CrlSign,
        KeyUsagePurpose::DigitalSignature,
    ];
    params.not_before = timestamp(now - CLOCK_SKEW_ALLOWANCE_SECS)?;
    params.not_after = timestamp(now + ROOT_LIFETIME_SECS)?;
    params.serial_number = Some(random_serial()?);

    let cert = params
        .self_signed(&key)
        .map_err(|e| PkiError::native(format!("cannot sign the root: {e}")))?;

    let key_pem = Zeroizing::new(key.serialize_pem());
    store.write_secret(&store.ca_key_path(), &key_pem)?;
    store.write_text(&store.ca_cert_path(), &cert.pem())?;

    describe(cert.der())
}

/// True when this machine holds the authority's private key.
pub fn is_here(store: &Store) -> PkiResult<bool> {
    Ok(store.read_text(&store.ca_key_path())?.is_some())
}

fn issuer(store: &Store) -> PkiResult<(Issuer<'static, KeyPair>, String)> {
    let key_pem = store
        .read_secret(&store.ca_key_path())?
        .ok_or_else(|| PkiError::CaNotHere {
            detail: "this machine does not hold the installation's authority key".to_string(),
        })?;
    let cert_pem = store
        .read_text(&store.ca_cert_path())?
        .ok_or(PkiError::CertificateNotFound)?;
    let key = KeyPair::from_pem(&key_pem)
        .map_err(|e| PkiError::keystore(format!("the authority key is unusable: {e}")))?;
    let issuer = Issuer::from_ca_cert_pem(&cert_pem, key)
        .map_err(|e| PkiError::keystore(format!("the authority certificate is unusable: {e}")))?;
    Ok((issuer, cert_pem))
}

/// The authority's own certificate, for a machine that wants to show or ship
/// its trust anchor.
pub fn root_info(store: &Store) -> PkiResult<CertificateInfo> {
    let pem = store
        .read_text(&store.ca_cert_path())?
        .ok_or(PkiError::CertificateNotFound)?;
    describe(&certificate_from_pem(&pem)?)
}

pub fn root_pem(store: &Store) -> PkiResult<String> {
    store
        .read_text(&store.ca_cert_path())?
        .ok_or(PkiError::CertificateNotFound)
}

/// Accepts somebody else's root as this machine's trust anchor — what a till
/// stores about the shop server that enrolled it.
pub fn trust_root(store: &Store, root_pem: &str) -> PkiResult<CertificateInfo> {
    let der = certificate_from_pem(root_pem)?;
    let info = describe(&der)?;
    if !info.is_ca {
        return Err(PkiError::rejected(
            "the offered trust anchor is not a certificate authority",
        ));
    }
    store.write_text(&store.trusted_root_path(), root_pem)?;
    Ok(info)
}

fn normalise_invite(invite: &str) -> String {
    invite
        .chars()
        .filter(|c| c.is_ascii_alphanumeric())
        .collect::<String>()
        .to_uppercase()
}

fn invite_digest(invite: &str) -> String {
    crate::model::fingerprint_sha256(normalise_invite(invite).as_bytes())
}

/// Mints a one-time invite. The owner reads it out or scans it; it is not a
/// secret this code can hand to another machine on its own, which is the
/// point of section 12's rule that no human copies a secret by hand.
pub fn create_invite(store: &Store, now: i64, ttl_secs: Option<i64>) -> PkiResult<InviteOutcome> {
    if !is_here(store)? {
        return Err(PkiError::CaNotHere {
            detail: "only the machine holding the authority can mint an invite".to_string(),
        });
    }
    let ttl = ttl_secs.unwrap_or(DEFAULT_INVITE_TTL_SECS);
    if ttl <= 0 || ttl > 24 * 60 * 60 {
        return Err(PkiError::bad_request(
            "an invite lives between one second and one day",
        ));
    }

    let bytes = random_bytes(10)?;
    let hex: String = bytes.iter().map(|b| format!("{b:02X}")).collect();
    let invite = hex
        .as_bytes()
        .chunks(5)
        .map(|chunk| String::from_utf8_lossy(chunk).to_string())
        .collect::<Vec<_>>()
        .join("-");

    let expires_at = now + ttl;
    let mut invites = store.load_invites()?;
    invites.entries.retain(|entry| {
        // Forget what can no longer be redeemed: a burnt or long-expired
        // record is nothing but a growing file.
        entry.burnt_at.is_none() && entry.expires_at > now - 24 * 60 * 60
    });
    invites.entries.push(InviteRecord {
        digest: invite_digest(&invite),
        created_at: now,
        expires_at,
        burnt_at: None,
    });
    store.save_invites(&invites)?;

    Ok(InviteOutcome { invite, expires_at })
}

/// Redeems an invite, burning it **before** deciding whether it was still
/// valid. An invite that was presented is spent, whatever the answer: that is
/// what makes it one-time in the presence of a caller who retries.
pub fn redeem_invite(store: &Store, invite: &str, now: i64) -> PkiResult<()> {
    let digest = invite_digest(invite);
    let mut invites = store.load_invites()?;
    let Some(record) = invites
        .entries
        .iter_mut()
        .find(|entry| entry.digest == digest && entry.burnt_at.is_none())
    else {
        return Err(PkiError::InviteInvalid);
    };
    let expires_at = record.expires_at;
    record.burnt_at = Some(now);
    store.save_invites(&invites)?;

    if now > expires_at {
        return Err(PkiError::InviteExpired {
            expired_at: expires_at,
        });
    }
    Ok(())
}

/// Signs a request into a leaf certificate.
///
/// The request contributes exactly one thing that is trusted: the public key,
/// whose possession it proves by signing itself. Everything else — subject,
/// alternative names, key usage, basic constraints, validity — is decided
/// here, by the authority. `rcgen` would happily sign the requester's own
/// parameters, `is_ca` included; doing that would let any machine that can
/// reach the authority ask to become one.
pub fn issue_from_csr(
    store: &Store,
    csr_pem: &str,
    subject: &MachineSubject,
    profile: CertProfile,
    names: AltNames<'_>,
    now: i64,
) -> PkiResult<IssueOutcome> {
    let (issuer, root_pem) = issuer(store)?;

    let request = CertificateSigningRequestParams::from_pem(csr_pem)
        .map_err(|e| PkiError::rejected(format!("signing request refused: {e}")))?;

    let requested_common_name = request
        .params
        .distinguished_name
        .get(&DnType::CommonName)
        .and_then(|name| match name {
            rcgen::DnValue::Utf8String(value) => Some(value.as_str()),
            rcgen::DnValue::PrintableString(value) => Some(value.as_str()),
            _ => None,
        })
        .unwrap_or_default()
        .to_string();
    if requested_common_name != subject.machine_id {
        return Err(PkiError::rejected(format!(
            "signing request names {requested_common_name:?}, the authority was asked for {:?}",
            subject.machine_id
        )));
    }

    let mut params = CertificateParams::default();
    params.distinguished_name = subject_dn(subject);
    params.subject_alt_names = subject_alt_names(subject, profile, names)?;
    params.is_ca = IsCa::ExplicitNoCa;
    params.key_usages = vec![KeyUsagePurpose::DigitalSignature];
    params.extended_key_usages = vec![
        ExtendedKeyUsagePurpose::ServerAuth,
        ExtendedKeyUsagePurpose::ClientAuth,
    ];
    params.not_before = timestamp(now - CLOCK_SKEW_ALLOWANCE_SECS)?;
    params.not_after = timestamp(now + profile.lifetime_secs())?;
    params.serial_number = Some(random_serial()?);
    params.use_authority_key_identifier_extension = true;

    let certificate = params
        .signed_by(&request.public_key, &issuer)
        .map_err(|e| PkiError::native(format!("cannot sign the certificate: {e}")))?;

    Ok(IssueOutcome {
        cert_pem: certificate.pem(),
        chain_pem: root_pem,
        info: describe(certificate.der())?,
    })
}

/// Reissues for a machine that already holds a valid certificate from this
/// authority.
///
/// Rotation has to happen without a human (И53), so it cannot ask for an
/// invite: an invite is a person reading a code out. What authorises a
/// renewal instead is the certificate the machine already has — it chains to
/// this authority, it names this machine, it is not revoked, and it has not
/// run out. If it *has* run out, renewal is refused and the machine is back
/// to enrolment by invite, which is the honest outcome: an expired
/// certificate cannot open the session a renewal would travel over either.
pub fn renew_from_csr(
    store: &Store,
    csr_pem: &str,
    current_cert_pem: &str,
    subject: &MachineSubject,
    profile: CertProfile,
    names: AltNames<'_>,
    now: i64,
) -> PkiResult<IssueOutcome> {
    let current = certificate_from_pem(current_cert_pem)?;
    let roots = vec![certificate_from_pem(&root_pem(store)?)?];
    let revoked: Vec<String> = store
        .load_revocations()?
        .entries
        .into_iter()
        .map(|entry| entry.fingerprint_sha256)
        .collect();
    crate::verify::check_not_revoked(&crate::model::fingerprint_sha256(&current), &revoked)?;
    let info = crate::verify::verify_chain(
        &current,
        &roots,
        &[],
        now,
        crate::verify::PeerUsage::ClientAuth,
        None,
    )?;

    if info.subject_machine_id != subject.machine_id {
        return Err(PkiError::rejected(format!(
            "the presented certificate names {:?}, renewal was asked for {:?}",
            info.subject_machine_id, subject.machine_id
        )));
    }
    if info.profile != Some(profile) {
        return Err(PkiError::rejected(
            "the presented certificate is for another profile",
        ));
    }

    issue_from_csr(store, csr_pem, subject, profile, names, now)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn an_invite_is_read_back_however_it_was_typed() {
        assert_eq!(normalise_invite("a1b2c-d3e4f"), "A1B2CD3E4F");
        assert_eq!(normalise_invite("A1B2C D3E4F"), "A1B2CD3E4F");
        assert_eq!(invite_digest("a1b2c-d3e4f"), invite_digest("A1B2C D3E4F"));
    }

    #[test]
    fn a_serial_is_positive_and_never_zero() {
        for _ in 0..16 {
            let serial = random_serial().unwrap().to_bytes();
            assert_eq!(serial.len(), 16);
            assert!(serial[0] & 0x80 == 0);
            assert!(serial[0] != 0);
        }
    }
}

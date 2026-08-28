//! This machine's own key and certificate.
//!
//! The private key is generated here, written here, read here, and used here.
//! No function in this module returns it, and no operation of the C ABI can
//! reach it: what leaves is a certificate signing request and public
//! metadata. That is not politeness, it is the reason the crate exists —
//! `rsa_util.dart` generated a key pair and dropped the private half on the
//! floor, and the replacement must not be able to leak it instead.

use std::net::IpAddr;

use rcgen::{
    CertificateParams, DistinguishedName, DnType, ExtendedKeyUsagePurpose, IsCa, KeyPair,
    KeyUsagePurpose, SanType, PKCS_ECDSA_P256_SHA256,
};
use serde::Serialize;
use zeroize::Zeroizing;

use crate::error::{PkiError, PkiResult};
use crate::model::{describe, fingerprint_sha256, CertificateInfo, MachineSubject};
use crate::pem::{certificate_from_pem, certificates_from_pem};
use crate::profile::CertProfile;
use crate::store::Store;
use crate::verify::{verify_chain, PeerUsage};

/// What a certificate should answer to: names, and addresses.
///
/// One argument rather than two adjacent slices, because these travel together
/// through four functions and a pair of same-typed neighbours is a pair that
/// gets swapped eventually — silently, since both are `&[String]` and the
/// result still issues, just for the wrong kind of name.
#[derive(Debug, Clone, Copy)]
pub struct AltNames<'a> {
    pub dns_names: &'a [String],
    pub ip_addresses: &'a [String],
}

impl<'a> AltNames<'a> {
    pub fn new(dns_names: &'a [String], ip_addresses: &'a [String]) -> Self {
        Self {
            dns_names,
            ip_addresses,
        }
    }
}

#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct CsrOutcome {
    pub csr_pem: String,
    pub public_key_fingerprint_sha256: String,
    pub profile: CertProfile,
}

/// Loads this profile's key, generating one on first use.
///
/// The returned [`KeyPair`] holds the secret in native memory only; it is
/// dropped at the end of the operation that asked for it.
pub fn ensure_key(store: &Store, profile: CertProfile) -> PkiResult<KeyPair> {
    let path = store.key_path(profile);
    if let Some(pem) = store.read_secret(&path)? {
        return KeyPair::from_pem(&pem).map_err(|e| {
            PkiError::keystore(format!("stored key for {profile:?} is unusable: {e}"))
        });
    }
    let key = KeyPair::generate_for(&PKCS_ECDSA_P256_SHA256)
        .map_err(|e| PkiError::native(format!("cannot generate a P-256 key: {e}")))?;
    let pem = Zeroizing::new(key.serialize_pem());
    store.write_secret(&path, &pem)?;
    Ok(key)
}

/// True when a key already exists for this profile, without creating one.
pub fn has_key(store: &Store, profile: CertProfile) -> PkiResult<bool> {
    Ok(store.read_text(&store.key_path(profile))?.is_some())
}

/// Builds the certificate signing request this machine sends to the
/// authority — whether that authority is on another machine or is this same
/// process acting as the installation root (И154: one code path).
pub fn create_csr(
    store: &Store,
    subject: &MachineSubject,
    profile: CertProfile,
    names: AltNames<'_>,
) -> PkiResult<CsrOutcome> {
    let key = ensure_key(store, profile)?;
    let mut params = CertificateParams::default();
    params.distinguished_name = subject_dn(subject);
    params.subject_alt_names = subject_alt_names(subject, profile, names)?;
    // A request states what it wants; the authority decides what it gets.
    params.is_ca = IsCa::ExplicitNoCa;
    params.key_usages = vec![KeyUsagePurpose::DigitalSignature];
    params.extended_key_usages = vec![
        ExtendedKeyUsagePurpose::ServerAuth,
        ExtendedKeyUsagePurpose::ClientAuth,
    ];

    let csr = params
        .serialize_request(&key)
        .map_err(|e| PkiError::native(format!("cannot build a signing request: {e}")))?;
    let csr_pem = csr
        .pem()
        .map_err(|e| PkiError::native(format!("cannot encode the signing request: {e}")))?;

    Ok(CsrOutcome {
        csr_pem,
        public_key_fingerprint_sha256: fingerprint_sha256(key.public_key_raw()),
        profile,
    })
}

pub fn subject_dn(subject: &MachineSubject) -> DistinguishedName {
    let mut dn = DistinguishedName::new();
    dn.push(DnType::CommonName, subject.machine_id.clone());
    dn.push(DnType::OrganizationName, subject.installation_id.clone());
    dn.push(
        DnType::OrganizationalUnitName,
        subject.machine_kind.wire_name().to_string(),
    );
    dn
}

/// The alternative names a certificate carries: this machine's identity URN,
/// the names it answers to, and the addresses it answers on.
///
/// # Why addresses are a separate list and not just more names
///
/// A TLS client matching `https://192.168.1.50/` looks at `iPAddress` entries
/// and at nothing else — RFC 6125 §6.4 and every browser that implements it.
/// A certificate carrying `DNS:192.168.1.50` therefore fails against that URL
/// while looking, to a reader, exactly like one that should work. The two
/// kinds are different extension entries, so they are different arguments
/// here: the caller states which it means and cannot state it by accident.
///
/// This matters on a shop network specifically. The till is reached by name
/// over mDNS, and mDNS is filtered on a good number of guest networks; the
/// address is the fallback that keeps a terminal working there, and a
/// fallback that fails the handshake is not one.
pub fn subject_alt_names(
    subject: &MachineSubject,
    profile: CertProfile,
    names: AltNames<'_>,
) -> PkiResult<Vec<SanType>> {
    let mut sans = vec![SanType::URI(subject.urn(profile).try_into().map_err(
        |e| PkiError::native(format!("identity URN is not a valid IA5 string: {e}")),
    )?)];
    for name in names.dns_names {
        sans.push(SanType::DnsName(name.clone().try_into().map_err(|e| {
            PkiError::bad_request(format!("{name:?} is not a DNS name: {e}"))
        })?));
    }
    for text in names.ip_addresses {
        // Refused rather than dropped: a certificate silently issued without
        // the address it was asked for is one whose failure surfaces later,
        // on a terminal, as a handshake nobody can explain.
        let address: IpAddr = text
            .parse()
            .map_err(|e| PkiError::bad_request(format!("{text:?} is not an IP address: {e}")))?;
        sans.push(SanType::IpAddress(address));
    }
    Ok(sans)
}

/// Stores a certificate the authority issued for this machine.
///
/// Three things are checked before it is written, and each one has a reason:
/// it must chain to a root we already trust (otherwise anyone who can write
/// to the store can hand us an identity), it must carry *our* public key
/// (otherwise it is somebody else's certificate), and it must not already be
/// expired (otherwise the store is seeded with something that cannot work).
pub fn install_certificate(
    store: &Store,
    profile: CertProfile,
    cert_pem: &str,
    chain_pem: Option<&str>,
    now: i64,
) -> PkiResult<CertificateInfo> {
    let leaf = certificate_from_pem(cert_pem)?;
    let intermediates = match chain_pem {
        Some(pem) if !pem.trim().is_empty() => certificates_from_pem(pem)?,
        _ => Vec::new(),
    };
    let roots = trusted_roots(store)?;
    let info = verify_chain(
        &leaf,
        &roots,
        &intermediates,
        now,
        PeerUsage::ClientAuth,
        None,
    )?;

    let key = ensure_key(store, profile)?;
    if !certificate_carries_key(&leaf, key.public_key_raw())? {
        return Err(PkiError::rejected(
            "certificate does not carry this machine's public key",
        ));
    }
    if info.profile != Some(profile) {
        return Err(PkiError::rejected(format!(
            "certificate is for profile {:?}, not {}",
            info.profile.map(|p| p.wire_name()),
            profile.wire_name()
        )));
    }

    store.write_text(&store.cert_path(profile), cert_pem)?;
    Ok(info)
}

/// Every root this machine will accept: the authority it runs itself, if any,
/// and the authority that enrolled it, if different.
pub fn trusted_roots(store: &Store) -> PkiResult<Vec<Vec<u8>>> {
    let mut roots = Vec::new();
    for path in [store.ca_cert_path(), store.trusted_root_path()] {
        if let Some(pem) = store.read_text(&path)? {
            let der = certificate_from_pem(&pem)?;
            if !roots.contains(&der) {
                roots.push(der);
            }
        }
    }
    Ok(roots)
}

fn certificate_carries_key(cert_der: &[u8], public_key_raw: &[u8]) -> PkiResult<bool> {
    use x509_parser::prelude::{FromDer, X509Certificate};
    let (_rest, cert) = X509Certificate::from_der(cert_der)
        .map_err(|e| PkiError::rejected(format!("certificate does not parse: {e}")))?;
    Ok(cert.public_key().subject_public_key.data.as_ref() == public_key_raw)
}

/// The certificate stored for this profile, read without touching the network.
///
/// Expiry is reported as [`PkiError::CertificateExpired`] carrying the
/// description, because the caller needs the facts (when it expired, which
/// machine, which profile) to log the security event section 16 asks for
/// while it carries on selling.
pub fn current(store: &Store, profile: CertProfile, now: i64) -> PkiResult<CertificateInfo> {
    let Some(pem) = store.read_text(&store.cert_path(profile))? else {
        return Err(PkiError::CertificateNotFound);
    };
    let der = certificate_from_pem(&pem)?;
    let info = describe(&der)?;
    if let Some(expired_at) = info.expired_at(now) {
        return Err(PkiError::CertificateExpired {
            expired_at,
            info: Some(Box::new(info)),
        });
    }
    Ok(info)
}

/// The stored certificate whether or not it is still valid — what the health
/// screen shows, and what rotation reasons about.
pub fn current_regardless(
    store: &Store,
    profile: CertProfile,
) -> PkiResult<Option<CertificateInfo>> {
    match store.read_text(&store.cert_path(profile))? {
        None => Ok(None),
        Some(pem) => {
            let der = certificate_from_pem(&pem)?;
            Ok(Some(describe(&der)?))
        }
    }
}

/// Forgets this profile's key and certificate. Called on revocation and
/// before a reissue: the old secret stops existing at that moment (И146 read
/// as "no secret outlives its purpose"), not whenever something is collected.
pub fn forget(store: &Store, profile: CertProfile) -> PkiResult<()> {
    store.remove_secret(&store.key_path(profile))?;
    store.remove_secret(&store.cert_path(profile))?;
    Ok(())
}

/// Drops the key but keeps the certificate, so that a rotation generates a
/// fresh key while the machine still holds something to authenticate the
/// renewal with. Rotation that reuses the key rotates nothing that matters if
/// the key is what leaked.
pub fn forget_key_only(store: &Store, profile: CertProfile) -> PkiResult<()> {
    store.remove_secret(&store.key_path(profile))
}

//! PEM in, DER out — through `rustls-pki-types`, the same decoder rustls uses.
//!
//! Nothing in this crate hand-writes ASN.1 or DER. That is the whole point of
//! replacing `rsa_util.dart`: the byte-level encoding is somebody else's
//! audited job, and ours is the policy above it.

use rustls_pki_types::pem::PemObject;
use rustls_pki_types::CertificateDer;

use crate::error::{PkiError, PkiResult};

/// Decodes one certificate from PEM.
pub fn certificate_from_pem(pem: &str) -> PkiResult<Vec<u8>> {
    CertificateDer::from_pem_slice(pem.as_bytes())
        .map(|der| der.as_ref().to_vec())
        .map_err(|e| PkiError::rejected(format!("not a PEM certificate: {e:?}")))
}

/// Decodes every certificate in a PEM bundle, in the order they appear.
pub fn certificates_from_pem(pem: &str) -> PkiResult<Vec<Vec<u8>>> {
    let mut out = Vec::new();
    for item in CertificateDer::pem_slice_iter(pem.as_bytes()) {
        let der = item.map_err(|e| PkiError::rejected(format!("not a PEM bundle: {e:?}")))?;
        out.push(der.as_ref().to_vec());
    }
    if out.is_empty() {
        return Err(PkiError::rejected("PEM bundle holds no certificate"));
    }
    Ok(out)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn rubbish_is_refused_rather_than_half_parsed() {
        assert!(certificate_from_pem("not a certificate").is_err());
        assert!(certificates_from_pem("").is_err());
    }
}

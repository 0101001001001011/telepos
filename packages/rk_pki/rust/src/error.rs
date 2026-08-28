//! Failures are values.
//!
//! И144: a failure of the native library is returned as a value; it never
//! aborts the process and never leaves the foreign stack as an exception.
//! Every variant below is serialised with a `kind` **name** (И147), so
//! inserting a variant cannot silently change the meaning of a stored or
//! logged value.

use serde::Serialize;

use crate::model::CertificateInfo;

/// Everything that can go wrong inside `rk_pki`.
#[derive(Debug, Clone, Serialize)]
#[serde(tag = "kind", rename_all = "camelCase")]
pub enum PkiError {
    /// No such invite, or it was already redeemed.
    InviteInvalid,
    /// The invite existed but its window had closed. It is burnt regardless.
    InviteExpired {
        #[serde(rename = "expiredAt")]
        expired_at: i64,
    },
    /// The certificate authority could not be reached. Degrades like an
    /// absent network: local selling continues, work queues.
    CaUnreachable { detail: String },
    /// This machine does not hold the installation's certificate authority.
    CaNotHere { detail: String },
    /// Nothing is stored for that profile yet.
    CertificateNotFound,
    /// The certificate exists and is well-formed, but wall-clock time is past
    /// its `notAfter`. An honest answer, not a fatal error: the caller must
    /// treat it exactly as it treats an absent network.
    CertificateExpired {
        #[serde(rename = "expiredAt")]
        expired_at: i64,
        // Boxed so that the whole error type stays small: it is returned
        // from every function in the crate, including the hot ones.
        #[serde(skip_serializing_if = "Option::is_none")]
        info: Option<Box<CertificateInfo>>,
    },
    /// The certificate is not one we will trust: unknown issuer, broken
    /// signature, wrong subject, revoked, or not for the asked-for purpose.
    CertificateRejected { detail: String },
    /// No certificate authority root is installed, so nothing can be judged.
    TrustAnchorMissing,
    /// The key store could not be read or written.
    KeystoreUnavailable { detail: String },
    /// A signature did not verify.
    SignatureInvalid,
    /// The request itself was malformed — a name that is not an operation, a
    /// field of the wrong shape, an identifier with characters we do not allow.
    BadRequest { detail: String },
    /// A panic was caught at the FFI boundary, or an invariant of the native
    /// side broke. This is the only variant that means "the library is at
    /// fault"; every other one is a fact about the world.
    NativeFault { detail: String },
}

impl PkiError {
    /// Short, stable name of the variant. The same string serde emits.
    pub fn kind_name(&self) -> &'static str {
        match self {
            Self::InviteInvalid => "inviteInvalid",
            Self::InviteExpired { .. } => "inviteExpired",
            Self::CaUnreachable { .. } => "caUnreachable",
            Self::CaNotHere { .. } => "caNotHere",
            Self::CertificateNotFound => "certificateNotFound",
            Self::CertificateExpired { .. } => "certificateExpired",
            Self::CertificateRejected { .. } => "certificateRejected",
            Self::TrustAnchorMissing => "trustAnchorMissing",
            Self::KeystoreUnavailable { .. } => "keystoreUnavailable",
            Self::SignatureInvalid => "signatureInvalid",
            Self::BadRequest { .. } => "badRequest",
            Self::NativeFault { .. } => "nativeFault",
        }
    }

    /// Whether this failure must degrade no harder than an absent network.
    ///
    /// The architecture's own rule (И2, И39, and the section 2 reading of it
    /// in the design spec): no level above the till stops a sale. An expired
    /// or missing certificate, or an unreachable authority, blocks the *new
    /// sessions that need it* and nothing else.
    pub fn degrades_like_offline(&self) -> bool {
        matches!(
            self,
            Self::CaUnreachable { .. }
                | Self::CertificateNotFound
                | Self::CertificateExpired { .. }
                | Self::TrustAnchorMissing
        )
    }

    pub fn bad_request(detail: impl Into<String>) -> Self {
        Self::BadRequest {
            detail: detail.into(),
        }
    }

    pub fn rejected(detail: impl Into<String>) -> Self {
        Self::CertificateRejected {
            detail: detail.into(),
        }
    }

    pub fn keystore(detail: impl Into<String>) -> Self {
        Self::KeystoreUnavailable {
            detail: detail.into(),
        }
    }

    pub fn native(detail: impl Into<String>) -> Self {
        Self::NativeFault {
            detail: detail.into(),
        }
    }
}

pub type PkiResult<T> = Result<T, PkiError>;

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn error_crosses_the_boundary_by_name() {
        let json = serde_json::to_value(PkiError::InviteExpired { expired_at: 7 }).unwrap();
        assert_eq!(json["kind"], "inviteExpired");
        assert_eq!(json["expiredAt"], 7);
    }

    #[test]
    fn kind_name_matches_what_serde_writes() {
        let all = [
            PkiError::InviteInvalid,
            PkiError::InviteExpired { expired_at: 0 },
            PkiError::CaUnreachable {
                detail: String::new(),
            },
            PkiError::CaNotHere {
                detail: String::new(),
            },
            PkiError::CertificateNotFound,
            PkiError::CertificateExpired {
                expired_at: 0,
                info: None,
            },
            PkiError::CertificateRejected {
                detail: String::new(),
            },
            PkiError::TrustAnchorMissing,
            PkiError::KeystoreUnavailable {
                detail: String::new(),
            },
            PkiError::SignatureInvalid,
            PkiError::BadRequest {
                detail: String::new(),
            },
            PkiError::NativeFault {
                detail: String::new(),
            },
        ];
        for e in all {
            let json = serde_json::to_value(&e).unwrap();
            assert_eq!(json["kind"].as_str().unwrap(), e.kind_name());
        }
    }

    #[test]
    fn only_the_offline_shaped_failures_degrade_softly() {
        assert!(PkiError::CertificateExpired {
            expired_at: 0,
            info: None
        }
        .degrades_like_offline());
        assert!(PkiError::CaUnreachable {
            detail: String::new()
        }
        .degrades_like_offline());
        // A rejected certificate is a decision, not a network condition.
        assert!(!PkiError::rejected("unknown issuer").degrades_like_offline());
        assert!(!PkiError::InviteInvalid.degrades_like_offline());
        assert!(!PkiError::SignatureInvalid.degrades_like_offline());
    }
}

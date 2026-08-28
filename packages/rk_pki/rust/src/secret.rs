//! What `rsa_util.dart` was actually doing, done properly.
//!
//! The old code encrypted a staff PIN with an RSA public key using
//! `RSA/ECB/NoPadding` and compared ciphertexts. That is a deterministic
//! function whose every input — modulus, exponent — sat in the same database
//! row as its output, with no salt, so two people with the same PIN had the
//! same stored value. It is replaced here by a salted one-way hash, which is
//! what the job needed all along. This has nothing to do with certificates
//! and shares nothing with them but the crate that holds one audited
//! implementation of each primitive instead of two home-made ones.

use argon2::password_hash::{PasswordHash, PasswordHasher, PasswordVerifier, SaltString};
use argon2::Argon2;
use aws_lc_rs::rand::{SecureRandom, SystemRandom};

use crate::error::{PkiError, PkiResult};

/// Hashes a secret with Argon2id and a fresh random salt. The salt and the
/// parameters travel inside the returned PHC string, so verification needs
/// nothing else stored beside it.
pub fn hash_secret(secret: &str) -> PkiResult<String> {
    if secret.is_empty() {
        return Err(PkiError::bad_request("an empty secret cannot be hashed"));
    }
    let mut salt_bytes = [0u8; 16];
    SystemRandom::new()
        .fill(&mut salt_bytes)
        .map_err(|_| PkiError::native("the system random source refused"))?;
    let salt = SaltString::encode_b64(&salt_bytes)
        .map_err(|e| PkiError::native(format!("cannot encode a salt: {e}")))?;
    Argon2::default()
        .hash_password(secret.as_bytes(), &salt)
        .map(|hash| hash.to_string())
        .map_err(|e| PkiError::native(format!("cannot hash a secret: {e}")))
}

/// Verifies a secret against a stored PHC string. A malformed stored value is
/// a bad request, not a silent `false`: a corrupt row must be visible rather
/// than look like a wrong PIN forever.
pub fn verify_secret(secret: &str, stored: &str) -> PkiResult<bool> {
    let parsed = PasswordHash::new(stored)
        .map_err(|e| PkiError::bad_request(format!("stored secret is not a PHC string: {e}")))?;
    match Argon2::default().verify_password(secret.as_bytes(), &parsed) {
        Ok(()) => Ok(true),
        Err(argon2::password_hash::Error::Password) => Ok(false),
        Err(e) => Err(PkiError::native(format!("cannot verify a secret: {e}"))),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn a_secret_verifies_against_its_own_hash() {
        let stored = hash_secret("1234").unwrap();
        assert!(verify_secret("1234", &stored).unwrap());
        assert!(!verify_secret("1235", &stored).unwrap());
    }

    #[test]
    fn the_same_secret_hashes_differently_every_time() {
        // The defect being replaced: two people with the same PIN used to
        // have byte-identical stored values.
        let a = hash_secret("1234").unwrap();
        let b = hash_secret("1234").unwrap();
        assert_ne!(a, b);
        assert!(verify_secret("1234", &a).unwrap());
        assert!(verify_secret("1234", &b).unwrap());
    }

    #[test]
    fn the_hash_says_which_algorithm_it_is() {
        assert!(hash_secret("1234").unwrap().starts_with("$argon2id$"));
    }

    #[test]
    fn a_corrupt_stored_value_is_reported_not_swallowed() {
        let error = verify_secret("1234", "nonsense").unwrap_err();
        assert_eq!(error.kind_name(), "badRequest");
    }
}

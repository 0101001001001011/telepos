//! Where key material and certificates live on disk.
//!
//! Two rules hold everywhere in this file:
//!
//! * A private key is read into a [`Zeroizing<String>`], used, and wiped when
//!   the borrow ends. It is never returned upwards, never serialised into a
//!   response, and never handed across the FFI boundary.
//! * A key file is created with owner-only permissions where the platform has
//!   them. On Windows it inherits the directory ACL — see the note on
//!   [`write_secret`].

use std::fs;
use std::io::Write as _;
use std::path::{Path, PathBuf};

use serde::{Deserialize, Serialize};
use zeroize::Zeroizing;

use crate::error::{PkiError, PkiResult};
use crate::profile::CertProfile;

/// A record of an invite. Only the digest is kept: the code itself is shown
/// once, to one person, and is not recoverable from the store afterwards.
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct InviteRecord {
    pub digest: String,
    pub created_at: i64,
    pub expires_at: i64,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub burnt_at: Option<i64>,
}

#[derive(Debug, Clone, Default, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct Invites {
    #[serde(default)]
    pub entries: Vec<InviteRecord>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct RevocationRecord {
    pub fingerprint_sha256: String,
    pub revoked_at: i64,
    pub reason: String,
}

#[derive(Debug, Clone, Default, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct Revocations {
    #[serde(default)]
    pub entries: Vec<RevocationRecord>,
}

/// A directory holding one machine's PKI state.
#[derive(Debug, Clone)]
pub struct Store {
    dir: PathBuf,
}

impl Store {
    pub fn open(dir: impl Into<PathBuf>) -> PkiResult<Self> {
        let dir = dir.into();
        fs::create_dir_all(dir.join("keys"))
            .and_then(|_| fs::create_dir_all(dir.join("certs")))
            .map_err(|e| PkiError::keystore(format!("cannot create key store at {dir:?}: {e}")))?;
        Ok(Self { dir })
    }

    pub fn dir(&self) -> &Path {
        &self.dir
    }

    pub fn ca_key_path(&self) -> PathBuf {
        self.dir.join("keys").join("ca.key.pem")
    }

    pub fn ca_cert_path(&self) -> PathBuf {
        self.dir.join("certs").join("ca.cert.pem")
    }

    /// A certificate authority root we trust but do not hold the key for —
    /// what a till stores after being enrolled by its shop server.
    pub fn trusted_root_path(&self) -> PathBuf {
        self.dir.join("certs").join("trusted-root.cert.pem")
    }

    pub fn key_path(&self, profile: CertProfile) -> PathBuf {
        self.dir
            .join("keys")
            .join(format!("{}.key.pem", profile.wire_name()))
    }

    pub fn cert_path(&self, profile: CertProfile) -> PathBuf {
        self.dir
            .join("certs")
            .join(format!("{}.cert.pem", profile.wire_name()))
    }

    pub fn invites_path(&self) -> PathBuf {
        self.dir.join("invites.json")
    }

    pub fn revocations_path(&self) -> PathBuf {
        self.dir.join("revocations.json")
    }

    pub fn read_text(&self, path: &Path) -> PkiResult<Option<String>> {
        match fs::read_to_string(path) {
            Ok(text) => Ok(Some(text)),
            Err(e) if e.kind() == std::io::ErrorKind::NotFound => Ok(None),
            Err(e) => Err(PkiError::keystore(format!("cannot read {path:?}: {e}"))),
        }
    }

    pub fn write_text(&self, path: &Path, contents: &str) -> PkiResult<()> {
        fs::write(path, contents)
            .map_err(|e| PkiError::keystore(format!("cannot write {path:?}: {e}")))
    }

    /// Reads a private key. The result wipes itself when dropped; callers must
    /// not clone it into a plain `String`.
    pub fn read_secret(&self, path: &Path) -> PkiResult<Option<Zeroizing<String>>> {
        Ok(self.read_text(path)?.map(Zeroizing::new))
    }

    /// Writes a private key with owner-only permissions.
    ///
    /// On Unix the mode is set to 0600 at creation, so the key is never
    /// briefly world-readable. On Windows the file inherits the ACL of the
    /// store directory: the deployment is expected to place the store under
    /// the application's own profile, and a DPAPI- or CNG-held key is the
    /// wiring this crate leaves to the platform layer rather than pretends to
    /// have. That gap is stated in the package documentation, not hidden.
    pub fn write_secret(&self, path: &Path, contents: &str) -> PkiResult<()> {
        let mut options = fs::OpenOptions::new();
        options.write(true).create(true).truncate(true);
        #[cfg(unix)]
        {
            use std::os::unix::fs::OpenOptionsExt as _;
            options.mode(0o600);
        }
        let mut file = options
            .open(path)
            .map_err(|e| PkiError::keystore(format!("cannot create {path:?}: {e}")))?;
        file.write_all(contents.as_bytes())
            .and_then(|_| file.sync_all())
            .map_err(|e| PkiError::keystore(format!("cannot write {path:?}: {e}")))
    }

    /// Removes a private key from disk. Used by revocation and reissue: the
    /// old key stops existing at that moment, not at the next collection of
    /// anything.
    pub fn remove_secret(&self, path: &Path) -> PkiResult<()> {
        match fs::remove_file(path) {
            Ok(()) => Ok(()),
            Err(e) if e.kind() == std::io::ErrorKind::NotFound => Ok(()),
            Err(e) => Err(PkiError::keystore(format!("cannot remove {path:?}: {e}"))),
        }
    }

    pub fn load_invites(&self) -> PkiResult<Invites> {
        match self.read_text(&self.invites_path())? {
            None => Ok(Invites::default()),
            Some(text) => serde_json::from_str(&text)
                .map_err(|e| PkiError::keystore(format!("invites.json is unreadable: {e}"))),
        }
    }

    pub fn save_invites(&self, invites: &Invites) -> PkiResult<()> {
        let text = serde_json::to_string_pretty(invites)
            .map_err(|e| PkiError::native(format!("cannot encode invites: {e}")))?;
        self.write_text(&self.invites_path(), &text)
    }

    pub fn load_revocations(&self) -> PkiResult<Revocations> {
        match self.read_text(&self.revocations_path())? {
            None => Ok(Revocations::default()),
            Some(text) => serde_json::from_str(&text)
                .map_err(|e| PkiError::keystore(format!("revocations.json is unreadable: {e}"))),
        }
    }

    pub fn save_revocations(&self, revocations: &Revocations) -> PkiResult<()> {
        let text = serde_json::to_string_pretty(revocations)
            .map_err(|e| PkiError::native(format!("cannot encode revocations: {e}")))?;
        self.write_text(&self.revocations_path(), &text)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn a_missing_file_is_absence_not_failure() {
        let dir = tempfile::tempdir().unwrap();
        let store = Store::open(dir.path()).unwrap();
        assert!(store.read_text(&store.ca_cert_path()).unwrap().is_none());
        assert!(store.load_invites().unwrap().entries.is_empty());
    }

    #[cfg(unix)]
    #[test]
    fn a_key_file_is_owner_only() {
        use std::os::unix::fs::PermissionsExt as _;
        let dir = tempfile::tempdir().unwrap();
        let store = Store::open(dir.path()).unwrap();
        let path = store.key_path(CertProfile::Machine);
        store.write_secret(&path, "not really a key").unwrap();
        let mode = fs::metadata(&path).unwrap().permissions().mode() & 0o777;
        assert_eq!(mode, 0o600);
    }
}

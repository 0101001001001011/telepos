//! `rk_pki` — machine identity, mutual TLS and a per-installation
//! certificate authority.
//!
//! The job this crate exists for is one Dart cannot do: build an X.509
//! certificate and sign it with an authority's key, and hold a private key
//! somewhere a garbage collector cannot copy it. What it replaces —
//! `rsa_util.dart` — wrote ASN.1/DER by hand, generated a key pair and threw
//! the private half away, and used the public half as a slow unsalted hash.
//! Nothing here hand-writes DER; encoding belongs to `rcgen` and
//! `rustls-webpki`, and this crate is the policy above them.
//!
//! # What it is built on
//!
//! `rustls-webpki` over `aws-lc-rs` for verification, `rcgen` for issuance,
//! `argon2` for the secret hashing `rsa_util.dart` was standing in for. Not
//! `ring` — unmaintained, RUSTSEC-2025-0007. Not an `openssl` binding — a C
//! build dependency on six platforms buys nothing here. The certificate type
//! is `rustls_pki_types::CertificateDer`, which is the type `rk_quic`'s TLS
//! stack passes around, so a certificate has one representation and not two.
//!
//! # Shape of the interface
//!
//! Everything goes through [`ffi::rk_pki_call`] with an operation **name** and
//! a JSON request, and comes back as a JSON envelope. Enumerations —
//! profiles, machine kinds, error kinds, operations — are names on the wire,
//! never indices (И147), because an index changes meaning the moment a case
//! is inserted, and here that decides whether a machine is trusted.
//!
//! # Offline
//!
//! An expired certificate degrades exactly like an absent network and never
//! harder. `certificate.status` answers without failing, and says in as many
//! words that selling does not stop, that only new sessions needing that
//! certificate are blocked, and that an open session is not torn down by
//! wall-clock expiry. Revocation is the one thing that does tear a session
//! down, and it is a decision rather than a lapse.

pub mod ca;
pub mod engine;
pub mod error;
pub mod ffi;
pub mod identity;
pub mod model;
pub mod pem;
pub mod profile;
pub mod secret;
pub mod store;
pub mod verify;

pub use engine::{call_stateless, envelope, Engine, EngineConfig};
pub use error::{PkiError, PkiResult};
pub use ffi::RK_PKI_ABI_VERSION;
pub use model::{CertificateInfo, MachineKind, MachineSubject};
pub use profile::CertProfile;

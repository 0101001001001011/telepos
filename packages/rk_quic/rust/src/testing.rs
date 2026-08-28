//! Test helpers, shared by the unit tests and by `tests/session_lifecycle.rs`
//! (which pulls this file in with `#[path]` rather than keeping a second copy).
//!
//! **The shipped library cannot mint a certificate, and that is deliberate**
//! — issuing is rk_pki's job, and two packages that can both mint one is how
//! an install ends up with two authorities nobody chose between. `rcgen` is a
//! dev-dependency for exactly this reason: a test needs a certificate nothing
//! else has to trust, and only a test.

/// A fresh self-signed certificate and its PKCS#8 key, both PEM.
///
/// Shaped to the W3C WebTransport rules for a certificate a browser will
/// accept **by hash** rather than by trust store, because that is what a till
/// with a locally-issued certificate actually relies on:
///
/// - ECDSA over secp256r1 — rcgen's default, and the only algorithm the rule
///   allows;
/// - a validity window inside the permitted **two weeks**. rcgen's own default
///   is far longer, and a certificate that breaks this rule is rejected as
///   `UnknownIssuer` — a message that sends you looking for the wrong problem
///   entirely.
///
/// PEM and not DER because that is the form the FFI boundary accepts, so a
/// test exercises the same parsing path a caller would.
pub fn self_signed_pem() -> (String, String) {
    let key = rcgen::KeyPair::generate().expect("generate key");
    let mut params =
        rcgen::CertificateParams::new(vec!["localhost".to_string(), "127.0.0.1".to_string()])
            .expect("certificate parameters");
    params.distinguished_name = rcgen::DistinguishedName::new();

    // A day back so a clock skew of minutes cannot make it "not valid yet",
    // and well inside the fourteen-day ceiling.
    let now = std::time::SystemTime::now();
    params.not_before = (now - std::time::Duration::from_secs(24 * 60 * 60)).into();
    params.not_after = (now + std::time::Duration::from_secs(10 * 24 * 60 * 60)).into();

    let certificate = params.self_signed(&key).expect("self-sign");
    (certificate.pem(), key.serialize_pem())
}

//! What the caller has to say to start an endpoint, and the one representation
//! a certificate has.
//!
//! **A certificate is `rustls_pki_types::CertificateDer` — the same type
//! rk_pki uses.** PEM is only how it travels across the FFI boundary, because
//! a NUL-terminated string is the one thing both sides already agree on.
//! Nothing here invents a second certificate type, and nothing here *mints*
//! one: issuing is rk_pki's job, and two packages that can both mint a
//! certificate is how an install ends up with two authorities nobody chose
//! between.

use std::net::SocketAddr;

use rustls_pki_types::{CertificateDer, PrivateKeyDer};
use serde::Deserialize;

use crate::status::Status;

/// The JSON a caller passes to `rk_quic_server_start`.
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields, rename_all = "camelCase")]
pub struct ServerConfig {
    /// Address to bind, `"127.0.0.1:4433"`. Port 0 asks the operating system
    /// to choose; `rk_quic_server_local_port` then reports what it chose.
    pub bind_address: String,

    /// The certificate chain, PEM, leaf first.
    pub certificate_chain_pem: String,

    /// The private key for the leaf, PEM.
    pub private_key_pem: String,

    /// The URL path a WebTransport client connects to, e.g. `"/rk"`. A client
    /// asking for any other path is refused, so a stray connection cannot be
    /// mistaken for a session.
    #[serde(default = "default_path")]
    pub path: String,

    /// How long a silent session may stay open, in **milliseconds**.
    ///
    /// This has to be a number and cannot be left to a default, because
    /// without it a peer that vanishes is never noticed at all: a browser tab
    /// closed by the operating system, a laptop lid shut, a Wi-Fi that went —
    /// none of these send anything, and the server would hold the session and
    /// go on believing someone is there. Measured: with no idle timeout the
    /// server saw no `sessionClosed` twenty seconds after the client was gone.
    ///
    /// The endpoint sends a keep-alive at a third of this, so an idle but live
    /// session is not mistaken for a dead one.
    #[serde(default = "default_idle_timeout_ms")]
    pub idle_timeout_ms: u64,
}

fn default_path() -> String {
    "/rk".to_string()
}

/// Thirty seconds: long enough that a phone changing network or a laptop
/// waking keeps its session, short enough that a queue does not back up for
/// minutes behind a peer nobody is on the other end of.
fn default_idle_timeout_ms() -> u64 {
    30_000
}

/// A parsed, validated configuration.
#[derive(Debug)]
pub struct ParsedConfig {
    pub bind: SocketAddr,
    pub chain: Vec<CertificateDer<'static>>,
    pub key: PrivateKeyDer<'static>,
    pub path: String,
    pub idle_timeout: std::time::Duration,
}

impl ServerConfig {
    /// Turns the wire form into something that can be bound, or says which
    /// part was wrong.
    ///
    /// Returns a status **and** a message: the status is what code branches
    /// on, the message is what a human reads. Neither is asked to do the
    /// other's job.
    pub fn parse(&self) -> Result<ParsedConfig, (Status, String)> {
        let bind: SocketAddr = self.bind_address.parse().map_err(|_| {
            (
                Status::InvalidArgument,
                format!(
                    "bindAddress \"{}\" is not host:port — note that a bare host \
                     is not enough, the port has to be there even if it is 0",
                    self.bind_address
                ),
            )
        })?;

        // The cheap scalar checks come before the PEM, and the order is not
        // cosmetic: a caller with both a typo in `path` and a certificate that
        // needs reissuing should be told about the typo, which is the one they
        // can fix in a second. Reported the other way round, the message sends
        // them to a certificate authority for a missing slash.
        if !self.path.starts_with('/') {
            return Err((
                Status::InvalidArgument,
                format!("path \"{}\" must start with /", self.path),
            ));
        }

        // Zero would mean "never time out", which is the state that made a
        // vanished peer invisible. Refused by name rather than quietly
        // substituted, because a caller who wrote 0 meant something.
        if self.idle_timeout_ms < 1_000 {
            return Err((
                Status::InvalidArgument,
                format!(
                    "idleTimeoutMs is {}, and under a second a live session would \
                     be dropped as dead; there is no value meaning 'never', \
                     because a peer that vanishes silently would then never be \
                     noticed",
                    self.idle_timeout_ms
                ),
            ));
        }

        let chain: Vec<CertificateDer<'static>> =
            rustls_pemfile::certs(&mut self.certificate_chain_pem.as_bytes())
                .collect::<Result<Vec<_>, _>>()
                .map_err(|e| {
                    (
                        Status::BadCertificate,
                        format!("certificateChainPem is not readable PEM: {e}"),
                    )
                })?;
        if chain.is_empty() {
            return Err((
                Status::BadCertificate,
                "certificateChainPem contains no CERTIFICATE block".to_string(),
            ));
        }

        let key = rustls_pemfile::private_key(&mut self.private_key_pem.as_bytes())
            .map_err(|e| {
                (
                    Status::BadCertificate,
                    format!("privateKeyPem is not readable PEM: {e}"),
                )
            })?
            .ok_or_else(|| {
                (
                    Status::BadCertificate,
                    "privateKeyPem contains no PRIVATE KEY block".to_string(),
                )
            })?;

        Ok(ParsedConfig {
            bind,
            chain,
            key,
            path: self.path.clone(),
            idle_timeout: std::time::Duration::from_millis(self.idle_timeout_ms),
        })
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn valid_json(bind: &str) -> String {
        let (chain, key) = crate::testing::self_signed_pem();
        serde_json::json!({
            "bindAddress": bind,
            "certificateChainPem": chain,
            "privateKeyPem": key,
        })
        .to_string()
    }

    #[test]
    fn a_valid_config_parses_and_keeps_the_chain() {
        let cfg: ServerConfig = serde_json::from_str(&valid_json("127.0.0.1:0")).unwrap();
        let parsed = cfg.parse().unwrap();
        assert_eq!(parsed.bind.port(), 0);
        assert_eq!(parsed.chain.len(), 1);
        assert_eq!(parsed.path, "/rk");
    }

    #[test]
    fn a_host_without_a_port_is_rejected_by_name() {
        let cfg: ServerConfig = serde_json::from_str(&valid_json("127.0.0.1")).unwrap();
        let (status, message) = cfg.parse().unwrap_err();
        assert_eq!(status, Status::InvalidArgument);
        assert!(message.contains("port"), "unhelpful message: {message}");
    }

    #[test]
    fn pem_with_no_certificate_block_is_bad_certificate_not_invalid_argument() {
        let cfg = ServerConfig {
            bind_address: "127.0.0.1:0".into(),
            certificate_chain_pem: "not a certificate".into(),
            private_key_pem: crate::testing::self_signed_pem().1,
            path: "/rk".into(),
            idle_timeout_ms: 30_000,
        };
        assert_eq!(cfg.parse().unwrap_err().0, Status::BadCertificate);
    }

    #[test]
    fn pem_with_no_key_block_is_bad_certificate() {
        let cfg = ServerConfig {
            bind_address: "127.0.0.1:0".into(),
            certificate_chain_pem: crate::testing::self_signed_pem().0,
            private_key_pem: "-----BEGIN NOTHING-----\n-----END NOTHING-----\n".into(),
            path: "/rk".into(),
            idle_timeout_ms: 30_000,
        };
        assert_eq!(cfg.parse().unwrap_err().0, Status::BadCertificate);
    }

    #[test]
    fn a_path_without_a_leading_slash_is_rejected() {
        let cfg = ServerConfig {
            bind_address: "127.0.0.1:0".into(),
            certificate_chain_pem: crate::testing::self_signed_pem().0,
            private_key_pem: crate::testing::self_signed_pem().1,
            path: "rk".into(),
            idle_timeout_ms: 30_000,
        };
        assert_eq!(cfg.parse().unwrap_err().0, Status::InvalidArgument);
    }

    #[test]
    fn an_unknown_field_is_refused_rather_than_ignored() {
        // A typo in a key must not be silently dropped: the caller would then
        // believe a setting took effect that never did.
        let json = r#"{"bindAddress":"127.0.0.1:0","certificateChainPem":"x",
                       "privateKeyPem":"y","paths":"/rk"}"#;
        assert!(serde_json::from_str::<ServerConfig>(json).is_err());
    }
}

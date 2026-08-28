//! RFC 5425: syslog over TLS, with octet-counting framing.
//!
//! # Framing
//!
//! ```text
//! SYSLOG-FRAME = MSG-LEN SP SYSLOG-MSG
//! MSG-LEN      = NONZERO-DIGIT *DIGIT      ; octets of SYSLOG-MSG
//! ```
//!
//! Not a trailing newline. RFC 5425 §4.3 says so, and the reason is the
//! reason it matters here: a message may legitimately contain a newline —
//! a stack trace, a device response — and with newline framing the receiver
//! reads the second half as a new record with a forged priority. Counting
//! octets removes the ambiguity rather than asking everyone upstream to
//! escape.
//!
//! # Who is trusted
//!
//! Nobody, by default. There is no built-in root store: the collector is
//! normally an internal host with a private certificate authority, and a
//! sink that silently trusted a public root would be trusting the wrong set
//! of issuers for the deployment it is in. The operator supplies either a
//! roots bundle or a pinned certificate fingerprint, and without one of the
//! two the sink refuses to open.

use std::io::Write;
use std::net::{TcpStream, ToSocketAddrs};
use std::sync::Arc;
use std::time::Duration;

use rustls::client::danger::{HandshakeSignatureValid, ServerCertVerified, ServerCertVerifier};
use rustls::pki_types::{CertificateDer, PrivateKeyDer, ServerName, UnixTime};
use rustls::{ClientConfig, ClientConnection, DigitallySignedStruct, RootCertStore, StreamOwned};
use sha2::{Digest, Sha256};

use crate::status::{Failure, Fallible, Status};

/// How the sink reaches a collector.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Scheme {
    /// No collector. Records are framed and spooled and nothing is sent.
    /// The default, because a new installation opens nothing outward until
    /// somebody says so.
    None,
    /// RFC 5425 — syslog over TLS.
    Tls,
    /// Plain TCP with the same octet-counting framing. **Not RFC 5425**: it
    /// authenticates nobody and encrypts nothing. Present because a
    /// loopback collector on the same machine is a real deployment, and
    /// because the framing has to be testable without a certificate. Anything
    /// leaving the machine wants `tls`.
    Tcp,
}

impl Scheme {
    pub const fn name(self) -> &'static str {
        match self {
            Scheme::None => "none",
            Scheme::Tls => "tls",
            Scheme::Tcp => "tcp",
        }
    }

    pub fn from_name(name: &str) -> Option<Scheme> {
        match name {
            "none" => Some(Scheme::None),
            "tls" => Some(Scheme::Tls),
            "tcp" => Some(Scheme::Tcp),
            _ => None,
        }
    }
}

/// Everything needed to reach a collector.
#[derive(Debug, Clone)]
pub struct CollectorSettings {
    pub scheme: Scheme,
    pub host: String,
    pub port: u16,
    /// Name checked against the certificate, and sent as SNI. Defaults to
    /// `host`.
    pub server_name: Option<String>,
    pub roots_pem: Option<String>,
    /// Lowercase hex SHA-256 of the server's end-entity certificate, in DER.
    pub fingerprint_sha256: Option<String>,
    pub client_cert_pem: Option<String>,
    pub client_key_pem: Option<String>,
    pub connect_timeout: Duration,
    pub write_timeout: Duration,
}

/// Writes one octet-counted frame in front of a record.
///
/// Separate from the sending so it can be tested for what it is: a length,
/// a space, and the bytes, with no allocation surprises.
pub fn octet_count_frame(record: &[u8], out: &mut Vec<u8>) {
    out.clear();
    out.extend_from_slice(record.len().to_string().as_bytes());
    out.push(b' ');
    out.extend_from_slice(record);
}

#[derive(Debug)]
enum Stream {
    Plain(TcpStream),
    Tls(Box<StreamOwned<ClientConnection, TcpStream>>),
}

impl Stream {
    fn write_all(&mut self, bytes: &[u8]) -> std::io::Result<()> {
        match self {
            Stream::Plain(s) => s.write_all(bytes),
            Stream::Tls(s) => s.write_all(bytes),
        }
    }

    fn flush(&mut self) -> std::io::Result<()> {
        match self {
            Stream::Plain(s) => s.flush(),
            Stream::Tls(s) => s.flush(),
        }
    }
}

/// A connection to a collector, opened lazily and reopened after a failure.
#[derive(Debug)]
pub struct Transport {
    settings: CollectorSettings,
    tls: Option<Arc<ClientConfig>>,
    stream: Option<Stream>,
    scratch: Vec<u8>,
}

impl Transport {
    /// Builds the transport, validating the TLS settings now rather than at
    /// the first send. A mistyped certificate path should fail when the sink
    /// opens, not silently become an unreachable collector.
    pub fn new(settings: CollectorSettings) -> Fallible<Transport> {
        let tls = match settings.scheme {
            Scheme::Tls => Some(Arc::new(build_client_config(&settings)?)),
            _ => None,
        };
        if settings.scheme != Scheme::None && settings.host.is_empty() {
            return Err(Failure::new(
                Status::InvalidConfigValue,
                "collector_scheme is set but collector_host is empty".to_string(),
            ));
        }
        Ok(Transport {
            settings,
            tls,
            stream: None,
            scratch: Vec::with_capacity(2048),
        })
    }

    pub fn is_enabled(&self) -> bool {
        self.settings.scheme != Scheme::None
    }

    /// Sends one record. Opens the connection if it is not open.
    pub fn send(&mut self, record: &[u8]) -> Fallible<()> {
        if !self.is_enabled() {
            return Err(Failure::new(
                Status::TransportIo,
                "no collector is configured".to_string(),
            ));
        }
        if self.stream.is_none() {
            self.stream = Some(self.connect()?);
        }
        octet_count_frame(record, &mut self.scratch);
        let stream = self.stream.as_mut().expect("just connected");
        let sent = stream
            .write_all(&self.scratch)
            .and_then(|()| stream.flush());
        if let Err(err) = sent {
            self.stream = None;
            return Err(Failure::new(
                Status::TransportIo,
                format!(
                    "writing to {}:{}: {err}",
                    self.settings.host, self.settings.port
                ),
            ));
        }
        Ok(())
    }

    pub fn disconnect(&mut self) {
        self.stream = None;
    }

    fn connect(&self) -> Fallible<Stream> {
        let address = format!("{}:{}", self.settings.host, self.settings.port);
        let mut last: Option<std::io::Error> = None;
        let resolved = address
            .to_socket_addrs()
            .map_err(|e| Failure::new(Status::TransportIo, format!("resolving {address}: {e}")))?;

        let mut tcp = None;
        for candidate in resolved {
            match TcpStream::connect_timeout(&candidate, self.settings.connect_timeout) {
                Ok(stream) => {
                    tcp = Some(stream);
                    break;
                }
                Err(err) => last = Some(err),
            }
        }
        let Some(tcp) = tcp else {
            return Err(Failure::new(
                Status::TransportIo,
                match last {
                    Some(err) => format!("connecting to {address}: {err}"),
                    None => format!("{address} resolved to no usable address"),
                },
            ));
        };
        let _ = tcp.set_nodelay(true);
        tcp.set_write_timeout(Some(self.settings.write_timeout))
            .map_err(|e| {
                Failure::new(Status::TransportIo, format!("setting a write timeout: {e}"))
            })?;

        match self.settings.scheme {
            Scheme::Tcp => Ok(Stream::Plain(tcp)),
            Scheme::Tls => {
                let config = self
                    .tls
                    .as_ref()
                    .expect("tls scheme built a config")
                    .clone();
                let name = self
                    .settings
                    .server_name
                    .clone()
                    .unwrap_or_else(|| self.settings.host.clone());
                let server_name = ServerName::try_from(name.clone()).map_err(|e| {
                    Failure::new(
                        Status::TlsConfig,
                        format!("'{name}' is not a usable server name: {e}"),
                    )
                })?;
                let connection = ClientConnection::new(config, server_name).map_err(|e| {
                    Failure::new(Status::TlsConfig, format!("starting the TLS session: {e}"))
                })?;
                Ok(Stream::Tls(Box::new(StreamOwned::new(connection, tcp))))
            }
            Scheme::None => unreachable!("send() refuses before reaching here"),
        }
    }
}

fn read_pem_certs(path: &str) -> Fallible<Vec<CertificateDer<'static>>> {
    let bytes = std::fs::read(path).map_err(|e| {
        Failure::new(
            Status::TlsConfig,
            format!("reading certificates from {path}: {e}"),
        )
    })?;
    let mut reader = std::io::BufReader::new(bytes.as_slice());
    rustls_pemfile::certs(&mut reader)
        .collect::<Result<Vec<_>, _>>()
        .map_err(|e| Failure::new(Status::TlsConfig, format!("parsing {path}: {e}")))
}

fn build_client_config(settings: &CollectorSettings) -> Fallible<ClientConfig> {
    let provider = Arc::new(rustls::crypto::ring::default_provider());
    let builder = ClientConfig::builder_with_provider(provider.clone())
        .with_safe_default_protocol_versions()
        .map_err(|e| Failure::new(Status::TlsConfig, format!("selecting TLS versions: {e}")))?;

    let verified = match (&settings.roots_pem, &settings.fingerprint_sha256) {
        (None, None) => {
            return Err(Failure::new(
                Status::TlsConfig,
                "collector_scheme is 'tls' but neither tls_roots_pem nor \
                 tls_server_fingerprint_sha256 is set; this library ships no default \
                 trust store, so it would have nothing to check the collector against"
                    .to_string(),
            ));
        }
        (Some(path), None) => {
            let mut store = RootCertStore::empty();
            let certs = read_pem_certs(path)?;
            if certs.is_empty() {
                return Err(Failure::new(
                    Status::TlsConfig,
                    format!("{path} contains no certificates"),
                ));
            }
            for cert in certs {
                store.add(cert).map_err(|e| {
                    Failure::new(Status::TlsConfig, format!("adding a root from {path}: {e}"))
                })?;
            }
            builder.with_root_certificates(store)
        }
        (_, Some(hex)) => {
            // Pinning wins when both are given: it is the narrower statement.
            let expected = decode_hex_sha256(hex)?;
            builder
                .dangerous()
                .with_custom_certificate_verifier(Arc::new(PinnedVerifier { expected, provider }))
        }
    };

    let config = match (&settings.client_cert_pem, &settings.client_key_pem) {
        (Some(cert_path), Some(key_path)) => {
            let certs = read_pem_certs(cert_path)?;
            let key = read_pem_key(key_path)?;
            verified.with_client_auth_cert(certs, key).map_err(|e| {
                Failure::new(
                    Status::TlsConfig,
                    format!("using the client certificate: {e}"),
                )
            })?
        }
        (None, None) => verified.with_no_client_auth(),
        _ => {
            return Err(Failure::new(
                Status::InvalidConfigValue,
                "tls_client_cert_pem and tls_client_key_pem must be set together".to_string(),
            ));
        }
    };
    Ok(config)
}

fn read_pem_key(path: &str) -> Fallible<PrivateKeyDer<'static>> {
    let bytes = std::fs::read(path).map_err(|e| {
        Failure::new(
            Status::TlsConfig,
            format!("reading the key from {path}: {e}"),
        )
    })?;
    let mut reader = std::io::BufReader::new(bytes.as_slice());
    rustls_pemfile::private_key(&mut reader)
        .map_err(|e| Failure::new(Status::TlsConfig, format!("parsing the key in {path}: {e}")))?
        .ok_or_else(|| Failure::new(Status::TlsConfig, format!("{path} holds no private key")))
}

fn decode_hex_sha256(hex: &str) -> Fallible<[u8; 32]> {
    // Colons are how every tool prints a fingerprint, so accept them.
    let cleaned: String = hex
        .chars()
        .filter(|c| *c != ':' && !c.is_whitespace())
        .collect();
    if cleaned.len() != 64 {
        return Err(Failure::new(
            Status::InvalidConfigValue,
            format!(
                "tls_server_fingerprint_sha256 has {} hex digits, a SHA-256 has 64",
                cleaned.len()
            ),
        ));
    }
    let mut out = [0u8; 32];
    for (i, chunk) in cleaned.as_bytes().chunks(2).enumerate() {
        let text = std::str::from_utf8(chunk).map_err(|_| {
            Failure::new(
                Status::InvalidConfigValue,
                "tls_server_fingerprint_sha256 is not hexadecimal".to_string(),
            )
        })?;
        out[i] = u8::from_str_radix(text, 16).map_err(|_| {
            Failure::new(
                Status::InvalidConfigValue,
                format!("'{text}' in tls_server_fingerprint_sha256 is not hexadecimal"),
            )
        })?;
    }
    Ok(out)
}

/// Accepts exactly one certificate, by its SHA-256.
///
/// RFC 5425 §4.2.1 offers fingerprint-based authentication precisely for
/// deployments with no usable certificate authority, which is most shops.
#[derive(Debug)]
struct PinnedVerifier {
    expected: [u8; 32],
    provider: Arc<rustls::crypto::CryptoProvider>,
}

impl ServerCertVerifier for PinnedVerifier {
    fn verify_server_cert(
        &self,
        end_entity: &CertificateDer<'_>,
        _intermediates: &[CertificateDer<'_>],
        _server_name: &ServerName<'_>,
        _ocsp_response: &[u8],
        _now: UnixTime,
    ) -> Result<ServerCertVerified, rustls::Error> {
        let actual: [u8; 32] = Sha256::digest(end_entity.as_ref()).into();
        // Compared byte by byte without an early return, so the time this
        // takes says nothing about how much of the fingerprint matched.
        let mut diff = 0u8;
        for (mine, theirs) in actual.iter().zip(self.expected.iter()) {
            diff |= mine ^ theirs;
        }
        if diff == 0 {
            Ok(ServerCertVerified::assertion())
        } else {
            Err(rustls::Error::General(
                "the collector's certificate does not match the pinned SHA-256".to_string(),
            ))
        }
    }

    fn verify_tls12_signature(
        &self,
        message: &[u8],
        cert: &CertificateDer<'_>,
        dss: &DigitallySignedStruct,
    ) -> Result<HandshakeSignatureValid, rustls::Error> {
        rustls::crypto::verify_tls12_signature(
            message,
            cert,
            dss,
            &self.provider.signature_verification_algorithms,
        )
    }

    fn verify_tls13_signature(
        &self,
        message: &[u8],
        cert: &CertificateDer<'_>,
        dss: &DigitallySignedStruct,
    ) -> Result<HandshakeSignatureValid, rustls::Error> {
        rustls::crypto::verify_tls13_signature(
            message,
            cert,
            dss,
            &self.provider.signature_verification_algorithms,
        )
    }

    fn supported_verify_schemes(&self) -> Vec<rustls::SignatureScheme> {
        self.provider
            .signature_verification_algorithms
            .supported_schemes()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn settings(scheme: Scheme) -> CollectorSettings {
        CollectorSettings {
            scheme,
            host: "collector.example".into(),
            port: 6514,
            server_name: None,
            roots_pem: None,
            fingerprint_sha256: None,
            client_cert_pem: None,
            client_key_pem: None,
            connect_timeout: Duration::from_millis(200),
            write_timeout: Duration::from_millis(200),
        }
    }

    #[test]
    fn counts_octets_rather_than_ending_with_a_newline() {
        let mut out = Vec::new();
        octet_count_frame(b"<134>1 - - - - - - hello", &mut out);
        assert_eq!(out, b"24 <134>1 - - - - - - hello");
        assert!(!out.ends_with(b"\n"));
    }

    #[test]
    fn the_count_is_octets_not_characters() {
        // Two characters, six octets. A count in characters would make the
        // receiver read six bytes of the next record as part of this one.
        let record = "₸₸".as_bytes();
        let mut out = Vec::new();
        octet_count_frame(record, &mut out);
        assert_eq!(&out[..2], b"6 ");
        assert_eq!(out.len(), 2 + 6);
    }

    #[test]
    fn a_message_containing_a_newline_stays_one_frame() {
        let mut out = Vec::new();
        octet_count_frame(b"a\nb", &mut out);
        assert_eq!(out, b"3 a\nb");
    }

    #[test]
    fn tls_without_anything_to_trust_is_refused_at_open() {
        let failure = Transport::new(settings(Scheme::Tls)).unwrap_err();
        assert_eq!(failure.status, Status::TlsConfig);
        assert!(failure.detail.contains("no default trust store"));
    }

    #[test]
    fn a_pinned_fingerprint_is_accepted_in_either_spelling() {
        let plain = "a".repeat(64);
        let mut colonised = settings(Scheme::Tls);
        colonised.fingerprint_sha256 = Some(
            plain
                .as_bytes()
                .chunks(2)
                .map(|c| std::str::from_utf8(c).unwrap())
                .collect::<Vec<_>>()
                .join(":"),
        );
        Transport::new(colonised).expect("a colon-separated fingerprint is the usual spelling");
    }

    #[test]
    fn a_fingerprint_of_the_wrong_length_is_refused() {
        let mut bad = settings(Scheme::Tls);
        bad.fingerprint_sha256 = Some("abcd".into());
        let failure = Transport::new(bad).unwrap_err();
        assert_eq!(failure.status, Status::InvalidConfigValue);
        assert!(failure.detail.contains("64"));
    }

    #[test]
    fn a_client_certificate_without_its_key_is_refused() {
        let mut bad = settings(Scheme::Tls);
        bad.fingerprint_sha256 = Some("b".repeat(64));
        bad.client_cert_pem = Some("client.pem".into());
        let failure = Transport::new(bad).unwrap_err();
        assert_eq!(failure.status, Status::InvalidConfigValue);
        assert!(failure.detail.contains("together"));
    }

    #[test]
    fn no_collector_means_nothing_is_sent() {
        let mut transport = Transport::new(settings(Scheme::None)).unwrap();
        assert!(!transport.is_enabled());
        let failure = transport.send(b"anything").unwrap_err();
        assert_eq!(failure.status, Status::TransportIo);
    }
}

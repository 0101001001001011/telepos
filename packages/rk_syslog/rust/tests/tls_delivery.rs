//! RFC 5425 delivery, against a real TLS collector.
//!
//! A test server with a certificate generated on the spot. Without this, the
//! TLS path would be a claim rather than a fact — the transport would only
//! ever have been exercised in plaintext, and the first time anyone found out
//! whether the handshake, the pinning and the framing worked together would
//! be at a customer's site.

use std::io::Read;
use std::net::TcpListener;
use std::path::{Path, PathBuf};
use std::sync::mpsc;
use std::sync::Arc;
use std::time::Duration;

use rustls::pki_types::{CertificateDer, PrivateKeyDer};
use rustls::{ServerConfig, ServerConnection, StreamOwned};

use rk_syslog::config::ConfigBuilder;
use rk_syslog::rfc5424::{Record, StructuredData};
use rk_syslog::severity::{Facility, Severity};
use rk_syslog::sink::Sink;

struct TempDir(PathBuf);

impl TempDir {
    fn new(tag: &str) -> TempDir {
        let mut path = std::env::temp_dir();
        let nanos = std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .unwrap()
            .as_nanos();
        path.push(format!("rk_syslog-tls-{tag}-{nanos}"));
        std::fs::create_dir_all(&path).unwrap();
        TempDir(path)
    }
    fn path(&self) -> &Path {
        &self.0
    }
}

impl Drop for TempDir {
    fn drop(&mut self) {
        let _ = std::fs::remove_dir_all(&self.0);
    }
}

struct Collector {
    port: u16,
    /// SHA-256 of the DER certificate, as an operator would read it out of
    /// `openssl x509 -fingerprint -sha256`.
    fingerprint: String,
    /// The certificate on disk, for the roots-bundle path.
    roots_pem: PathBuf,
    records: mpsc::Receiver<String>,
}

/// Starts a TLS syslog collector on loopback that decodes octet-counted
/// frames by the book.
fn start_collector(dir: &Path) -> Collector {
    let mut params = rcgen::CertificateParams::new(vec!["localhost".to_string()]).unwrap();
    params.distinguished_name = rcgen::DistinguishedName::new();
    params
        .distinguished_name
        .push(rcgen::DnType::CommonName, "rk_syslog test collector");
    let key = rcgen::KeyPair::generate().unwrap();
    let certificate = params.self_signed(&key).unwrap();

    let cert_der = CertificateDer::from(certificate.der().to_vec());
    let fingerprint = {
        use sha2::{Digest, Sha256};
        let digest = Sha256::digest(cert_der.as_ref());
        digest
            .iter()
            .map(|b| format!("{b:02x}"))
            .collect::<String>()
    };

    let roots_pem = dir.join("collector.pem");
    std::fs::write(&roots_pem, certificate.pem()).unwrap();

    let key_der = PrivateKeyDer::try_from(key.serialize_der()).unwrap();
    let config =
        ServerConfig::builder_with_provider(Arc::new(rustls::crypto::ring::default_provider()))
            .with_safe_default_protocol_versions()
            .unwrap()
            .with_no_client_auth()
            .with_single_cert(vec![cert_der], key_der)
            .unwrap();

    let listener = TcpListener::bind("127.0.0.1:0").unwrap();
    let port = listener.local_addr().unwrap().port();
    let (sender, records) = mpsc::channel();

    std::thread::spawn(move || {
        let config = Arc::new(config);
        let Ok((tcp, _)) = listener.accept() else {
            return;
        };
        let Ok(connection) = ServerConnection::new(config) else {
            return;
        };
        let mut stream = StreamOwned::new(connection, tcp);

        let mut buffer: Vec<u8> = Vec::new();
        let mut chunk = [0u8; 4096];
        loop {
            let read = match stream.read(&mut chunk) {
                Ok(0) | Err(_) => return,
                Ok(n) => n,
            };
            buffer.extend_from_slice(&chunk[..read]);
            while let Some(space) = buffer.iter().position(|b| *b == b' ') {
                let Ok(length) = std::str::from_utf8(&buffer[..space])
                    .unwrap_or("x")
                    .parse::<usize>()
                else {
                    return;
                };
                if buffer.len() < space + 1 + length {
                    break;
                }
                let record = buffer[space + 1..space + 1 + length].to_vec();
                buffer.drain(..space + 1 + length);
                if sender
                    .send(String::from_utf8_lossy(&record).into_owned())
                    .is_err()
                {
                    return;
                }
            }
        }
    });

    Collector {
        port,
        fingerprint,
        roots_pem,
        records,
    }
}

fn record(message: &str) -> Record {
    Record {
        facility: Facility::Local0,
        severity: Severity::Informational,
        epoch_micros: 1_065_910_455_003_000,
        utc_offset_minutes: 0,
        msgid: Some("TLS".into()),
        structured_data: StructuredData::new(),
        message: Some(message.into()),
    }
}

fn builder(dir: &Path, collector: &Collector) -> ConfigBuilder {
    let mut builder = ConfigBuilder::new();
    builder.set("spool_dir", dir.to_str().unwrap()).unwrap();
    builder.set("host_name", "till-01").unwrap();
    builder.set("app_name", "telepos").unwrap();
    builder.set("proc_id", "7").unwrap();
    builder.set("collector_scheme", "tls").unwrap();
    builder.set("collector_host", "127.0.0.1").unwrap();
    builder.set("tls_server_name", "localhost").unwrap();
    builder
        .set("collector_port", &collector.port.to_string())
        .unwrap();
    builder.set("msg_bom", "false").unwrap();
    builder
}

/// Waits for a counter to reach a value.
///
/// A record arriving at the collector and the counter for it being bumped are
/// two steps in the worker, in that order. Reading the counter the instant the
/// tenth record lands is a race, and asserting on it would make this suite
/// flaky rather than make the library wrong.
fn expect_stat(sink: &Sink, name: &str, least: u64) {
    let deadline = std::time::Instant::now() + Duration::from_secs(10);
    loop {
        let value = sink
            .stat(name)
            .unwrap_or_else(|| panic!("no counter '{name}'"));
        if value >= least {
            return;
        }
        assert!(
            std::time::Instant::now() < deadline,
            "'{name}' reached only {value}, expected at least {least}"
        );
        std::thread::sleep(Duration::from_millis(20));
    }
}

fn expect_records(collector: &Collector, count: usize) -> Vec<String> {
    let mut received = Vec::new();
    while received.len() < count {
        match collector.records.recv_timeout(Duration::from_secs(20)) {
            Ok(record) => received.push(record),
            Err(_) => panic!(
                "only {} of {count} records arrived over TLS",
                received.len()
            ),
        }
    }
    received
}

#[test]
fn delivers_over_tls_to_a_collector_pinned_by_fingerprint() {
    let dir = TempDir::new("pinned");
    let collector = start_collector(dir.path());

    let mut builder = builder(dir.path(), &collector);
    builder
        .set("tls_server_fingerprint_sha256", &collector.fingerprint)
        .unwrap();
    let sink = Sink::open(builder.build().unwrap()).unwrap();

    for i in 0..10 {
        sink.submit(&record(&format!("over tls {i}"))).unwrap();
    }

    let received = expect_records(&collector, 10);
    assert_eq!(
        received[0],
        "<134>1 2003-10-11T22:14:15.003000Z till-01 telepos 7 TLS - over tls 0"
    );
    for (i, record) in received.iter().enumerate() {
        assert!(record.ends_with(&format!("over tls {i}")), "{record}");
    }
    expect_stat(&sink, "sent", 10);
    assert_eq!(sink.stat("connected"), Some(1));
}

#[test]
fn delivers_over_tls_to_a_collector_trusted_through_a_roots_bundle() {
    let dir = TempDir::new("roots");
    let collector = start_collector(dir.path());

    let mut builder = builder(dir.path(), &collector);
    builder
        .set("tls_roots_pem", collector.roots_pem.to_str().unwrap())
        .unwrap();
    let sink = Sink::open(builder.build().unwrap()).unwrap();
    sink.submit(&record("through a bundle")).unwrap();

    let received = expect_records(&collector, 1);
    assert!(received[0].ends_with("through a bundle"));
}

#[test]
fn a_collector_whose_certificate_does_not_match_the_pin_gets_nothing() {
    // The failure that matters: a wrong pin must stop delivery, not be
    // shrugged off. Records stay in the spool, and the sink says it is not
    // connected.
    let dir = TempDir::new("wrongpin");
    let collector = start_collector(dir.path());

    let mut builder = builder(dir.path(), &collector);
    builder.set("retry_min_ms", "50").unwrap();
    builder.set("retry_max_ms", "100").unwrap();
    builder
        .set("tls_server_fingerprint_sha256", &"0".repeat(64))
        .unwrap();
    let sink = Sink::open(builder.build().unwrap()).unwrap();
    sink.submit(&record("must not arrive")).unwrap();

    // Long enough for several retries.
    std::thread::sleep(Duration::from_secs(2));
    assert_eq!(
        collector.records.try_recv().ok(),
        None,
        "a record reached a collector whose certificate did not match the pin"
    );
    assert_eq!(sink.stat("sent"), Some(0));
    assert_eq!(sink.stat("connected"), Some(0));
    assert!(sink.stat("send_failures").unwrap() > 0);
    // And the record is still on disk, waiting.
    assert_eq!(sink.stat("spooled"), Some(1));
}

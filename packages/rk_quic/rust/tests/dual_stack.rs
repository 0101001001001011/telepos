//! An endpoint asked to listen on `::` listens on **both** families.
//!
//! This is not a refinement of "it binds". `wtransport::ServerConfig`'s plain
//! `with_bind_address` leaves `IPV6_V6ONLY` at the operating system's default,
//! and that default is not the same everywhere: measured 2026-08-06 on
//! Windows 11, a UDP socket bound to `::` with the option untouched receives
//! IPv6 datagrams only, while on Linux it receives both. `[::]:4433` would
//! therefore mean every address on one till and half of them on another.
//!
//! The half that would go missing is the half that matters most. Windows
//! resolves `localhost` and a machine name to IPv6 **first** — measured, a
//! `.local` name gives `fe80::…` ahead of `192.168.1.210` — so a browser aimed
//! at an IPv4-only listener sends and hears nothing back, and reports
//! `QUIC_NETWORK_IDLE_TIMEOUT` with `num_undecryptable_packets: 0`. Aimed at
//! an IPv6-only one, an IPv4 address fails the same way in the other
//! direction. Both are silent, and `curl` answers 200 through both, because it
//! picks a family differently than a browser does.
//!
//! So the assertion is made with a real client over a real socket, once per
//! family, on one listener.

use std::time::{Duration, Instant};

use rk_quic::config::ServerConfig;
use rk_quic::event::Event;
use rk_quic::transport;
use wtransport::tls::{Certificate, Sha256Digest};
use wtransport::{ClientConfig, Endpoint};

#[path = "../src/testing.rs"]
mod testing;

use testing::self_signed_pem as self_signed;

fn digest_of(pem: &str) -> Sha256Digest {
    let der = rustls_pemfile::certs(&mut pem.as_bytes())
        .next()
        .expect("a certificate")
        .expect("readable");
    Certificate::from_der(der.to_vec()).expect("usable").hash()
}

fn wait_for_session(endpoint: &transport::Endpoint, within: Duration) -> bool {
    let deadline = Instant::now() + within;
    while Instant::now() < deadline {
        if let Some(event) = endpoint.next_event(Duration::from_millis(100)) {
            if matches!(event, Event::SessionOpened { .. }) {
                return true;
            }
        }
    }
    false
}

#[test]
fn a_listener_on_the_ipv6_wildcard_answers_on_both_families() {
    let (chain_pem, key_pem) = self_signed();
    let digest = digest_of(&chain_pem);

    let config = ServerConfig {
        bind_address: "[::]:0".into(),
        certificate_chain_pem: chain_pem,
        private_key_pem: key_pem,
        path: "/rk".into(),
        idle_timeout_ms: 5_000,
    }
    .parse()
    .expect("configuration");

    let handle = transport::start(config).expect("endpoint starts");
    let server = transport::lookup(handle).expect("handle resolves");
    let port = server.local_port();

    let runtime = tokio::runtime::Runtime::new().expect("client runtime");

    // Both spellings of the same machine, in the order a browser would find
    // them on Windows: the IPv6 loopback first, then the IPv4 one. A listener
    // that had kept the operating system's default would open the first
    // session on Windows and never the second.
    for authority in ["[::1]", "127.0.0.1"] {
        let hash = digest.clone();
        let connection = runtime.block_on(async {
            let client = Endpoint::client(
                ClientConfig::builder()
                    .with_bind_default()
                    .with_server_certificate_hashes([hash])
                    .build(),
            )
            .expect("client endpoint");
            client
                .connect(format!("https://{authority}:{port}/rk"))
                .await
        });

        assert!(
            connection.is_ok(),
            "no session over {authority}: {:?} — the listener is bound to one \
             family only, and a browser reaching this till by the other name \
             would sit in silence until it timed out",
            connection.err()
        );

        assert!(
            wait_for_session(&server, Duration::from_secs(10)),
            "the endpoint never reported a session opened over {authority}"
        );

        drop(connection);
    }

    runtime.shutdown_background();
    transport::remove(handle);
}

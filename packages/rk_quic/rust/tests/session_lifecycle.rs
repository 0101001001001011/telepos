//! The one test that proves the point of the package: **the server speaks
//! first**, and it notices when the peer stops listening.
//!
//! Everything else in this crate can be true while the endpoint is useless.
//! Here a real WebTransport client connects over a real UDP socket, the server
//! sends without having been asked, and then the client is dropped mid-session
//! so the server has to report `sessionClosed` rather than wait forever on a
//! connection nobody is on the other end of.
//!
//! The certificate is verified by **hash**, not by a trust store — which is
//! exactly the mechanism a browser uses for a locally-issued certificate
//! (`WebTransport`'s `serverCertificateHashes`). So the trust path under test
//! is the one a till would actually use, not a test-only bypass.

use std::time::{Duration, Instant};

use rk_quic::config::ServerConfig;
use rk_quic::event::Event;
use rk_quic::status::Status;
use rk_quic::transport;
use wtransport::tls::{Certificate, Sha256Digest};
use wtransport::{ClientConfig, Endpoint};

// The same certificate helper the unit tests use, pulled in by path rather
// than copied: two generators would drift, and the W3C rules it satisfies are
// exactly the kind of detail that gets fixed in one copy only.
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

/// Drains events until one satisfies `wanted`, or the deadline passes.
fn wait_for(
    endpoint: &transport::Endpoint,
    within: Duration,
    mut wanted: impl FnMut(&Event) -> bool,
) -> Option<Event> {
    let deadline = Instant::now() + within;
    while Instant::now() < deadline {
        if let Some(event) = endpoint.next_event(Duration::from_millis(100)) {
            if wanted(&event) {
                return Some(event);
            }
        }
    }
    None
}

#[test]
fn a_browser_style_client_opens_a_session_is_spoken_to_first_and_its_departure_is_noticed() {
    let (chain_pem, key_pem) = self_signed();
    let digest = digest_of(&chain_pem);

    let config = ServerConfig {
        bind_address: "127.0.0.1:0".into(),
        certificate_chain_pem: chain_pem,
        private_key_pem: key_pem,
        path: "/rk".into(),
        // Short on purpose: the point of the test is that a peer which vanishes
        // silently is noticed, and a thirty-second default would make the run
        // longer without making the assertion stronger.
        idle_timeout_ms: 3_000,
    }
    .parse()
    .expect("configuration");

    let handle = transport::start(config).expect("endpoint starts");
    let server = transport::lookup(handle).expect("handle resolves");
    let port = server.local_port();

    let runtime = tokio::runtime::Runtime::new().expect("client runtime");

    // --- the client connects -------------------------------------------------

    let connection = runtime.block_on(async {
        let client = Endpoint::client(
            ClientConfig::builder()
                .with_bind_default()
                .with_server_certificate_hashes([digest])
                .build(),
        )
        .expect("client endpoint");
        client
            .connect(format!("https://127.0.0.1:{port}/rk"))
            .await
            .expect("session opens")
    });

    let opened = wait_for(&server, Duration::from_secs(10), |event| {
        matches!(event, Event::SessionOpened { .. })
    })
    .expect("the server never saw the session open");

    let Event::SessionOpened {
        session_id, path, ..
    } = opened
    else {
        unreachable!()
    };
    assert_eq!(path, "/rk");

    // --- the server speaks first --------------------------------------------
    //
    // Nothing was requested. This is the whole reason the package exists: a
    // print job changing state reaches the browser now, not when it next asks.

    assert_eq!(
        server.send(session_id, "print job 41 finished", true),
        Ok(()),
        "the server could not speak to a session that is open"
    );

    let heard = runtime.block_on(async {
        tokio::time::timeout(Duration::from_secs(10), async {
            use tokio::io::AsyncReadExt;
            let mut stream = connection
                .accept_uni()
                .await
                .expect("a stream from the server");
            let mut text = String::new();
            stream.read_to_string(&mut text).await.expect("read");
            text
        })
        .await
        .expect("the client never heard the unsolicited message")
    });
    assert_eq!(heard, "print job 41 finished");

    // A datagram takes the other road: unordered and droppable, for a value
    // that will be sent again anyway.
    assert_eq!(server.send(session_id, "queue depth 3", false), Ok(()));

    // --- the peer goes away mid-session --------------------------------------
    //
    // Dropped, not closed politely: the interesting case is the browser tab
    // that vanished, the network that went, the laptop lid that shut. The
    // server has to *notice*, because otherwise it goes on writing to nobody
    // and a queue backs up behind a session that will never drain.

    drop(connection);
    runtime.shutdown_background();

    let closed = wait_for(&server, Duration::from_secs(20), |event| {
        matches!(event, Event::SessionClosed { .. })
    })
    .expect("the server never noticed the peer had gone");

    let Event::SessionClosed {
        session_id: closed_id,
        reason,
    } = closed
    else {
        unreachable!()
    };
    assert_eq!(closed_id, session_id);
    assert!(
        !reason.is_empty(),
        "a close with no reason tells nobody anything"
    );

    // And writing to it now is `peerGone` — a fact about the session, not a
    // fault of ours, and the signal to stop.
    assert_eq!(
        server.send(session_id, "too late", true),
        Err(Status::UnknownHandle),
        "a session the server has already reported closed must not still accept writes"
    );

    drop(server);
    assert_eq!(transport::remove(handle), Status::Ok);
}

/// The other half of the point: **the till can answer where it was asked**.
///
/// A unidirectional stream carries a message and ends; there is nowhere to
/// reply. Everything the browser terminal needs — a question with an answer, a
/// subscription, a long run reporting progress — needs the reply to land in the
/// stream the question arrived on, or the client cannot tell which of several
/// exchanges in flight it belongs to. That is what is proved here, over a real
/// socket, end to end.
#[test]
fn a_question_on_a_bidirectional_stream_is_answered_in_that_same_stream() {
    let (chain_pem, key_pem) = self_signed();
    let digest = digest_of(&chain_pem);

    let config = ServerConfig {
        bind_address: "127.0.0.1:0".into(),
        certificate_chain_pem: chain_pem,
        private_key_pem: key_pem,
        path: "/rk".into(),
        idle_timeout_ms: 10_000,
    }
    .parse()
    .expect("configuration");

    let handle = transport::start(config).expect("endpoint starts");
    let server = transport::lookup(handle).expect("handle resolves");
    let port = server.local_port();

    let runtime = tokio::runtime::Runtime::new().expect("client runtime");

    let connection = runtime.block_on(async {
        let client = Endpoint::client(
            ClientConfig::builder()
                .with_bind_default()
                .with_server_certificate_hashes([digest])
                .build(),
        )
        .expect("client endpoint");
        client
            .connect(format!("https://127.0.0.1:{port}/rk"))
            .await
            .expect("session opens")
    });

    let Some(Event::SessionOpened { session_id, .. }) =
        wait_for(&server, Duration::from_secs(10), |event| {
            matches!(event, Event::SessionOpened { .. })
        })
    else {
        panic!("the server never saw the session open");
    };

    // --- the client asks -----------------------------------------------------

    let (mut client_send, mut client_recv) = runtime.block_on(async {
        connection
            .open_bi()
            .await
            .expect("a bidirectional stream")
            .await
            .expect("the peer accepted it")
    });
    let client_stream_id = client_send.id().into_u64();

    runtime.block_on(async {
        client_send
            .write_all(b"which shift is open?")
            .await
            .expect("write");
        // The question is complete, so the asking side ends. The *answering*
        // side must not: that is the difference from a unidirectional stream.
        client_send.finish().await.expect("finish");
    });

    let Some(Event::StreamOpened {
        session_id: opened_session,
        stream_id: opened_stream,
    }) = wait_for(&server, Duration::from_secs(10), |event| {
        matches!(event, Event::StreamOpened { .. })
    })
    else {
        panic!("the server never saw the bidirectional stream open");
    };
    assert_eq!(opened_session, session_id);
    assert_eq!(
        opened_stream, client_stream_id,
        "the two ends disagree about which stream this is, so a reply would \
         be addressed to a stream that does not exist"
    );

    let Some(Event::StreamData {
        stream_id, utf8, ..
    }) = wait_for(&server, Duration::from_secs(10), |event| {
        matches!(event, Event::StreamData { .. })
    })
    else {
        panic!("the question never reached the server");
    };
    assert_eq!(utf8, "which shift is open?");
    assert_eq!(stream_id, client_stream_id);

    // --- the till answers into the stream it was asked on ---------------------

    assert_eq!(
        server.stream_send(session_id, stream_id, "shift 41, opened 09:02"),
        Ok(()),
        "the till could not write back into a stream that is open"
    );
    assert_eq!(server.stream_close(session_id, stream_id), Ok(()));

    let heard = runtime.block_on(async {
        tokio::time::timeout(Duration::from_secs(10), async {
            use tokio::io::AsyncReadExt;
            let mut text = String::new();
            client_recv.read_to_string(&mut text).await.expect("read");
            text
        })
        .await
        .expect("the client never heard the answer")
    });
    assert_eq!(heard, "shift 41, opened 09:02");

    // Closed means forgotten, not merely finished: a stream map that only ever
    // grows is a leak that tracks the number of exchanges, which on a till is
    // every operation of every shift.
    assert_eq!(
        server.stream_send(session_id, stream_id, "too late"),
        Err(Status::UnknownHandle),
        "a closed stream is still accepting writes"
    );

    runtime.shutdown_background();
    drop(server);
    assert_eq!(transport::remove(handle), Status::Ok);
}

#[test]
fn a_client_asking_for_the_wrong_path_never_becomes_a_session() {
    let (chain_pem, key_pem) = self_signed();
    let digest = digest_of(&chain_pem);

    let config = ServerConfig {
        bind_address: "127.0.0.1:0".into(),
        certificate_chain_pem: chain_pem,
        private_key_pem: key_pem,
        path: "/rk".into(),
        // Short on purpose: the point of the test is that a peer which vanishes
        // silently is noticed, and a thirty-second default would make the run
        // longer without making the assertion stronger.
        idle_timeout_ms: 3_000,
    }
    .parse()
    .expect("configuration");

    let handle = transport::start(config).expect("endpoint starts");
    let server = transport::lookup(handle).expect("handle resolves");
    let port = server.local_port();

    let runtime = tokio::runtime::Runtime::new().expect("client runtime");

    // The right path FIRST, and it must succeed.
    //
    // Without this the test is worthless: every connection failure looks the
    // same from here, so a certificate this client cannot verify — or an
    // endpoint that never started — would make the assertion below pass while
    // proving nothing about paths at all. This happened: a certificate whose
    // validity window was too long failed as `UnknownIssuer`, and the
    // wrong-path test went green.
    let accepted = runtime.block_on(async {
        let client = Endpoint::client(
            ClientConfig::builder()
                .with_bind_default()
                .with_server_certificate_hashes([digest.clone()])
                .build(),
        )
        .expect("client endpoint");
        client.connect(format!("https://127.0.0.1:{port}/rk")).await
    });
    assert!(
        accepted.is_ok(),
        "the correct path was refused, so this test cannot say anything about \
         the wrong one: {accepted:?}"
    );
    drop(accepted);
    // Let the close land, so the session it opened is not still in flight when
    // the queue is inspected below.
    let opened = wait_for(&server, Duration::from_secs(10), |event| {
        matches!(event, Event::SessionOpened { .. })
    });
    assert!(
        opened.is_some(),
        "the accepted session never reached the queue"
    );
    wait_for(&server, Duration::from_secs(20), |event| {
        matches!(event, Event::SessionClosed { .. })
    });

    let outcome = runtime.block_on(async {
        let client = Endpoint::client(
            ClientConfig::builder()
                .with_bind_default()
                .with_server_certificate_hashes([digest])
                .build(),
        )
        .expect("client endpoint");
        client
            .connect(format!("https://127.0.0.1:{port}/somewhere-else"))
            .await
    });
    assert!(outcome.is_err(), "the wrong path was accepted as a session");

    // And nothing reached the queue: a stray connection must not look like a
    // session that opened and closed, or an operator is shown a peer that was
    // never there.
    assert!(
        wait_for(&server, Duration::from_millis(500), |_| true).is_none(),
        "a refused connection produced an event"
    );

    runtime.shutdown_background();
    drop(server);
    assert_eq!(transport::remove(handle), Status::Ok);
}

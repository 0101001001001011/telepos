//! The failure this package exists to answer: **a stale Zenoh ID after a
//! session is recreated.**
//!
//! A till restarts on updates, crashes, and changes bindings. Every restart
//! gives its Zenoh session a fresh Zenoh ID unless the configuration pins one.
//! Anything that recorded the old ID as *the address of that till* now holds a
//! dead one — and the reported symptom is that messages sent to it **vanish
//! without an error**, which is the worst shape a failure can take.
//!
//! These tests measure the two ways out rather than assuming either:
//!
//! 1. the ZID is an ephemeral handle, and addressing goes by our own durable
//!    identity, with liveliness to notice comings and goings;
//! 2. the ZID is pinned in the configuration, so routes survive the restart.
//!
//! Run with `cargo test --test stale_zid -- --nocapture` to see the numbers.
//!
//! Both use plain TCP on the loopback. That is why they call
//! `RkzSession::open_unchecked`: the C ABI refuses a pinned ZID without TLS
//! (see `RkzSession::open`), and a loopback test has no network to
//! authenticate against. The refusal itself is covered in `c_abi.rs`.

use std::net::TcpListener;
use std::time::{Duration, Instant};

use rk_zenoh::config::{RkzConfigBuilder, Zid};
use rk_zenoh::session::{peer_zids, RkzSession};
use zenoh::handlers::FifoChannel;
use zenoh::Wait;

/// How long a step may take before the test calls it a failure to converge.
const PATIENCE: Duration = Duration::from_secs(20);
/// How often the shop server retries while waiting to converge.
const RETRY: Duration = Duration::from_millis(50);

fn free_port() -> u16 {
    let listener = TcpListener::bind("127.0.0.1:0").expect("the loopback must be bindable");
    let port = listener
        .local_addr()
        .expect("a bound listener has an address")
        .port();
    drop(listener);
    port
}

/// The shop server: listens, and is the side that holds a stale address.
fn open_server(port: u16) -> RkzSession {
    let mut cfg = RkzConfigBuilder::new();
    cfg.mode("peer")
        .expect("peer is a mode")
        .listen(&format!("tcp/127.0.0.1:{port}"))
        .multicast_scouting(false)
        .gossip_scouting(false);
    RkzSession::open_unchecked(&cfg).expect("the server session must open")
}

/// The till: dials the server. `pinned` decides which of the two answers is
/// under test.
fn open_till(port: u16, pinned: Option<&str>) -> RkzSession {
    let mut cfg = RkzConfigBuilder::new();
    cfg.mode("peer")
        .expect("peer is a mode")
        .connect(&format!("tcp/127.0.0.1:{port}"))
        .multicast_scouting(false)
        .gossip_scouting(false);
    if let Some(identity) = pinned {
        cfg.pin_zid(Zid::derive(identity));
    }
    RkzSession::open_unchecked(&cfg).expect("the till session must open")
}

/// Wait until `predicate` holds, returning how long it took.
fn wait_until(what: &str, mut predicate: impl FnMut() -> bool) -> Duration {
    let started = Instant::now();
    while started.elapsed() < PATIENCE {
        if predicate() {
            return started.elapsed();
        }
        std::thread::sleep(RETRY);
    }
    panic!("{what} did not happen within {PATIENCE:?}");
}

/// Publish `payload` at `key` every [`RETRY`] until the subscriber yields it,
/// and report how long that took. `None` means it never arrived.
fn time_to_first_delivery(
    server: &RkzSession,
    key: &str,
    subscriber: &zenoh::pubsub::Subscriber<
        zenoh::handlers::FifoChannelHandler<zenoh::sample::Sample>,
    >,
    patience: Duration,
) -> Option<Duration> {
    let started = Instant::now();
    while started.elapsed() < patience {
        server
            .inner
            .put(key, b"ping".to_vec())
            .wait()
            .expect("a put with no matching subscriber still succeeds; that is the point");
        if let Ok(Some(_)) = subscriber.recv_timeout(RETRY) {
            return Some(started.elapsed());
        }
    }
    None
}

fn declare(
    session: &RkzSession,
    key: &str,
) -> zenoh::pubsub::Subscriber<zenoh::handlers::FifoChannelHandler<zenoh::sample::Sample>> {
    session
        .inner
        .declare_subscriber(key.to_string())
        .with(FifoChannel::new(64))
        .wait()
        .unwrap_or_else(|e| panic!("declaring {key} must work: {e}"))
}

// ---------------------------------------------------------------------------

/// **The failure, reproduced.**
///
/// The shop server caches the till's ZID, the till restarts unpinned, and the
/// server keeps publishing to the address it cached. Nothing is delivered and
/// nothing reports an error. The same restart is then survived by addressing
/// the till by its durable identity instead.
#[test]
fn an_unpinned_zid_goes_stale_and_the_loss_is_silent() {
    let port = free_port();
    let server = open_server(port);
    let till = open_till(port, None);

    let old_zid = till.inner.zid().to_string();
    let joined = wait_until("the server must see the till", || {
        peer_zids(&server).contains(&old_zid)
    });
    println!("[unpinned] the server saw zid {old_zid} after {joined:?}");

    // Both addressing schemes work before the restart.
    let by_zid_key = format!("telepos/direct/{old_zid}/cmd");
    let by_identity_key = "telepos/till/till-17/cmd".to_string();
    let sub_by_zid = declare(&till, &by_zid_key);
    let sub_by_identity = declare(&till, &by_identity_key);

    let before_zid = time_to_first_delivery(&server, &by_zid_key, &sub_by_zid, PATIENCE);
    let before_identity =
        time_to_first_delivery(&server, &by_identity_key, &sub_by_identity, PATIENCE);
    assert!(
        before_zid.is_some(),
        "addressing by zid must work before the restart"
    );
    assert!(
        before_identity.is_some(),
        "addressing by identity must work before the restart"
    );
    println!(
        "[unpinned] before the restart: by zid {before_zid:?}, by identity {before_identity:?}"
    );

    // The till dies. Everything it declared dies with it.
    drop(sub_by_zid);
    drop(sub_by_identity);
    till.inner.close().wait().expect("closing must succeed");
    drop(till);

    let gone = wait_until("the server must stop seeing the dead zid", || {
        !peer_zids(&server).contains(&old_zid)
    });
    println!("[unpinned] the dead zid left the server's view after {gone:?}");

    // The till comes back. A fresh session, therefore a fresh identity.
    let restarted = Instant::now();
    let till = open_till(port, None);
    let new_zid = till.inner.zid().to_string();
    assert_ne!(
        new_zid, old_zid,
        "an unpinned session must get a new zid; if this ever fails the premise is wrong"
    );
    println!("[unpinned] the till came back as {new_zid}");

    let sub_by_new_zid = declare(&till, &format!("telepos/direct/{new_zid}/cmd"));
    let sub_by_identity = declare(&till, &by_identity_key);

    // Addressing by durable identity survives the restart. This is measured
    // **first**, before the deliberate three-second stale probe below, so the
    // number is convergence and not the test's own waiting.
    let convergence = time_to_first_delivery(&server, &by_identity_key, &sub_by_identity, PATIENCE)
        .expect("addressing by durable identity must recover");
    let recovered_after = restarted.elapsed();
    println!(
        "[unpinned] durable identity converged {convergence:?} after the put loop began, \
         {recovered_after:?} after the restart"
    );

    wait_until("the server must see the till again", || {
        peer_zids(&server).contains(&new_zid)
    });

    // The server still holds the old address. This is the reported failure.
    let stale = time_to_first_delivery(
        &server,
        &by_zid_key,
        &sub_by_new_zid,
        Duration::from_secs(3),
    );
    assert!(
        stale.is_none(),
        "the whole point: a message to the stale zid must not reach the till, \
         and it must not have raised anything either"
    );
    println!(
        "[unpinned] every put to the stale zid succeeded and delivered nothing, \
         for three seconds after the till was already reachable by identity"
    );
}

/// **The other way out.**
///
/// The till pins its ZID from its durable identity. The server's cached
/// address is still correct after the restart, so nothing has to converge on
/// the application's side at all.
#[test]
fn a_pinned_zid_survives_the_restart() {
    let port = free_port();
    let server = open_server(port);
    let till = open_till(port, Some("till-17.shop-3.telepos"));

    let old_zid = till.inner.zid().to_string();
    assert_eq!(
        old_zid,
        Zid::derive("till-17.shop-3.telepos").as_str(),
        "the session must actually take the zid we pinned"
    );
    wait_until("the server must see the till", || {
        peer_zids(&server).contains(&old_zid)
    });

    let by_zid_key = format!("telepos/direct/{old_zid}/cmd");
    let sub = declare(&till, &by_zid_key);
    assert!(
        time_to_first_delivery(&server, &by_zid_key, &sub, PATIENCE).is_some(),
        "addressing by pinned zid must work before the restart"
    );

    drop(sub);
    till.inner.close().wait().expect("closing must succeed");
    drop(till);
    wait_until("the server must stop seeing the till", || {
        !peer_zids(&server).contains(&old_zid)
    });

    let restarted = Instant::now();
    let till = open_till(port, Some("till-17.shop-3.telepos"));
    let new_zid = till.inner.zid().to_string();
    assert_eq!(
        new_zid, old_zid,
        "a pinned zid must be the same one after a restart"
    );

    let sub = declare(&till, &by_zid_key);
    let convergence = time_to_first_delivery(&server, &by_zid_key, &sub, PATIENCE)
        .expect("the cached address must still be the right one");
    println!(
        "[pinned] the stale address was never stale: converged {convergence:?} after the put \
         loop began, {:?} after the restart",
        restarted.elapsed()
    );
}

/// **Why a pinned ZID is only half an answer.**
///
/// Two sessions claiming the same pinned ZID at the same time is exactly what
/// an impostor looks like from the fabric's side. This test does not assert a
/// particular outcome — it records what Zenoh actually does — because the
/// conclusion is the same either way: nothing here distinguishes the till that
/// restarted from a machine asserting that it is the till. That distinction is
/// mutual TLS, which is why `RkzSession::open` refuses a pin without it.
#[test]
fn two_sessions_may_claim_the_same_pinned_zid() {
    let port = free_port();
    let server = open_server(port);
    let identity = "till-17.shop-3.telepos";

    let genuine = open_till(port, Some(identity));
    let zid = genuine.inner.zid().to_string();
    wait_until("the server must see the genuine till", || {
        peer_zids(&server).contains(&zid)
    });

    let key = format!("telepos/direct/{zid}/cmd");
    let sub_genuine = declare(&genuine, &key);
    assert!(
        time_to_first_delivery(&server, &key, &sub_genuine, PATIENCE).is_some(),
        "the genuine till must receive before the impostor appears"
    );

    // A second machine, same claim, no certificate anywhere.
    let mut impostor_cfg = RkzConfigBuilder::new();
    impostor_cfg
        .mode("peer")
        .expect("peer is a mode")
        .connect(&format!("tcp/127.0.0.1:{port}"))
        .multicast_scouting(false)
        .gossip_scouting(false)
        .pin_zid(Zid::derive(identity));
    let impostor = RkzSession::open_unchecked(&impostor_cfg);

    match impostor {
        Ok(impostor) => {
            assert_eq!(
                impostor.inner.zid().to_string(),
                zid,
                "nothing stopped a second process from taking the pinned identity"
            );
            let sub_impostor = declare(&impostor, &key);
            std::thread::sleep(Duration::from_millis(500));

            // Three questions, all of them recorded rather than asserted: does
            // the impostor reach the fabric at all, does traffic for the till
            // reach it, and does the genuine till keep working?
            let impostor_is_connected = !peer_zids(&impostor).is_empty();
            let reached_impostor =
                time_to_first_delivery(&server, &key, &sub_impostor, Duration::from_secs(5));
            let genuine_still_receives =
                time_to_first_delivery(&server, &key, &sub_genuine, Duration::from_secs(5));

            println!(
                "[impostor] session opened with the same pinned zid; \
                 connected to the fabric: {impostor_is_connected}; \
                 traffic for the till reached the impostor: {}; \
                 the genuine till still receives: {}",
                reached_impostor.is_some(),
                genuine_still_receives.is_some(),
            );
            assert!(
                reached_impostor.is_some() || genuine_still_receives.is_some(),
                "one of the two must be receiving, otherwise this test measured nothing"
            );
            drop(sub_impostor);
            let _ = impostor.inner.close().wait();
        }
        Err(e) => {
            println!(
                "[impostor] zenoh refused the duplicate pinned zid: {}",
                e.detail
            );
        }
    }

    drop(sub_genuine);
    let _ = genuine.inner.close().wait();
}

/// **The reason a pinned ZID without mutual TLS is worse than no pin at all.**
///
/// Same duplicate claim, opposite order: the impostor is already connected
/// when the till restarts. Whoever holds the ZID keeps it, and the till is
/// locked out of the fabric it owns — by a machine that presented nothing.
///
/// This is a denial of service that costs an engineer a site visit, and no
/// amount of ZID discipline prevents it. Only an authenticated identity does,
/// which is what `RkzSession::open` insists on.
#[test]
fn whoever_claims_a_pinned_zid_first_keeps_it() {
    let port = free_port();
    let server = open_server(port);
    let identity = "till-17.shop-3.telepos";

    let impostor = open_till(port, Some(identity));
    let zid = impostor.inner.zid().to_string();
    wait_until("the impostor must get in first", || {
        peer_zids(&server).contains(&zid)
    });

    // Now the genuine till boots, with exactly the configuration it has always
    // had, and finds its own identity occupied.
    let genuine = open_till(port, Some(identity));
    assert_eq!(genuine.inner.zid().to_string(), zid);
    std::thread::sleep(Duration::from_secs(2));

    let genuine_joined = !peer_zids(&genuine).is_empty();
    println!(
        "[first come] the impostor was already connected; the genuine till joined the fabric: \
         {genuine_joined}"
    );
    assert!(
        !genuine_joined,
        "if this ever passes, zenoh has started tolerating duplicate zids and the \
         mutual-tls requirement below needs restating rather than removing"
    );

    let key = format!("telepos/direct/{zid}/cmd");
    let sub_genuine = declare(&genuine, &key);
    assert!(
        time_to_first_delivery(&server, &key, &sub_genuine, Duration::from_secs(3)).is_none(),
        "the locked-out till must receive nothing, which is the damage being measured"
    );

    drop(sub_genuine);
    let _ = genuine.inner.close().wait();
    let _ = impostor.inner.close().wait();
}

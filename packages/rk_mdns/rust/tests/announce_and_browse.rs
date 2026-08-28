//! The two halves against each other, over a real socket.
//!
//! This is the weakest of the three proofs this package rests on, and it is
//! written down as such: a responder and a browser from the same source agree
//! with each other whether or not either agrees with the RFC. The proofs that
//! carry weight are `avahi-browse` seeing this responder and this browser
//! seeing an Avahi service — `doc/interop.md` holds the transcripts.
//!
//! What this suite does add is everything the interop check cannot: the
//! goodbye, the conflict rename, and the states in between, which need two
//! instances started in a controlled order.

mod common;

use std::time::Duration;

use rk_mdns::browser::{Browser, BrowserEvent};
use rk_mdns::responder::{Responder, ResponderEvent};

#[test]
fn a_browser_finds_the_service_a_responder_announced() {
    let port = common::port(3);
    let service = "_rkannounce._tcp.local";

    let responder = Responder::start(common::responder_config("rk-till", service, port))
        .expect("the responder started");
    let claimed =
        common::wait_for_responder(&responder, Duration::from_secs(20), |event| match event {
            ResponderEvent::Claimed { instance, .. } => Some(instance.clone()),
            _ => None,
        });
    assert_eq!(claimed, "rk-till._rkannounce._tcp.local");

    let browser = Browser::start(common::browser_config(service, port)).expect("the browser");

    let resolved =
        common::wait_for_browser(&browser, Duration::from_secs(30), |event| match event {
            BrowserEvent::ServiceResolved {
                instance,
                host,
                port,
                addresses,
                txt,
            } => Some((
                instance.clone(),
                host.clone(),
                *port,
                addresses.clone(),
                txt.clone(),
            )),
            _ => None,
        });

    assert_eq!(resolved.0, "rk-till._rkannounce._tcp.local");
    assert_eq!(resolved.1, "rk-till.local");
    assert_eq!(resolved.2, 8443, "the port did not survive the SRV record");
    assert!(
        !resolved.3.is_empty(),
        "the service resolved with no address, which is a service that cannot be connected to"
    );
    // The TXT is what the till carries its second port and its path in, so it
    // is checked pair by pair rather than "is not empty".
    let pairs: Vec<(String, String)> = resolved
        .4
        .iter()
        .map(|p| (p.key.clone(), p.value.clone()))
        .collect();
    assert!(
        pairs.contains(&("quic".to_string(), "4433".to_string())),
        "{pairs:?}"
    );
    assert!(
        pairs.contains(&("path".to_string(), "/rk".to_string())),
        "{pairs:?}"
    );
    assert!(
        pairs.contains(&("scheme".to_string(), "https".to_string())),
        "{pairs:?}"
    );

    browser.stop();
    responder.stop();
}

#[test]
fn a_second_responder_with_the_same_name_renames_itself() {
    // RFC 6762 §8.1. Two tills named alike is a setup mistake, and the whole
    // reason to probe is to make it visible instead of leaving a tablet to
    // reach whichever answered first.
    let port = common::port(4);
    let service = "_rkconflict._tcp.local";

    let first = Responder::start(common::responder_config("rk-same", service, port))
        .expect("the first responder started");
    common::wait_for_responder(&first, Duration::from_secs(20), |event| {
        matches!(event, ResponderEvent::Claimed { .. }).then_some(())
    });

    // A different port behind the same name — which is what two tills on one
    // segment actually look like, and what §8.1 calls a conflict. Identical
    // rdata is explicitly not one; see `common::responder_config_serving`.
    let second = Responder::start(common::responder_config_serving(
        "rk-same", service, port, 9443,
    ))
    .expect("the second responder started");

    let (from, to) =
        common::wait_for_responder(&second, Duration::from_secs(30), |event| match event {
            ResponderEvent::NameConflict { from, to, .. } => Some((from.clone(), to.clone())),
            _ => None,
        });
    assert_eq!(from, "rk-same._rkconflict._tcp.local");
    assert_eq!(to, "rk-same-2._rkconflict._tcp.local");

    // And the name it ends up with is the one it reports, so a caller can show
    // an operator what actually happened.
    let claimed =
        common::wait_for_responder(&second, Duration::from_secs(30), |event| match event {
            ResponderEvent::Claimed { instance, host, .. } => {
                Some((instance.clone(), host.clone()))
            }
            _ => None,
        });
    assert_eq!(claimed.0, "rk-same-2._rkconflict._tcp.local");
    assert_eq!(
        claimed.1, "rk-same-2.local",
        "the host name stayed contested while only the service instance moved"
    );

    let state = second.state();
    assert_eq!(state.instance, "rk-same-2._rkconflict._tcp.local");
    assert!(state.claimed);

    second.stop();
    first.stop();
}

#[test]
fn the_first_responder_keeps_its_name() {
    // The other half of the conflict: the host that was there first must not
    // move. A rename on both sides would leave the name nobody holds and every
    // cached record pointing at it.
    let port = common::port(5);
    let service = "_rkkeep._tcp.local";

    let first = Responder::start(common::responder_config("rk-keep", service, port))
        .expect("the first responder started");
    common::wait_for_responder(&first, Duration::from_secs(20), |event| {
        matches!(event, ResponderEvent::Claimed { .. }).then_some(())
    });

    let second = Responder::start(common::responder_config_serving(
        "rk-keep", service, port, 9443,
    ))
    .expect("the second responder started");
    common::wait_for_responder(&second, Duration::from_secs(30), |event| {
        matches!(event, ResponderEvent::NameConflict { .. }).then_some(())
    });
    // Give the first every chance to change its mind.
    std::thread::sleep(Duration::from_secs(2));

    assert_eq!(
        first.state().instance,
        "rk-keep._rkkeep._tcp.local",
        "the responder that was there first renamed itself too"
    );

    second.stop();
    first.stop();
}

#[test]
fn a_responder_does_not_rename_itself_over_its_own_announcement() {
    // Multicast loopback is on — a till's own setup page browses for the
    // service the till is announcing — so every announcement comes straight
    // back to its sender. A responder that read that as somebody else holding
    // the name would rename itself once a second, forever, and the name in the
    // certificate would stop matching the name on the wire.
    let port = common::port(9);
    let responder = Responder::start(common::responder_config(
        "rk-echo",
        "_rkecho._tcp.local",
        port,
    ))
    .expect("the responder started");

    common::wait_for_responder(&responder, Duration::from_secs(20), |event| {
        matches!(event, ResponderEvent::Claimed { .. }).then_some(())
    });
    // Long enough for all three announcements and their echoes.
    std::thread::sleep(Duration::from_secs(5));

    assert_eq!(
        responder.state().instance,
        "rk-echo._rkecho._tcp.local",
        "the responder renamed itself over its own announcement coming back on the loopback"
    );
    responder.stop();
}

#[test]
fn a_service_that_stops_is_reported_gone_rather_than_left_to_expire() {
    // RFC 6762 §10.1. Without the goodbye the record sits in every cache on
    // the segment for its full lifetime — two minutes here — and a tablet goes
    // on offering a till that is switched off.
    let port = common::port(6);
    let service = "_rkgoodbye._tcp.local";

    let responder = Responder::start(common::responder_config("rk-bye", service, port))
        .expect("the responder started");
    let browser = Browser::start(common::browser_config(service, port)).expect("the browser");

    common::wait_for_browser(&browser, Duration::from_secs(30), |event| match event {
        BrowserEvent::ServiceResolved { instance, .. }
            if instance == "rk-bye._rkgoodbye._tcp.local" =>
        {
            Some(())
        }
        _ => None,
    });

    responder.stop();

    let lost = common::wait_for_browser(&browser, Duration::from_secs(20), |event| match event {
        BrowserEvent::ServiceLost { instance } => Some(instance.clone()),
        _ => None,
    });
    assert_eq!(lost, "rk-bye._rkgoodbye._tcp.local");

    // Two minutes is the record's lifetime. Arriving inside twenty seconds is
    // only possible because the goodbye was sent and honoured.
    browser.stop();
}

#[test]
fn a_resolver_finds_the_host_name_on_its_own() {
    // The other question a caller asks: not "what services are there" but
    // "where is till-3.local". Answered by the A/AAAA path rather than the
    // DNS-SD one, and they are separate code.
    let port = common::port(7);
    let responder = Responder::start(common::responder_config(
        "rk-host",
        "_rkhost._tcp.local",
        port,
    ))
    .expect("the responder started");
    common::wait_for_responder(&responder, Duration::from_secs(20), |event| {
        matches!(event, ResponderEvent::Claimed { .. }).then_some(())
    });

    let resolved = rk_mdns::browser::resolve_host(
        serde_json::from_value(serde_json::json!({
            "hostName": "rk-host.local",
            "timeoutMs": 8000,
            "mdnsPort": port,
            "ipv6": false,
            "loopbackInterface": true,
            "multicastLoopback": true,
        }))
        .expect("the configuration parses"),
    )
    .expect("the resolve ran");

    assert_eq!(resolved.host, "rk-host.local");
    assert!(
        !resolved.addresses.is_empty(),
        "rk-host.local resolved to nothing while its responder was running"
    );
    assert!(
        !resolved.addresses.iter().any(|a| a == "127.0.0.1"),
        "the responder advertised loopback, which resolves and reaches the wrong machine: {:?}",
        resolved.addresses
    );

    responder.stop();
}

#[test]
fn a_name_nobody_holds_resolves_to_nothing_rather_than_to_a_failure() {
    // On a network that filters multicast this is the ORDINARY outcome, and
    // turning it into an error would make a filtered network
    // indistinguishable from a broken call.
    let resolved = rk_mdns::browser::resolve_host(
        serde_json::from_value(serde_json::json!({
            "hostName": "rk-nobody-holds-this.local",
            "timeoutMs": 1200,
            "mdnsPort": common::port(8),
            "ipv6": false,
            "loopbackInterface": true,
            "multicastLoopback": true,
        }))
        .expect("the configuration parses"),
    )
    .expect("the resolve ran and did not fail");
    assert!(resolved.addresses.is_empty());
}

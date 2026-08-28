//! The check that goes red if anybody ever adds the default-send fallback
//! back.
//!
//! # What is being defended
//!
//! Measured 2026-08-05 on a workstation with four IPv4 interfaces. A datagram
//! sent to `224.0.0.251` **without** `IP_MULTICAST_IF` left by exactly one of
//! them, chosen by the routing table, and the chosen one was a virtual switch
//! adapter that no tablet is ever behind. Nothing was wrong with the packet;
//! the host was simply invisible, silently.
//!
//! The fix is not "prefer the right interface" — there is no way to know which
//! one is right. The fix is to send on all of them, and the defence is that
//! this crate **has no code path that sends on one**. That is what the two
//! tests below assert, from the two directions it can be broken from:
//!
//! 1. A set with no interface is an error, not a socket. If somebody adds
//!    `else { bind the wildcard and hope }`, the first test goes red.
//! 2. Every interface in a live set is offered every datagram. If somebody
//!    makes the send pick one — the cheapest way to "fix" a duplicate — the
//!    second goes red.

mod common;

use std::time::Duration;

use rk_mdns::interfaces::{usable, InterfaceFilter};
use rk_mdns::socket::{SocketOptions, SocketSet};

#[test]
fn an_empty_interface_list_is_refused_and_never_becomes_a_default_socket() {
    // The filter that can select nothing: no IPv4, no IPv6, no loopback. There
    // is no machine on which this yields an interface, so the only two possible
    // outcomes are an error — correct — or a socket built without one, which is
    // the routing-table default in disguise.
    let filter = InterfaceFilter {
        loopback: false,
        ipv4: false,
        ipv6: false,
        ..InterfaceFilter::everything()
    };

    let listed = usable(&filter);
    assert!(
        listed.is_err(),
        "the interface list came back non-empty for a filter that excludes every family: {:?}",
        listed.map(|found| found.len())
    );

    let opened = SocketSet::open(SocketOptions {
        port: common::port(0),
        filter: filter.clone(),
        loopback: true,
    });
    assert!(
        opened.is_err(),
        "SocketSet::open produced a socket with no interface behind it. That socket sends \
         wherever the routing table prefers — measured 2026-08-05 to be a virtual switch on \
         a four-interface machine — and this crate must not have that path."
    );
}

#[test]
fn every_interface_is_offered_every_datagram() {
    let filter = InterfaceFilter {
        loopback: true,
        ipv4: true,
        ipv6: false,
        ..InterfaceFilter::everything()
    };
    let interfaces = usable(&filter).expect("this host has at least the loopback");

    let mut set = SocketSet::open(SocketOptions {
        port: common::port(1),
        filter,
        loopback: true,
    })
    .expect("the sockets came up");

    assert_eq!(
        set.len(),
        interfaces.len(),
        "the set bound {} sockets for {} interfaces — one interface is not being sent on",
        set.len(),
        interfaces.len()
    );

    const SENDS: u64 = 5;
    for _ in 0..SENDS {
        set.send_to_group(b"rk_mdns interface fan-out check");
    }

    for entry in set.sent_per_interface() {
        assert_eq!(
            entry.sent() + entry.failed(),
            SENDS,
            "interface {} ({}) was offered {} of {SENDS} datagrams. A send that picks one \
             interface is the defect this crate exists to prevent.",
            entry.interface.name,
            entry.interface.address,
            entry.sent() + entry.failed()
        );
    }

    // And at least one of them actually carried it: a set where every send
    // failed would satisfy the count above and prove nothing.
    let carried: u64 = set.sent_per_interface().iter().map(|e| e.sent()).sum();
    assert!(carried > 0, "not one interface carried a datagram");
}

#[test]
fn a_caller_can_confine_the_announcement_to_the_interfaces_it_names() {
    // Why this exists, in one sentence: in a certificate a spare address is
    // *checked* and costs nothing, in an announcement it is *tried* and costs
    // the client a connection timeout — so the responder's rule has to be
    // stricter than the certificate's, and only the caller knows which
    // interface is a shop's cable and which is a Hyper-V switch.
    // Deliberately NOT the first interface in the list: on Linux that is `lo`,
    // and confining to it means every address is a loopback address, which is
    // never advertised — a service announced at 127.0.0.1 resolves, connects,
    // and reaches the wrong machine. The responder refuses that with a
    // sentence rather than announcing nothing, which is right, and which made
    // the first version of this test fail on Linux and pass on Windows.
    let all = usable(&InterfaceFilter::everything()).expect("this host has a real interface");
    let chosen = all[0].name.clone();

    let mut config =
        common::responder_config("rk-confined", "_rkconfined._tcp.local", common::port(3));
    config.interfaces = vec![chosen.clone()];
    config.loopback_interface = false;

    let responder = rk_mdns::responder::Responder::start(config).expect("the responder started");
    common::wait_for_responder(&responder, Duration::from_secs(20), |event| {
        matches!(event, rk_mdns::responder::ResponderEvent::Announced { .. }).then_some(())
    });

    let state = responder.state();
    assert!(!state.interfaces.is_empty());
    for interface in &state.interfaces {
        assert_eq!(
            interface.name, chosen,
            "the responder announced on {} although only {chosen} was named",
            interface.name
        );
    }
    responder.stop();
}

#[test]
fn an_interface_name_that_matches_nothing_is_refused_by_name() {
    // A typo in a setting must not look like a machine with no network, and it
    // must not silently fall back to every interface — which would put the
    // unreachable addresses back in the announcement, one client timeout each.
    let mut config = common::responder_config("rk-typo", "_rktypo._tcp.local", common::port(4));
    config.interfaces = vec!["no-such-interface-42".into()];

    let Err(error) = rk_mdns::responder::Responder::start(config) else {
        panic!("a name nothing matches must not start a responder");
    };
    let text = error.to_string();
    assert!(
        text.contains("no-such-interface-42"),
        "the error does not name what was asked for: {text}"
    );
    assert!(
        text.contains("this host has"),
        "the error does not say which interfaces exist: {text}"
    );
}

#[test]
fn a_responder_reports_what_each_interface_carried() {
    // The same property, seen from the surface a caller actually has. A caller
    // must be able to find out that the announcement went everywhere, because
    // "the till is invisible" and "the till announced out of the wrong door"
    // look identical from a tablet.
    let responder = rk_mdns::responder::Responder::start(common::responder_config(
        "rk-fanout",
        "_rkfanout._tcp.local",
        common::port(2),
    ))
    .expect("the responder started");

    common::wait_for_responder(&responder, Duration::from_secs(20), |event| {
        matches!(event, rk_mdns::responder::ResponderEvent::Announced { .. }).then_some(())
    });

    let state = responder.state();
    assert!(
        !state.interfaces.is_empty(),
        "the responder reports no interfaces at all"
    );
    for interface in &state.interfaces {
        assert!(
            interface.sent > 0,
            "interface {} ({}) carried nothing while the responder announced. Either the \
             send is picking one interface, or this one is silently refusing every datagram \
             — and the report is the only place either is visible.",
            interface.name,
            interface.address
        );
    }
    responder.stop();
}

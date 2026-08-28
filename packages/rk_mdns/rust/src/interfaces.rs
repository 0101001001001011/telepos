//! Which interfaces exist, and which of them a multicast datagram must leave
//! by.
//!
//! # The measurement this module exists for
//!
//! Taken 2026-08-05 on a workstation with four IPv4 interfaces — a wired
//! network, a Wi-Fi, and two virtual switches. Sending to `224.0.0.251`
//! **without** `IP_MULTICAST_IF` put the datagram on exactly one of them,
//! chosen by the routing table, and the chosen one was a virtual switch
//! adapter that no tablet is ever behind. Nothing was wrong with the packet.
//! It left through the wrong door, silently, and the host was invisible.
//!
//! Setting the option and sending once per interface delivered on three of the
//! four; the fourth was a Wi-Fi adapter that does not loop a datagram back to
//! its own host, which is a property of that driver rather than of the send.
//!
//! This is not tuning. A till on a shop's wired network with a Wi-Fi card
//! still enabled is the ordinary case, and one send picks the wrong one about
//! as often as the right one.
//!
//! # What follows from it
//!
//! **There is no default-send path in this crate.** Not "there is one and we
//! avoid it": an interface list that comes back empty is
//! [`InterfaceError::NoInterface`], a status the caller sees, and never a
//! socket that sends wherever the routing table likes. A test asserts exactly
//! that, and it is the test that goes red if anybody ever adds the fallback
//! back for convenience.

use std::net::{IpAddr, Ipv4Addr, Ipv6Addr};

/// One address on one interface, with what a socket needs to use it — and
/// what a caller needs to decide whether it wants it.
///
/// # Why the name and the netmask are here
///
/// **The cost of a spare address is not symmetric.** In a TLS certificate an
/// `iPAddress` entry is *checked*: a spare one costs nothing and a missing one
/// costs the handshake, so being generous there is safe. In an mDNS
/// announcement an address is *tried*: a client works through the list, and a
/// spare one costs it a connection timeout. The responder's rule therefore has
/// to be **stricter** than the certificate's.
///
/// Measured on the development machine 2026-08-06: of four addresses that
/// survive the ordinary filters, two — `172.23.48.1` (Hyper-V) and
/// `172.19.208.1` (WSL) — are unreachable from any terminal, and each costs
/// one timeout.
///
/// **Filtering by the address does not work.** A prefix rule that dropped
/// `172.16/12` and `10/8` would drop the shop networks this is for; those are
/// exactly the ranges a real site uses. What separates a virtual switch from a
/// shop's cable is the **interface**, not the address — so the name is carried
/// here, and the choice is the caller's. This crate does not guess which
/// interface is real, in the same way `rk_pki` refuses to guess which address
/// belongs in a certificate.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Interface {
    /// The operating system's name for it — `eth0`, `Ethernet 2`,
    /// `vEthernet (WSL)`.
    ///
    /// This is what a caller filters on. See the note on the type.
    pub name: String,
    /// The address itself.
    pub address: IpAddr,
    /// The netmask.
    pub netmask: IpAddr,
    /// The CIDR prefix length — `24` for a `/24`.
    ///
    /// Carried because it is the one piece of information that says which
    /// addresses this interface can reach without a router, and a caller
    /// deciding whether an interface is worth announcing on wants it.
    pub prefix: u8,
    /// The interface index.
    ///
    /// Load-bearing for IPv6 and only for IPv6: `ff02::fb` is link-local, so a
    /// socket joins and sends by index rather than by address. There is no way
    /// to say this through `std::net`, which is one of the reasons this
    /// package is native.
    pub index: u32,
    /// Whether this is the loopback interface.
    pub loopback: bool,
}

impl Interface {
    /// The IPv4 address, when this is one.
    pub fn ipv4(&self) -> Option<Ipv4Addr> {
        match self.address {
            IpAddr::V4(addr) => Some(addr),
            IpAddr::V6(_) => None,
        }
    }

    /// The IPv6 address, when this is one.
    pub fn ipv6(&self) -> Option<Ipv6Addr> {
        match self.address {
            IpAddr::V6(addr) => Some(addr),
            IpAddr::V4(_) => None,
        }
    }
}

/// Why no interface could be used.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum InterfaceError {
    /// The list could not be read at all.
    Unreadable(String),
    /// The list was read and holds nothing usable.
    ///
    /// A separate variant from [`InterfaceError::Unreadable`] because the two
    /// mean different things to an operator: one is a machine with no network,
    /// the other is a machine whose network cannot be enumerated, and only the
    /// second is a bug in something.
    NoInterface,
    /// The caller named interfaces and none of them exists.
    ///
    /// Its own variant because it is almost always a typo in a setting, and
    /// without it a mistyped name looks exactly like a machine with no
    /// network. The names that *do* exist travel with it, so the message says
    /// what to write instead.
    NoNameMatched {
        /// What the caller asked for.
        asked: Vec<String>,
        /// What this host actually has.
        available: Vec<String>,
    },
}

impl std::fmt::Display for InterfaceError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            InterfaceError::Unreadable(why) => {
                write!(f, "the interface list could not be read: {why}")
            }
            InterfaceError::NoInterface => write!(
                f,
                "no usable network interface — there is nowhere to announce to, \
                 and sending on whichever one the routing table prefers is not \
                 a fallback this crate has"
            ),
            InterfaceError::NoNameMatched { asked, available } => write!(
                f,
                "no interface is named any of {asked:?}; this host has {available:?}"
            ),
        }
    }
}

/// What to leave out of the list.
///
/// [`InterfaceFilter::only`] and [`InterfaceFilter::except`] are how a caller
/// says which interfaces are real, and they exist because this crate refuses
/// to guess. See the note on [`Interface`] for the measurement behind that.
#[derive(Debug, Clone, Default)]
pub struct InterfaceFilter {
    /// Whether to include the loopback interface.
    ///
    /// On for the tests that prove the protocol against a resolver on the same
    /// host — which is the only place the proof can be run when multicast does
    /// not cross the segment — and off in ordinary use, where announcing to
    /// oneself is noise.
    pub loopback: bool,
    /// Whether to include IPv6.
    pub ipv6: bool,
    /// Whether to include IPv4.
    pub ipv4: bool,
    /// If non-empty, **only** interfaces with these names are used.
    ///
    /// Names are matched case-insensitively and exactly. A name that matches
    /// nothing is not silently ignored: the result is
    /// [`InterfaceError::NoNameMatched`], which carries the names that do
    /// exist — otherwise a typo in a setting looks exactly like a machine with
    /// no network.
    pub only: Vec<String>,
    /// Interfaces with these names are left out. Applied after [`Self::only`].
    pub except: Vec<String>,
}

impl InterfaceFilter {
    /// Both families, no loopback, no name restriction — what ordinary use
    /// wants.
    pub fn everything() -> InterfaceFilter {
        InterfaceFilter {
            loopback: false,
            ipv6: true,
            ipv4: true,
            only: Vec::new(),
            except: Vec::new(),
        }
    }
}

/// Every address this host can send multicast from, after filtering.
pub fn usable(filter: &InterfaceFilter) -> Result<Vec<Interface>, InterfaceError> {
    let listed = if_addrs::get_if_addrs().map_err(|e| InterfaceError::Unreadable(e.to_string()))?;
    let mut out = Vec::new();
    let mut names_seen: Vec<String> = Vec::new();

    for entry in listed {
        let address = entry.ip();
        if !names_seen.iter().any(|n| n == &entry.name) {
            names_seen.push(entry.name.clone());
        }
        if entry.is_loopback() && !filter.loopback {
            continue;
        }
        if !filter.only.is_empty()
            && !filter
                .only
                .iter()
                .any(|wanted| wanted.eq_ignore_ascii_case(&entry.name))
        {
            continue;
        }
        if filter
            .except
            .iter()
            .any(|unwanted| unwanted.eq_ignore_ascii_case(&entry.name))
        {
            continue;
        }
        let (netmask, prefix) = match &entry.addr {
            if_addrs::IfAddr::V4(v4) => (IpAddr::V4(v4.netmask), v4.prefixlen),
            if_addrs::IfAddr::V6(v6) => (IpAddr::V6(v6.netmask), v6.prefixlen),
        };
        match address {
            IpAddr::V4(_) if !filter.ipv4 => continue,
            IpAddr::V6(v6) => {
                if !filter.ipv6 {
                    continue;
                }
                // A unique-local or global v6 address is fine; what is never
                // usable is an unspecified one.
                if v6.is_unspecified() {
                    continue;
                }
            }
            _ => {}
        }
        out.push(Interface {
            name: entry.name.clone(),
            index: entry.index.unwrap_or(0),
            loopback: entry.is_loopback(),
            netmask,
            prefix,
            address,
        });
    }

    if out.is_empty() {
        // A name that matched nothing is a different problem from a machine
        // with no network, and only one of them is a typo in a setting.
        if !filter.only.is_empty()
            && !filter.only.iter().any(|wanted| {
                names_seen
                    .iter()
                    .any(|have| have.eq_ignore_ascii_case(wanted))
            })
        {
            return Err(InterfaceError::NoNameMatched {
                asked: filter.only.clone(),
                available: names_seen,
            });
        }
        return Err(InterfaceError::NoInterface);
    }
    Ok(out)
}

/// The addresses that belong in `A` and `AAAA` records, given the interfaces
/// in use.
///
/// Loopback is excluded even when the interface list includes it: announcing
/// `127.0.0.1` to the segment publishes an address that resolves, connects,
/// and reaches the wrong machine — which is worse than not announcing.
pub fn advertisable(interfaces: &[Interface]) -> Vec<IpAddr> {
    let mut out = Vec::new();
    for interface in interfaces {
        let addr = interface.address;
        let loopback = match addr {
            IpAddr::V4(v4) => v4.is_loopback(),
            IpAddr::V6(v6) => v6.is_loopback(),
        };
        if loopback {
            continue;
        }
        if !out.contains(&addr) {
            out.push(addr);
        }
    }
    out
}

#[cfg(test)]
mod tests {
    use super::*;

    fn fake(name: &str, address: IpAddr) -> Interface {
        Interface {
            name: name.into(),
            address,
            netmask: IpAddr::V4(Ipv4Addr::new(255, 255, 255, 0)),
            prefix: 24,
            index: 2,
            loopback: match address {
                IpAddr::V4(v4) => v4.is_loopback(),
                IpAddr::V6(v6) => v6.is_loopback(),
            },
        }
    }

    #[test]
    fn this_machine_has_at_least_one_usable_interface() {
        // Not a tautology: it is the assertion that enumeration works at all on
        // the platform the tests run on, and it is what would have caught an
        // if-addrs that returns nothing on Windows.
        let found = usable(&InterfaceFilter::everything()).expect("this host has a network");
        assert!(!found.is_empty());
        for interface in &found {
            assert!(!interface.name.is_empty(), "an interface with no name");
            // The netmask and prefix are what a caller uses to decide whether
            // an interface is worth announcing on, so they must actually be
            // filled in rather than defaulted.
            assert!(interface.prefix > 0, "{} has no prefix", interface.name);
        }
    }

    #[test]
    fn loopback_is_left_out_unless_it_is_asked_for() {
        let without = usable(&InterfaceFilter::everything()).expect("a network");
        assert!(
            !without.iter().any(|i| i.loopback),
            "loopback appeared in a list that did not ask for it"
        );

        let with = usable(&InterfaceFilter {
            loopback: true,
            ..InterfaceFilter::everything()
        })
        .expect("a network");
        assert!(with.len() >= without.len());
    }

    #[test]
    fn ipv6_can_be_left_out_entirely() {
        let v4_only = usable(&InterfaceFilter {
            ipv6: false,
            ..InterfaceFilter::everything()
        })
        .expect("a network");
        assert!(v4_only.iter().all(|i| i.ipv4().is_some()));
    }

    #[test]
    fn a_caller_can_name_the_interfaces_it_wants() {
        // The reason this exists: on the development machine, two of the four
        // surviving addresses are a Hyper-V switch and a WSL switch, and each
        // costs a client a connection timeout. Filtering by address prefix
        // cannot separate them from a real shop network in 172.16/12, so the
        // caller names the interface instead — and this crate does not guess.
        let all = usable(&InterfaceFilter {
            loopback: true,
            ..InterfaceFilter::everything()
        })
        .expect("a network");
        let one = all[0].name.clone();

        let only = usable(&InterfaceFilter {
            loopback: true,
            only: vec![one.clone()],
            ..InterfaceFilter::everything()
        })
        .expect("the named interface exists");
        assert!(only.iter().all(|i| i.name == one));
        assert!(!only.is_empty());

        // Case-insensitively, because Windows names them `Ethernet 2` and an
        // operator will type `ethernet 2`.
        let shouted = usable(&InterfaceFilter {
            loopback: true,
            only: vec![one.to_uppercase()],
            ..InterfaceFilter::everything()
        })
        .expect("the named interface exists whatever the case");
        assert_eq!(shouted.len(), only.len());

        let except = usable(&InterfaceFilter {
            loopback: true,
            except: vec![one.clone()],
            ..InterfaceFilter::everything()
        });
        match except {
            Ok(rest) => assert!(rest.iter().all(|i| i.name != one)),
            // A machine with exactly one interface. Still correct.
            Err(InterfaceError::NoInterface) => assert_eq!(all.len(), only.len()),
            Err(other) => panic!("unexpected: {other}"),
        }
    }

    #[test]
    fn a_name_that_matches_nothing_says_so_and_lists_what_exists() {
        // A mistyped interface name must not look like a machine with no
        // network. The names that do exist travel with the error, so the
        // message says what to write instead.
        let error = usable(&InterfaceFilter {
            loopback: true,
            only: vec!["no-such-interface-42".into()],
            ..InterfaceFilter::everything()
        })
        .expect_err("nothing is named that");
        match error {
            InterfaceError::NoNameMatched { asked, available } => {
                assert_eq!(asked, vec!["no-such-interface-42".to_string()]);
                assert!(!available.is_empty(), "the error named no alternatives");
            }
            other => panic!("expected NoNameMatched, got {other}"),
        }
    }

    #[test]
    fn loopback_is_never_advertised_even_when_it_is_used_for_sending() {
        // The same-host proof runs with loopback ON, and the till must still
        // not publish 127.0.0.1: that address resolves, connects, and reaches
        // the wrong machine.
        let interfaces = vec![
            fake("lo", IpAddr::V4(Ipv4Addr::LOCALHOST)),
            fake("eth0", IpAddr::V4(Ipv4Addr::new(10, 0, 0, 7))),
            fake("lo", IpAddr::V6(Ipv6Addr::LOCALHOST)),
        ];
        assert_eq!(
            advertisable(&interfaces),
            vec![IpAddr::V4(Ipv4Addr::new(10, 0, 0, 7))]
        );
    }

    #[test]
    fn the_same_address_is_advertised_once() {
        let interfaces = vec![
            fake("eth0", IpAddr::V4(Ipv4Addr::new(10, 0, 0, 7))),
            fake("eth0:1", IpAddr::V4(Ipv4Addr::new(10, 0, 0, 7))),
        ];
        assert_eq!(advertisable(&interfaces).len(), 1);
    }
}

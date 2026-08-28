//! The sockets, one per interface, and the options that make them work.
//!
//! # Why one socket per interface and not one socket
//!
//! Two separate reasons, and both were measured rather than assumed.
//!
//! **Sending.** `IP_MULTICAST_IF` is per socket, not per datagram. One socket
//! can therefore be pointed at one interface at a time, and a responder that
//! flips the option between sends races with its own reads. One socket per
//! interface, each pointed at its own, removes the race and makes "sent on
//! every interface" a countable fact — see [`SocketSet::sent_per_interface`].
//!
//! **Receiving.** A socket that joined the group on `eth0` is delivered the
//! datagrams that arrive on `eth0`. So the socket a question came in on *is*
//! the interface it came in on, and the answer can go back out the same door
//! without `IP_PKTINFO` and its three incompatible spellings across
//! Linux, Windows and Apple.
//!
//! # The port is shared, and that is not optional
//!
//! **Chrome holds UDP 5353 on Windows** — measured 2026-08-05, and it holds it
//! from the moment the browser starts. So does `avahi-daemon` on any Linux
//! that has one, and so does `mDNSResponder` on every Mac. Sharing the port is
//! the normal condition of an mDNS responder, not an edge case, and
//! `SO_REUSEADDR` (plus `SO_REUSEPORT` where it exists) is what makes it
//! possible. When it still fails, the failure is reported as `portInUse` with
//! the port in the message rather than as a generic bind error: "something
//! else has 5353" is a sentence an operator can act on.

use std::io;
use std::net::{IpAddr, Ipv4Addr, Ipv6Addr, SocketAddr, SocketAddrV4, SocketAddrV6, UdpSocket};
use std::time::{Duration, Instant};

use socket2::{Domain, Protocol, Socket, Type};

use crate::interfaces::{Interface, InterfaceError, InterfaceFilter};

/// The IPv4 group every mDNS responder listens on.
pub const GROUP_V4: Ipv4Addr = Ipv4Addr::new(224, 0, 0, 251);

/// The IPv6 group, link-local.
pub const GROUP_V6: Ipv6Addr = Ipv6Addr::new(0xff02, 0, 0, 0, 0, 0, 0, 0x00fb);

/// The port, from RFC 6762 §5.
pub const MDNS_PORT: u16 = 5353;

/// RFC 6762 §11: multicast DNS packets carry a TTL of 255, and a receiver may
/// discard a packet that does not. Setting it lower is the kind of default
/// that works on a switch and fails on a router.
const MULTICAST_TTL: u32 = 255;

/// The largest datagram read. RFC 6762 §17 allows up to 9000 octets on a link
/// that carries them; anything longer than this is not a message we can use.
const READ_BUFFER: usize = 9216;

/// How long a read pass sleeps when every socket is empty.
///
/// Not zero: a busy loop over four sockets burns a core. Not 100 ms either —
/// probing works in 250 ms windows (RFC 6762 §8.1), and a granularity of a
/// tenth of that is the difference between a conflict detected and a conflict
/// detected late.
const IDLE_SLEEP: Duration = Duration::from_millis(5);

/// A socket bound for one interface, and what it has done.
pub struct InterfaceSocket {
    /// Which interface this one speaks for.
    pub interface: Interface,
    socket: UdpSocket,
    sent: u64,
    failed: u64,
}

impl InterfaceSocket {
    /// How many datagrams left through this interface.
    pub fn sent(&self) -> u64 {
        self.sent
    }

    /// How many sends this interface refused.
    ///
    /// Counted rather than logged: an interface that went away between
    /// enumeration and now is ordinary and must not stop the others, but an
    /// interface that refuses *every* send is a fault, and only a count tells
    /// the two apart.
    pub fn failed(&self) -> u64 {
        self.failed
    }

    /// The address a reply from this interface appears to come from.
    pub fn address(&self) -> IpAddr {
        self.interface.address
    }
}

/// Every socket a responder or a browser sends and receives through.
pub struct SocketSet {
    sockets: Vec<InterfaceSocket>,
    port: u16,
}

/// Why the sockets could not be opened.
#[derive(Debug)]
pub enum SocketError {
    /// There is no interface to bind for.
    Interfaces(InterfaceError),
    /// The port is held by something that will not share it.
    ///
    /// Distinct from [`SocketError::Bind`] because it is the one an operator
    /// can do something about, and because it is the expected outcome on a
    /// Windows machine with Chrome running and reuse unavailable.
    PortInUse {
        /// The port that could not be shared.
        port: u16,
        /// What the operating system said.
        detail: String,
    },
    /// Binding failed for another reason — no permission, no such address.
    Bind {
        /// What the operating system said.
        detail: String,
    },
    /// Not one interface accepted a socket.
    ///
    /// Separate from [`SocketError::Interfaces`]: there the machine had no
    /// network, here it has one and every attempt on it failed, which is a
    /// different conversation.
    NoInterfaceBound {
        /// One line per interface tried, so the reason is per interface rather
        /// than a single verdict over all of them.
        attempts: Vec<String>,
    },
}

impl std::fmt::Display for SocketError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            SocketError::Interfaces(e) => write!(f, "{e}"),
            SocketError::PortInUse { port, detail } => write!(
                f,
                "UDP port {port} is held by something that will not share it \
                 ({detail}). On Windows Chrome holds 5353 whenever it is \
                 running, and on Linux avahi-daemon does; sharing needs \
                 SO_REUSEADDR, and this bind had it"
            ),
            SocketError::Bind { detail } => write!(f, "the socket could not be bound: {detail}"),
            SocketError::NoInterfaceBound { attempts } => write!(
                f,
                "not one interface accepted a socket: {}",
                attempts.join("; ")
            ),
        }
    }
}

/// What a set of sockets is opened for.
#[derive(Debug, Clone)]
pub struct SocketOptions {
    /// The port to bind. 5353 in use; a private number in tests, so that the
    /// machine's own responder does not answer questions meant for this one.
    pub port: u16,
    /// Which interfaces to take.
    pub filter: InterfaceFilter,
    /// Whether a datagram this host sends is delivered back to this host.
    ///
    /// On for every same-host proof — including the one against `avahi-resolve`
    /// on the machine where multicast does not cross the segment at all — and
    /// on by default besides, because a till's own setup page browses for the
    /// service it is announcing.
    pub loopback: bool,
}

impl Default for SocketOptions {
    fn default() -> Self {
        SocketOptions {
            port: MDNS_PORT,
            filter: InterfaceFilter::everything(),
            loopback: true,
        }
    }
}

impl SocketSet {
    /// Opens one socket per usable interface.
    ///
    /// **There is no fallback to a single default socket, deliberately.** A
    /// datagram sent without `IP_MULTICAST_IF` leaves by exactly one
    /// interface, chosen by the routing table, and on the machine this was
    /// measured on that was a virtual switch. An empty interface list is an
    /// error the caller sees; see `interfaces.rs` for the measurement and
    /// `tests/no_default_send.rs` for the check that goes red if anybody adds
    /// the fallback back.
    pub fn open(options: SocketOptions) -> Result<SocketSet, SocketError> {
        let interfaces =
            crate::interfaces::usable(&options.filter).map_err(SocketError::Interfaces)?;

        let mut sockets = Vec::new();
        let mut attempts = Vec::new();
        let mut port_in_use: Option<String> = None;

        for interface in interfaces {
            match bind_for(&interface, &options) {
                Ok(socket) => sockets.push(InterfaceSocket {
                    interface,
                    socket,
                    sent: 0,
                    failed: 0,
                }),
                Err(error) => {
                    if error.kind() == io::ErrorKind::AddrInUse {
                        port_in_use = Some(error.to_string());
                    }
                    attempts.push(format!(
                        "{} ({}): {error}",
                        interface.name, interface.address
                    ));
                }
            }
        }

        if sockets.is_empty() {
            if let Some(detail) = port_in_use {
                return Err(SocketError::PortInUse {
                    port: options.port,
                    detail,
                });
            }
            return Err(SocketError::NoInterfaceBound { attempts });
        }

        Ok(SocketSet {
            sockets,
            port: options.port,
        })
    }

    /// The port these sockets are bound to.
    pub fn port(&self) -> u16 {
        self.port
    }

    /// How many interfaces are being sent through.
    pub fn len(&self) -> usize {
        self.sockets.len()
    }

    /// Whether the set is empty. It never is — [`SocketSet::open`] refuses to
    /// produce one — and the method exists so clippy's pairing rule is
    /// satisfied without inviting a caller to build one.
    pub fn is_empty(&self) -> bool {
        self.sockets.is_empty()
    }

    /// The interfaces in use, with their send counts.
    pub fn sent_per_interface(&self) -> &[InterfaceSocket] {
        &self.sockets
    }

    /// Every address worth putting in an `A` or `AAAA` record.
    pub fn advertisable(&self) -> Vec<IpAddr> {
        let interfaces: Vec<Interface> = self.sockets.iter().map(|s| s.interface.clone()).collect();
        crate::interfaces::advertisable(&interfaces)
    }

    /// Sends one payload to the group **on every interface**, and reports how
    /// many carried it.
    ///
    /// A per-interface failure is counted and skipped rather than fatal: a
    /// machine with a disconnected Wi-Fi card and a live cable must still
    /// announce on the cable, and that is the ordinary state of a shop till.
    pub fn send_to_group(&mut self, payload: &[u8]) -> usize {
        let mut carried = 0usize;
        for entry in &mut self.sockets {
            let destination = match entry.interface.address {
                IpAddr::V4(_) => SocketAddr::V4(SocketAddrV4::new(GROUP_V4, self.port)),
                IpAddr::V6(_) => SocketAddr::V6(SocketAddrV6::new(
                    GROUP_V6,
                    self.port,
                    0,
                    entry.interface.index,
                )),
            };
            match entry.socket.send_to(payload, destination) {
                Ok(_) => {
                    entry.sent += 1;
                    carried += 1;
                }
                Err(_) => entry.failed += 1,
            }
        }
        carried
    }

    /// Sends one payload straight to one address, out of one interface.
    ///
    /// This is the `QU` reply (RFC 6762 §5.4). It goes out the interface the
    /// question arrived on, which is the only one that can reach the querier.
    pub fn send_unicast(&mut self, interface_index: usize, payload: &[u8], to: SocketAddr) -> bool {
        let Some(entry) = self.sockets.get_mut(interface_index) else {
            return false;
        };
        match entry.socket.send_to(payload, to) {
            Ok(_) => {
                entry.sent += 1;
                true
            }
            Err(_) => {
                entry.failed += 1;
                false
            }
        }
    }

    /// Waits up to `timeout` for a datagram on any interface.
    ///
    /// Returns the bytes, who sent them, and which socket took them — the last
    /// of which is how the reply finds its way back out the same door.
    pub fn recv(&self, timeout: Duration) -> Option<Received> {
        let deadline = Instant::now() + timeout;
        let mut buffer = [0u8; READ_BUFFER];
        loop {
            for (index, entry) in self.sockets.iter().enumerate() {
                match entry.socket.recv_from(&mut buffer) {
                    Ok((read, from)) => {
                        return Some(Received {
                            payload: buffer[..read].to_vec(),
                            from,
                            interface_index: index,
                        });
                    }
                    Err(ref e)
                        if e.kind() == io::ErrorKind::WouldBlock
                            || e.kind() == io::ErrorKind::TimedOut => {}
                    // A datagram that could not be read is not a reason to stop
                    // reading. On Windows an ICMP port-unreachable for an
                    // earlier send surfaces here as ConnectionReset on the next
                    // read, and treating it as fatal would stop the responder
                    // because somebody else's machine refused a packet.
                    Err(_) => {}
                }
            }
            let now = Instant::now();
            if now >= deadline {
                return None;
            }
            std::thread::sleep(IDLE_SLEEP.min(deadline - now));
        }
    }
}

/// One datagram, and where it came from.
pub struct Received {
    /// The bytes.
    pub payload: Vec<u8>,
    /// The sender.
    pub from: SocketAddr,
    /// Which socket in the set took it — that is, which interface it arrived
    /// on.
    pub interface_index: usize,
}

fn bind_for(interface: &Interface, options: &SocketOptions) -> io::Result<UdpSocket> {
    match interface.address {
        IpAddr::V4(address) => bind_v4(address, interface.index, options),
        IpAddr::V6(address) => bind_v6(address, interface.index, options),
    }
}

fn bind_v4(address: Ipv4Addr, index: u32, options: &SocketOptions) -> io::Result<UdpSocket> {
    let socket = Socket::new(Domain::IPV4, Type::DGRAM, Some(Protocol::UDP))?;
    share_the_port(&socket)?;
    // Bound to the wildcard, not to `address`. Binding to a unicast address
    // means multicast is never delivered — the destination is 224.0.0.251 and
    // does not match the bind — which is a socket that sends and never hears,
    // and the failure looks like a network that filters mDNS.
    socket.bind(&SocketAddr::V4(SocketAddrV4::new(Ipv4Addr::UNSPECIFIED, options.port)).into())?;
    socket.set_multicast_if_v4(&address)?;
    socket.set_multicast_ttl_v4(MULTICAST_TTL)?;
    socket.set_multicast_loop_v4(options.loopback)?;
    // Membership is per interface, which is what makes the receiving socket
    // stand for the arriving interface.
    if let Err(error) = socket.join_multicast_v4(&GROUP_V4, &address) {
        // Already a member — another socket in this process joined on the same
        // interface — is not a failure. Anything else is.
        if error.kind() != io::ErrorKind::AddrInUse && error.kind() != io::ErrorKind::AlreadyExists
        {
            return Err(error);
        }
    }
    let _ = index;
    socket.set_nonblocking(true)?;
    Ok(socket.into())
}

fn bind_v6(address: Ipv6Addr, index: u32, options: &SocketOptions) -> io::Result<UdpSocket> {
    let socket = Socket::new(Domain::IPV6, Type::DGRAM, Some(Protocol::UDP))?;
    share_the_port(&socket)?;
    // A dual-stack socket would collide with the IPv4 socket bound to the same
    // port on the same interface, and on Windows the collision is a bind
    // failure rather than a shared bind.
    socket.set_only_v6(true)?;
    socket.bind(
        &SocketAddr::V6(SocketAddrV6::new(Ipv6Addr::UNSPECIFIED, options.port, 0, 0)).into(),
    )?;
    // By index, not by address: `ff02::fb` is link-local, so which link is
    // meant cannot be inferred from the address. `std::net` offers no way to
    // say this, which is one of the reasons this package is native.
    socket.set_multicast_if_v6(index)?;
    socket.set_multicast_hops_v6(MULTICAST_TTL)?;
    socket.set_multicast_loop_v6(options.loopback)?;
    if let Err(error) = socket.join_multicast_v6(&GROUP_V6, index) {
        if error.kind() != io::ErrorKind::AddrInUse && error.kind() != io::ErrorKind::AlreadyExists
        {
            return Err(error);
        }
    }
    let _ = address;
    socket.set_nonblocking(true)?;
    Ok(socket.into())
}

/// `SO_REUSEADDR`, and `SO_REUSEPORT` where the platform has it.
///
/// Both, not either. On Linux and Apple `SO_REUSEADDR` alone is not enough to
/// bind a second socket to a port already bound to the wildcard; on Windows
/// `SO_REUSEPORT` does not exist and `SO_REUSEADDR` alone is what sharing
/// means. Setting them before the bind is not optional — after it they do
/// nothing.
fn share_the_port(socket: &Socket) -> io::Result<()> {
    socket.set_reuse_address(true)?;
    #[cfg(all(unix, not(any(target_os = "solaris", target_os = "illumos"))))]
    socket.set_reuse_port(true)?;
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    /// A port nothing on a developer's machine is using, so the machine's own
    /// responder does not answer questions meant for these tests.
    fn private_port() -> u16 {
        // Derived from the process id so two suites running at once do not
        // collide. Kept out of the ephemeral range that the OS hands out.
        20000 + (std::process::id() % 4000) as u16 * 2
    }

    /// A port for one test, and **only** that test.
    ///
    /// The offset is not tidiness. Measured 2026-08-06 on Ubuntu 26.04: with
    /// two of these tests sharing a port, the loopback delivered one test's
    /// datagram to the other's receiver and the assertion failed on a payload
    /// it had never sent. The same two tests pass on Windows, where the
    /// loopback does not carry between them — so a shared port is a suite that
    /// is correct on one platform by accident.
    fn options(offset: u16) -> SocketOptions {
        SocketOptions {
            port: private_port() + offset,
            filter: InterfaceFilter {
                loopback: true,
                ..InterfaceFilter::everything()
            },
            loopback: true,
        }
    }

    #[test]
    fn a_set_binds_one_socket_per_interface() {
        let set = SocketSet::open(options(0)).expect("this host has interfaces");
        assert!(!set.is_empty());
        // Every socket must know which interface it speaks for. A socket with
        // no interface would be the default-send path wearing a disguise.
        for entry in set.sent_per_interface() {
            assert!(!entry.interface.name.is_empty());
        }
    }

    #[test]
    fn the_port_can_be_bound_twice_in_one_process() {
        // The property the whole package rests on: mDNS shares its port. If
        // this fails on a platform, that platform cannot run a second responder
        // beside the system one, and the failure must be visible here rather
        // than at a customer's till.
        let first = SocketSet::open(options(1)).expect("first bind");
        let second = SocketSet::open(options(1)).expect(
            "the port could not be shared — SO_REUSEADDR/SO_REUSEPORT did not take, and a \
             till cannot coexist with the machine's own responder",
        );
        assert_eq!(first.port(), second.port());
    }

    #[test]
    fn a_datagram_sent_to_the_group_comes_back_on_the_loopback() {
        let mut sender = SocketSet::open(options(2)).expect("sender");
        let receiver = SocketSet::open(options(2)).expect("receiver");

        let payload = b"rk_mdns loopback probe";
        let carried = sender.send_to_group(payload);
        assert!(carried > 0, "not one interface carried the datagram");

        let received = receiver
            .recv(Duration::from_millis(1500))
            .expect("the datagram did not come back on any interface");
        assert_eq!(received.payload, payload);
    }

    #[test]
    fn every_interface_is_counted_separately() {
        let mut set = SocketSet::open(options(3)).expect("a set");
        set.send_to_group(b"one");
        set.send_to_group(b"two");
        for entry in set.sent_per_interface() {
            // Each interface got its own two sends, or refused them. What must
            // never happen is one interface carrying everything while the rest
            // sit at zero — that is the routing-table default in disguise.
            assert_eq!(
                entry.sent() + entry.failed(),
                2,
                "interface {} was not offered both datagrams",
                entry.interface.name
            );
        }
    }
}

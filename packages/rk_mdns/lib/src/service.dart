/// What a caller says, and what it gets told back. Pure Dart, no `dart:ffi`:
/// these types are shared by the native half and the browser half, and the
/// browser half must compile where `dart:ffi` does not exist (И143).
library;

/// The UDP port every mDNS responder on the network listens on.
const int mdnsPort = 5353;

/// What to announce.
class ServiceAnnouncement {
  /// One service, one host.
  const ServiceAnnouncement({
    required this.instanceName,
    required this.serviceType,
    required this.port,
    this.hostName,
    this.txt = const <String>[],
    this.addresses = const <String>[],
    this.interfaces = const <String>[],
    this.excludeInterfaces = const <String>[],
    this.hostTtl = const Duration(minutes: 2),
    this.serviceTtl = const Duration(minutes: 75),
    this.mdnsPort = 5353,
    this.probe = true,
    this.ipv6 = true,
    this.includeLoopbackInterface = false,
    this.multicastLoopback = true,
  });

  /// The instance label — `till-3`. One label: a dot inside it must be
  /// escaped as `\.`, because DNS-SD allows one and splitting it would
  /// announce a service nothing can resolve.
  final String instanceName;

  /// The DNS-SD type — `_telepos._tcp.local`.
  final String serviceType;

  /// The port that goes in the `SRV` record.
  final int port;

  /// The host name to claim. `<instanceName>.local` when null.
  final String? hostName;

  /// `TXT` strings, in order, each usually `key=value`.
  final List<String> txt;

  /// What to put in `A` and `AAAA`. Empty means every address of every
  /// interface the responder came up on.
  final List<String> addresses;

  /// If non-empty, only interfaces with these names are used — for sending and
  /// for the addresses announced.
  ///
  /// ## Why this exists, and why the package will not decide it for you
  ///
  /// **The cost of a spare address is not symmetric.** In a TLS certificate an
  /// `iPAddress` entry is *checked*: a spare one costs nothing, a missing one
  /// costs the handshake, so being generous there is safe. In an mDNS
  /// announcement an address is *tried*: a client works down the list, so a
  /// spare one costs it a connection timeout. The rule here has to be
  /// **stricter** than the certificate's.
  ///
  /// Measured 2026-08-06 on a development machine: four addresses survive the
  /// ordinary filters, and two of them — a Hyper-V switch and a WSL switch —
  /// are unreachable from any client, one timeout each.
  ///
  /// **A rule over the address cannot separate them.** Dropping `172.16/12`
  /// and `10/8` would drop the shop networks this is for. What distinguishes a
  /// virtual switch from a cable is the interface, so the caller names it —
  /// `mdnsInterfaces()` lists what there is, with a name and a prefix.
  ///
  /// A name matching no interface is refused, with the names that do exist in
  /// the message. It is not ignored and it does not fall back to announcing
  /// everything: a typo in a setting must not look like a machine with no
  /// network, and it must not quietly restore the addresses it was written to
  /// remove.
  final List<String> interfaces;

  /// Interfaces with these names are left out. Applied after [interfaces].
  final List<String> excludeInterfaces;

  /// How long a resolver may cache the host and service records.
  ///
  /// Two minutes by default, not the hour DNS-SD suggests for a stable
  /// service: a host that moved by DHCP has to become findable at its new
  /// address without anybody power-cycling a tablet, and the goodbye only
  /// covers the stops that are clean.
  final Duration hostTtl;

  /// How long a resolver may cache the fact that the service exists at all.
  final Duration serviceTtl;

  /// The UDP port. 5353 in use; a private number in tests, so the machine's
  /// own responder does not answer questions meant for this one.
  final int mdnsPort;

  /// Whether to probe for a name conflict before claiming the name
  /// (RFC 6762 §8.1).
  ///
  /// On by default, and turning it off is a decision rather than a
  /// convenience: two hosts answering one name is exactly what probing exists
  /// to make visible.
  final bool probe;

  /// Whether to announce over IPv6 as well.
  final bool ipv6;

  /// Whether to announce on the loopback interface too.
  ///
  /// Needed to prove anything on one host — which on a segment that filters
  /// multicast is the only place a resolver and a responder can meet. The
  /// loopback address itself is still never advertised: it resolves, connects,
  /// and reaches the wrong machine.
  final bool includeLoopbackInterface;

  /// Whether this host receives its own multicast. On by default, because a
  /// till's own setup page browses for the service the till is announcing.
  final bool multicastLoopback;

  /// The JSON the native side reads.
  Map<String, Object?> toJson() => <String, Object?>{
    'instanceName': instanceName,
    'serviceType': serviceType,
    if (hostName != null) 'hostName': hostName,
    'port': port,
    'txt': txt,
    'addresses': addresses,
    'interfaces': interfaces,
    'excludeInterfaces': excludeInterfaces,
    'hostTtlSeconds': hostTtl.inSeconds,
    'serviceTtlSeconds': serviceTtl.inSeconds,
    'mdnsPort': mdnsPort,
    'probe': probe,
    'ipv6': ipv6,
    'loopbackInterface': includeLoopbackInterface,
    'multicastLoopback': multicastLoopback,
  };
}

/// What to browse for.
class BrowseRequest {
  /// One DNS-SD service type.
  const BrowseRequest({
    required this.serviceType,
    this.mdnsPort = 5353,
    this.ipv6 = true,
    this.includeLoopbackInterface = false,
    this.interfaces = const <String>[],
    this.excludeInterfaces = const <String>[],
    this.multicastLoopback = true,
  });

  /// `_telepos._tcp.local`.
  final String serviceType;

  /// The UDP port.
  final int mdnsPort;

  /// Whether to browse over IPv6 as well.
  final bool ipv6;

  /// Whether to listen on the loopback interface too.
  final bool includeLoopbackInterface;

  /// If non-empty, only interfaces with these names are used. See
  /// [ServiceAnnouncement.interfaces].
  final List<String> interfaces;

  /// Interfaces with these names are left out.
  final List<String> excludeInterfaces;

  /// Whether this host receives its own multicast.
  final bool multicastLoopback;

  /// The JSON the native side reads.
  Map<String, Object?> toJson() => <String, Object?>{
    'serviceType': serviceType,
    'mdnsPort': mdnsPort,
    'ipv6': ipv6,
    'loopbackInterface': includeLoopbackInterface,
    'interfaces': interfaces,
    'excludeInterfaces': excludeInterfaces,
    'multicastLoopback': multicastLoopback,
  };
}

/// One `<name>.local` to look up.
class HostQuery {
  /// One name, with a bound on how long to wait.
  const HostQuery({
    required this.hostName,
    this.timeout = const Duration(seconds: 3),
    this.mdnsPort = 5353,
    this.ipv6 = true,
    this.includeLoopbackInterface = false,
    this.interfaces = const <String>[],
    this.excludeInterfaces = const <String>[],
    this.multicastLoopback = true,
  });

  /// `till-3.local`.
  final String hostName;

  /// How long to wait before giving up.
  final Duration timeout;

  /// The UDP port.
  final int mdnsPort;

  /// Whether to ask for `AAAA` as well as `A`.
  final bool ipv6;

  /// Whether to ask on the loopback interface too.
  final bool includeLoopbackInterface;

  /// If non-empty, only interfaces with these names are used.
  final List<String> interfaces;

  /// Interfaces with these names are left out.
  final List<String> excludeInterfaces;

  /// Whether this host receives its own multicast.
  final bool multicastLoopback;

  /// The JSON the native side reads.
  Map<String, Object?> toJson() => <String, Object?>{
    'hostName': hostName,
    'timeoutMs': timeout.inMilliseconds,
    'mdnsPort': mdnsPort,
    'ipv6': ipv6,
    'loopbackInterface': includeLoopbackInterface,
    'interfaces': interfaces,
    'excludeInterfaces': excludeInterfaces,
    'multicastLoopback': multicastLoopback,
  };
}

/// One `key=value` out of a `TXT` record.
class TxtEntry {
  /// A pair as RFC 6763 §6.3 defines it.
  const TxtEntry(this.key, this.value);

  /// Everything before the first `=`.
  final String key;

  /// Everything after it, or empty for an entry with no `=` at all — which
  /// RFC 6763 §6.4 defines as a key that is present with no value, and which
  /// is not the same thing as an absent key.
  final String value;

  @override
  String toString() => value.isEmpty ? key : '$key=$value';

  @override
  bool operator ==(Object other) =>
      other is TxtEntry && other.key == key && other.value == value;

  @override
  int get hashCode => Object.hash(key, value);
}

/// One interface a responder is sending through, and what it has carried.
///
/// This is the evidence behind "sent on every interface". An entry with
/// [sent] at zero while the responder has announced means the datagram is
/// going out one door — which is the failure this package exists to prevent,
/// and the only place it is visible.
class InterfaceReport {
  /// One interface's record.
  const InterfaceReport({
    required this.name,
    required this.address,
    required this.index,
    required this.sent,
    required this.failed,
  });

  /// The operating system's name for it — `eth0`, `Ethernet 2`.
  final String name;

  /// The address it sends from.
  final String address;

  /// The interface index, which is what an IPv6 link-local group needs.
  final int index;

  /// Datagrams that left through it.
  final int sent;

  /// Sends it refused. An interface that went away between enumeration and
  /// now is ordinary; one that refuses every send is a fault, and only the
  /// two counts together tell them apart.
  final int failed;

  /// Reads what the native side wrote.
  factory InterfaceReport.fromJson(Map<String, Object?> json) =>
      InterfaceReport(
        name: _text(json['name']),
        address: _text(json['address']),
        index: _int(json['index']),
        sent: _int(json['sent']),
        failed: _int(json['failed']),
      );

  @override
  String toString() =>
      'InterfaceReport($name $address, sent: $sent, failed: $failed)';
}

/// What a responder ended up with.
class ResponderState {
  /// The names, the addresses, and the interfaces.
  const ResponderState({
    required this.instance,
    required this.host,
    required this.addresses,
    required this.claimed,
    required this.interfaces,
  });

  /// The instance name **actually claimed**, after any rename.
  ///
  /// Compare it with what was asked for. A difference means two hosts are
  /// configured with one name, which is a setup mistake and has to be visible
  /// rather than inferred from a tablet reaching the wrong one.
  final String instance;

  /// The host name actually claimed.
  final String host;

  /// What the `A` and `AAAA` records carry.
  final List<String> addresses;

  /// Whether probing has finished and the name is held.
  final bool claimed;

  /// One entry per interface.
  final List<InterfaceReport> interfaces;

  /// Reads what the native side wrote.
  factory ResponderState.fromJson(Map<String, Object?> json) => ResponderState(
    instance: _text(json['instance']),
    host: _text(json['host']),
    addresses: _strings(json['addresses']),
    claimed: _flag(json['claimed']),
    interfaces: _interfaces(json['interfaces']),
  );

  @override
  String toString() =>
      'ResponderState($instance at $host, claimed: $claimed, '
      'addresses: $addresses, interfaces: ${interfaces.length})';
}

/// One network interface this host could announce on.
class MdnsInterface {
  /// Everything known about one address on one interface.
  const MdnsInterface({
    required this.name,
    required this.address,
    required this.netmask,
    required this.prefix,
    required this.index,
    required this.loopback,
  });

  /// The operating system's name for it — `eth0`, `Ethernet 2`,
  /// `vEthernet (WSL)`.
  ///
  /// This is what [ServiceAnnouncement.interfaces] matches on, and the reason
  /// this type carries more than an address: no rule over the address itself
  /// can tell a virtual switch from a shop's own `172.16/12` network.
  final String name;

  /// The address.
  final String address;

  /// The netmask.
  final String netmask;

  /// The CIDR prefix length — `24` for a `/24`.
  ///
  /// The one figure that says which addresses this interface reaches without a
  /// router, which is what a caller deciding whether to announce on it wants.
  final int prefix;

  /// The interface index, which is what an IPv6 link-local group needs.
  final int index;

  /// Whether this is the loopback interface.
  final bool loopback;

  /// Reads what the native side wrote.
  factory MdnsInterface.fromJson(Map<String, Object?> json) => MdnsInterface(
    name: _text(json['name']),
    address: _text(json['address']),
    netmask: _text(json['netmask']),
    prefix: _int(json['prefix']),
    index: _int(json['index']),
    loopback: _flag(json['loopback']),
  );

  @override
  String toString() => 'MdnsInterface($name $address/$prefix #$index)';
}

/// What a host lookup found.
class HostAddresses {
  /// The name asked about and what answered.
  const HostAddresses({required this.host, required this.addresses});

  /// The name asked about.
  final String host;

  /// What answered, in the order the records arrived.
  ///
  /// Empty is an answer, not a failure: on a network that filters multicast it
  /// is the expected one, and turning it into an exception would leave a
  /// filtered network indistinguishable from a broken call.
  final List<String> addresses;

  /// Reads what the native side wrote.
  factory HostAddresses.fromJson(Map<String, Object?> json) => HostAddresses(
    host: _text(json['host']),
    addresses: _strings(json['addresses']),
  );

  /// Whether anything answered.
  bool get isEmpty => addresses.isEmpty;

  @override
  String toString() => 'HostAddresses($host -> $addresses)';
}

// Every field above is read leniently, and that is not laziness about types.
//
// This reads JSON that crossed an FFI boundary and an isolate port. A cast
// that threw would take a whole event stream down over one surprising field,
// and the caller would lose every later event for a value it might not even
// have read. An empty string is recoverable; a dead stream is not.

int _int(Object? value) => value is num ? value.toInt() : 0;

String _text(Object? value) => value is String ? value : '';

bool _flag(Object? value) => value is bool && value;

List<String> _strings(Object? value) => value is List<Object?>
    ? value.map((e) => e.toString()).toList(growable: false)
    : const <String>[];

List<InterfaceReport> _interfaces(Object? value) {
  if (value is! List<Object?>) return const <InterfaceReport>[];
  return value
      .whereType<Map<Object?, Object?>>()
      .map((e) => InterfaceReport.fromJson(e.cast<String, Object?>()))
      .toList(growable: false);
}

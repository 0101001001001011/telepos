/// Which addresses this machine is reachable at, from this machine's point of
/// view.
///
/// # Why this is its own file
///
/// Two callers need the same answer and must not disagree about it: the
/// certificate is issued for these addresses (`iPAddress` alternative names)
/// and the mDNS announcement offers these addresses as `A` records. A terminal
/// that resolved one address and got a certificate naming another would fail
/// the handshake, and the reason would look like a certificate problem while
/// being a bookkeeping one.
library;

import 'dart:io';

/// The IPv4 addresses of this machine's real interfaces.
///
/// # What is left out, and why each one
///
/// * **Loopback.** Announcing `127.0.0.1` to the network tells a tablet to
///   look for the till inside itself.
/// * **Link-local (`169.254/16`).** These exist when DHCP did not answer.
///   Offering one says "I have an address" at exactly the moment the machine
///   effectively has none.
/// * **IPv6.** Not excluded on principle — excluded because nothing in this
///   deployment has been tested on it, and an address in a certificate that
///   nobody has ever connected to is a claim, not a capability. It goes in the
///   day somebody measures it.
///
/// Never throws: on a machine with no network at all this is an empty list,
/// which is the truth, and the callers treat it as one — a till with no
/// addresses is reachable by name or not at all.
Future<List<String>> localIPv4Addresses() async {
  try {
    final interfaces = await NetworkInterface.list(
      includeLoopback: false,
      includeLinkLocal: false,
      type: InternetAddressType.IPv4,
    );
    return <String>[
      for (final interface in interfaces)
        for (final address in interface.addresses)
          if (!address.isLoopback && !_isLinkLocal(address.address))
            address.address,
    ];
  } on Object {
    // A machine that will not enumerate its interfaces is a machine with no
    // addresses to offer. Saying so beats refusing to start the till.
    return const <String>[];
  }
}

/// `169.254.0.0/16` — what an interface gets when DHCP did not answer.
///
/// Checked here as well as through `includeLinkLocal: false`, and the
/// duplication is deliberate rather than measured: the flag's behaviour across
/// the six platforms has not been verified here, and the cost of being wrong
/// is asymmetric. A redundant check costs a string comparison; a link-local
/// address that slipped through goes into a certificate that then lives seven
/// days and into an announcement a tablet believes.
bool _isLinkLocal(String address) => address.startsWith('169.254.');

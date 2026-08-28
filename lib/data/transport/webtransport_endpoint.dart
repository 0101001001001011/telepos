/// The till's WebTransport listener: the half that lets this machine speak
/// first.
///
/// # What this changes, and what it does not
///
/// The browser terminal used to reach this till over HTTP
/// (`lib/backend/api_server.dart` on TCP 8787, `lib/web/api_client.dart` on the
/// other side), and every one of those exchanges began with the browser
/// asking. That is the whole limitation this file exists to lift: a print job
/// that failed, a device that appeared, a shift somebody else closed — under
/// polling they arrive at the next question, and here they arrive when they
/// happen.
///
/// Both of those files are gone: the client on 2026-08-04, the data routes on
/// 2026-08-05, once nothing was left calling them. What survives on TCP 8787 is
/// the page itself — the document, the bundle and the fonts a browser has to
/// download before it can construct a `WebTransport` at all — so the HTTP
/// server stays and this is a second socket beside it, not instead of it.
///
/// There is no fallback path any more, by the customer's decision of
/// 2026-08-04: a browser that cannot raise a QUIC session gets a named reason
/// on screen (`WtUnavailableScreen`), never a blank one. The till itself goes
/// on selling regardless — nothing about taking money runs over this socket.
///
/// # Why it is in `lib/data/`
///
/// `package:rk_quic` imports `dart:ffi`. Section 3а, and
/// `flutter build web -t lib/web/main_web.dart` is what keeps it honest.
///
/// # The two things that are not obvious
///
/// * **UDP.** QUIC is not TCP. This opens a second port, which means a second
///   firewall rule on the till and a second address wherever a terminal is
///   pointed at this machine.
/// * **The certificate is short-lived on purpose.** A browser pinning
///   `serverCertificateHashes` refuses anything valid for fourteen days or
///   more, so the leaf is a seven-day one from `rk_pki` and the endpoint has
///   to be restarted with a fresh one before it lapses. [certificateExpiry]
///   is what the caller watches to do that.
library;

import 'dart:async';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:rk_quic/rk_quic.dart';
import 'package:telepos/core/net/listen_scope.dart';
import 'package:telepos/data/pki/till_certificates.dart';

/// A listener that came up, with the facts a browser needs to reach it.
class WebTransportEndpoint {
  WebTransportEndpoint._(
    this.servers,
    this.port,
    this.certificateExpiry,
    this.certificateFingerprintSha256,
    this.bindFailures,
  );

  /// The listeners themselves, for whoever answers on them.
  ///
  /// A list because a scope can need more than one socket: no single socket
  /// covers both loopbacks — `::1` does not accept a connection to
  /// `127.0.0.1`, measured — so [ListenScope.loopback] is two. They share a
  /// port; see [startWebTransport].
  ///
  /// Exposed because answering is not this class's job: this one binds sockets
  /// and holds a certificate, `TillWire` holds the conversation, and the split
  /// is deliberate — the certificate has to be rotated on a timer that has
  /// nothing to do with what any exchange is saying. The lifetime stays here:
  /// [stop] is what ends the listeners, never the wire.
  final List<QuicServer> servers;

  /// Addresses that could not be taken, each with its reason.
  ///
  /// Empty in the ordinary case. Non-empty when one family fell away and
  /// another came up: the endpoint works, so refusing outright would be worse
  /// — but staying silent about it is how "the terminal will not connect"
  /// becomes a question with no evidence behind it. A value, not a throw
  /// (И144).
  final List<String> bindFailures;

  /// The UDP port actually bound. Asking for 0 lets the operating system
  /// choose, and this is where the choice is reported.
  final int port;

  /// When the presented certificate stops being accepted.
  final DateTime certificateExpiry;

  /// What the browser must pin to open a session at all.
  ///
  /// Goes into the served document the same way the session token already
  /// does — see `api_server.dart`'s frontend handler. A page that had to be
  /// told this by hand would be a page whose trust decision came from a human
  /// copying a hex string, which is worse than no pinning.
  final String certificateFingerprintSha256;

  /// Events as they happen — sessions opening and closing, datagrams, stream
  /// messages, and the endpoint's own failures — from every listener at once.
  ///
  /// Merged rather than per-socket because which family a browser arrived on
  /// is not a fact anything upstream acts on: a session is a session. Built
  /// once and held, not assembled per read: a getter that subscribed on every
  /// call would add a subscription per caller and never drop one.
  late final Stream<QuicEvent> events = _merged(servers);

  static Stream<QuicEvent> _merged(List<QuicServer> servers) {
    if (servers.length == 1) return servers.single.events;
    // Broadcast because that is what `QuicServer.events` already is, and a
    // single-subscription merge would refuse the second listener rather than
    // say why.
    final merged = StreamController<QuicEvent>.broadcast();
    for (final server in servers) {
      server.events.listen(merged.add, onError: merged.addError);
    }
    return merged.stream;
  }

  Future<void> stop() async {
    for (final server in servers) {
      await server.stop();
    }
  }
}

/// Why the endpoint is not listening, when it is not.
///
/// A value rather than an exception, and the reason is not style: "the port is
/// taken" and "there is no native library here" are ordinary conditions on a
/// till, and neither is worth stopping a shift over. The sentence is written
/// into the local log so the state is readable rather than silent.
class WebTransportUnavailable {
  const WebTransportUnavailable(this.reason);

  final String reason;

  @override
  String toString() => reason;
}

/// Binds the WebTransport listener for this till.
///
/// Returns a [WebTransportEndpoint] or a [WebTransportUnavailable]; never
/// throws, never returns null.
///
/// # Why the leaf comes in rather than being asked for here
///
/// The same leaf has to be presented by two listeners — this one and the HTTPS
/// server that hands the browser its page — and the caller is the only place
/// that sees both. Asking `TillCertificates` twice would work today and stop
/// working the moment a renewal fell between the two calls: the page would be
/// served under one certificate while the fingerprint written *into* that page
/// belonged to another, and the browser would refuse the session with nothing
/// on either side saying why.
///
/// It also keeps the page reachable when this listener is not: a till with no
/// QUIC still has to serve the screen that says so.
///
/// [scope] defaults to the loopback because that is the safe default, not
/// because it is the deployment: a terminal on another machine needs this bound
/// wider **and** the leaf issued for the name and address that machine will
/// use — a decision about the shop's network, which the caller makes.
///
/// # Why a scope and not an address
///
/// It used to be `bindAddress: '127.0.0.1'`, and the string was the defect. A
/// listener on one family is invisible to a browser that resolved the till's
/// name to the other, and it is invisible *silently*: measured 2026-08-06,
/// Chrome reported `QUIC_NETWORK_IDLE_TIMEOUT` with
/// `num_undecryptable_packets: 0` — it sent and heard nothing back — while
/// `curl` answered 200 through every address, because it picks a family
/// differently. See [ListenScope].
Future<Object> startWebTransport({
  required WebTransportCredential credential,
  ListenScope scope = ListenScope.loopback,
  int port = 0,
  String path = '/rk',
  Duration idleTimeout = const Duration(seconds: 30),
}) async {
  final leaf = credential;
  final servers = <QuicServer>[];
  final failures = <String>[];

  Future<void> bind(String address) async {
    // The port comes from whichever socket came up first, not from [port]: at
    // 0 the system picks, and the other family has to land on the same number
    // — the page carries one port to the browser, and a browser that reached
    // the till by the other name would otherwise be sent to a closed one.
    final wanted = servers.isEmpty ? port : servers.first.port;
    final QuicServerStart start;
    try {
      start = await QuicServer.start(
        QuicServerConfig(
          bindAddress: '$address:$wanted',
          certificateChainPem: leaf.chainPem,
          privateKeyPem: leaf.privateKeyPem,
          path: path,
          // И153. There is no value meaning "never", and that is deliberate: a
          // cashier's laptop lid closed on an open session sends nothing, and
          // without a bound the endpoint would hold that session and go on
          // believing somebody is there.
          idleTimeout: idleTimeout,
        ),
      );
    } on Object catch (error) {
      // The package answers with values, but a library that failed to load in
      // an unforeseen way must not take the till down either.
      failures.add('$address:$wanted — threw: $error');
      return;
    }

    final server = start.server;
    if (server == null) {
      failures.add('$address:$wanted — ${start.status.name}');
      return;
    }
    servers.add(server);
  }

  for (final address in quicAddressesFor(scope)) {
    await bind(address);
  }
  if (servers.isEmpty) {
    // Only when nothing at all came up — a host with IPv6 switched off, where
    // `[::]` does not bind. On a healthy host `0.0.0.0` over an already-bound
    // `::` would be refused as taken, so trying it unconditionally would put a
    // false line in [WebTransportEndpoint.bindFailures] on every start.
    for (final address in quicFallbackAddressesFor(scope)) {
      await bind(address);
    }
  }

  if (servers.isEmpty) {
    return WebTransportUnavailable(
      'the QUIC endpoint did not start: ${failures.join('; ')}',
    );
  }

  return WebTransportEndpoint._(
    servers,
    servers.first.port,
    leaf.notAfter,
    leaf.fingerprintSha256,
    List.unmodifiable(failures),
  );
}

/// The addresses this scope has to take, in `rk_quic`'s spelling.
///
/// Two for the loopback, and that is measured rather than cautious: a socket
/// on `::1` does not receive anything sent to `127.0.0.1`. One for
/// [ListenScope.everywhere], because `[::]` is bound with `IPV6_V6ONLY` off
/// (rk_quic asks for it explicitly — the OS default differs by OS, and on
/// Windows it is on) and then covers IPv4 too.
///
/// Visible so a test can hold it to that, because nothing else can: the
/// listener itself needs the native library, and a `flutter test` has none.
/// Without this the table could go back to a single `0.0.0.0` and every test
/// in the suite would stay green.
@visibleForTesting
List<String> quicAddressesFor(ListenScope scope) => switch (scope) {
  ListenScope.loopback => const ['[::1]', '127.0.0.1'],
  ListenScope.everywhere => const ['[::]'],
};

/// What to fall back to when nothing in [quicAddressesFor] came up.
///
/// Empty for the loopback: `127.0.0.1` is already required, so there is
/// nothing left to try.
@visibleForTesting
List<String> quicFallbackAddressesFor(ListenScope scope) => switch (scope) {
  ListenScope.loopback => const [],
  ListenScope.everywhere => const ['0.0.0.0'],
};

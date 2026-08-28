@TestOn('vm')
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:rk_mdns/rk_mdns.dart';

import 'support/built_library.dart';

/// The Dart surface against the **real** library, over the real FFI boundary
/// and a real socket.
///
/// Nothing here is mocked, and nothing here skips. `flutter test` does not
/// build a plugin's native part, so a suite that shrugged at a missing library
/// would pass whether the native side works, is broken, or does not exist —
/// which is exactly the green this project has been caught by before.
/// [requireBuiltLibrary] fails the run instead, and says which command fixes
/// it.
void main() {
  late final List<String> library = <String>[
    requireBuiltLibrary(locateBuiltLibrary()),
  ];

  test('the probe reports a loaded library and its version', () {
    final probe = probeNativeLibrary(candidatePaths: library);
    expect(probe.outcome, NativeLoadOutcome.loaded);
    expect(probe.version, crateVersionFromCargoToml());
    expect(probe.abiVersion, rkMdnsAbiVersion);
  });

  test('the interfaces this host would announce on can be listed', () async {
    final found = await mdnsInterfaces(candidatePaths: library);
    expect(found, isNotNull);
    expect(
      found,
      isNotEmpty,
      reason: 'this machine reports no usable interface at all',
    );
    for (final entry in found!) {
      expect(entry.name, isNotEmpty);
      expect(entry.address, isNotEmpty);
    }
  });

  test('an interface carries more than an address', () async {
    // The reason this type is not just a string: in a certificate a spare
    // address is *checked* and costs nothing, in an announcement it is *tried*
    // and costs a client a connection timeout. So the caller has to be able to
    // choose, and no rule over the address can tell a Hyper-V switch from a
    // shop's own 172.16/12 network — only the name can.
    final found = await mdnsInterfaces(
      includeLoopback: true,
      candidatePaths: library,
    );
    expect(found, isNotNull);
    expect(found, isNotEmpty);
    for (final entry in found!) {
      expect(entry.name, isNotEmpty);
      expect(entry.netmask, isNotEmpty, reason: '${entry.name} has no netmask');
      expect(
        entry.prefix,
        greaterThan(0),
        reason: '${entry.name} has no prefix',
      );
    }
    expect(
      found.any((i) => i.loopback),
      isTrue,
      reason: 'includeLoopback: true returned no loopback interface',
    );
  });

  test(
    'a caller can confine the announcement to interfaces it names',
    () async {
      // Deliberately not asking for loopback: on Linux `lo` is first in the
      // list, and confining to it leaves only loopback addresses — which are
      // never advertised, because 127.0.0.1 resolves, connects and reaches the
      // wrong machine. The responder refuses that with a sentence, which is
      // right, and which made the first version of this test pass on Windows
      // and fail on Linux.
      final all = await mdnsInterfaces(candidatePaths: library);
      final chosen = all!.first.name;

      final started = await MdnsResponder.start(
        ServiceAnnouncement(
          instanceName: 'rk-confined',
          serviceType: '_rkdartconfined._tcp.local',
          port: 8443,
          mdnsPort: privatePort(6),
          ipv6: false,
          interfaces: [chosen],
        ),
        candidatePaths: library,
      );
      expect(started.isOk, isTrue, reason: started.toString());

      final state = await started.responder!.state();
      expect(state!.interfaces, isNotEmpty);
      for (final entry in state.interfaces) {
        expect(
          entry.name,
          chosen,
          reason: 'announced on ${entry.name} although only $chosen was named',
        );
      }
      await started.responder!.stop();
    },
    timeout: const Timeout(Duration(seconds: 60)),
  );

  test(
    'an interface name that matches nothing is refused, not ignored',
    () async {
      // A typo in a setting must not fall back to announcing on everything —
      // that would quietly put back the unreachable addresses the setting was
      // written to remove, one client timeout each.
      final started = await MdnsResponder.start(
        ServiceAnnouncement(
          instanceName: 'rk-typo',
          serviceType: '_rkdarttypo._tcp.local',
          port: 8443,
          mdnsPort: privatePort(7),
          ipv6: false,
          interfaces: const ['no-such-interface-42'],
        ),
        candidatePaths: library,
      );
      expect(started.isOk, isFalse);
      expect(started.status, RkMdnsStatus.invalidArgument);
      expect(
        started.detail,
        contains('no-such-interface-42'),
        reason: 'the failure does not name what was asked for',
      );
      expect(
        started.detail,
        contains('this host has'),
        reason: 'the failure does not say which interfaces exist',
      );
    },
  );

  test('an announcement without a name is refused as a value', () async {
    // И144: a failure comes back, it is not thrown. And it is refused before
    // any socket is opened, so a bad name cannot leave a port bound.
    final started = await MdnsResponder.start(
      ServiceAnnouncement(
        instanceName: '   ',
        serviceType: '_rkdart._tcp.local',
        port: 8443,
        mdnsPort: privatePort(0),
      ),
      candidatePaths: library,
    );
    expect(started.isOk, isFalse);
    expect(started.status, RkMdnsStatus.invalidArgument);
    expect(started.responder, isNull);
    expect(started.detail, isNotNull);
  });

  test('a service type that is not one is refused', () async {
    final started = await MdnsResponder.start(
      ServiceAnnouncement(
        instanceName: 'till',
        serviceType: 'local',
        port: 8443,
        mdnsPort: privatePort(1),
      ),
      candidatePaths: library,
    );
    expect(started.status, RkMdnsStatus.invalidArgument);
  });

  test(
    'a responder announces, reports its interfaces, and says goodbye',
    () async {
      final started = await MdnsResponder.start(
        ServiceAnnouncement(
          instanceName: 'rk-dart',
          serviceType: '_rkdart._tcp.local',
          port: 8443,
          txt: const ['quic=4433', 'scheme=https'],
          mdnsPort: privatePort(2),
          ipv6: false,
          includeLoopbackInterface: true,
        ),
        candidatePaths: library,
      );
      expect(started.isOk, isTrue, reason: started.toString());
      final responder = started.responder!;

      // Every event, in order, until the name is claimed.
      final claimed = await responder.events
          .where((e) => e is NameClaimed)
          .cast<NameClaimed>()
          .first
          .timeout(const Duration(seconds: 25));

      expect(claimed.instance, 'rk-dart._rkdart._tcp.local');
      expect(claimed.host, 'rk-dart.local');
      expect(claimed.interfaces, greaterThan(0));
      expect(await responder.hasRequestedName, isTrue);

      final announced = await responder.events
          .where((e) => e is Announced)
          .cast<Announced>()
          .first
          .timeout(const Duration(seconds: 10));
      expect(
        announced.carried,
        greaterThan(0),
        reason: 'the announcement left by no interface at all',
      );

      final state = await responder.state();
      expect(state, isNotNull);
      expect(state!.claimed, isTrue);
      expect(state.instance, 'rk-dart._rkdart._tcp.local');
      expect(state.interfaces, isNotEmpty);
      // The evidence behind "sent on every interface". An entry at zero while
      // the responder has announced means the datagram went out one door.
      for (final entry in state.interfaces) {
        expect(
          entry.sent,
          greaterThan(0),
          reason:
              'interface ${entry.name} (${entry.address}) carried nothing '
              'while the responder had announced',
        );
      }
      // And loopback is never advertised, even though it is being sent on:
      // 127.0.0.1 resolves, connects, and reaches the wrong machine.
      expect(state.addresses, isNot(contains('127.0.0.1')));

      expect(await responder.stop(), RkMdnsStatus.ok);
      // Stopping twice is not an error.
      expect(await responder.stop(), RkMdnsStatus.notRunning);
      // And the handle is gone rather than merely marked.
      expect(await responder.state(), isNull);
    },
    timeout: const Timeout(Duration(seconds: 60)),
  );

  test(
    'a browser finds what a responder announced, and notices it leave',
    () async {
      final port = privatePort(3);
      const service = '_rkdartbrowse._tcp.local';

      final started = await MdnsResponder.start(
        ServiceAnnouncement(
          instanceName: 'rk-found',
          serviceType: service,
          port: 8443,
          txt: const ['quic=4433'],
          mdnsPort: port,
          ipv6: false,
          includeLoopbackInterface: true,
        ),
        candidatePaths: library,
      );
      expect(started.isOk, isTrue, reason: started.toString());

      final browsing = await MdnsBrowser.start(
        BrowseRequest(
          serviceType: service,
          mdnsPort: port,
          ipv6: false,
          includeLoopbackInterface: true,
        ),
        candidatePaths: library,
      );
      expect(browsing.isOk, isTrue, reason: browsing.toString());
      final browser = browsing.browser!;
      final events = browser.events;

      final resolved = await events
          .where((e) => e is ServiceResolved)
          .cast<ServiceResolved>()
          .firstWhere((e) => e.instance == 'rk-found.$service')
          .timeout(const Duration(seconds: 40));

      expect(resolved.host, 'rk-found.local');
      expect(resolved.port, 8443);
      expect(resolved.addresses, isNotEmpty);
      expect(resolved['quic'], '4433');
      expect(resolved['nothing-like-this'], isNull);

      // The goodbye, seen from the other side. Without it the record would sit
      // in this browser's cache for its full two minutes; arriving inside
      // twenty seconds is only possible because it was sent and honoured.
      final lost = events
          .where((e) => e is ServiceLost)
          .cast<ServiceLost>()
          .firstWhere((e) => e.instance == 'rk-found.$service')
          .timeout(const Duration(seconds: 25));
      await started.responder!.stop();
      await lost;

      expect(await browser.stop(), RkMdnsStatus.ok);
    },
    timeout: const Timeout(Duration(seconds: 90)),
  );

  test(
    'a name a responder holds resolves, and one nobody holds answers empty',
    () async {
      final port = privatePort(4);
      final started = await MdnsResponder.start(
        ServiceAnnouncement(
          instanceName: 'rk-resolve',
          serviceType: '_rkdartresolve._tcp.local',
          port: 8443,
          mdnsPort: port,
          ipv6: false,
          includeLoopbackInterface: true,
        ),
        candidatePaths: library,
      );
      expect(started.isOk, isTrue, reason: started.toString());
      await started.responder!.events
          .where((e) => e is NameClaimed)
          .first
          .timeout(const Duration(seconds: 25));

      final found = await resolveHost(
        HostQuery(
          hostName: 'rk-resolve.local',
          timeout: const Duration(seconds: 8),
          mdnsPort: port,
          ipv6: false,
          includeLoopbackInterface: true,
        ),
        candidatePaths: library,
      );
      expect(found, isNotNull);
      expect(found!.host, 'rk-resolve.local');
      expect(found.addresses, isNotEmpty);
      expect(found.addresses, isNot(contains('127.0.0.1')));

      // And a name nobody holds. Empty is an ANSWER — on a network that
      // filters multicast it is the expected one — so it must not throw and
      // must not be null.
      final absent = await resolveHost(
        HostQuery(
          hostName: 'rk-nobody-holds-this.local',
          timeout: const Duration(milliseconds: 1200),
          mdnsPort: port,
          ipv6: false,
          includeLoopbackInterface: true,
        ),
        candidatePaths: library,
      );
      expect(absent, isNotNull);
      expect(absent!.addresses, isEmpty);

      await started.responder!.stop();
    },
    timeout: const Timeout(Duration(seconds: 60)),
  );

  test(
    'a second responder with the same name renames itself, visibly',
    () async {
      // The whole reason to probe. Two hosts named alike is a setup mistake,
      // and a caller has to be able to see it rather than infer it from a
      // client reaching the wrong machine.
      final port = privatePort(5);
      const service = '_rkdartconflict._tcp.local';

      final first = await MdnsResponder.start(
        ServiceAnnouncement(
          instanceName: 'rk-twice',
          serviceType: service,
          port: 8443,
          mdnsPort: port,
          ipv6: false,
          includeLoopbackInterface: true,
        ),
        candidatePaths: library,
      );
      expect(first.isOk, isTrue, reason: first.toString());
      await first.responder!.events
          .where((e) => e is NameClaimed)
          .first
          .timeout(const Duration(seconds: 25));

      // A different service port behind the same name — which is what two
      // hosts on one segment look like, and the only shape RFC 6762 §8.1 calls
      // a conflict. Identical rdata under one name is explicitly not one.
      final second = await MdnsResponder.start(
        ServiceAnnouncement(
          instanceName: 'rk-twice',
          serviceType: service,
          port: 9443,
          mdnsPort: port,
          ipv6: false,
          includeLoopbackInterface: true,
        ),
        candidatePaths: library,
      );
      expect(second.isOk, isTrue, reason: second.toString());

      final conflict = await second.responder!.events
          .where((e) => e is NameConflict)
          .cast<NameConflict>()
          .first
          .timeout(const Duration(seconds: 30));
      expect(conflict.from, 'rk-twice.$service');
      expect(conflict.to, 'rk-twice-2.$service');
      expect(conflict.detail, isNotEmpty);

      expect(
        await second.responder!.hasRequestedName,
        isFalse,
        reason: 'the responder is on a renamed name and says it has its own',
      );
      expect(
        await first.responder!.hasRequestedName,
        isTrue,
        reason: 'the responder that was there first moved as well',
      );

      await second.responder!.stop();
      await first.responder!.stop();
    },
    timeout: const Timeout(Duration(seconds: 90)),
  );
}

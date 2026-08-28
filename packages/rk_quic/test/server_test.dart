@TestOn('vm')
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:rk_quic/rk_quic.dart';

import 'support/built_library.dart';

/// What these tests cover, and what they deliberately do not.
///
/// They exercise the whole Dart path — two helper isolates, the FFI call, the
/// status coming back **by name** — on the cases that need no certificate.
///
/// The cases that do need one (a session opening, the server speaking first, a
/// peer vanishing mid-session, a port already taken) live in
/// `rust/tests/session_lifecycle.rs`, where a fresh certificate is minted per
/// run. That is not a gap being papered over: a checked-in private key would
/// be a private key in the repository, and a certificate valid for the two
/// weeks WebTransport permits would expire and take the suite with it.
void main() {
  late final String? libraryPath = locateBuiltLibrary();

  QuicServerConfig configWith({
    String bindAddress = '127.0.0.1:0',
    String chain =
        '-----BEGIN CERTIFICATE-----\nnot really\n-----END CERTIFICATE-----\n',
    String key =
        '-----BEGIN PRIVATE KEY-----\nnot really\n-----END PRIVATE KEY-----\n',
    Duration idleTimeout = const Duration(seconds: 30),
  }) => QuicServerConfig(
    bindAddress: bindAddress,
    certificateChainPem: chain,
    privateKeyPem: key,
    idleTimeout: idleTimeout,
  );

  group('starting fails as a value, never as an exception (И144)', () {
    test(
      'a bind address with no port is invalidArgument, with a reason',
      () async {
        final path = requireBuiltLibrary(libraryPath);
        final start = await QuicServer.start(
          configWith(bindAddress: '127.0.0.1'),
          candidatePaths: [path],
        );

        expect(start.status, RkQuicStatus.invalidArgument);
        expect(start.server, isNull);
        expect(
          start.detail,
          contains('port'),
          reason: 'the reason must be usable',
        );
      },
    );

    test(
      'a certificate that is not one is badCertificate, not invalidArgument',
      () async {
        final path = requireBuiltLibrary(libraryPath);
        final start = await QuicServer.start(
          configWith(chain: 'plainly not a certificate'),
          candidatePaths: [path],
        );

        // The distinction earns its keep: one of these is a typo in a setting,
        // the other is a certificate that has to be reissued. Merging them would
        // send an operator to the wrong place.
        expect(start.status, RkQuicStatus.badCertificate);
        expect(start.server, isNull);
      },
    );

    test('an idle timeout under a second is refused, and says why', () async {
      final path = requireBuiltLibrary(libraryPath);
      final start = await QuicServer.start(
        configWith(idleTimeout: Duration.zero),
        candidatePaths: [path],
      );

      expect(start.status, RkQuicStatus.invalidArgument);
      expect(
        start.detail,
        contains('never'),
        reason:
            'a caller passing 0 meant "never time out", and must be told '
            'that there is no such setting and why',
      );
    });

    test(
      'no native library at all is unsupported, and nothing throws',
      () async {
        final start = await QuicServer.start(
          configWith(),
          candidatePaths: const ['rk_quic_absent_xyz'],
        );

        expect(start.status, RkQuicStatus.unsupported);
        expect(start.server, isNull);
        expect(start.detail, isNotNull);
      },
    );

    test('nothing about starting throws, whatever the configuration', () async {
      final path = requireBuiltLibrary(libraryPath);
      for (final config in <QuicServerConfig>[
        configWith(bindAddress: ''),
        configWith(bindAddress: ':::::'),
        configWith(bindAddress: '999.999.999.999:1'),
        configWith(chain: ''),
        configWith(key: ''),
      ]) {
        final start = await QuicServer.start(config, candidatePaths: [path]);
        expect(start.isOk, isFalse);
        expect(
          start.status,
          isNot(RkQuicStatus.unrecognised),
          reason:
              'an unrecognised status means a name crossed the boundary '
              'that this build does not know: ${start.detail}',
        );
      }
    });
  });

  group('statuses come back by name across the isolate boundary (И147)', () {
    test('every status a failed start produced is a known variant', () async {
      final path = requireBuiltLibrary(libraryPath);
      final seen = <RkQuicStatus>{};
      seen.add(
        (await QuicServer.start(
          configWith(bindAddress: 'x'),
          candidatePaths: [path],
        )).status,
      );
      seen.add(
        (await QuicServer.start(
          configWith(chain: 'x'),
          candidatePaths: [path],
        )).status,
      );

      expect(seen, isNot(contains(RkQuicStatus.unrecognised)));
      expect(seen, contains(RkQuicStatus.invalidArgument));
      expect(seen, contains(RkQuicStatus.badCertificate));
    });
  });

  group('events resolve by name, and an unknown one stays whole', () {
    test('each known kind becomes its own type', () {
      expect(
        QuicEvent.fromJson(
          '{"kind":"sessionOpened","sessionId":3,'
          '"authority":"till.local","path":"/rk"}',
        ),
        isA<SessionOpened>()
            .having((e) => e.sessionId, 'sessionId', 3)
            .having((e) => e.authority, 'authority', 'till.local'),
      );
      expect(
        QuicEvent.fromJson(
          '{"kind":"sessionClosed","sessionId":3,"reason":"gone"}',
        ),
        isA<SessionClosed>().having((e) => e.reason, 'reason', 'gone'),
      );
      expect(
        QuicEvent.fromJson('{"kind":"datagram","sessionId":3,"utf8":"hi"}'),
        isA<DatagramReceived>().having((e) => e.message, 'message', 'hi'),
      );
      expect(
        QuicEvent.fromJson(
          '{"kind":"streamMessage","sessionId":3,"utf8":"hi"}',
        ),
        isA<StreamMessageReceived>().having((e) => e.message, 'message', 'hi'),
      );
      expect(
        QuicEvent.fromJson('{"kind":"endpointError","message":"boom"}'),
        isA<EndpointError>().having((e) => e.message, 'message', 'boom'),
      );
    });

    test(
      'a kind from a newer library is kept, not guessed at and not dropped',
      () {
        final event = QuicEvent.fromJson('{"kind":"somethingNewer","x":1}');
        expect(event, isA<UnknownQuicEvent>());
        expect((event as UnknownQuicEvent).kind, 'somethingNewer');
        expect(
          event.raw,
          contains('somethingNewer'),
          reason:
              'discarding it would turn a version mismatch into '
              '"the feature does not work"',
        );
      },
    );

    test('a field of the wrong type is absent, not an exception', () {
      // The helper reading these fields is shared by every kind, and it used
      // `as int?` — which throws on a String rather than yielding null. It
      // runs on the poll isolate, where an exception is reported nowhere and
      // stops the transport, so one oddly-typed field would have looked like
      // "events stopped arriving". Found by the bidirectional-event tests.
      expect(
        QuicEvent.fromJson('{"kind":"datagram","sessionId":"three","utf8":7}'),
        isA<DatagramReceived>()
            .having((e) => e.sessionId, 'sessionId', -1)
            .having((e) => e.message, 'message', ''),
      );
      expect(
        QuicEvent.fromJson('{"kind":"sessionOpened","sessionId":[],"path":1}'),
        isA<SessionOpened>().having((e) => e.sessionId, 'sessionId', -1),
      );
    });

    test('malformed JSON is an event, not an exception out of an isolate', () {
      for (final json in <String>['', 'not json', '[]', '{}', '{"kind":7}']) {
        expect(() => QuicEvent.fromJson(json), returnsNormally, reason: json);
        expect(QuicEvent.fromJson(json), isA<UnknownQuicEvent>());
      }
    });
  });
}

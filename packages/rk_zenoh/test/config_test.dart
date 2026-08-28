/// The part a caller reasons about, tested without a native library.
@TestOn('vm')
library;

import 'package:rk_zenoh/rk_zenoh.dart';
import 'package:test/test.dart';

void main() {
  group('enum names', () {
    test('every wire name is distinct and lowercase with underscores', () {
      final names = [
        ...SessionMode.values.map((e) => e.wireName),
        ...CongestionControl.values.map((e) => e.wireName),
        ...Priority.values.map((e) => e.wireName),
        ...SampleKind.values.map((e) => e.wireName),
      ];
      for (final name in names) {
        expect(
          name,
          matches(RegExp(r'^[a-z][a-z_]*$')),
          reason: '$name is not a wire name this package would send',
        );
      }
      expect(
        Priority.values.map((e) => e.wireName).toSet(),
        hasLength(Priority.values.length),
      );
    });

    test('a sample kind is parsed by name, and an unknown one is refused', () {
      expect(SampleKind.parse('put'), SampleKind.put);
      expect(SampleKind.parse('delete'), SampleKind.delete);
      expect(() => SampleKind.parse('Put'), throwsArgumentError);
      expect(
        () => SampleKind.parse('0'),
        throwsArgumentError,
        reason: 'an index must never be accepted where a name belongs',
      );
    });

    test('an error kind is parsed by name and never by position', () {
      expect(RkzErrorKind.parse('timeout'), RkzErrorKind.timeout);
      expect(RkzErrorKind.parse('panic'), RkzErrorKind.panic);
      expect(
        RkzErrorKind.parse('something_new_upstream'),
        RkzErrorKind.unrecognised,
        reason: 'an unknown kind must degrade, not throw while reporting',
      );
      expect(RkzErrorKind.parse('1'), RkzErrorKind.unrecognised);
    });

    test('a transient failure is distinguishable from a real one', () {
      expect(RkzException(RkzErrorKind.timeout, '').isTransient, isTrue);
      expect(RkzException(RkzErrorKind.disconnected, '').isTransient, isTrue);
      expect(RkzException(RkzErrorKind.invalidConfig, '').isTransient, isFalse);
      expect(RkzException(RkzErrorKind.panic, '').isTransient, isFalse);
    });

    test('an unrecognised kind keeps the name it arrived with', () {
      final e = RkzException(
        RkzErrorKind.unrecognised,
        'x',
        wireName: 'something_new_upstream',
      );
      expect(e.toString(), contains('something_new_upstream'));
    });
  });

  group('a pinned identity', () {
    test('is refused without tls, and the reason names the danger', () {
      final config = ZenohConfig(
        identity: const ZenohIdentity.derivedFrom('till-17'),
        connect: ['tcp/10.0.0.2:7447'],
      );
      final refusal = config.refusalReason;
      expect(refusal, isNotNull);
      expect(refusal, contains('TLS'));
      expect(
        refusal,
        contains('first'),
        reason: 'the reason must say why, not merely that it is refused',
      );
    });

    test('is allowed over tls', () {
      final config = ZenohConfig(
        identity: const ZenohIdentity.derivedFrom('till-17'),
        connect: ['tls/shop-3.telepos:7447'],
      );
      expect(config.isAuthenticated, isTrue);
      expect(config.refusalReason, isNull);
    });

    test('is allowed over quic', () {
      final config = ZenohConfig(
        identity: const ZenohIdentity.pinnedTo('a0b'),
        connect: ['quic/shop-3.telepos:7447'],
      );
      expect(config.refusalReason, isNull);
    });

    test('counts mtls material in extra json5 as authentication', () {
      final config = ZenohConfig(
        identity: const ZenohIdentity.derivedFrom('till-17'),
        listen: ['tcp/0.0.0.0:7447'],
        extraJson5:
            '{ transport: { link: { tls: { '
            'root_ca_certificate: "/etc/telepos/ca.pem" } } } }',
      );
      expect(config.isAuthenticated, isTrue);
      expect(config.refusalReason, isNull);
    });

    test('rejects a zenoh id with a leading zero before anything opens', () {
      final config = ZenohConfig(
        identity: const ZenohIdentity.pinnedTo('0a0b'),
        connect: ['tls/shop-3.telepos:7447'],
      );
      expect(
        config.refusalReason,
        contains('zero'),
        reason: 'zenoh stores the id as an integer and refuses a leading 0',
      );
    });

    test('rejects a zenoh id that is not hexadecimal or is too long', () {
      expect(
        ZenohConfig(
          identity: const ZenohIdentity.pinnedTo('zz'),
          connect: ['tls/x:1'],
        ).refusalReason,
        contains('hexadecimal'),
      );
      expect(
        ZenohConfig(
          identity: ZenohIdentity.pinnedTo('a${'b' * 32}'),
          connect: ['tls/x:1'],
        ).refusalReason,
        contains('sixteen bytes'),
      );
      expect(
        ZenohConfig(
          identity: const ZenohIdentity.derivedFrom(''),
          connect: ['tls/x:1'],
        ).refusalReason,
        contains('non-empty'),
      );
    });
  });

  group('an ephemeral identity', () {
    test('needs no tls, because it claims nothing', () {
      final config = ZenohConfig(connect: ['tcp/10.0.0.2:7447']);
      expect(config.isAuthenticated, isFalse);
      expect(config.refusalReason, isNull);
    });
  });

  group('defaults', () {
    test('multicast scouting is off, because it only works on one lan', () {
      expect(ZenohConfig().multicastScouting, isFalse);
      expect(ZenohConfig().gossipScouting, isTrue);
    });

    test('endpoint lists cannot be mutated behind the config', () {
      final endpoints = ['tcp/1.2.3.4:7447'];
      final config = ZenohConfig(connect: endpoints);
      endpoints.add('tcp/evil:1');
      expect(config.connect, hasLength(1));
      expect(() => config.connect.add('tcp/evil:1'), throwsUnsupportedError);
    });
  });

  group('library lookup', () {
    test('names the platform file and reports every path it tried', () {
      expect(defaultLibraryFileName(), contains('rk_zenoh'));
      expect(defaultLibrarySearchPaths(), isNotEmpty);
      final e = RkzLibraryNotFound({'/nowhere/librk_zenoh.so': 'no such file'});
      expect(e.toString(), contains('/nowhere/librk_zenoh.so'));
      expect(
        e.toString(),
        contains('no such file'),
        reason: 'a support call starts with where it looked and what failed',
      );
    });
  });
}

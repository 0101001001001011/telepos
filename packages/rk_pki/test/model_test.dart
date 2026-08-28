import 'package:rk_pki/rk_pki.dart';
import 'package:test/test.dart';

void main() {
  group('names, never indices', () {
    test('profiles round trip through their wire names', () {
      for (final profile in CertProfile.values) {
        expect(CertProfile.tryParse(profile.wireName), profile);
      }
    });

    test('an index is not a profile', () {
      for (final text in <String>['0', '1', 'Machine', 'browserfacing', '']) {
        expect(CertProfile.tryParse(text), isNull, reason: text);
      }
    });

    test('machine kinds round trip, and nothing else parses', () {
      for (final kind in MachineKind.values) {
        expect(MachineKind.tryParse(kind.wireName), kind);
      }
      expect(MachineKind.tryParse('0'), isNull);
      expect(MachineKind.tryParse('server'), isNull);
    });

    test('the wire name is spelled out, not derived from the constant', () {
      // If someone renames the Dart constant, the protocol must not follow it
      // silently — this test is what makes that a compile-time chore rather
      // than a field incident.
      expect(CertProfile.machine.wireName, 'machine');
      expect(CertProfile.browserFacing.wireName, 'browserFacing');
      expect(MachineKind.shopServer.wireName, 'shopServer');
      expect(MachineKind.relayClient.wireName, 'relayClient');
    });
  });

  group('CertificateInfo', () {
    final json = <String, Object?>{
      'subjectMachineId': 'till-17',
      'installationId': 'inst-1',
      'machineKind': 'till',
      'profile': 'browserFacing',
      'notBefore': 1800000000,
      'notAfter': 1800604800,
      'fingerprintSha256': 'ab' * 32,
      'serial': '01ff',
      'dnsNames': <Object?>['till-17.local', 42],
      'ipAddresses': <Object?>['192.168.1.50', true],
      'isCa': false,
    };

    test('reads what the native side wrote', () {
      final info = CertificateInfo.fromJson(json);
      expect(info.subjectMachineId, 'till-17');
      expect(info.machineKind, MachineKind.till);
      expect(info.profile, CertProfile.browserFacing);
      expect(info.notAfter.toUtc().year, 2027);
      expect(info.dnsNames, <String>['till-17.local']);
      expect(info.ipAddresses, <String>['192.168.1.50']);
      expect(info.isCa, isFalse);
    });

    test('names and addresses do not bleed into one another', () {
      // Two lists rather than one, because a client matching an address URL
      // reads only the second. If these merged, a caller could not tell a
      // certificate that works by address from one that only looks like it.
      final info = CertificateInfo.fromJson(json);
      expect(info.dnsNames, isNot(contains('192.168.1.50')));
      expect(info.ipAddresses, isNot(contains('till-17.local')));
    });

    test('an older library that says nothing about addresses gives none', () {
      // `ipAddresses` is absent from every answer written before 0.4.0. The
      // honest reading is "no addresses" — inventing one here would put an
      // address on a health screen that no certificate actually carries.
      final withoutAddresses = Map<String, Object?>.from(json)
        ..remove('ipAddresses');
      expect(CertificateInfo.fromJson(withoutAddresses).ipAddresses, isEmpty);
    });

    test('a certificate that is not ours leaves the fields empty', () {
      final info = CertificateInfo.fromJson(<String, Object?>{
        'subjectMachineId': 'some.host',
        'installationId': 'Acme Ltd',
        'notBefore': 0,
        'notAfter': 0,
        'fingerprintSha256': '',
        'serial': '',
        'dnsNames': <Object?>[],
        'isCa': true,
      });
      expect(info.machineKind, isNull);
      expect(info.profile, isNull);
      expect(info.isCa, isTrue);
    });

    test('expiry is asked about, not assumed', () {
      final info = CertificateInfo.fromJson(json);
      final before = DateTime.fromMillisecondsSinceEpoch(
        1800604799 * 1000,
        isUtc: true,
      );
      final after = DateTime.fromMillisecondsSinceEpoch(
        1800604801 * 1000,
        isUtc: true,
      );
      expect(info.isExpiredAt(before), isFalse);
      expect(info.isExpiredAt(after), isTrue);
      expect(info.remainingAt(before), const Duration(seconds: 1));
    });
  });

  group('CertificateStatus', () {
    test('an expired certificate blocks sessions and nothing else', () {
      final status = CertificateStatus.fromJson(<String, Object?>{
        'present': true,
        'profile': 'machine',
        'expired': true,
        'revoked': false,
        'notYetValid': false,
        'rotateAt': 1800000000,
        'rotationDue': true,
        'secondsRemaining': -86400,
        'blocksNewSessions': true,
        'tearsDownOpenSessions': false,
        'stopsSelling': false,
      });
      expect(status.expired, isTrue);
      expect(status.blocksNewSessions, isTrue);
      expect(status.tearsDownOpenSessions, isFalse);
      expect(status.stopsSelling, isFalse);
      expect(status.isSecurityEvent, isTrue);
      expect(status.secondsRemaining, -86400);
    });

    test('a missing certificate is present:false, not an exception', () {
      final status = CertificateStatus.fromJson(<String, Object?>{
        'present': false,
        'profile': 'machine',
        'expired': false,
        'rotationDue': true,
        'blocksNewSessions': true,
        'tearsDownOpenSessions': false,
      });
      expect(status.present, isFalse);
      expect(status.info, isNull);
      expect(status.rotateAt, isNull);
      expect(status.stopsSelling, isFalse);
    });
  });

  group('PkiConfig', () {
    PkiConfig config({
      String installation = 'inst-1',
      String machine = 'till-17',
      String dir = '/tmp/pki',
    }) => PkiConfig(
      storeDirectory: dir,
      installationId: installation,
      machineId: machine,
      machineKind: MachineKind.till,
    );

    test('a good configuration passes and encodes by name', () {
      expect(config().validate(), isNull);
      expect(config().toJson()['machineKind'], 'till');
    });

    test('identifiers that would break the identity URN are refused', () {
      expect(config(machine: 'till:17').validate(), isA<BadRequest>());
      expect(config(machine: '').validate(), isA<BadRequest>());
      expect(config(installation: 'a b').validate(), isA<BadRequest>());
      expect(config(machine: 'x' * 65).validate(), isA<BadRequest>());
      expect(config(dir: '').validate(), isA<BadRequest>());
    });
  });
}

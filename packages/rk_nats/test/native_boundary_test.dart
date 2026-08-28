/// What the Dart side and the native library agree on, checked by asking the
/// library rather than by remembering.
///
/// Tagged `native`. Needs the library built; run
/// `cargo build --release` in `rust/` first, then `dart test`.
@Tags(['native'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:rk_nats/rk_nats.dart';
import 'package:rk_nats/src/native_library.dart';
import 'package:test/test.dart';

import 'support/library.dart';

void main() {
  final path = findNativeLibrary();
  if (path == null) {
    // A test that quietly passes without the library would report that the
    // boundary was checked when nothing was. It says what to type instead.
    test('native boundary', () {}, skip: buildTheLibraryFirst);
    return;
  }

  late RkNatsNativeLibrary library;
  setUpAll(() => library = RkNatsNativeLibrary.open(path));

  group('the boundary', () {
    test('exports every symbol this binding names', () {
      // Opening already checks this, so reaching here is the assertion. The
      // point is that a renamed export fails at load rather than at the first
      // publish of the day.
      expect(RkNatsSymbols.all, isNotEmpty);
      expect(RkNatsSymbols.all, contains('rk_nats_publish'));
    });

    test('refuses a library that is not this one', () {
      expect(
        () => RkNatsNativeLibrary.open('definitely-not-here.dll'),
        throwsA(isA<RkNatsLibraryUnavailable>()),
      );
      // Something that exists and is a valid library but is not ours: the
      // package's own pubspec is not a shared object at all, and the failure
      // must still be a named exception rather than a crash.
      expect(
        () => RkNatsNativeLibrary.open('pubspec.yaml'),
        throwsA(isA<RkNatsLibraryUnavailable>()),
      );
    });

    test('turns a native panic into a code and stays usable (I144)', () {
      final reply = library.call('rk_nats_panic_for_test', const {});
      expect(reply['code'], 'panic');
      expect(reply['message'], contains('deliberate panic'));

      // The other half of the evidence: the process is still here, and so is
      // the library.
      final after = library.call('rk_nats_vocabulary', const {});
      expect(after['code'], 'ok');
    });

    test('turns an unknown handle into a code, not a crash', () {
      final reply = library.call('rk_nats_close', const {'handle': 999999});
      expect(reply['code'], 'handleClosed');
    });

    test('speaks the ABI this binding was written against', () {
      final reply = library.call('rk_nats_vocabulary', const {});
      expect(reply['abiVersion'], rkNatsExpectedAbiVersion);
    });
  });

  group('the vocabulary', () {
    test('has a name for every code this binding knows', () {
      final reply = library.call('rk_nats_vocabulary', const {});
      final fromLibrary = (reply['codes']! as List<Object?>).cast<String>();
      for (final name in rkNatsKnownCodeNames) {
        expect(
          fromLibrary,
          contains(name),
          reason:
              'this binding knows $name and the library does not: one of '
              'the two was edited alone',
        );
      }
    });

    test('has a name for every code, and every one is a name', () {
      final reply = library.call('rk_nats_vocabulary', const {});
      final names = [
        ...(reply['codes']! as List<Object?>).cast<String>(),
        ...(reply['policies']! as List<Object?>).cast<String>(),
        ...(reply['ackMeanings']! as List<Object?>).cast<String>(),
      ];
      for (final name in names) {
        expect(int.tryParse(name), isNull, reason: '$name is a number (I147)');
      }
    });

    test('lists exactly the policies this binding offers', () {
      final reply = library.call('rk_nats_vocabulary', const {});
      final fromLibrary = (reply['policies']! as List<Object?>).cast<String>();
      expect(fromLibrary, RkNatsDurability.values.map((p) => p.name).toList());
    });

    test('lists exactly the ack meanings this binding offers', () {
      final reply = library.call('rk_nats_vocabulary', const {});
      final fromLibrary = (reply['ackMeanings']! as List<Object?>)
          .cast<String>();
      expect(
        fromLibrary..sort(),
        RkNatsAckMeaning.values.map((m) => m.name).toList()..sort(),
      );
    });
  });

  group('the mirror of the durability rules', () {
    // The rules live in the native library. The Dart copy exists so a caller
    // can reason about an ack without a round trip. That is only safe while the
    // two agree, so the two are compared rather than trusted.
    for (final lagNanos in <int>[0, 1000000000, 300000000000]) {
      for (final serverIntervalNanos in <int?>[null, 120000000000, 1000000]) {
        test('agrees for lag $lagNanos ns and server interval '
            '$serverIntervalNanos ns', () {
          final reply = library.call('rk_nats_gate_matrix', {
            'acceptedFsyncLagNanos': lagNanos,
            'serverSyncIntervalNanos': serverIntervalNanos,
          });
          expect(reply['code'], 'ok');

          final server = serverIntervalNanos == null
              ? null
              : RkNatsServerDurability(
                  version: 'matrix',
                  syncAlways: false,
                  syncInterval: Duration(
                    microseconds: serverIntervalNanos ~/ 1000,
                  ),
                  storeDir: '',
                );

          final rows = (reply['rows']! as List<Object?>)
              .cast<Map<String, Object?>>();
          expect(
            rows,
            hasLength(
              RkNatsDurability.values.length * RkNatsAckMeaning.values.length,
            ),
          );

          for (final row in rows) {
            final policy = RkNatsDurability.values.firstWhere(
              (p) => p.name == row['policy'],
            );
            final meaning = RkNatsAckMeaning.values.firstWhere(
              (m) => m.name == row['meaning'],
            );
            final fromDart = rkNatsGate(
              policy: policy,
              meaning: meaning,
              acceptedFsyncLag: Duration(microseconds: lagNanos ~/ 1000),
              server: server,
            );
            expect(
              (fromDart ?? RkNatsCode.ok).name,
              row['code'],
              reason: 'the two sides disagree about $policy against $meaning',
            );
          }
        });
      }
    }
  });

  group('evaluating a captured varz', () {
    test('reads a real fsync-always document as fsynced to disk', () async {
      final varz = File(
        'rust/fixtures/varz_2_14_4_sync_always.json',
      ).readAsStringSync();
      final result = await rkNatsEvaluateVarz(varz, libraryPath: path);
      expect(result.isOk, isTrue, reason: result.message);
      expect(result.value!.ackMeaning, RkNatsAckMeaning.fsyncedToDisk);
      expect(result.value!.server!.syncAlways, isTrue);
      // The trap, from a real capture: the interval is still two minutes.
      expect(result.value!.server!.syncInterval, const Duration(minutes: 2));
    });

    test('reads a real default document as written but not fsynced', () async {
      final varz = File(
        'rust/fixtures/varz_2_14_4_default.json',
      ).readAsStringSync();
      final result = await rkNatsEvaluateVarz(varz, libraryPath: path);
      expect(result.isOk, isTrue, reason: result.message);
      expect(result.value!.ackMeaning, RkNatsAckMeaning.writtenNotFsynced);
      expect(result.value!.server!.version, '2.14.4');
    });

    test('reads the system-account shape the same way', () async {
      final varz = File(
        'rust/fixtures/varz_2_14_4_sync_always_sys.json',
      ).readAsStringSync();
      final result = await rkNatsEvaluateVarz(varz, libraryPath: path);
      expect(result.isOk, isTrue, reason: result.message);
      expect(result.value!.ackMeaning, RkNatsAckMeaning.fsyncedToDisk);
    });

    test('refuses a document it cannot read rather than assuming', () async {
      final result = await rkNatsEvaluateVarz(
        jsonEncode({'version': '2.14.4'}),
        libraryPath: path,
      );
      expect(result.isOk, isFalse);
      expect(result.code, RkNatsCode.durabilityProbeFailed);
    });
  });
}

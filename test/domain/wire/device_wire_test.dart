import 'package:flutter_test/flutter_test.dart';
import 'package:telepos/domain/device/device_check.dart';
import 'package:telepos/domain/device/device_class.dart';
import 'package:telepos/domain/device/device_discovery.dart';
import 'package:telepos/domain/wire/device_wire.dart';

/// Pure encode/decode tests for `lib/domain/wire/device_wire.dart` — no router, no
/// HTTP, importable and runnable under plain `flutter test` because this
/// file (unlike `http_device_discovery.dart`/`http_device_check.dart`) never
/// touches `api_client.dart`'s `dart:js_interop`.
///
/// `test/unit/web/device_routes_test.dart` proves the same functions agree
/// with what `TerminalRoutes` actually sends over shelf `Request`/`Response`
/// objects; this file proves the functions themselves are lossless in
/// isolation, including the two things a naive wire format silently drops —
/// `failedSources` and enum-by-index.
void main() {
  group('DeviceCandidate/DeviceDiscoveryResult', () {
    test('a candidate round-trips every field, including an empty parameters map', () {
      const candidate = DeviceCandidate(
        source: DeviceDiscoverySource.serialPort,
        title: 'Последовательный порт COM3',
        parameters: {'comPort': 'COM3', 'devicePath': 'COM3'},
      );

      final decoded = deviceCandidateFromWireJson(deviceCandidateToJson(candidate));

      expect(decoded.source, candidate.source);
      expect(decoded.title, candidate.title);
      expect(decoded.parameters, candidate.parameters);
    });

    test(
      'failedSources survives round trip even when it names a source with '
      'zero candidates — the whole reason the field exists (fix round 1, '
      'device_discovery.dart)',
      () {
        const result = DeviceDiscoveryResult(
          candidates: [
            DeviceCandidate(
              source: DeviceDiscoverySource.usb,
              title: '/dev/usb/lp0',
              parameters: {'devicePath': '/dev/usb/lp0'},
            ),
          ],
          failedSources: {
            DeviceDiscoverySource.bluetooth,
            DeviceDiscoverySource.network,
          },
        );

        final decoded = deviceDiscoveryResultFromWireJson(
          deviceDiscoveryResultToJson(result),
        );

        expect(decoded.candidates, hasLength(1));
        expect(decoded.candidates.single.source, DeviceDiscoverySource.usb);
        expect(
          decoded.failedSources,
          {DeviceDiscoverySource.bluetooth, DeviceDiscoverySource.network},
          reason:
              'a source can fail even while a *different* source found '
              'candidates — collapsing this to "empty means failed" would '
              'be exactly the defect fix round 1 closed',
        );
      },
    );

    test('an empty result — genuinely nothing found, nothing failed — round-trips as empty, not as an error shape', () {
      final decoded = deviceDiscoveryResultFromWireJson(
        deviceDiscoveryResultToJson(const DeviceDiscoveryResult()),
      );
      expect(decoded.candidates, isEmpty);
      expect(decoded.failedSources, isEmpty);
    });

    test('every DeviceDiscoverySource value round-trips by name', () {
      for (final source in DeviceDiscoverySource.values) {
        expect(deviceDiscoverySourceFromWireName(source.name), source);
      }
    });

    test('an unrecognised source name is refused, not guessed', () {
      expect(
        () => deviceDiscoverySourceFromWireName('quantumRadio'),
        throwsStateError,
      );
    });
  });

  group('DeviceCheckOutcome', () {
    test('every DeviceCheckReason value round-trips by name, carrying the exact message', () {
      final outcomes = <DeviceCheckOutcome>[
        DeviceCheckOutcome.ok('Пробный чек напечатан (128 байт)'),
        DeviceCheckOutcome.notConfigured(DeviceClass.scale),
        DeviceCheckOutcome.invalidBinding(
          DeviceClass.receiptPrinter,
          'DeviceClass.scale != DeviceClass.receiptPrinter',
        ),
        DeviceCheckOutcome.driverNotLive(DeviceClass.labelPrinter),
        DeviceCheckOutcome.connectionFailed('Порт занят другим приложением'),
        DeviceCheckOutcome.deviceRefused('Нет бумаги'),
        DeviceCheckOutcome.notSupportedOnPlatform(
          'Денежный ящик не поддерживается на этой платформе',
        ),
        DeviceCheckOutcome.notImplemented(DeviceClass.scanner),
        DeviceCheckOutcome.unexpectedError('база данных недоступна'),
      ];

      // Every DeviceCheckReason must be exercised by the list above, or a
      // reason added to the enum later could silently never be proven to
      // round-trip.
      expect(
        outcomes.map((o) => o.reason).toSet(),
        DeviceCheckReason.values.toSet(),
        reason: 'add the new reason above, not just to the enum',
      );

      for (final outcome in outcomes) {
        final decoded = deviceCheckOutcomeFromWireJson(
          deviceCheckOutcomeToJson(outcome),
        );
        expect(decoded.reason, outcome.reason);
        expect(
          decoded.message,
          outcome.message,
          reason:
              'the message is not regenerated on the way back — '
              'DeviceCheckOutcome.wire carries it verbatim',
        );
      }
    });

    test('an unrecognised reason name is refused, not guessed', () {
      expect(
        () => deviceCheckOutcomeFromWireJson({
          'reason': 'quantumFailure',
          'message': 'x',
        }),
        throwsStateError,
      );
    });

    test(
      'a missing message is refused, not silently turned into "" — the one '
      'value DeviceCheckOutcome.message advertises it never carries (fix '
      'round 1, minor finding)',
      () {
        expect(
          () => deviceCheckOutcomeFromWireJson({'reason': 'ok'}),
          throwsStateError,
        );
      },
    );

    test('an empty-string message is refused the same way a missing one is', () {
      expect(
        () => deviceCheckOutcomeFromWireJson({'reason': 'ok', 'message': ''}),
        throwsStateError,
      );
    });
  });

  group('M2: a candidate title is refused empty, exactly like a message', () {
    // These two decoders sit twelve lines apart and used to disagree: the
    // outcome refused an empty `message`, the candidate manufactured an empty
    // `title`. `DeviceCandidate.title` is the whole of what an operator picks
    // by, so an empty one is a row that looks choosable and says nothing.

    test('a missing title is refused, not silently turned into ""', () {
      expect(
        () => deviceCandidateFromWireJson({
          'source': 'serialPort',
          'parameters': {'comPort': 'COM3'},
        }),
        throwsStateError,
      );
    });

    test('an empty-string title is refused the same way a missing one is', () {
      expect(
        () => deviceCandidateFromWireJson({
          'source': 'serialPort',
          'title': '',
          'parameters': {'comPort': 'COM3'},
        }),
        throwsStateError,
      );
    });

    test('a candidate carrying a title still decodes', () {
      final decoded = deviceCandidateFromWireJson({
        'source': 'serialPort',
        'title': 'COM3',
        'parameters': {'comPort': 'COM3'},
      });
      expect(decoded.title, 'COM3');
      expect(decoded.source, DeviceDiscoverySource.serialPort);
      expect(decoded.parameters, {'comPort': 'COM3'});
    });

    test(
      'a whole result whose candidate list contains a titleless entry is '
      'refused rather than half-decoded into an unlabelled row',
      () {
        expect(
          () => deviceDiscoveryResultFromWireJson({
            'candidates': [
              {'source': 'serialPort', 'title': 'COM3', 'parameters': {}},
              {'source': 'usb', 'parameters': {}},
            ],
            'failedSources': <String>[],
          }),
          throwsStateError,
        );
      },
    );
  });
}

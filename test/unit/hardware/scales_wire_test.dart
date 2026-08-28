import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telepos/hardware/scales/scales_service.dart';
import 'package:telepos/presentation/screens/sale/sale_hardware.dart';

import '../../fixtures/scale_wire_lines.dart';

/// A scale that is already open on a port and answers with one fixed frame.
///
/// It parses that frame with the **real** [ScalesService.parseLine], so a test
/// through it exercises the shipping wire code, not a restatement of it.
class _FrameScales extends ScalesService {
  _FrameScales(this.frame, ScalesProtocol protocol)
    : super(port: 'COM9', protocol: protocol);

  final String frame;

  @override
  bool get isConnected => true;

  @override
  Future<ScalesConnectResult> connect() async =>
      ScalesConnectResult.success();

  @override
  Future<ScalesReading> requestWeight({
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final reading = parseLine(frame);
    return reading ?? ScalesReading.error('нет показания');
  }
}

ScalesReading? _read(ScaleWireLine wire) =>
    ScalesService(protocol: wire.protocol).parseLine(wire.line);

void main() {
  group('wire corpus', () {
    test('every frame in the corpus is read exactly as it is meant', () {
      // Volume: one assertion per case would let a whole dialect be deleted
      // without a red test. The corpus is walked as a whole and every
      // disagreement is collected, so a failure names all of them at once.
      final wrong = <String>[];

      for (final wire in scaleWireCorpus) {
        final reading = _read(wire);

        if (wire.weight == null) {
          if (reading != null) {
            wrong.add('$wire\n    expected: no reading\n    got: $reading');
          }
          continue;
        }

        if (reading == null) {
          wrong.add('$wire\n    expected: ${wire.weight}\n    got: no reading');
          continue;
        }

        if (reading.weight != wire.expectedWeight) {
          wrong.add(
            '$wire\n    weight expected: ${wire.expectedWeight}'
            '\n    weight got: ${reading.weight}',
          );
        }
        if (reading.unit != wire.unit) {
          wrong.add(
            '$wire\n    unit expected: ${wire.unit.name}'
            '\n    unit got: ${reading.unit.name}',
          );
        }
        if (reading.status != wire.status) {
          wrong.add(
            '$wire\n    status expected: ${wire.status.name}'
            '\n    status got: ${reading.status.name}',
          );
        }
        if (wire.weightKg != null &&
            reading.weightKg != wire.expectedWeightKg) {
          wrong.add(
            '$wire\n    kg expected: ${wire.expectedWeightKg}'
            '\n    kg got: ${reading.weightKg}',
          );
        }
      }

      expect(wrong, isEmpty, reason: wrong.join('\n\n'));
    });

    test('the corpus itself still covers what it claims to', () {
      // A corpus quietly emptied of its hard cases is a green suite that
      // proves nothing — so the shape of the set is asserted too.
      for (final protocol in ScalesProtocol.values) {
        final forProtocol = scaleWireCorpus.where(
          (w) => w.protocol == protocol,
        );
        expect(
          forProtocol.where((w) => w.expectedWeight?.sign == -1),
          isNotEmpty,
          reason: '${protocol.name} has no negative frame to lose the sign of',
        );
        expect(
          forProtocol.where((w) => w.weight == null),
          isNotEmpty,
          reason: '${protocol.name} has no frame that must be refused, so it '
              'cannot tell "read the weight" from "read anything"',
        );
      }
    });
  });

  group('the padded sign', () {
    // The defect. CAS-family scales right-justify the number inside a
    // fixed-width slot and park the sign at its left edge, so a returned half
    // kilo arrives as `-  0.500kg`. An expression that demands the sign touch
    // the digits does not fail loudly — it matches from `0.500` onward and
    // reports a positive weight.
    for (final wire in scaleWireCorpus.where(
      (w) => w.expectedWeight != null && w.expectedWeight!.sign == -1,
    )) {
      test('${wire.protocol.name}: "${wire.line}" is read as negative', () {
        final reading = _read(wire);

        expect(reading, isNotNull, reason: '$wire');
        expect(
          reading!.weight.sign,
          -1,
          reason: 'sign lost — a return booked as a sale. $wire',
        );
        expect(reading.weight, wire.expectedWeight, reason: '$wire');
      });
    }

    test('padding is the only difference: the unpadded form agrees', () {
      // Kept as a control, and honestly labelled as one. `-0.500` is the case
      // that already worked, so on its own it proves nothing; its job is to
      // show the widened expression did not break what was already right.
      final padded = ScalesService(
        protocol: ScalesProtocol.cas,
      ).parseLine('ST,NT,-  0.500kg');
      final tight = ScalesService(
        protocol: ScalesProtocol.cas,
      ).parseLine('ST,NT,-0.500kg');

      expect(padded!.weight, tight!.weight);
      expect(padded.weight, Decimal.parse('-0.500'));
    });
  });

  group('money', () {
    test('grams are converted exactly, where a double would not be', () {
      final reading = ScalesService(
        protocol: ScalesProtocol.cas,
      ).parseLine('ST,GS,+ 1005.0 g');

      expect(reading!.unit, WeightUnit.g);
      expect(
        reading.weightKg.toString(),
        '1.005',
        reason: 'on double 1005.0 / 1000 is 1.0049999999999999 — this test '
            'is here to fail if the conversion ever leaves Decimal',
      );
    });

    test('weights add up exactly, where a double would not', () {
      final scale = ScalesService(protocol: ScalesProtocol.cas);
      final tenth = scale.parseLine('ST,GS,+  0.100kg')!.weight;
      final fifth = scale.parseLine('ST,GS,+  0.200kg')!.weight;

      expect(
        (tenth + fifth).toString(),
        '0.3',
        reason: 'on double 0.1 + 0.2 is 0.30000000000000004',
      );
    });

    test('the half-gram boundary survives the conversion', () {
      final reading = ScalesService(
        protocol: ScalesProtocol.generic,
      ).parseLine('ST,+00000.50 g');

      expect(reading!.weightKg, Decimal.parse('0.0005'));
    });

    test('a negative frame does not become a sale quantity', () async {
      // The money consequence, end to end through the caller that turns a
      // reading into a line on a receipt. Before the fix this returned
      // +0.5 kg: half a kilo handed back over the counter, charged for.
      final hardware = SaleHardware(
        scales: _FrameScales('ST,NT,-  0.500kg', ScalesProtocol.cas),
      );

      expect(await hardware.readWeightKg(), isNull);
    });

    test('a positive frame still becomes one', () async {
      final hardware = SaleHardware(
        scales: _FrameScales('ST,GS,+  1.250kg', ScalesProtocol.cas),
      );

      expect(await hardware.readWeightKg(), Decimal.parse('1.250'));
    });

    test('a gram frame becomes kilograms, not a thousand times too much', () async {
      final hardware = SaleHardware(
        scales: _FrameScales('ST,GS,+ 1005.0 g', ScalesProtocol.cas),
      );

      expect(await hardware.readWeightKg(), Decimal.parse('1.005'));
    });
  });

  group('waiting for a reading', () {
    late StreamController<ScalesReading> readings;

    setUp(() => readings = StreamController<ScalesReading>.broadcast());
    tearDown(() async {
      if (!readings.isClosed) await readings.close();
    });

    test('a stable reading ends the wait', () async {
      final waited = awaitSettledReading(
        readings.stream,
        const Duration(seconds: 5),
      );

      readings.add(ScalesReading(weight: Decimal.parse('0.732')));
      readings.add(
        ScalesReading(
          weight: Decimal.parse('0.750'),
          status: ScalesStatus.stable,
        ),
      );

      final reading = await waited;
      expect(reading.hasError, isFalse);
      expect(reading.weight, Decimal.parse('0.750'));
    });

    test('an overload is reported at once, not waited out', () async {
      final started = DateTime.now();
      final waited = awaitSettledReading(
        readings.stream,
        const Duration(seconds: 5),
      );

      readings.add(
        ScalesReading(weight: Decimal.zero, status: ScalesStatus.overload),
      );

      final reading = await waited;
      expect(reading.hasError, isTrue);
      expect(reading.status, ScalesStatus.overload);
      expect(reading.errorMessage, contains('Перегрузка'));
      expect(
        DateTime.now().difference(started),
        lessThan(const Duration(seconds: 5)),
        reason: 'an overload that is waited out is an overload nobody is told '
            'about until the timeout fires',
      );
    });

    test('a load that never settles is named as such', () async {
      final waited = awaitSettledReading(
        readings.stream,
        const Duration(milliseconds: 150),
      );

      readings.add(ScalesReading(weight: Decimal.parse('0.732')));
      readings.add(ScalesReading(weight: Decimal.parse('0.741')));

      final reading = await waited;
      expect(reading.hasError, isTrue);
      expect(reading.errorMessage, contains('не установился'));
      expect(
        reading.errorMessage,
        contains('0.741'),
        reason: 'the last thing the scale said is the useful half of this '
            'message',
      );
    });

    test('a scale that says nothing at all is named differently', () async {
      final reading = await awaitSettledReading(
        readings.stream,
        const Duration(milliseconds: 150),
      );

      expect(reading.hasError, isTrue);
      expect(
        reading.errorMessage,
        contains('ни одного показания'),
        reason: 'silence is a wiring, baud-rate or protocol fault, and it is '
            'not the same problem as a load that keeps moving',
      );
      expect(reading.errorMessage, isNot(contains('не установился')));
    });

    test('the wait leaves no listener behind', () async {
      await awaitSettledReading(
        readings.stream,
        const Duration(milliseconds: 50),
      );

      expect(
        readings.hasListener,
        isFalse,
        reason: 'a shift is twelve hours long — a subscription leaked per '
            'weighing is a subscription leaked per sale',
      );
    });
  });
}

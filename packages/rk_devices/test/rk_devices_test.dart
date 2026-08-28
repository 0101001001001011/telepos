// Every assertion here is on bytes that came back through the FFI boundary,
// not on "a method was called". The only test in this product that ever
// caught a real printing defect was the one that read the wire, and these are
// written the same way: a protocol test that does not name the bytes proves
// nothing about the protocol.
//
// These tests require the native crate to be built:
//
//   cd rust && cargo build --release
//
// They fail loudly if it is missing rather than skipping. A green run over a
// library that was never loaded is the exact shape of claim this project
// refuses to accept.

import 'dart:convert';
import 'dart:typed_data';

import 'package:rk_devices/rk_devices.dart';
import 'package:test/test.dart';

late RkDevices devices;

void main() {
  setUpAll(() {
    devices = RkDevices.open();
  });

  group('the boundary itself', () {
    test('the library loads and agrees with this binding about its ABI', () {
      expect(devices.version, '0.2.1');
      expect(rkDevicesVersion, devices.version);
    });

    test('a panic in the native library comes back as a value', () {
      // И144. Provably a real panic: the native function calls panic!(), and
      // catch_unwind at the boundary turns it into this name. If the guard
      // were removed the process would die instead of this assertion failing.
      expect(devices.provokePanicForTest(), 'panic');
    });

    test('an unknown name is refused, never resolved to something nearby', () {
      expect(
        () => devices.mdbCommandByte(MdbAddress.coinChanger, 'escrow'),
        throwsA(
          isA<RkDevicesException>().having(
            (e) => e.status,
            'status',
            'unknown_name',
          ),
        ),
      );
    });

    test('a model that cannot do something says so instead of guessing', () {
      expect(
        () => devices.displayEncode(
          model: DisplayModel.led8,
          op: DisplayOp.setCursor,
        ),
        throwsA(
          isA<RkDevicesException>().having(
            (e) => e.status,
            'status',
            'unsupported_operation',
          ),
        ),
      );
    });

    test('hasNativeDevices is true once a library is loadable', () {
      expect(hasNativeDevices, isTrue);
    });
  });

  group('scales', () {
    test('the weight request is the bytes each protocol expects', () {
      expect(
        devices.scaleWeightRequest(ScaleProtocol.cas),
        equals([0x57, 0x0D]),
      );
      expect(
        devices.scaleWeightRequest(ScaleProtocol.generic),
        equals([0x57, 0x0D]),
      );
      expect(
        devices.scaleWeightRequest(ScaleProtocol.massaK),
        equals([0x4E, 0x0D]),
      );
      expect(
        devices.scaleTareRequest(ScaleProtocol.massaK),
        equals([0x54, 0x0D]),
      );
    });

    test('a CAS line becomes an exact decimal, never a double', () {
      final frame = devices.scaleParse(
        ScaleProtocol.cas,
        _bytes('ST,GS,+  1.234kg\r\n'),
      );
      final reading = (frame as ScaleReadingFrame).reading;
      expect(reading.scaled, 1234);
      expect(reading.decimals, 3);
      expect(reading.toDecimalString(), '1.234');
      expect(reading.unit, WeightUnit.kilogram);
      expect(reading.stability, ScaleStability.stable);
      expect(reading.measure, ScaleMeasure.gross);
      expect(frame.consumed, 18);
    });

    test('a negative net weight keeps its sign across the padding', () {
      // The defect this replaces: `([+-]?\d+[.,]\d+)` could not match across
      // the spaces CAS puts between the sign and the digits, so minus half a
      // kilo was read as plus half a kilo.
      final frame = devices.scaleParse(
        ScaleProtocol.cas,
        _bytes('ST,NT,-  0.500kg\r\n'),
      );
      final reading = (frame as ScaleReadingFrame).reading;
      expect(reading.toDecimalString(), '-0.500');
      expect(reading.measure, ScaleMeasure.net);
    });

    test('an overload is reported as an overload, not as motion', () {
      final frame = devices.scaleParse(
        ScaleProtocol.cas,
        _bytes('OL,GS,  0.000kg\r\n'),
      );
      expect(
        (frame as ScaleReadingFrame).reading.stability,
        ScaleStability.overload,
      );
    });

    test('a half-arrived line is incomplete and consumes nothing', () {
      final frame = devices.scaleParse(
        ScaleProtocol.cas,
        _bytes('ST,GS,+  1.2'),
      );
      expect(frame, isA<ScaleIncompleteFrame>());
      expect(frame.consumed, 0);
    });

    test('an unreadable line is garbage that can be skipped past', () {
      const stream = 'hello\r\nST,GS,  2.000kg\r\n';
      final first = devices.scaleParse(ScaleProtocol.cas, _bytes(stream));
      expect(first, isA<ScaleGarbageFrame>());
      expect(first.consumed, 7);

      final second = devices.scaleParse(
        ScaleProtocol.cas,
        Uint8List.sublistView(_bytes(stream), first.consumed),
      );
      expect((second as ScaleReadingFrame).reading.toDecimalString(), '2.000');
    });

    test('every frame in the wire corpus is read exactly as it is meant', () {
      // Walked as a whole, with every disagreement collected: one assertion
      // per line would let a whole dialect break without the failure naming
      // the others. Every case goes through the native parser over real
      // bytes — terminator included — so this is the wire, not the call.
      final wrong = <String>[];

      for (final wire in _wireCorpus) {
        final bytes = _bytes('${wire.line}\r\n');
        final frame = devices.scaleParse(wire.protocol, bytes);
        final head = '${wire.protocol.wireName}: "${wire.line}" — ${wire.what}';

        if (frame.consumed != bytes.length) {
          wrong.add(
            '$head\n    consumed expected: ${bytes.length}'
            '\n    consumed got: ${frame.consumed}',
          );
        }

        if (wire.weight == null) {
          if (frame is! ScaleGarbageFrame) {
            wrong.add('$head\n    expected: no reading\n    got: $frame');
          }
          continue;
        }

        if (frame is! ScaleReadingFrame) {
          wrong.add('$head\n    expected: ${wire.weight}\n    got: $frame');
          continue;
        }

        final reading = frame.reading;
        if (reading.toDecimalString() != wire.weight) {
          wrong.add(
            '$head\n    weight expected: ${wire.weight}'
            '\n    weight got: ${reading.toDecimalString()}',
          );
        }
        if (reading.unit != wire.unit) {
          wrong.add(
            '$head\n    unit expected: ${wire.unit.wireName}'
            '\n    unit got: ${reading.unit.wireName}',
          );
        }
        if (reading.stability != wire.stability) {
          wrong.add(
            '$head\n    stability expected: ${wire.stability.wireName}'
            '\n    stability got: ${reading.stability.wireName}',
          );
        }
      }

      expect(wrong, isEmpty, reason: '\n${wrong.join('\n\n')}');
    });

    test('the corpus itself still covers what it claims to', () {
      // A corpus quietly emptied of its hard cases is a green run that proves
      // nothing, so the shape of the set is asserted too.
      for (final protocol in ScaleProtocol.values) {
        final mine = _wireCorpus.where((w) => w.protocol == protocol);
        expect(
          mine.where((w) => w.weight?.startsWith('-') ?? false),
          isNotEmpty,
          reason:
              '${protocol.wireName} has no negative frame to lose the '
              'sign of',
        );
        expect(
          mine.where((w) => w.weight == null),
          isNotEmpty,
          reason:
              '${protocol.wireName} has no frame that must be refused, so '
              'it cannot tell "read the weight" from "read anything"',
        );
        expect(
          mine.where((w) => w.weight == '0.000'),
          isNotEmpty,
          reason: '${protocol.wireName} has no reading at zero',
        );
      }
      for (final protocol in [ScaleProtocol.cas, ScaleProtocol.generic]) {
        expect(
          _wireCorpus.where(
            (w) =>
                w.protocol == protocol &&
                w.stability == ScaleStability.overload,
          ),
          isNotEmpty,
          reason: '${protocol.wireName} has no overload frame',
        );
      }
      for (final unit in [WeightUnit.gram, WeightUnit.pound]) {
        expect(
          _wireCorpus.where((w) => w.unit == unit),
          isNotEmpty,
          reason: 'no frame states ${unit.wireName}',
        );
      }
    });

    test('a stated unit is reported and never assumed', () {
      // Hard-coding kilograms here read `500.0 g` as five hundred kilograms —
      // a thousandfold error in a quantity a price is about to multiply. The
      // package converts nothing; it must therefore state the unit correctly,
      // because the caller's conversion depends on it entirely.
      for (final (protocol, line, unit) in [
        (ScaleProtocol.generic, '  500.0 g\r\n', WeightUnit.gram),
        (ScaleProtocol.generic, '  1.500 kg\r\n', WeightUnit.kilogram),
        (ScaleProtocol.generic, '  1.500 lbs\r\n', WeightUnit.pound),
        (ScaleProtocol.cas, 'ST,GS,  500.0 g\r\n', WeightUnit.gram),
        (
          ScaleProtocol.massaK,
          r'$  500.0 g'
              '\r\n',
          WeightUnit.gram,
        ),
      ]) {
        final frame = devices.scaleParse(protocol, _bytes(line));
        expect(
          (frame as ScaleReadingFrame).reading.unit,
          unit,
          reason: '${protocol.wireName}: "$line"',
        );
      }
    });

    test('an overload survives a value slot with nothing in it', () {
      // The frame that used to be dropped: the fields are there, the third
      // holds nothing, and a parser insisting on a number returns garbage for
      // the one line that says why this scale will never settle.
      for (final line in ['OL,GS,\r\n', 'OL,GS,   \r\n', 'OL\r\n']) {
        final frame = devices.scaleParse(ScaleProtocol.cas, _bytes(line));
        expect(frame, isA<ScaleReadingFrame>(), reason: line);
        final reading = (frame as ScaleReadingFrame).reading;
        expect(reading.stability, ScaleStability.overload, reason: line);
        expect(reading.toDecimalString(), '0', reason: line);
      }
    });

    test('Massa-K has no overload marker, and none is invented', () {
      // Deliberate. This dialect's over-capacity marker is not established,
      // and a guessed one fires on an ordinary line and stops a sale with a
      // false refusal — strictly worse than the honest outcome below, where
      // the scale answers and the settling rule reports that it never settled.
      final frame = devices.scaleParse(
        ScaleProtocol.massaK,
        _bytes('   12.345\r\n'),
      );
      final reading = (frame as ScaleReadingFrame).reading;
      expect(reading.stability, ScaleStability.unstable);
      expect(reading.toDecimalString(), '12.345');

      final rule = devices.stabilizer(budget: const Duration(seconds: 1));
      try {
        expect(
          rule.offer(
            elapsed: Duration.zero,
            heard: Heard.reading,
            reading: reading,
          ),
          SettleVerdict.notYet,
        );
        expect(
          rule.offer(
            elapsed: const Duration(seconds: 1),
            heard: Heard.reading,
            reading: reading,
          ),
          SettleVerdict.expired,
        );
      } finally {
        rule.dispose();
      }
    });

    test('silence for the whole budget is "no answer", not a timeout', () {
      final rule = devices.stabilizer(budget: const Duration(seconds: 1));
      try {
        expect(
          rule.offer(elapsed: Duration.zero, heard: Heard.silence),
          SettleVerdict.notYet,
        );
        expect(
          rule.offer(
            elapsed: const Duration(milliseconds: 999),
            heard: Heard.silence,
          ),
          SettleVerdict.notYet,
        );
        expect(
          rule.offer(elapsed: const Duration(seconds: 1), heard: Heard.silence),
          SettleVerdict.noAnswer,
        );
      } finally {
        rule.dispose();
      }
    });

    test('a scale that talks but never settles expires instead', () {
      final rule = devices.stabilizer(budget: const Duration(seconds: 1));
      try {
        const moving = WeightReading(
          scaled: 1000,
          decimals: 3,
          unit: WeightUnit.kilogram,
          stability: ScaleStability.unstable,
          measure: ScaleMeasure.unknown,
        );
        expect(
          rule.offer(
            elapsed: Duration.zero,
            heard: Heard.reading,
            reading: moving,
          ),
          SettleVerdict.notYet,
        );
        expect(
          rule.offer(
            elapsed: const Duration(seconds: 1),
            heard: Heard.reading,
            reading: moving,
          ),
          SettleVerdict.expired,
        );
      } finally {
        rule.dispose();
      }
    });

    test('a run of equal settled readings settles once it is long enough', () {
      final rule = devices.stabilizer(
        budget: const Duration(seconds: 10),
        neededRepeats: 3,
      );
      try {
        const still = WeightReading(
          scaled: 1001,
          decimals: 3,
          unit: WeightUnit.kilogram,
          stability: ScaleStability.stable,
          measure: ScaleMeasure.unknown,
        );
        expect(
          rule.offer(
            elapsed: Duration.zero,
            heard: Heard.reading,
            reading: still,
          ),
          SettleVerdict.notYet,
        );
        expect(
          rule.offer(
            elapsed: const Duration(milliseconds: 200),
            heard: Heard.reading,
            reading: still,
          ),
          SettleVerdict.notYet,
        );
        expect(
          rule.offer(
            elapsed: const Duration(milliseconds: 400),
            heard: Heard.reading,
            reading: still,
          ),
          SettleVerdict.settled,
        );
      } finally {
        rule.dispose();
      }
    });

    test('a disposed rule is refused rather than read after free', () {
      final rule = devices.stabilizer(budget: const Duration(seconds: 1));
      rule.dispose();
      rule.dispose(); // idempotent
      expect(
        () => rule.offer(elapsed: Duration.zero, heard: Heard.silence),
        throwsStateError,
      );
    });
  });

  group('customer displays', () {
    test('geometry is what the device catalogue declares', () {
      expect(devices.displayGeometry(DisplayModel.led8).columns, 8);
      expect(devices.displayGeometry(DisplayModel.led8).lines, 1);
      expect(devices.displayGeometry(DisplayModel.vfd20).columns, 20);
      expect(devices.displayGeometry(DisplayModel.vfd20).lines, 2);
      expect(devices.displayGeometry(DisplayModel.lcd2x20).columns, 20);
    });

    test('a VFD line is cursor-addressed and padded to the full width', () {
      final out = devices.displayEncode(
        model: DisplayModel.vfd20,
        op: DisplayOp.writeLine,
        line: 1,
        text: 'ИТОГО:',
      );
      expect(out.bytes.sublist(0, 4), equals([0x1B, 0x24, 0x00, 0x01]));
      expect(out.bytes.length, 24);
      expect(
        out.bytes.sublist(4, 10),
        equals([0x88, 0x92, 0x8E, 0x83, 0x8E, 0x3A]),
      );
      expect(out.bytes.sublist(10), equals(List.filled(14, 0x20)));
      expect(out.substitutions, 0);
    });

    test('lowercase Cyrillic lands where CP866 actually puts it', () {
      // The defect: vfd_display.dart mapped 0x410..0x44F to one contiguous
      // run, so `р` came out as 0xB0 instead of 0xE0 — a different letter on
      // the customer's display for half the lowercase alphabet.
      final out = devices.displayEncode(
        model: DisplayModel.vfd20,
        op: DisplayOp.writeLine,
        text: 'ар',
      );
      expect(out.bytes.sublist(4, 6), equals([0xA0, 0xE0]));
    });

    test('a character CP866 cannot hold is counted, not swallowed', () {
      final out = devices.displayEncode(
        model: DisplayModel.led8,
        op: DisplayOp.writeLine,
        text: '100 ₸',
      );
      expect(out.substitutions, 1);
      expect(
        out.bytes,
        equals([0x0B, 0x31, 0x30, 0x30, 0x20, 0x20, 0x20, 0x20, 0x20]),
      );
    });

    test('LED and VFD switch on with different bytes', () {
      expect(
        devices
            .displayEncode(model: DisplayModel.led8, op: DisplayOp.displayOn)
            .bytes,
        equals([0x14]),
      );
      expect(
        devices
            .displayEncode(model: DisplayModel.vfd20, op: DisplayOp.displayOn)
            .bytes,
        equals([0x1B, 0x28]),
      );
    });

    test('a brightness the protocol cannot carry is refused', () {
      expect(
        () => devices.displayEncode(
          model: DisplayModel.vfd20,
          op: DisplayOp.setBrightness,
          brightness: 8,
        ),
        throwsA(
          isA<RkDevicesException>().having(
            (e) => e.status,
            'status',
            'out_of_range',
          ),
        ),
      );
    });
  });

  group('cash drawers', () {
    test('the default pulse is byte for byte what the product sends', () {
      // lib/hardware/cash_drawer/cash_drawer_service.dart:29 and :31.
      final pin2 = devices.drawerPulse();
      expect(
        (pin2 as DrawerPulseBytes).bytes,
        equals([0x1B, 0x70, 0x00, 0x20, 0xA0]),
      );
      final pin5 = devices.drawerPulse(pin: DrawerPin.pin5);
      expect(
        (pin5 as DrawerPulseBytes).bytes,
        equals([0x1B, 0x70, 0x01, 0x20, 0xA0]),
      );
    });

    test('a pulse is rounded up to two-millisecond units', () {
      // Up, never down: a caller asking for 3 ms that got 2 ms would
      // under-energise the solenoid and be told nothing was wrong. Found as a
      // gap during the anti-gaps pass — the Rust unit test caught the mutation
      // and the Dart suite did not, because 64 and 320 both divide evenly.
      final out = devices.drawerPulse(
        on: const Duration(milliseconds: 3),
        off: const Duration(milliseconds: 3),
      );
      expect(
        (out as DrawerPulseBytes).bytes,
        equals([0x1B, 0x70, 0x00, 0x02, 0x02]),
      );
    });

    test('the default pulse durations are 64 ms on, 320 ms off', () {
      expect(devices.drawerDefaultPulse.on, const Duration(milliseconds: 64));
      expect(devices.drawerDefaultPulse.off, const Duration(milliseconds: 320));
    });

    test(
      'a pulse longer than the protocol allows is a refusal, not a throw',
      () {
        final result = devices.drawerPulse(on: const Duration(seconds: 1));
        expect(result, isA<DrawerPulseRefused>());
        expect((result as DrawerPulseRefused).status, 'out_of_range');
      },
    );

    test('the drawer admits it cannot report back', () {
      expect(
        devices.drawerReporting(DrawerModel.escposKick),
        DrawerReporting.cannotReport,
      );
    });

    test('the three outcomes are three types a caller must tell apart', () {
      // Bytes, refusal and "not on this host" are separate types, so the
      // third cannot be quietly handled as the second — which is exactly what
      // CashDrawerResult.notSupported has always existed to prevent. The
      // switch below is exhaustive over a sealed hierarchy: adding a fourth
      // outcome breaks compilation here rather than being silently ignored.
      String describe(DrawerPulse outcome) => switch (outcome) {
        DrawerPulseBytes(:final bytes) => 'send ${bytes.length} bytes',
        DrawerPulseRefused(:final status) => 'refused: $status',
        DrawerPulseUnsupportedHere() => 'no drawer support on this host',
      };

      expect(describe(cashDrawerPulse()), 'send 5 bytes');
      expect(
        describe(cashDrawerPulse(on: const Duration(seconds: 1))),
        'refused: out_of_range',
      );
      expect(
        describe(const DrawerPulseUnsupportedHere('none built')),
        'no drawer support on this host',
      );
    });

    test('a host with no native library is a null, not an exception', () {
      RkDevices.resetCache();
      try {
        expect(RkDevices.tryOpen(path: 'definitely-not-a-library'), isNull);
        expect(RkDevices.lastLoadFailure, isA<RkDevicesUnavailable>());
      } finally {
        RkDevices.resetCache();
      }
    });
  });

  group('MDB', () {
    test('a poll frame carries the mode bit on the command byte only', () {
      final frame = devices.mdbEncode(MdbAddress.coinChanger, 'poll');
      expect(frame, equals([0x10B, 0x00B]));
      expect(frame[0] & devices.mdbModeBit, devices.mdbModeBit);
      expect(frame[1] & devices.mdbModeBit, 0);
    });

    test('the checksum is the wrapping sum of the frame', () {
      expect(devices.mdbChecksum(Uint8List.fromList([0xFF, 0x02])), 0x01);
      final frame = devices.mdbEncode(
        MdbAddress.coinChanger,
        'coin_type',
        Uint8List.fromList([0xFF, 0xFF, 0x00, 0x00]),
      );
      expect(frame, equals([0x10C, 0x0FF, 0x0FF, 0x000, 0x000, 0x00A]));
    });

    test('a raw command byte bypasses the transcribed table', () {
      expect(
        devices.mdbEncodeRaw(0x7B, Uint8List.fromList([0x01])),
        equals([0x17B, 0x001, 0x07C]),
      );
    });

    test('ACK, NAK and RET are told apart by name', () {
      final mode = devices.mdbModeBit;
      expect(devices.mdbDecode(Uint16List.fromList([mode])), isA<MdbAck>());
      expect(
        devices.mdbDecode(Uint16List.fromList([0xFF | mode])),
        isA<MdbNak>(),
      );
      expect(
        devices.mdbDecode(Uint16List.fromList([0xAA | mode])),
        isA<MdbRet>(),
      );
    });

    test('a block comes back without its checksum', () {
      final mode = devices.mdbModeBit;
      final payload = Uint8List.fromList([0x01, 0x02, 0x03]);
      final chk = devices.mdbChecksum(payload);
      final reply = devices.mdbDecode(
        Uint16List.fromList([...payload, chk | mode]),
      );
      expect((reply as MdbBlock).payload, equals([0x01, 0x02, 0x03]));
      expect(reply.consumed, 4);
    });

    test('a block still arriving is incomplete and consumes nothing', () {
      final reply = devices.mdbDecode(Uint16List.fromList([0x01, 0x02]));
      expect(reply, isA<MdbIncomplete>());
      expect(reply.consumed, 0);
    });

    test('a wrong checksum is reported, not returned as data', () {
      final mode = devices.mdbModeBit;
      final reply = devices.mdbDecode(
        Uint16List.fromList([0x01, 0x02, 0x09 | mode]),
      );
      expect(reply, isA<MdbBadChecksum>());
    });

    test('the response window is published and nothing enforces it', () {
      expect(devices.mdbResponseWindow, const Duration(milliseconds: 5));
      expect(devices.mdbBitTimeMicroseconds, 104);
      expect(devices.mdbModeBit, 0x100);
    });
  });

  group('partial writes', () {
    test('only a serial port claims to report how much it took', () {
      expect(devices.wireReportsPartialWrites(Wire.serial), isTrue);
      expect(devices.wireReportsPartialWrites(Wire.socket), isFalse);
      expect(devices.wireReportsPartialWrites(Wire.usbRaw), isFalse);
    });

    test('a short serial write is a continuation with an offset', () {
      final resume = devices.resolveWrite(
        wire: Wire.serial,
        total: 80,
        accepted: 40,
      );
      expect(resume, isA<WriteContinue>());
      expect((resume as WriteContinue).offset, 40);
    });

    test('a failed write is unknowable on every wire, serial included', () {
      for (final wire in Wire.values) {
        expect(
          devices.resolveWrite(wire: wire, total: 80, accepted: null),
          isA<WriteUnknown>(),
          reason: '${wire.wireName} carries no count with a failure',
        );
      }
    });

    test('a socket is not allowed to claim a partial count it cannot have', () {
      expect(
        () => devices.resolveWrite(wire: Wire.socket, total: 80, accepted: 40),
        throwsA(
          isA<RkDevicesException>().having(
            (e) => e.status,
            'status',
            'invalid_argument',
          ),
        ),
      );
      expect(
        () => devices.resolveWrite(wire: Wire.usbRaw, total: 80, accepted: 40),
        throwsA(isA<RkDevicesException>()),
      );
    });

    test('draining a serial write sends every byte exactly once', () {
      final payload = Uint8List.fromList(List.generate(8, (i) => i));
      final sent = <int>[];
      var pending = payload;
      for (final accepted in const [3, 2, 3]) {
        sent.addAll(pending.sublist(0, accepted));
        final next = remainingAfterWrite(
          devices: devices,
          wire: Wire.serial,
          payload: pending,
          accepted: accepted,
        );
        if (next == null) break;
        pending = next;
      }
      expect(sent, equals(payload));
    });

    test('an unknowable write refuses to invent a remainder', () {
      expect(
        () => remainingAfterWrite(
          devices: devices,
          wire: Wire.socket,
          payload: Uint8List(80),
          accepted: null,
        ),
        throwsA(isA<RkDevicesUnavailable>()),
      );
    });
  });
}

Uint8List _bytes(String s) => Uint8List.fromList(utf8.encode(s));

/// One line a serial scale actually puts on the wire, and what it must be read
/// as.
///
/// The same corpus is held by the Rust crate's own tests and by the consuming
/// product. Deliberately copied rather than shared: a published package cannot
/// reach into an application's test tree, and this copy is what proves the
/// **boundary** carries the parse — sign, unit and stability — rather than the
/// crate merely getting it right internally.
class _WireLine {
  const _WireLine(
    this.protocol,
    this.line,
    this.weight,
    this.what, {
    this.unit = WeightUnit.kilogram,
    this.stability = ScaleStability.stable,
  });

  final ScaleProtocol protocol;

  /// The frame itself, exactly as it arrives before its terminator.
  final String line;

  /// The value this frame must be read as. `null` is the strongest
  /// expectation here: **no reading at all**.
  final String? weight;

  /// What this case is, in words — printed by the failure, so a red run names
  /// the real-world frame that broke rather than an array index.
  final String what;

  final WeightUnit unit;
  final ScaleStability stability;
}

const _wireCorpus = <_WireLine>[
  // ------------------------------------------------------------------ CAS ---
  // `<status>,<type>,<sign><right-justified number><unit>`. The sign sits at
  // the left edge of a fixed-width numeric slot, so padding between it and the
  // digits is the ordinary case, not a quirk of one unit.
  _WireLine(
    ScaleProtocol.cas,
    'ST,NT,-  0.500kg',
    '-0.500',
    'PADDED NEGATIVE — net weight below zero after a tare, i.e. a return. The '
        'defect: the sign dropped, and half a kilo given back booked as half '
        'a kilo sold',
  ),
  _WireLine(
    ScaleProtocol.cas,
    'ST,GS,+  1.250kg',
    '1.250',
    'padded positive — same slot, sign the other way',
  ),
  _WireLine(
    ScaleProtocol.cas,
    'ST,GS,   0.000kg',
    '0.000',
    'empty platform — zero, with the sign slot blank',
  ),
  _WireLine(
    ScaleProtocol.cas,
    'US,GS,+  0.732kg',
    '0.732',
    'unstable — the load is still moving',
    stability: ScaleStability.unstable,
  ),
  _WireLine(
    ScaleProtocol.cas,
    'OL,GS,+  9.999kg',
    '0',
    'OVERLOAD — over capacity; the number in the slot is the full-scale '
        'value, not a weight',
    stability: ScaleStability.overload,
  ),
  _WireLine(
    ScaleProtocol.cas,
    'OL,GS,',
    '0',
    'OVERLOAD with the value slot blank — the frame this parser used to throw '
        'away entirely, leaving the caller to wait out its whole budget',
    stability: ScaleStability.overload,
  ),
  _WireLine(
    ScaleProtocol.cas,
    'UL,GS,',
    '0',
    'under capacity — likewise reported without a readable number',
    stability: ScaleStability.underload,
  ),
  _WireLine(
    ScaleProtocol.cas,
    'ST,GS,+ 1005.0 g',
    '1005.0',
    'gram mode, just over a kilo — the unit slot says «g» and must be '
        'believed; read as kilograms this is 1005 kg',
    unit: WeightUnit.gram,
  ),
  _WireLine(
    ScaleProtocol.cas,
    'ST,GS,-  500.0 g',
    '-500.0',
    'gram mode AND a padded negative at once — both defects on one line',
    unit: WeightUnit.gram,
  ),
  _WireLine(
    ScaleProtocol.cas,
    'ST,GS,+  0.0005kg',
    '0.0005',
    'rounding boundary — half a gram, where the rounding direction shows',
  ),
  _WireLine(
    ScaleProtocol.cas,
    'ST,GS,+  0.100kg',
    '0.100',
    'one tenth — half of the pair a double would add up wrong',
  ),
  _WireLine(
    ScaleProtocol.cas,
    'ST,GS,+  0.200kg',
    '0.200',
    'two tenths — the other half of that pair',
  ),
  _WireLine(
    ScaleProtocol.cas,
    'ST,GS,',
    null,
    'MUST NOT PARSE — a truncated frame carries no weight',
  ),
  _WireLine(
    ScaleProtocol.cas,
    'CAS PD-II  Ver 1.00',
    null,
    'MUST NOT PARSE — the power-up banner; «1.00» is a firmware version, not '
        'a kilo',
  ),

  // -------------------------------------------------------------- Massa-K ---
  _WireLine(
    ScaleProtocol.massaK,
    r'$ -  0.500',
    '-0.500',
    'PADDED NEGATIVE — same slot layout, same dropped sign',
  ),
  _WireLine(
    ScaleProtocol.massaK,
    r'$    1.250',
    '1.250',
    'padded positive with no sign character at all',
  ),
  _WireLine(ScaleProtocol.massaK, r'$    0.000', '0.000', 'empty platform'),
  _WireLine(
    ScaleProtocol.massaK,
    r'$   1.250 кг',
    '1.250',
    'Cyrillic unit in the unit slot — falls back to kilograms, which is what '
        '«кг» means anyway',
  ),
  _WireLine(
    ScaleProtocol.massaK,
    '   12.345',
    '12.345',
    'unstable — the marker slot is blank and the line is trimmed before it is '
        'parsed. Cutting the first character regardless read this as 2.345',
    stability: ScaleStability.unstable,
  ),
  _WireLine(
    ScaleProtocol.massaK,
    r'$',
    null,
    'MUST NOT PARSE — marker with nothing behind it',
  ),
  _WireLine(
    ScaleProtocol.massaK,
    '#####',
    null,
    'MUST NOT PARSE — line noise from a wrong baud rate',
  ),

  // -------------------------------------------------------------- generic ---
  _WireLine(
    ScaleProtocol.generic,
    '-  0.500 kg',
    '-0.500',
    'PADDED NEGATIVE — bare weight line, sign padded away from the digits',
  ),
  _WireLine(ScaleProtocol.generic, '   1.250 kg', '1.250', 'padded positive'),
  _WireLine(ScaleProtocol.generic, '0.000 kg', '0.000', 'zero, unpadded'),
  _WireLine(
    ScaleProtocol.generic,
    '~  0.732 kg',
    '0.732',
    'unstable — «~» is this dialect\'s motion marker',
    stability: ScaleStability.unstable,
  ),
  _WireLine(
    ScaleProtocol.generic,
    'OL',
    '0',
    'OVERLOAD — the marker arrives with no number behind it at all',
    stability: ScaleStability.overload,
  ),
  _WireLine(
    ScaleProtocol.generic,
    '-OL- kg',
    '0',
    'OVERLOAD written the way a display blanks it',
    stability: ScaleStability.overload,
  ),
  _WireLine(
    ScaleProtocol.generic,
    'TOL 1.500 kg',
    '1.500',
    'a checkweighing tolerance marker — «TOL» contains «OL» and must not be '
        'taken for one',
  ),
  _WireLine(
    ScaleProtocol.generic,
    'ST,+00000.50 g',
    '0.50',
    'zero-padded gram frame — half a gram; read as kilograms it is half a '
        'tonne',
    unit: WeightUnit.gram,
  ),
  _WireLine(
    ScaleProtocol.generic,
    '  1.500 lbs',
    '1.500',
    'pounds, stated — the third unit a scale can name',
    unit: WeightUnit.pound,
  ),
  _WireLine(
    ScaleProtocol.generic,
    'ERROR',
    null,
    'MUST NOT PARSE — the scale reporting its own fault',
  ),
  _WireLine(
    ScaleProtocol.generic,
    '------',
    null,
    'MUST NOT PARSE — a blanked display',
  ),
];

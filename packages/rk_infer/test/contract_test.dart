/// The contract's own behaviour: names, results, retention.
///
/// No native library is needed here. These are the rules that hold whether or
/// not an engine is installed, and they are the ones that decide what a caller
/// sees when it is not.
@TestOn('vm')
library;

import 'package:rk_infer/rk_infer.dart';
import 'package:test/test.dart';

void main() {
  group('a status crosses by name (И147)', () {
    test('every name this build knows maps to its own case', () {
      // Not a loop over a list that is checked against itself: each expected
      // pairing is written out, so a rename in one place and not the other is
      // a failure rather than a silent agreement.
      const expected = <String, Type>{
        'InvalidArgument': InvalidArgument,
        'ModelNotFound': ModelNotFound,
        'ManifestUnreadable': ManifestUnreadable,
        'ManifestMalformed': ManifestMalformed,
        'ModelChecksumMismatch': ModelChecksumMismatch,
        'ModelIncompatible': ModelIncompatible,
        'ModelPinMismatch': ModelPinMismatch,
        'EngineUnavailable': EngineUnavailable,
        'EngineIncompatible': EngineIncompatible,
        'EngineBusy': EngineBusy,
        'NotImplemented': NotImplemented,
        'UnsupportedPixelFormat': UnsupportedPixelFormat,
        'FrameShapeMismatch': FrameShapeMismatch,
        'FrameInUse': FrameInUse,
        'InferenceFailed': InferenceFailed,
        'NativeFault': NativeFault,
      };

      expect(
        expected.keys.toSet(),
        InferError.knownNames.toSet(),
        reason: 'knownNames and the mapping have drifted apart',
      );

      for (final entry in expected.entries) {
        final error = InferError.fromName(entry.key, 'because');
        expect(error.runtimeType, entry.value, reason: entry.key);
        expect(error.name, entry.key, reason: 'the name must round-trip');
        expect(error.detail, 'because');
        expect(error.toString(), '${entry.key}: because');
      }
    });

    test('an unknown name is carried, never guessed at', () {
      // This is the whole reason names cross instead of numbers. A newer
      // library that inserts a status in the middle of its list must not turn
      // one of ours into another.
      final e = InferError.fromName('SomethingNewerKnows', 'from the future');
      expect(e, isA<UnknownNativeStatus>());
      expect((e as UnknownNativeStatus).nativeName, 'SomethingNewerKnows');
      expect(e.name, 'SomethingNewerKnows');
      expect(e.detail, 'from the future');
      expect(
        e.toString(),
        contains('SomethingNewerKnows'),
        reason:
            'an operator reading a log must see the name the other side '
            'used, not "unknown error"',
      );
    });

    test('the empty and blank cases do not collapse into each other', () {
      expect(InferError.fromName('NativeFault', '').toString(), 'NativeFault');
      expect(
        InferError.fromName('', 'detail only'),
        isA<UnknownNativeStatus>(),
      );
    });
  });

  group('a task and a format cross by name', () {
    test('both round-trip and both are case sensitive', () {
      for (final t in InferenceTask.values) {
        expect(InferenceTask.fromWireName(t.wireName), t);
      }
      for (final f in PixelFormat.values) {
        expect(PixelFormat.fromWireName(f.wireName), f);
      }
      for (final p in ExecutionProvider.values) {
        expect(ExecutionProvider.fromWireName(p.wireName), p);
      }

      expect(InferenceTask.fromWireName('VisitorCount'), isNull);
      expect(PixelFormat.fromWireName('RGB8'), isNull);
      expect(ExecutionProvider.fromWireName('cpu'), isNull);
    });

    test('the wire names are exactly the two tasks this package is for', () {
      // Scope, asserted. Widening it should require changing a test that says
      // out loud what the scope was, not just adding an enum case.
      expect(
        InferenceTask.values.map((t) => t.wireName).toList(),
        <String>['visitorCount', 'unscannedItemHint'],
        reason:
            'section 10 names six events; four are till events with a '
            'video link, and the fifth is a number from a scale. Adding a '
            'third task here is a scope decision, not a code change.',
      );
    });

    test('a name is never derived from an index', () {
      // If someone "simplifies" wireName to `name` or to `index.toString()`,
      // the ABI silently changes meaning. Pin the strings.
      expect(InferenceTask.visitorCount.wireName, 'visitorCount');
      expect(InferenceTask.unscannedItemHint.wireName, 'unscannedItemHint');
      expect(PixelFormat.rgb8.wireName, 'rgb8');
      expect(PixelFormat.gray8.wireName, 'gray8');
      expect(ExecutionProvider.cpu.wireName, 'Cpu');
    });
  });

  group('a frame spec is arithmetic, not a guess', () {
    test('byte length matches the format on the sizes we actually ship', () {
      const cases = <(FrameSpec, int)>[
        (
          FrameSpec(width: 640, height: 384, format: PixelFormat.rgb8),
          640 * 384 * 3,
        ),
        (
          FrameSpec(width: 640, height: 384, format: PixelFormat.rgba8),
          640 * 384 * 4,
        ),
        (
          FrameSpec(width: 640, height: 384, format: PixelFormat.gray8),
          640 * 384,
        ),
        // The size that makes И146 matter: 6.2 MB per frame.
        (
          FrameSpec(width: 1920, height: 1080, format: PixelFormat.rgb8),
          1920 * 1080 * 3,
        ),
      ];
      for (final (spec, want) in cases) {
        expect(spec.byteLength, want, reason: '$spec');
      }

      expect(
        const FrameSpec(
          width: 1920,
          height: 1080,
          format: PixelFormat.rgb8,
        ).byteLength,
        greaterThan(6 * 1000 * 1000),
        reason:
            'a frame at this size is megabytes, which is why freeing it '
            'deterministically is the difference between running and swapping',
      );
    });

    test('specs compare by value so a shape check cannot pass by identity', () {
      const a = FrameSpec(width: 640, height: 384, format: PixelFormat.rgb8);
      const b = FrameSpec(width: 640, height: 384, format: PixelFormat.rgb8);
      const different = FrameSpec(
        width: 640,
        height: 384,
        format: PixelFormat.bgr8,
      );

      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(different));
      expect(
        a.byteLength,
        different.byteLength,
        reason:
            'rgb8 and bgr8 are the same size and not the same thing; a '
            'length check alone would let a swapped-channel frame through, '
            'which is why the format is compared too',
      );
    });
  });

  group('a result carries its own retention (И93, И94)', () {
    test('an output knows when it must be gone', () {
      final now = DateTime.utc(2026, 7, 31, 12);
      final output = InferenceOutput(
        task: InferenceTask.visitorCount,
        detections: const <Detection>[
          Detection(
            className: 'person',
            confidence: 0.87,
            x: 0.1,
            y: 0.2,
            width: 0.3,
            height: 0.4,
          ),
        ],
        retainUntil: now.add(const Duration(days: 7)),
      );

      expect(output.isExpiredAt(now), isFalse);
      expect(
        output.isExpiredAt(now.add(const Duration(days: 6, hours: 23))),
        isFalse,
      );
      expect(
        output.isExpiredAt(now.add(const Duration(days: 7))),
        isTrue,
        reason:
            'the deadline is inclusive: at the moment it arrives, the '
            'result is expired, not "expiring"',
      );
      expect(output.isExpiredAt(now.add(const Duration(days: 8))), isTrue);
    });

    test('the deadline travels with the result, not beside it', () {
      // A retention rule kept in a table somewhere else is a retention rule
      // that gets lost the first time the result is copied.
      final output = InferenceOutput(
        task: InferenceTask.unscannedItemHint,
        detections: const <Detection>[],
        retainUntil: DateTime.utc(2026, 8, 7),
      );
      expect(
        output.retainUntil.isUtc,
        isTrue,
        reason:
            'a deadline in local time is a deadline that moves when the '
            'till does',
      );
      expect(output.toString(), contains('2026-08-07'));
    });

    test('an output renders without any hint of what it saw', () {
      // toString is where a leak actually happens, because it is what ends up
      // in a log line. Numbers and a class name; nothing else.
      final output = InferenceOutput(
        task: InferenceTask.visitorCount,
        detections: const <Detection>[
          Detection(
            className: 'person',
            confidence: 0.5,
            x: 0,
            y: 0,
            width: 1,
            height: 1,
          ),
        ],
        retainUntil: DateTime.utc(2026, 8, 7),
      );
      final rendered = '$output ${output.detections.single}';
      expect(rendered, contains('visitorCount'));
      expect(rendered, contains('person'));
      expect(
        rendered.length,
        lessThan(300),
        reason:
            'a frame would not fit in a line this short; length alone '
            'catches a toString that started printing one: $rendered',
      );
    });
  });

  group('a result is a value, never a throw', () {
    test('ok and err are told apart without a try', () {
      const ok = InferOk<int>(7);
      const err = InferErr<int>(EngineStopped('closed'));

      expect(ok.isOk, isTrue);
      expect(ok.valueOrNull, 7);
      expect(ok.errorOrNull, isNull);

      expect(err.isOk, isFalse);
      expect(err.valueOrNull, isNull);
      expect(err.errorOrNull, isA<EngineStopped>());

      // The shape a caller actually writes. Typed as the sealed supertype so
      // the switch is the real exhaustive one and not narrowed away.
      String describe(InferResult<int> result) => switch (result) {
        InferOk<int>(:final value) => 'got $value',
        InferErr<int>(:final error) => 'failed: ${error.name}',
      };
      expect(describe(err), 'failed: EngineStopped');
      expect(describe(ok), 'got 7');
    });

    test('a successful void result is still a value', () {
      const done = InferOk<void>(null);
      expect(done.isOk, isTrue);
      expect(done.errorOrNull, isNull);
    });
  });

  group('the package tells the truth about itself', () {
    test('the reported version matches the pubspec', () {
      // Kept in step by hand, so checked rather than trusted.
      expect(rkInferVersion, '0.2.0');
    });

    test('hasNativeEngine answers about the package, not the machine', () {
      // This build contains the binding, so it is true. It does no native
      // work: a synchronous probe would be exactly the call on the interface
      // isolate the design forbids, which is why the real answer -- is a
      // runtime installed, which provider -- comes from starting an engine.
      expect(hasNativeEngine, isTrue);
    });

    test('a model ref says whether it is pinned', () {
      const unpinned = ModelRef(
        manifestPath: '/opt/telepos/models/vc/model.manifest',
      );
      const pinned = ModelRef(
        manifestPath: '/opt/telepos/models/vc/model.manifest',
        pinnedVersion: '1.4.0',
      );
      expect(unpinned.pinnedVersion, isNull);
      expect(pinned.pinnedVersion, '1.4.0');
      expect(pinned.toString(), contains('1.4.0'));
      expect(unpinned.toString(), isNot(contains('pinned')));
    });
  });
}

/// The boundary, end to end, through the real library.
///
/// This builds the Rust crate and talks to it over the real ABI. It covers the
/// part of `rk_infer` that is finished: the loader, the model delivery chain
/// (manifest, schema, ABI, retention, length, SHA-256, pin), the failure
/// mapping, and the worker isolate.
///
/// It stops exactly where the package stops. A model load reaches
/// `NotImplemented` because the ONNX Runtime session path is not bound, and
/// that is asserted rather than papered over -- if it ever returned an empty
/// success instead, this test goes red.
@TestOn('vm')
library;

import 'dart:convert';
import 'dart:io';

import 'package:rk_infer/rk_infer.dart';
import 'package:test/test.dart';

import 'support/native_fixture.dart';

void main() {
  group('the engine', () {
    test('a runtime that is not installed is a value, not a crash', () async {
      final started = await NativeInferenceEngine.start(
        bindingLibraryPath: bindingLibraryPath,
        runtimeLibraryPath: '${Directory.systemTemp.path}/no-such-runtime.so',
      );

      expect(started.isOk, isFalse);
      final error = started.errorOrNull;
      expect(error, isA<EngineUnavailable>());
      expect(
        error!.detail,
        contains('no-such-runtime'),
        reason:
            'the detail must name what was tried; "not found" with no path '
            'sends an operator hunting',
      );
    });

    test('a library that is not rk_infer at all is a value too', () async {
      final started = await NativeInferenceEngine.start(
        bindingLibraryPath: '${Directory.systemTemp.path}/not-a-library.so',
      );
      expect(started.errorOrNull, isA<EngineUnavailable>());
      expect(started.errorOrNull!.detail, contains('not-a-library'));
    });

    test('a runtime that is there opens, and says what it is', () async {
      final started = await NativeInferenceEngine.start(
        bindingLibraryPath: bindingLibraryPath,
        runtimeLibraryPath: stubRuntimePath,
      );
      expect(started.isOk, isTrue, reason: '${started.errorOrNull}');
      final engine = started.valueOrNull!;
      addTearDown(engine.close);

      final caps = await engine.capabilities();
      final value = caps.valueOrNull!;

      expect(value.abiVersion, 1);
      expect(
        value.provider,
        ExecutionProvider.cpu,
        reason:
            'CPU is the guaranteed path and the only one this build '
            'claims. An accelerator is reported when it is found, never when '
            'it is hoped for.',
      );
      expect(
        value.runtimeVersion,
        '1.99.0-stub',
        reason: 'the version comes from the runtime, not from us',
      );
      expect(value.runtimeLibraryPath, stubRuntimePath);
    });

    test('a closed engine answers rather than hanging', () async {
      final engine = (await NativeInferenceEngine.start(
        bindingLibraryPath: bindingLibraryPath,
        runtimeLibraryPath: stubRuntimePath,
      )).valueOrNull!;

      expect((await engine.close()).isOk, isTrue);
      // Closing twice is not an error; a shutdown path that throws on the
      // second call turns a tidy-up into an incident.
      expect((await engine.close()).isOk, isTrue);

      final after = await engine.loadModel(
        const ModelRef(manifestPath: 'anything'),
      );
      expect(
        after.errorOrNull,
        isA<EngineStopped>(),
        reason:
            'a call after close returns; it does not wait forever for a '
            'worker that is gone',
      );

      expect((await engine.capabilities()).errorOrNull, isA<EngineStopped>());
    });
  });

  group('a model reaches a till, or is refused for a reason', () {
    late NativeInferenceEngine engine;
    final fixtures = <ModelFixture>[];

    setUp(() async {
      final started = await NativeInferenceEngine.start(
        bindingLibraryPath: bindingLibraryPath,
        runtimeLibraryPath: stubRuntimePath,
      );
      expect(started.isOk, isTrue, reason: '${started.errorOrNull}');
      engine = started.valueOrNull!;
    });

    tearDown(() async {
      await engine.close();
      for (final f in fixtures) {
        f.dispose();
      }
      fixtures.clear();
    });

    ModelFixture make({
      String name = 'visitor-counter',
      String version = '1.4.0',
      String task = 'visitorCount',
      List<int>? weights,
      String? overrideSha,
      int? overrideBytes,
      int retentionSeconds = 604800,
      int schema = 1,
      int minAbi = 1,
    }) {
      final f = ModelFixture.create(
        name: name,
        version: version,
        task: task,
        weights: weights,
        overrideSha: overrideSha,
        overrideBytes: overrideBytes,
        retentionSeconds: retentionSeconds,
        schema: schema,
        minAbi: minAbi,
      );
      fixtures.add(f);
      return f;
    }

    test(
      'a manifest that is not there is ModelNotFound, not a crash',
      () async {
        final result = await engine.loadModel(
          ModelRef(
            manifestPath: '${Directory.systemTemp.path}/nope/model.manifest',
          ),
        );
        expect(result.errorOrNull, isA<ModelNotFound>());
      },
    );

    test('weights that do not match the manifest are refused', () async {
      // One flipped byte, same length. This is the case a length check cannot
      // see and the whole reason a hash is here.
      final f = make(weights: utf8.encode('the genuine weights'));
      final bytes = File(f.weightsPath).readAsBytesSync();
      bytes[0] ^= 0x01;
      File(f.weightsPath).writeAsBytesSync(bytes);

      final result = await engine.loadModel(
        ModelRef(manifestPath: f.manifestPath),
      );
      expect(
        result.errorOrNull,
        isA<ModelChecksumMismatch>(),
        reason:
            'a model whose weights changed by one byte must not load. '
            'Weights read in the wrong layout do not fail loudly; they '
            'produce a confident wrong answer, and here that is an accusation '
            'against a customer.',
      );
    });

    test(
      'a truncated download is caught by the length before the hash',
      () async {
        final f = make(weights: utf8.encode('x' * 100), overrideBytes: 999);
        final result = await engine.loadModel(
          ModelRef(manifestPath: f.manifestPath),
        );
        final error = result.errorOrNull!;
        expect(error, isA<ModelChecksumMismatch>());
        expect(error.detail, contains('999'));
      },
    );

    test('missing weights are told apart from wrong weights', () async {
      // The difference tells an operator whether apt finished or whether
      // something is corrupt. Collapsing them into one status loses that.
      final f = make();
      File(f.weightsPath).deleteSync();
      final result = await engine.loadModel(
        ModelRef(manifestPath: f.manifestPath),
      );
      expect(result.errorOrNull, isA<ModelNotFound>());
    });

    test('a pin that does not match refuses the load', () async {
      final f = make(version: '1.4.0');

      final wrong = await engine.loadModel(
        ModelRef(manifestPath: f.manifestPath, pinnedVersion: '1.3.0'),
      );
      expect(wrong.errorOrNull, isA<ModelPinMismatch>());
      expect(
        wrong.errorOrNull!.detail,
        allOf(contains('1.3.0'), contains('1.4.0')),
        reason:
            'both versions must be in the message or an operator cannot '
            'tell which end is wrong',
      );

      // The right pin gets past the pin check and on to the session, which is
      // where this build stops.
      final right = await engine.loadModel(
        ModelRef(manifestPath: f.manifestPath, pinnedVersion: '1.4.0'),
      );
      expect(right.errorOrNull, isA<NotImplemented>());
    });

    test(
      'a retention that is absent, zero or unbounded refuses the load',
      () async {
        // И93 and И94 as a refusal rather than a default. A result with no
        // retention is a result kept forever.
        final zero = make(retentionSeconds: 0);
        final zeroResult = await engine.loadModel(
          ModelRef(manifestPath: zero.manifestPath),
        );
        expect(zeroResult.errorOrNull, isA<ManifestMalformed>());
        expect(zeroResult.errorOrNull!.detail, contains('kept forever'));

        final huge = make(retentionSeconds: 4294967295);
        final hugeResult = await engine.loadModel(
          ModelRef(manifestPath: huge.manifestPath),
        );
        expect(hugeResult.errorOrNull, isA<ManifestMalformed>());
        expect(hugeResult.errorOrNull!.detail, contains('ceiling'));

        final missing = make();
        final text = File(missing.manifestPath).readAsStringSync();
        File(missing.manifestPath).writeAsStringSync(
          text
              .split('\n')
              .where((l) => !l.startsWith('Retention-Seconds'))
              .join('\n'),
        );
        final missingResult = await engine.loadModel(
          ModelRef(manifestPath: missing.manifestPath),
        );
        expect(missingResult.errorOrNull, isA<ManifestMalformed>());
        expect(
          missingResult.errorOrNull!.detail,
          contains('Retention-Seconds'),
        );
      },
    );

    test('a model from a newer world is incompatible, not malformed', () async {
      final newerSchema = make(schema: 2);
      expect(
        (await engine.loadModel(
          ModelRef(manifestPath: newerSchema.manifestPath),
        )).errorOrNull,
        isA<ModelIncompatible>(),
      );

      final newerAbi = make(minAbi: 2);
      final abiResult = await engine.loadModel(
        ModelRef(manifestPath: newerAbi.manifestPath),
      );
      expect(abiResult.errorOrNull, isA<ModelIncompatible>());
      expect(abiResult.errorOrNull!.detail, contains('ABI'));
    });

    test('an unknown task is named, and the known ones are listed', () async {
      final f = make(task: 'faceMatch');
      final result = await engine.loadModel(
        ModelRef(manifestPath: f.manifestPath),
      );
      final detail = result.errorOrNull!.detail;
      expect(result.errorOrNull, isA<ManifestMalformed>());
      expect(detail, contains('visitorCount'));
      expect(detail, contains('unscannedItemHint'));
      expect(
        detail,
        isNot(contains('faceMatch is supported')),
        reason:
            'face matching is not in section 9 or section 10 and is not '
            'in scope here',
      );
    });

    test('a valid model gets as far as the session and stops there', () async {
      // Everything up to the runtime session is finished, and this is the
      // seam. If the day comes that this returns InferOk, that is real
      // progress and this test should be rewritten -- but it must never
      // quietly become an empty success.
      final f = make();
      final result = await engine.loadModel(
        ModelRef(manifestPath: f.manifestPath),
      );

      expect(
        result.errorOrNull,
        isA<NotImplemented>(),
        reason:
            'if this ever passes with an empty model, the session path is '
            'a stub returning a plausible value',
      );

      final detail = result.errorOrNull!.detail;
      for (final entry in <String>[
        'CreateSession',
        'CreateTensorWithDataAsOrtValue',
        'Run',
      ]) {
        expect(
          detail,
          contains(entry),
          reason: 'an unfinished path names what is missing',
        );
      }
    });
  });

  group('nothing about a frame comes back out', () {
    test('an error never echoes the bytes it was handed', () async {
      // The real leak vector is not a getter someone adds on purpose; it is a
      // failure message that helpfully includes the buffer. Put a pattern in
      // the weights that nothing else would produce, make the load fail, and
      // demand the pattern is absent from what comes back.
      const marker = 'MARKER-6f2ad3c1-NOT-FOR-EYES';
      final payload = utf8.encode('$marker${' ' * 32}$marker');

      final f = ModelFixture.create(
        name: 'leaky',
        weights: payload,
        // A checksum that will not match, so the failure path runs with the
        // marker sitting in the file it just read.
        overrideSha: '0' * 64,
      );
      addTearDown(f.dispose);

      final engine = (await NativeInferenceEngine.start(
        bindingLibraryPath: bindingLibraryPath,
        runtimeLibraryPath: stubRuntimePath,
      )).valueOrNull!;
      addTearDown(engine.close);

      final result = await engine.loadModel(
        ModelRef(manifestPath: f.manifestPath),
      );
      final rendered =
          '${result.errorOrNull} ${result.errorOrNull!.detail} '
          '$result';

      expect(result.errorOrNull, isA<ModelChecksumMismatch>());
      expect(
        rendered,
        isNot(contains(marker)),
        reason:
            'the failure carried content out of the file it read. A hash '
            'and a length are facts about the bytes; the bytes are not.',
      );
      expect(
        rendered,
        contains('hashes to'),
        reason:
            'it should say what it computed -- that is the useful part, '
            'and it is not the content',
      );
    });
  });
}

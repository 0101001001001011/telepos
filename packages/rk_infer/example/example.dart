// A visitor counter, from start-up to shutdown, with every failure handled as
// the value it is.
//
// Run it against a built native library:
//
//   cd rust && cargo build
//   dart run example/example.dart ../rust/target/debug/librk_infer.so \
//        /opt/telepos/models/visitor-counter/model.manifest
//
// It will get as far as the model verification chain and stop at
// `NotImplemented`, because the ONNX Runtime session path is not bound yet.
// That is the honest state of this release, and the example shows it rather
// than pretending otherwise.

import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:rk_infer/rk_infer.dart';

Future<void> main(List<String> args) async {
  if (args.length < 2) {
    stderr.writeln(
      'usage: example.dart <librk_infer path> <model.manifest> '
      '[onnxruntime path]',
    );
    exitCode = 2;
    return;
  }

  final bindingPath = args[0];
  final manifestPath = args[1];
  final runtimePath = args.length > 2 ? args[2] : null;

  // 1. Start the engine. It lives in its own isolate from here on; nothing
  //    below this line runs native code where the interface lives.
  final started = await NativeInferenceEngine.start(
    bindingLibraryPath: bindingPath,
    runtimeLibraryPath: runtimePath,
  );

  if (started case InferErr(:final error)) {
    // A till sells without inference. It does not sell without a till, so this
    // is a degraded feature, not a fault.
    stderr.writeln('inference unavailable: $error');
    exitCode = 1;
    return;
  }
  final engine = (started as InferOk<NativeInferenceEngine>).value;

  final caps = (await engine.capabilities()).valueOrNull!;
  stdout.writeln('engine: $caps');

  // 2. Load the model, pinned. The repository is allowed to move on; this
  //    terminal is not, until someone says so.
  final loaded = await engine.loadModel(
    ModelRef(manifestPath: manifestPath, pinnedVersion: '1.4.0'),
  );

  if (loaded case InferErr(:final error)) {
    stderr.writeln('model not usable: $error');
    await engine.close();
    exitCode = 1;
    return;
  }
  final model = (loaded as InferOk<LoadedModel>).value;
  stdout.writeln('loaded: $model');
  stdout.writeln('results from it may be kept for ${model.retention.inHours}h');

  // 3. Run a frame.
  //
  //    In production `pixels` comes from the video source -- an ONVIF/RTSP
  //    reader, which is somebody else's component, because the module that can
  //    open a socket must not be the module that holds frames. Here it is a
  //    flat grey field of exactly the right size.
  final pixels = Uint8List(model.input.byteLength)
    ..fillRange(0, model.input.byteLength, 0x80);

  // Building the transfer detaches `pixels`: after this line this code no
  // longer has the frame either, which is the point.
  final frame = TransferableTypedData.fromList(<TypedData>[pixels]);

  switch (await engine.run(model, frame)) {
    case InferOk(:final value):
      stdout.writeln(
        '${value.detections.length} detection(s), '
        'keep until ${value.retainUntil.toIso8601String()}',
      );
      for (final d in value.detections) {
        stdout.writeln('  $d');
      }
    case InferErr(:final error):
      stderr.writeln('run failed: $error');
  }

  // 4. Release native memory now, rather than when a collector gets round to
  //    it. A frame is megabytes and a session is more.
  await engine.unload(model);
  await engine.close();
}

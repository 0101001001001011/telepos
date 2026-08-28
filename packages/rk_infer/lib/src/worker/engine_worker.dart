/// The worker isolate, and the only way into the native side.
///
/// # Why an isolate, and why a long-lived one (И145)
///
/// A run is tens to hundreds of milliseconds on the hardware this product
/// actually ships to. On the isolate that also runs the interface, that is a
/// till frozen in the middle of a sale. A blocking FFI call on an isolate that
/// also runs the Flutter engine either hangs the interface or, with bad luck
/// on scheduling, runs into the isolate group's thread limit -- a documented
/// hazard of blocking FFI in Dart, and the reason the SDK's own advice is to
/// put blocking native code on its own isolate.
///
/// Long-lived, not one isolate per frame: a model costs real time and real
/// memory to load, and re-opening a session per frame would cost more than
/// anything an accelerator could give back.
///
/// # Why this is structural rather than a rule
///
/// [NativeInferenceEngine] is the only implementation exported from this
/// package, every one of its methods returns a `Future`, and every one of them
/// is a message to this isolate. There is no synchronous entry point, so there
/// is no shape of call a consumer could write that runs native code where the
/// interface lives. `test/isolate_discipline_test.dart` fails if one appears.
library;

import 'dart:async';
import 'dart:isolate';

import '../contract.dart';
import '../ffi/native_session.dart';

// ---------------------------------------------------------------------------
// Protocol
// ---------------------------------------------------------------------------

/// What the worker needs to start. Only sendable values.
final class WorkerBoot {
  const WorkerBoot({
    required this.reply,
    required this.bindingLibraryPath,
    required this.runtimeLibraryPath,
  });

  final SendPort reply;
  final String bindingLibraryPath;
  final String? runtimeLibraryPath;
}

/// The worker's first message back: either it is up, or it is not and why.
final class WorkerReady {
  const WorkerReady(this.requests, this.capabilities);

  /// `null` when start-up failed; the worker has already exited.
  final SendPort? requests;
  final InferResult<EngineCapabilities> capabilities;
}

sealed class WorkerRequest {
  const WorkerRequest(this.id, this.reply);
  final int id;
  final SendPort reply;
}

final class LoadModelRequest extends WorkerRequest {
  const LoadModelRequest(super.id, super.reply, this.ref);
  final ModelRef ref;
}

final class RunRequest extends WorkerRequest {
  const RunRequest(super.id, super.reply, this.model, this.frame);
  final LoadedModel model;

  /// A move, not a copy. The buffers this was built from were detached from
  /// the sender when it was created, so by the time it is here nobody else has
  /// the pixels.
  final TransferableTypedData frame;
}

final class UnloadRequest extends WorkerRequest {
  const UnloadRequest(super.id, super.reply, this.model);
  final LoadedModel model;
}

final class CapabilitiesRequest extends WorkerRequest {
  const CapabilitiesRequest(super.id, super.reply);
}

final class CloseRequest extends WorkerRequest {
  const CloseRequest(super.id, super.reply);
}

final class WorkerReply {
  const WorkerReply(this.id, this.result);
  final int id;

  /// `InferResult<Object?>` rather than `Object`, and the difference is not
  /// pedantry: a field typed `Object` can hold a frame, and no check over this
  /// package's surface could tell. Naming the real type keeps
  /// `test/no_raw_frame_test.dart` able to reason about what travels here.
  final InferResult<Object?> result;
}

// ---------------------------------------------------------------------------
// The isolate body
// ---------------------------------------------------------------------------

/// Runs in the worker isolate. Top-level, because `Isolate.spawn` requires it.
Future<void> engineWorkerMain(WorkerBoot boot) async {
  final opened = NativeEngineSession.open(
    bindingLibraryPath: boot.bindingLibraryPath,
    runtimeLibraryPath: boot.runtimeLibraryPath,
  );

  if (opened case InferErr<NativeEngineSession>(:final error)) {
    boot.reply.send(WorkerReady(null, InferErr<EngineCapabilities>(error)));
    return;
  }

  final session = (opened as InferOk<NativeEngineSession>).value;
  final requests = ReceivePort();
  boot.reply.send(
    WorkerReady(
      requests.sendPort,
      InferOk<EngineCapabilities>(session.capabilities),
    ),
  );

  await for (final message in requests) {
    if (message is! WorkerRequest) continue;

    // Every branch answers with a value. Nothing here can throw past this
    // loop: if it did, the worker would die silently and every pending caller
    // would wait forever (И144).
    InferResult<Object?> result;
    try {
      result = switch (message) {
        CapabilitiesRequest() => InferOk<EngineCapabilities>(
          session.capabilities,
        ),
        LoadModelRequest(:final ref) => session.loadModel(ref),
        UnloadRequest(:final model) => session.unload(model),
        RunRequest(:final model, :final frame) => session.run(
          model,
          // Materialising is what consumes the transfer. It can only happen
          // once, and it happens here, inside the isolate that owns the
          // engine. The bytes exist on the Dart heap for the length of the
          // copy into the native buffer and nowhere else.
          frame.materialize().asUint8List(),
        ),
        CloseRequest() => session.close(),
      };
    } on Object catch (e, stack) {
      // A bug in this binding, reported rather than dropped. The stack is
      // included; the frame is not, and cannot be -- nothing in this catch has
      // access to it.
      result = InferErr<Object>(
        NativeFault('rk_infer worker threw: $e\n$stack'),
      );
    }

    message.reply.send(WorkerReply(message.id, result));

    if (message is CloseRequest) {
      requests.close();
      return;
    }
  }
}

// ---------------------------------------------------------------------------
// The public implementation
// ---------------------------------------------------------------------------

/// The engine, backed by a worker isolate.
///
/// Start it with [start], which is the only constructor: an engine that failed
/// to open is an [InferErr], not a half-built object whose methods fail later.
final class NativeInferenceEngine implements InferenceEngine {
  NativeInferenceEngine._(this._isolate, this._requests, this._capabilities);

  final Isolate _isolate;
  SendPort? _requests;
  final EngineCapabilities _capabilities;

  int _nextId = 1;
  bool _closed = false;

  /// Starts the worker and opens the engine inside it.
  ///
  /// `bindingLibraryPath` is the `rk_infer` shared library. It is required
  /// rather than guessed: which mechanism puts it where Dart can find it is
  /// one decision taken once for all the `rk_*` packages, and this package
  /// does not pre-empt it.
  ///
  /// `runtimeLibraryPath` is the inference runtime (ONNX Runtime). `null`
  /// searches the platform defaults, which include the path the TelePOS apt
  /// package installs to.
  static Future<InferResult<NativeInferenceEngine>> start({
    required String bindingLibraryPath,
    String? runtimeLibraryPath,
  }) async {
    final ready = ReceivePort();
    final Isolate isolate;
    try {
      isolate = await Isolate.spawn(
        engineWorkerMain,
        WorkerBoot(
          reply: ready.sendPort,
          bindingLibraryPath: bindingLibraryPath,
          runtimeLibraryPath: runtimeLibraryPath,
        ),
        debugName: 'rk_infer',
        errorsAreFatal: true,
      );
    } on Object catch (e) {
      ready.close();
      return InferErr<NativeInferenceEngine>(
        EngineStopped('could not spawn the rk_infer worker isolate: $e'),
      );
    }

    final first = await ready.first;
    ready.close();

    if (first is! WorkerReady) {
      isolate.kill(priority: Isolate.immediate);
      return InferErr<NativeInferenceEngine>(
        NativeFault('the worker sent ${first.runtimeType} instead of a ready'),
      );
    }

    if (first.requests == null) {
      return InferErr<NativeInferenceEngine>(
        first.capabilities.errorOrNull ??
            const EngineStopped(
              'the worker refused to start without saying '
              'why, which is itself a bug',
            ),
      );
    }

    return InferOk<NativeInferenceEngine>(
      NativeInferenceEngine._(
        isolate,
        first.requests!,
        (first.capabilities as InferOk<EngineCapabilities>).value,
      ),
    );
  }

  /// What this engine is. Answered from memory, so it costs nothing and still
  /// returns a `Future`, because a synchronous method on this interface is the
  /// hole И145 is about.
  @override
  Future<InferResult<EngineCapabilities>> capabilities() async => _closed
      ? const InferErr<EngineCapabilities>(EngineStopped('engine closed'))
      : InferOk<EngineCapabilities>(_capabilities);

  @override
  Future<InferResult<LoadedModel>> loadModel(ModelRef ref) =>
      _ask<LoadedModel>((id, reply) => LoadModelRequest(id, reply, ref));

  @override
  Future<InferResult<InferenceOutput>> run(
    LoadedModel model,
    TransferableTypedData frame,
  ) =>
      _ask<InferenceOutput>((id, reply) => RunRequest(id, reply, model, frame));

  @override
  Future<InferResult<void>> unload(LoadedModel model) =>
      _ask<void>((id, reply) => UnloadRequest(id, reply, model));

  @override
  Future<InferResult<void>> close() async {
    if (_closed) return const InferOk<void>(null);
    final result = await _ask<void>((id, reply) => CloseRequest(id, reply));
    _closed = true;
    _requests = null;
    // The worker returns from its loop after answering a close; the kill is
    // belt and braces for the case where it did not get that far.
    _isolate.kill(priority: Isolate.beforeNextEvent);
    return result;
  }

  Future<InferResult<T>> _ask<T>(
    WorkerRequest Function(int id, SendPort reply) build,
  ) async {
    final requests = _requests;
    if (_closed || requests == null) {
      return const InferErr<Never>(
            EngineStopped('the engine is closed; start a new one'),
          )
          as InferResult<T>;
    }

    final reply = ReceivePort();
    try {
      final id = _nextId++;
      requests.send(build(id, reply.sendPort));
      final answer = await reply.first;

      if (answer is! WorkerReply || answer.id != id) {
        return InferErr<T>(
          NativeFault('the worker answered out of order or with rubbish'),
        );
      }
      final result = answer.result;
      if (result is InferResult<T>) return result;
      // The worker builds a result of the right type for each request; a
      // mismatch means the two sides have drifted, and a wrong-typed cast
      // would hide that.
      if (result is InferErr) return InferErr<T>(result.error);
      return InferErr<T>(
        NativeFault(
          'the worker answered with ${result.runtimeType} where '
          'InferResult<$T> was expected',
        ),
      );
    } on Object catch (e) {
      // The worker died mid-request; the caller gets a value, not a hang.
      return InferErr<T>(EngineStopped('the rk_infer worker went away: $e'));
    } finally {
      reply.close();
    }
  }
}

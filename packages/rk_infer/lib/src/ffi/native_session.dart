/// The synchronous native driver.
///
/// **Everything here blocks, and everything here runs inside the worker
/// isolate.** Nothing in this file is exported from the package, and the
/// public interface has no synchronous method, so there is no call shape that
/// reaches this code on the interface isolate (И145).
///
/// It also holds the one place a pointer into frame memory exists on the Dart
/// side: [NativeEngineSession.run] takes the write pointer Rust hands back,
/// copies the caller's pixels in, and drops the view. That pointer travels
/// inbound only. It does not leave [NativeEngineSession.run], it is never
/// stored, and nothing this class returns is derived from it.
library;

import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

import '../contract.dart';
import 'bindings.dart';

/// The ABI version this binding was written against. See
/// `RK_INFER_ABI_VERSION` in `rust/include/rk_infer.h`.
const int expectedAbiVersion = 1;

final class NativeEngineSession {
  NativeEngineSession._(this._lib, this._engine, this._capabilities);

  final RkInferLib _lib;
  Pointer<NativeEngine> _engine;
  final EngineCapabilities _capabilities;

  final Map<int, Pointer<NativeModel>> _models = <int, Pointer<NativeModel>>{};
  int _nextHandle = 1;

  EngineCapabilities get capabilities => _capabilities;

  /// Opens the `rk_infer` library and, through it, the inference runtime.
  ///
  /// `runtimeLibraryPath` overrides where the runtime is looked for; `null`
  /// uses the platform defaults, which include the path the TelePOS apt
  /// package installs to.
  static InferResult<NativeEngineSession> open({
    required String bindingLibraryPath,
    String? runtimeLibraryPath,
  }) {
    final RkInferLib lib;
    try {
      lib = RkInferLib.open(bindingLibraryPath);
    } on Object catch (e) {
      // Loading the *binding* is the one thing that can still throw, because
      // it happens before any of our own code runs. Turned into a value here
      // so no caller ever has to catch (И144).
      return InferErr<NativeEngineSession>(
        EngineUnavailable('could not load $bindingLibraryPath: $e'),
      );
    }

    final abi = lib.abiVersion();
    if (abi != expectedAbiVersion) {
      return InferErr<NativeEngineSession>(
        EngineIncompatible(
          '$bindingLibraryPath reports ABI $abi; this binding is written '
          'against ABI $expectedAbiVersion. Refusing rather than guessing: a '
          'mismatched layout reads as plausible garbage, not as an error.',
        ),
      );
    }

    // И147, checked rather than assumed. If the library can produce a status
    // name this binding has no case for, say so at start-up instead of
    // discovering it during a sale.
    final nativeNames = lib.statusNames().toDartString().split(',');
    final unmapped = nativeNames
        .where((n) => !InferError.knownNames.contains(n))
        .toList();
    if (unmapped.isNotEmpty) {
      return InferErr<NativeEngineSession>(
        EngineIncompatible(
          '$bindingLibraryPath can return status name(s) this binding does not '
          'map: ${unmapped.join(", ")}. Update InferError.fromName.',
        ),
      );
    }

    final enginePtr = calloc<Pointer<NativeEngine>>();
    final detailPtr = calloc<Pointer<Utf8>>();
    final pathPtr = runtimeLibraryPath == null
        ? nullptr as Pointer<Utf8>
        : runtimeLibraryPath.toNativeUtf8();
    try {
      final status = lib.engineOpen(pathPtr, enginePtr, detailPtr);
      final failure = _failureOrNull(lib, status, detailPtr);
      if (failure != null) {
        return InferErr<NativeEngineSession>(failure);
      }

      final engine = enginePtr.value;
      final providerName = lib.engineProvider(engine).toDartString();
      final provider = ExecutionProvider.fromWireName(providerName);
      if (provider == null) {
        lib.engineClose(engine);
        return InferErr<NativeEngineSession>(
          EngineIncompatible(
            'the library reports execution provider "$providerName", which '
            'this binding does not know. Names cross the ABI, so an unknown '
            'one is reported, never mapped onto whichever case sits at that '
            'index.',
          ),
        );
      }

      final versionPtr = lib.engineRuntimeVersion(engine);
      return InferOk<NativeEngineSession>(
        NativeEngineSession._(
          lib,
          engine,
          EngineCapabilities(
            abiVersion: abi,
            provider: provider,
            runtimeVersion: versionPtr == nullptr
                ? null
                : versionPtr.toDartString(),
            runtimeLibraryPath: runtimeLibraryPath ?? '(platform default)',
          ),
        ),
      );
    } finally {
      calloc.free(enginePtr);
      calloc.free(detailPtr);
      if (pathPtr != nullptr) calloc.free(pathPtr);
    }
  }

  InferResult<LoadedModel> loadModel(ModelRef ref) {
    if (_engine == nullptr) {
      return const InferErr<LoadedModel>(EngineStopped('the engine is closed'));
    }

    final outPtr = calloc<Pointer<NativeModel>>();
    final detailPtr = calloc<Pointer<Utf8>>();
    final manifestPtr = ref.manifestPath.toNativeUtf8();
    final pinPtr = ref.pinnedVersion == null
        ? nullptr as Pointer<Utf8>
        : ref.pinnedVersion!.toNativeUtf8();
    try {
      final status = _lib.modelLoad(
        _engine,
        manifestPtr,
        pinPtr,
        outPtr,
        detailPtr,
      );
      final failure = _failureOrNull(_lib, status, detailPtr);
      if (failure != null) return InferErr<LoadedModel>(failure);

      final model = outPtr.value;
      final taskName = _lib.modelTask(model).toDartString();
      final task = InferenceTask.fromWireName(taskName);
      final formatName = _lib.modelInputFormat(model).toDartString();
      final format = PixelFormat.fromWireName(formatName);

      if (task == null || format == null) {
        _lib.modelUnload(model);
        return InferErr<LoadedModel>(
          ModelIncompatible(
            'the model declares task "$taskName" and format "$formatName"; '
            'this binding knows tasks '
            '${InferenceTask.values.map((t) => t.wireName).join(", ")} and '
            'formats ${PixelFormat.values.map((f) => f.wireName).join(", ")}.',
          ),
        );
      }

      final handle = _nextHandle++;
      _models[handle] = model;

      return InferOk<LoadedModel>(
        LoadedModel(
          handle: handle,
          name: _lib.modelName(model).toDartString(),
          version: _lib.modelVersion(model).toDartString(),
          task: task,
          input: FrameSpec(
            width: _lib.modelInputWidth(model),
            height: _lib.modelInputHeight(model),
            format: format,
          ),
          retention: Duration(seconds: _lib.modelRetentionSeconds(model)),
        ),
      );
    } finally {
      calloc.free(outPtr);
      calloc.free(detailPtr);
      calloc.free(manifestPtr);
      if (pinPtr != nullptr) calloc.free(pinPtr);
    }
  }

  /// Runs one frame.
  ///
  /// # И146, in the order it happens
  ///
  /// 1. Rust allocates the pixel buffer and hands back a write pointer.
  /// 2. This method copies `pixels` in through that pointer and drops the
  ///    view. The pointer does not outlive this statement and is never stored.
  /// 3. The run borrows the frame; ownership stays with the frame handle.
  /// 4. `finally` frees the frame -- on success, on failure, and on the way
  ///    out of a thrown error. A six-megabyte buffer does not wait for a
  ///    collector.
  ///
  /// Nothing derived from those pixels is in the returned value.
  InferResult<InferenceOutput> run(LoadedModel model, Uint8List pixels) {
    if (_engine == nullptr) {
      return const InferErr<InferenceOutput>(
        EngineStopped('the engine is closed'),
      );
    }
    final modelPtr = _models[model.handle];
    if (modelPtr == null) {
      return InferErr<InferenceOutput>(
        InvalidArgument(
          'model handle ${model.handle} is not loaded in this engine; it was '
          'unloaded, or it came from a different engine',
        ),
      );
    }

    final expected = model.input.byteLength;
    if (pixels.length != expected) {
      return InferErr<InferenceOutput>(
        FrameShapeMismatch(
          'model ${model.name} ${model.version} expects ${model.input} '
          '= $expected bytes, got ${pixels.length}',
        ),
      );
    }

    final framePtr = calloc<Pointer<NativeFrame>>();
    final writePtr = calloc<Pointer<Uint8>>();
    final bytesPtr = calloc<Size>();
    final detailPtr = calloc<Pointer<Utf8>>();
    final outPtr = calloc<Pointer<NativeOutcome>>();
    final formatPtr = model.input.format.wireName.toNativeUtf8();

    Pointer<NativeFrame> frame = nullptr;
    Pointer<NativeOutcome> outcome = nullptr;
    try {
      final allocStatus = _lib.frameNew(
        model.input.width,
        model.input.height,
        formatPtr,
        framePtr,
        writePtr,
        bytesPtr,
        detailPtr,
      );
      final allocFailure = _failureOrNull(_lib, allocStatus, detailPtr);
      if (allocFailure != null) return InferErr<InferenceOutput>(allocFailure);

      frame = framePtr.value;
      final capacity = bytesPtr.value;
      if (capacity != expected) {
        return InferErr<InferenceOutput>(
          FrameShapeMismatch(
            'the native side allocated $capacity bytes for ${model.input} '
            'where this binding computed $expected; the two disagree about the '
            'layout and neither should guess',
          ),
        );
      }

      // The one inbound copy. `asTypedList` is a view onto Rust's buffer; it
      // is written and immediately forgotten. Nothing reads it back.
      writePtr.value.asTypedList(capacity).setAll(0, pixels);

      final runStatus = _lib.run(modelPtr, frame, outPtr, detailPtr);
      final runFailure = _failureOrNull(_lib, runStatus, detailPtr);
      if (runFailure != null) return InferErr<InferenceOutput>(runFailure);

      outcome = outPtr.value;
      final count = _lib.outcomeLen(outcome);
      final detections = <Detection>[];
      for (var i = 0; i < count; i++) {
        final d = _lib.outcomeAt(outcome, i);
        if (d == nullptr) continue;
        final ref = d.ref;
        detections.add(
          Detection(
            className: ref.className == nullptr
                ? ''
                : ref.className.toDartString(),
            confidence: ref.confidence,
            x: ref.x,
            y: ref.y,
            width: ref.w,
            height: ref.h,
          ),
        );
      }

      return InferOk<InferenceOutput>(
        InferenceOutput(
          task: model.task,
          detections: List<Detection>.unmodifiable(detections),
          retainUntil: DateTime.fromMillisecondsSinceEpoch(
            _lib.outcomeRetainUntil(outcome) * 1000,
            isUtc: true,
          ),
        ),
      );
    } finally {
      if (outcome != nullptr) _lib.outcomeFree(outcome);
      if (frame != nullptr) _lib.frameFree(frame);
      calloc.free(framePtr);
      calloc.free(writePtr);
      calloc.free(bytesPtr);
      calloc.free(detailPtr);
      calloc.free(outPtr);
      calloc.free(formatPtr);
    }
  }

  InferResult<void> unload(LoadedModel model) {
    final ptr = _models.remove(model.handle);
    if (ptr == null) {
      return InferErr<void>(
        InvalidArgument('model handle ${model.handle} is not loaded'),
      );
    }
    _lib.modelUnload(ptr);
    return const InferOk<void>(null);
  }

  InferResult<void> close() {
    if (_engine == nullptr) return const InferOk<void>(null);

    // Unload before closing: the sessions live inside the runtime this is
    // about to unload, and the native side refuses with EngineBusy otherwise.
    for (final ptr in _models.values) {
      _lib.modelUnload(ptr);
    }
    _models.clear();

    final status = _lib.engineClose(_engine);
    if (status != nullptr) {
      return InferErr<void>(
        InferError.fromName(status.toDartString(), 'closing the engine'),
      );
    }
    _engine = nullptr;
    return const InferOk<void>(null);
  }

  /// Turns a status pointer plus its detail into an [InferError], or `null` if
  /// the call succeeded. Frees the detail either way -- the header says the
  /// caller owns it, and this is the caller.
  static InferError? _failureOrNull(
    RkInferLib lib,
    Pointer<Utf8> status,
    Pointer<Pointer<Utf8>> detailOut,
  ) {
    final detailPtr = detailOut.value;
    var detail = '';
    if (detailPtr != nullptr) {
      detail = detailPtr.toDartString();
      lib.stringFree(detailPtr);
      detailOut.value = nullptr;
    }
    if (status == nullptr) return null;
    return InferError.fromName(status.toDartString(), detail);
  }
}

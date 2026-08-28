/// `dart:ffi` lookups for `include/rk_infer.h`.
///
/// **This file is reached only from inside the worker isolate.** It is not
/// exported from `package:rk_infer/rk_infer.dart`, and the public interface
/// has no synchronous method, so there is no call shape that lands here on the
/// interface isolate (И145).
///
/// Every signature below mirrors a declaration in `rust/include/rk_infer.h`.
/// Read them together; a mismatch is not a compile error, it is memory read as
/// plausible garbage.
library;

import 'dart:ffi';

import 'package:ffi/ffi.dart';

/// Opaque handles. `Opaque` rather than a struct because the layouts belong to
/// Rust and nothing here should be able to reach inside them.
final class NativeFrame extends Opaque {}

final class NativeEngine extends Opaque {}

final class NativeModel extends Opaque {}

final class NativeOutcome extends Opaque {}

/// `RkInferDetection` from the header. Numbers and a borrowed class name --
/// there is nothing byte-shaped in it, by construction.
final class NativeDetection extends Struct {
  external Pointer<Utf8> className;

  @Double()
  external double confidence;

  @Double()
  external double x;

  @Double()
  external double y;

  @Double()
  external double w;

  @Double()
  external double h;
}

typedef _AbiVersionC = Uint32 Function();
typedef RkAbiVersionFn = int Function();

typedef _StringFreeC = Void Function(Pointer<Utf8>);
typedef RkStringFreeFn = void Function(Pointer<Utf8>);

typedef _NamesC = Pointer<Utf8> Function();
typedef RkNamesFn = Pointer<Utf8> Function();

typedef _FrameNewC =
    Pointer<Utf8> Function(
      Uint32,
      Uint32,
      Pointer<Utf8>,
      Pointer<Pointer<NativeFrame>>,
      Pointer<Pointer<Uint8>>,
      Pointer<Size>,
      Pointer<Pointer<Utf8>>,
    );
typedef RkFrameNewFn =
    Pointer<Utf8> Function(
      int,
      int,
      Pointer<Utf8>,
      Pointer<Pointer<NativeFrame>>,
      Pointer<Pointer<Uint8>>,
      Pointer<Size>,
      Pointer<Pointer<Utf8>>,
    );

typedef _FrameBytesC = Size Function(Pointer<NativeFrame>);
typedef RkFrameBytesFn = int Function(Pointer<NativeFrame>);

typedef _FrameFreeC = Pointer<Utf8> Function(Pointer<NativeFrame>);
typedef RkFrameFreeFn = Pointer<Utf8> Function(Pointer<NativeFrame>);

typedef _EngineOpenC =
    Pointer<Utf8> Function(
      Pointer<Utf8>,
      Pointer<Pointer<NativeEngine>>,
      Pointer<Pointer<Utf8>>,
    );
typedef RkEngineOpenFn =
    Pointer<Utf8> Function(
      Pointer<Utf8>,
      Pointer<Pointer<NativeEngine>>,
      Pointer<Pointer<Utf8>>,
    );

typedef _EngineCloseC = Pointer<Utf8> Function(Pointer<NativeEngine>);
typedef RkEngineCloseFn = Pointer<Utf8> Function(Pointer<NativeEngine>);

typedef _EngineStringC = Pointer<Utf8> Function(Pointer<NativeEngine>);
typedef RkEngineStringFn = Pointer<Utf8> Function(Pointer<NativeEngine>);

typedef _ModelLoadC =
    Pointer<Utf8> Function(
      Pointer<NativeEngine>,
      Pointer<Utf8>,
      Pointer<Utf8>,
      Pointer<Pointer<NativeModel>>,
      Pointer<Pointer<Utf8>>,
    );
typedef RkModelLoadFn =
    Pointer<Utf8> Function(
      Pointer<NativeEngine>,
      Pointer<Utf8>,
      Pointer<Utf8>,
      Pointer<Pointer<NativeModel>>,
      Pointer<Pointer<Utf8>>,
    );

typedef _ModelUnloadC = Void Function(Pointer<NativeModel>);
typedef RkModelUnloadFn = void Function(Pointer<NativeModel>);

typedef _ModelStringC = Pointer<Utf8> Function(Pointer<NativeModel>);
typedef RkModelStringFn = Pointer<Utf8> Function(Pointer<NativeModel>);

typedef _ModelU32C = Uint32 Function(Pointer<NativeModel>);
typedef RkModelU32Fn = int Function(Pointer<NativeModel>);

typedef _RunC =
    Pointer<Utf8> Function(
      Pointer<NativeModel>,
      Pointer<NativeFrame>,
      Pointer<Pointer<NativeOutcome>>,
      Pointer<Pointer<Utf8>>,
    );
typedef RkRunFn =
    Pointer<Utf8> Function(
      Pointer<NativeModel>,
      Pointer<NativeFrame>,
      Pointer<Pointer<NativeOutcome>>,
      Pointer<Pointer<Utf8>>,
    );

typedef _OutcomeLenC = Size Function(Pointer<NativeOutcome>);
typedef RkOutcomeLenFn = int Function(Pointer<NativeOutcome>);

typedef _OutcomeAtC =
    Pointer<NativeDetection> Function(Pointer<NativeOutcome>, Size);
typedef RkOutcomeAtFn =
    Pointer<NativeDetection> Function(Pointer<NativeOutcome>, int);

typedef _OutcomeRetainC = Uint64 Function(Pointer<NativeOutcome>);
typedef RkOutcomeRetainFn = int Function(Pointer<NativeOutcome>);

typedef _OutcomeFreeC = Void Function(Pointer<NativeOutcome>);
typedef RkOutcomeFreeFn = void Function(Pointer<NativeOutcome>);

/// The resolved symbols of one loaded `rk_infer` library.
///
/// Notice what is absent: there is no lookup for a function that reads pixels
/// out of a frame, because the header declares none. The absence is the
/// guarantee.
final class RkInferLib {
  RkInferLib._(this._lib)
    : abiVersion = _lib.lookupFunction<_AbiVersionC, RkAbiVersionFn>(
        'rk_infer_abi_version',
      ),
      stringFree = _lib.lookupFunction<_StringFreeC, RkStringFreeFn>(
        'rk_infer_string_free',
      ),
      statusNames = _lib.lookupFunction<_NamesC, RkNamesFn>(
        'rk_infer_status_names',
      ),
      pixelFormatNames = _lib.lookupFunction<_NamesC, RkNamesFn>(
        'rk_infer_pixel_format_names',
      ),
      taskNames = _lib.lookupFunction<_NamesC, RkNamesFn>(
        'rk_infer_task_names',
      ),
      frameNew = _lib.lookupFunction<_FrameNewC, RkFrameNewFn>(
        'rk_infer_frame_new',
      ),
      frameBytes = _lib.lookupFunction<_FrameBytesC, RkFrameBytesFn>(
        'rk_infer_frame_bytes',
      ),
      frameFree = _lib.lookupFunction<_FrameFreeC, RkFrameFreeFn>(
        'rk_infer_frame_free',
      ),
      engineOpen = _lib.lookupFunction<_EngineOpenC, RkEngineOpenFn>(
        'rk_infer_engine_open',
      ),
      engineClose = _lib.lookupFunction<_EngineCloseC, RkEngineCloseFn>(
        'rk_infer_engine_close',
      ),
      engineRuntimeVersion = _lib
          .lookupFunction<_EngineStringC, RkEngineStringFn>(
            'rk_infer_engine_runtime_version',
          ),
      engineProvider = _lib.lookupFunction<_EngineStringC, RkEngineStringFn>(
        'rk_infer_engine_provider',
      ),
      modelLoad = _lib.lookupFunction<_ModelLoadC, RkModelLoadFn>(
        'rk_infer_model_load',
      ),
      modelUnload = _lib.lookupFunction<_ModelUnloadC, RkModelUnloadFn>(
        'rk_infer_model_unload',
      ),
      modelName = _lib.lookupFunction<_ModelStringC, RkModelStringFn>(
        'rk_infer_model_name',
      ),
      modelVersion = _lib.lookupFunction<_ModelStringC, RkModelStringFn>(
        'rk_infer_model_version',
      ),
      modelTask = _lib.lookupFunction<_ModelStringC, RkModelStringFn>(
        'rk_infer_model_task',
      ),
      modelInputFormat = _lib.lookupFunction<_ModelStringC, RkModelStringFn>(
        'rk_infer_model_input_format',
      ),
      modelInputWidth = _lib.lookupFunction<_ModelU32C, RkModelU32Fn>(
        'rk_infer_model_input_width',
      ),
      modelInputHeight = _lib.lookupFunction<_ModelU32C, RkModelU32Fn>(
        'rk_infer_model_input_height',
      ),
      modelRetentionSeconds = _lib.lookupFunction<_ModelU32C, RkModelU32Fn>(
        'rk_infer_model_retention_seconds',
      ),
      run = _lib.lookupFunction<_RunC, RkRunFn>('rk_infer_run'),
      outcomeLen = _lib.lookupFunction<_OutcomeLenC, RkOutcomeLenFn>(
        'rk_infer_outcome_len',
      ),
      outcomeAt = _lib.lookupFunction<_OutcomeAtC, RkOutcomeAtFn>(
        'rk_infer_outcome_at',
      ),
      outcomeRetainUntil = _lib
          .lookupFunction<_OutcomeRetainC, RkOutcomeRetainFn>(
            'rk_infer_outcome_retain_until',
          ),
      outcomeFree = _lib.lookupFunction<_OutcomeFreeC, RkOutcomeFreeFn>(
        'rk_infer_outcome_free',
      );

  /// Opens the `rk_infer` shared library.
  ///
  /// `path` is required rather than guessed, and stays required now that the
  /// mechanism is settled: since 0.2.0 this package is an FFI plugin, so a
  /// Flutter build places the library where the platform expects it. This
  /// binding still asks the caller, because it is also used outside a Flutter
  /// build -- from a plain Dart process, from tests against a freshly built
  /// crate -- and guessing there produces a wrong answer that looks like a
  /// missing file.
  factory RkInferLib.open(String path) =>
      RkInferLib._(DynamicLibrary.open(path));

  /// Uses the symbols already in the running process. Useful when the library
  /// is statically linked.
  factory RkInferLib.openProcess() => RkInferLib._(DynamicLibrary.process());

  // ignore: unused_field
  final DynamicLibrary _lib;

  final RkAbiVersionFn abiVersion;
  final RkStringFreeFn stringFree;
  final RkNamesFn statusNames;
  final RkNamesFn pixelFormatNames;
  final RkNamesFn taskNames;
  final RkFrameNewFn frameNew;
  final RkFrameBytesFn frameBytes;
  final RkFrameFreeFn frameFree;
  final RkEngineOpenFn engineOpen;
  final RkEngineCloseFn engineClose;
  final RkEngineStringFn engineRuntimeVersion;
  final RkEngineStringFn engineProvider;
  final RkModelLoadFn modelLoad;
  final RkModelUnloadFn modelUnload;
  final RkModelStringFn modelName;
  final RkModelStringFn modelVersion;
  final RkModelStringFn modelTask;
  final RkModelStringFn modelInputFormat;
  final RkModelU32Fn modelInputWidth;
  final RkModelU32Fn modelInputHeight;
  final RkModelU32Fn modelRetentionSeconds;
  final RkRunFn run;
  final RkOutcomeLenFn outcomeLen;
  final RkOutcomeAtFn outcomeAt;
  final RkOutcomeRetainFn outcomeRetainUntil;
  final RkOutcomeFreeFn outcomeFree;
}

/// The contract: everything a caller of `rk_infer` can name.
///
/// Nothing in this file imports `dart:ffi`, and nothing in it can return the
/// bytes of a frame. Both of those are load-bearing, and both are checked by
/// `test/no_raw_frame_test.dart` rather than promised here.
///
/// `dart:isolate` is imported for one type, [TransferableTypedData], and that
/// is the only reason this package is not web-safe. It does not need to be:
/// section 4 of the architecture gives `ownsDevices` to `desktop` and
/// `appliance` only, section 8 hangs the camera off ONVIF/RTSP on the shop
/// network, and inference therefore happens on the host that owns the camera.
/// A browser never does. И143 keeps the web build honest by keeping this
/// package out of `lib/presentation/` entirely.
library;

import 'dart:isolate' show TransferableTypedData;

// ---------------------------------------------------------------------------
// Failures
// ---------------------------------------------------------------------------

/// A failure, as a value.
///
/// И144: nothing from the native side arrives as a thrown exception. Every
/// native status becomes one of these, and the mapping is **by name**
/// ([InferError.fromName]) rather than by an ordinal, so a library that grows
/// a new status in the middle of its list cannot silently turn one failure
/// into another (И147).
///
/// A name this build has no case for becomes [UnknownNativeStatus] carrying
/// the name, which is the honest answer: we know something failed and we know
/// what the other side called it.
sealed class InferError {
  const InferError(this.detail);

  /// What went wrong, in words, from whoever knew. Never contains pixels.
  final String detail;

  /// The name this failure crosses the ABI as.
  String get name;

  @override
  String toString() => detail.isEmpty ? name : '$name: $detail';

  /// Maps a native status name to a case. The single place a name becomes a
  /// type.
  static InferError fromName(String name, String detail) => switch (name) {
    'InvalidArgument' => InvalidArgument(detail),
    'ModelNotFound' => ModelNotFound(detail),
    'ManifestUnreadable' => ManifestUnreadable(detail),
    'ManifestMalformed' => ManifestMalformed(detail),
    'ModelChecksumMismatch' => ModelChecksumMismatch(detail),
    'ModelIncompatible' => ModelIncompatible(detail),
    'ModelPinMismatch' => ModelPinMismatch(detail),
    'EngineUnavailable' => EngineUnavailable(detail),
    'EngineIncompatible' => EngineIncompatible(detail),
    'EngineBusy' => EngineBusy(detail),
    'NotImplemented' => NotImplemented(detail),
    'UnsupportedPixelFormat' => UnsupportedPixelFormat(detail),
    'FrameShapeMismatch' => FrameShapeMismatch(detail),
    'FrameInUse' => FrameInUse(detail),
    'InferenceFailed' => InferenceFailed(detail),
    'NativeFault' => NativeFault(detail),
    _ => UnknownNativeStatus(name, detail),
  };

  /// Every name this build maps to a case of its own. A binding that knows
  /// this list can check it against `rk_infer_status_names()` at start-up
  /// instead of meeting an unmapped name in production.
  static const List<String> knownNames = <String>[
    'InvalidArgument',
    'ModelNotFound',
    'ManifestUnreadable',
    'ManifestMalformed',
    'ModelChecksumMismatch',
    'ModelIncompatible',
    'ModelPinMismatch',
    'EngineUnavailable',
    'EngineIncompatible',
    'EngineBusy',
    'NotImplemented',
    'UnsupportedPixelFormat',
    'FrameShapeMismatch',
    'FrameInUse',
    'InferenceFailed',
    'NativeFault',
  ];
}

/// An argument this side got wrong.
final class InvalidArgument extends InferError {
  const InvalidArgument(super.detail);
  @override
  String get name => 'InvalidArgument';
}

/// The manifest, or the weights it names, is not on disk. On an appliance this
/// usually means apt has not finished, not that anything is broken.
final class ModelNotFound extends InferError {
  const ModelNotFound(super.detail);
  @override
  String get name => 'ModelNotFound';
}

/// The manifest is there and could not be read.
final class ManifestUnreadable extends InferError {
  const ManifestUnreadable(super.detail);
  @override
  String get name => 'ManifestUnreadable';
}

/// The manifest parsed and is wrong. The detail names the key.
final class ManifestMalformed extends InferError {
  const ManifestMalformed(super.detail);
  @override
  String get name => 'ManifestMalformed';
}

/// The weights on disk are not the weights the manifest describes.
///
/// This is a refusal, not a warning, and deliberately so: weights read in the
/// wrong layout do not fail, they produce a confident wrong answer.
final class ModelChecksumMismatch extends InferError {
  const ModelChecksumMismatch(super.detail);
  @override
  String get name => 'ModelChecksumMismatch';
}

/// The model asks for a schema or an ABI this build does not implement.
final class ModelIncompatible extends InferError {
  const ModelIncompatible(super.detail);
  @override
  String get name => 'ModelIncompatible';
}

/// The manifest is valid and is not the version this terminal is pinned to.
///
/// A repository is allowed to move on; a till is not, until someone says so.
final class ModelPinMismatch extends InferError {
  const ModelPinMismatch(super.detail);
  @override
  String get name => 'ModelPinMismatch';
}

/// No inference runtime is installed on this host. The detail lists the paths
/// that were tried.
final class EngineUnavailable extends InferError {
  const EngineUnavailable(super.detail);
  @override
  String get name => 'EngineUnavailable';
}

/// A runtime loaded and is not one this build can use.
final class EngineIncompatible extends InferError {
  const EngineIncompatible(super.detail);
  @override
  String get name => 'EngineIncompatible';
}

/// The engine still has models loaded from it.
final class EngineBusy extends InferError {
  const EngineBusy(super.detail);
  @override
  String get name => 'EngineBusy';
}

/// A path that is specified and not yet built. The detail names what is
/// missing. It is never returned next to a plausible-looking result.
final class NotImplemented extends InferError {
  const NotImplemented(super.detail);
  @override
  String get name => 'NotImplemented';
}

/// The pixel format is not one the native side accepts.
final class UnsupportedPixelFormat extends InferError {
  const UnsupportedPixelFormat(super.detail);
  @override
  String get name => 'UnsupportedPixelFormat';
}

/// The frame is not the shape the model's manifest declares.
final class FrameShapeMismatch extends InferError {
  const FrameShapeMismatch(super.detail);
  @override
  String get name => 'FrameShapeMismatch';
}

/// Another run holds this frame.
final class FrameInUse extends InferError {
  const FrameInUse(super.detail);
  @override
  String get name => 'FrameInUse';
}

/// The runtime accepted the call and reported a failure of its own.
final class InferenceFailed extends InferError {
  const InferenceFailed(super.detail);
  @override
  String get name => 'InferenceFailed';
}

/// A bug inside the native library, caught at the boundary and returned rather
/// than allowed to unwind into this isolate.
final class NativeFault extends InferError {
  const NativeFault(super.detail);
  @override
  String get name => 'NativeFault';
}

/// A status name this build has no case for.
///
/// The alternative -- mapping an unknown ordinal onto whichever case happened
/// to be at that index -- is exactly what И147 exists to prevent.
final class UnknownNativeStatus extends InferError {
  const UnknownNativeStatus(this.nativeName, super.detail);
  final String nativeName;
  @override
  String get name => nativeName;
}

/// The worker isolate is not running: it was never started, it was closed, or
/// it died.
///
/// A Dart-side failure, but a failure as a value like every other, because a
/// caller in the middle of a sale should not have to catch anything.
final class EngineStopped extends InferError {
  const EngineStopped(super.detail);
  @override
  String get name => 'EngineStopped';
}

// ---------------------------------------------------------------------------
// Results
// ---------------------------------------------------------------------------

/// Success or failure, as a value. Never a thrown exception.
sealed class InferResult<T> {
  const InferResult();

  /// The value, or `null` if this is a failure.
  T? get valueOrNull => switch (this) {
    InferOk<T>(:final value) => value,
    InferErr<T>() => null,
  };

  /// The failure, or `null` if this is a success.
  InferError? get errorOrNull => switch (this) {
    InferOk<T>() => null,
    InferErr<T>(:final error) => error,
  };

  bool get isOk => this is InferOk<T>;
}

final class InferOk<T> extends InferResult<T> {
  const InferOk(this.value);
  final T value;

  @override
  String toString() => 'InferOk($value)';
}

final class InferErr<T> extends InferResult<T> {
  const InferErr(this.error);
  final InferError error;

  @override
  String toString() => 'InferErr($error)';
}

// ---------------------------------------------------------------------------
// Named enums
// ---------------------------------------------------------------------------

/// What a model is for.
///
/// Two, and deliberately two. Section 10 of the architecture names six events
/// worth correlating with the till; four are till events with a video link
/// attached, and the fifth is a number from a scale.
enum InferenceTask {
  /// Visitors per hour, against receipts per hour, which is the only figure
  /// that shows what is lost *before* the till.
  ///
  /// A fallback. A camera or NVR speaking ONVIF Profile M already counts, and
  /// where it does, no model runs here at all. Accuracy is low by nature --
  /// someone walking a circuit counts twice, a group counts as one -- and the
  /// product wants an hourly trend, not a legally meaningful number.
  visitorCount('visitorCount'),

  /// A hint that something moved to the bagging side while the till recorded
  /// no scan.
  ///
  /// **Open research.** This is a filter that narrows what a person reviews,
  /// not a detector of theft, and it must not be described as the latter.
  /// Commercial systems in this niche use dedicated camera arrays and server
  /// infrastructure, and none publishes verifiable accuracy figures, so there
  /// is no baseline to claim parity with.
  unscannedItemHint('unscannedItemHint');

  const InferenceTask(this.wireName);

  /// The name this crosses the ABI as. Never an index (И147).
  final String wireName;

  static InferenceTask? fromWireName(String name) {
    for (final t in InferenceTask.values) {
      if (t.wireName == name) return t;
    }
    return null;
  }
}

/// How the bytes of a frame are laid out.
enum PixelFormat {
  rgb8('rgb8', 3),
  bgr8('bgr8', 3),
  rgba8('rgba8', 4),
  gray8('gray8', 1);

  const PixelFormat(this.wireName, this.bytesPerPixel);

  /// The name this crosses the ABI as. Never an index (И147).
  final String wireName;
  final int bytesPerPixel;

  static PixelFormat? fromWireName(String name) {
    for (final f in PixelFormat.values) {
      if (f.wireName == name) return f;
    }
    return null;
  }
}

/// Which execution provider actually ran.
///
/// CPU is the guaranteed path on every host. An accelerator is reported when
/// it was found, never when it was hoped for. The floor hardware this product
/// ships to includes a thin client with no usable GPU at all, and on that
/// machine the honest answer is [cpu].
enum ExecutionProvider {
  cpu('Cpu');

  const ExecutionProvider(this.wireName);
  final String wireName;

  static ExecutionProvider? fromWireName(String name) {
    for (final p in ExecutionProvider.values) {
      if (p.wireName == name) return p;
    }
    return null;
  }
}

// ---------------------------------------------------------------------------
// Values
// ---------------------------------------------------------------------------

/// The shape a frame must have. Numbers, not pixels.
final class FrameSpec {
  const FrameSpec({
    required this.width,
    required this.height,
    required this.format,
  });

  final int width;
  final int height;
  final PixelFormat format;

  /// Exactly how many bytes a frame of this shape holds.
  int get byteLength => width * height * format.bytesPerPixel;

  @override
  String toString() => '${width}x$height ${format.wireName}';

  @override
  bool operator ==(Object other) =>
      other is FrameSpec &&
      other.width == width &&
      other.height == height &&
      other.format == format;

  @override
  int get hashCode => Object.hash(width, height, format);
}

/// Which model to load, and which version this terminal will accept.
final class ModelRef {
  const ModelRef({required this.manifestPath, this.pinnedVersion});

  /// Path to the `model.manifest` an apt package installed. See
  /// `doc/models.md` for where that is and how it gets there.
  final String manifestPath;

  /// The version this terminal is pinned to, or `null` to accept whatever the
  /// manifest on disk says.
  ///
  /// Pinning is the difference between a repository update and a till changing
  /// behaviour unattended. A bad model on a till can mean false alarms in
  /// front of customers, which is not the same class of accident as a UI bug.
  final String? pinnedVersion;

  @override
  String toString() => pinnedVersion == null
      ? 'ModelRef($manifestPath)'
      : 'ModelRef($manifestPath pinned to $pinnedVersion)';
}

/// A model that loaded: its manifest checked, its weights hashed, its session
/// open.
///
/// A handle plus the metadata that came with it. It holds no pointer, which is
/// why it can be carried on the interface isolate without anything native
/// happening there.
final class LoadedModel {
  const LoadedModel({
    required this.handle,
    required this.name,
    required this.version,
    required this.task,
    required this.input,
    required this.retention,
  });

  /// Opaque. Means nothing outside the engine that issued it.
  final int handle;

  final String name;
  final String version;
  final InferenceTask task;

  /// The exact shape a frame for this model must have.
  final FrameSpec input;

  /// How long a result from this model may be kept. Always finite: a manifest
  /// without a retention does not load (И93, И94).
  final Duration retention;

  @override
  String toString() => 'LoadedModel($name $version, ${task.wireName}, $input)';
}

/// What the engine reports about itself once it is open.
final class EngineCapabilities {
  const EngineCapabilities({
    required this.abiVersion,
    required this.provider,
    required this.runtimeVersion,
    required this.runtimeLibraryPath,
  });

  /// The C ABI version of the loaded `rk_infer` library.
  final int abiVersion;

  /// What actually runs the model.
  final ExecutionProvider provider;

  /// The inference runtime's own version string, if it supplied one.
  final String? runtimeVersion;

  /// Where the runtime was found. Useful precisely when it was the wrong one.
  final String runtimeLibraryPath;

  @override
  String toString() =>
      'EngineCapabilities(abi $abiVersion, '
      '${provider.wireName}, runtime ${runtimeVersion ?? "unknown"} '
      'at $runtimeLibraryPath)';
}

/// One thing the model found.
///
/// Coordinates are normalised against the input frame, so reading a detection
/// never requires having the frame. That is not a convenience; it is what
/// makes it possible for the frame to be gone by the time anyone sees this.
final class Detection {
  const Detection({
    required this.className,
    required this.confidence,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });

  /// The class, by name. Never an index into a table the caller has to keep
  /// in step (И147).
  final String className;

  /// 0.0 to 1.0.
  final double confidence;

  /// Normalised 0.0 to 1.0 against the input frame.
  final double x;
  final double y;
  final double width;
  final double height;

  @override
  String toString() =>
      'Detection($className ${confidence.toStringAsFixed(3)} '
      'at [${x.toStringAsFixed(3)}, ${y.toStringAsFixed(3)}, '
      '${width.toStringAsFixed(3)}, ${height.toStringAsFixed(3)}])';
}

/// What a run produced.
///
/// This is the only thing that crosses out of the worker isolate. It is the
/// event section 10 asks for -- "a visitor entered", "something was not
/// recognised" -- and not the pixels it came from.
final class InferenceOutput {
  const InferenceOutput({
    required this.task,
    required this.detections,
    required this.retainUntil,
  });

  final InferenceTask task;

  final List<Detection> detections;

  /// When this result must be deleted or anonymised.
  ///
  /// It travels with the result rather than being looked up later, because a
  /// retention rule kept somewhere else is a retention rule that gets lost in
  /// the copy. Always finite and always in the future of the run (И93, И94).
  final DateTime retainUntil;

  /// Whether this result has outlived its retention as of [now].
  bool isExpiredAt(DateTime now) => !now.isBefore(retainUntil);

  @override
  String toString() =>
      'InferenceOutput(${task.wireName}, '
      '${detections.length} detection(s), keep until '
      '${retainUntil.toUtc().toIso8601String()})';
}

// ---------------------------------------------------------------------------
// The engine
// ---------------------------------------------------------------------------

/// On-device inference.
///
/// # Every method returns a `Future`, and that is structural
///
/// И145: no call into the native side happens on the interface isolate. A run
/// on a weak x86 box is tens to hundreds of milliseconds; on the isolate that
/// also runs Flutter, that is a till frozen mid-sale. The implementation keeps
/// the engine in a long-lived worker isolate and this interface exposes
/// nothing synchronous, so there is no shape of call that could run native
/// code where the interface lives. `test/isolate_discipline_test.dart` fails
/// if a synchronous method appears here.
///
/// # A frame goes in and does not come back
///
/// [run] takes a [TransferableTypedData]. That type *moves*: the buffers it
/// was built from are detached from the sender immediately, so after the call
/// the caller no longer has the pixels either. Inside the worker they are
/// copied once into a native buffer owned by Rust, used, and freed. Nothing on
/// this interface returns them, and `test/no_raw_frame_test.dart` fails if
/// anything ever does.
abstract interface class InferenceEngine {
  /// What this engine is, once it is open.
  Future<InferResult<EngineCapabilities>> capabilities();

  /// Loads and verifies a model: manifest, then pin, then SHA-256 of the
  /// weights, then a session.
  Future<InferResult<LoadedModel>> loadModel(ModelRef ref);

  /// Runs one frame.
  ///
  /// `frame` must hold exactly [LoadedModel.input] `byteLength` bytes, laid
  /// out in [FrameSpec.format]. It is consumed: a [TransferableTypedData] can
  /// be materialised once, and it is materialised here.
  ///
  /// The native frame buffer is allocated and freed inside the worker for this
  /// call and does not outlive it (И146). Nothing about its contents can
  /// appear in what comes back, in success or in failure.
  Future<InferResult<InferenceOutput>> run(
    LoadedModel model,
    TransferableTypedData frame,
  );

  /// Releases a model's native memory now, rather than when a collector gets
  /// round to it (И146).
  Future<InferResult<void>> unload(LoadedModel model);

  /// Closes the engine and stops the worker isolate. Fails with [EngineBusy]
  /// if models are still loaded, because their sessions live inside the
  /// runtime this would unload.
  Future<InferResult<void>> close();
}

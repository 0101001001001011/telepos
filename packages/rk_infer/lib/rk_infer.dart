/// On-device inference over an embedded engine.
///
/// We embed an inference engine, we do not write one. The baseline is ONNX
/// Runtime -- MIT, and a C API whose own guidelines say no C++ exception
/// crosses it. CPU execution is the guaranteed path on every host;
/// accelerators are declared where the hardware allows and never assumed.
///
/// # What this is for, and what it is not
///
/// Section 10 of the TelePOS architecture names six events worth correlating
/// with the till. Four of them are till events with a video link attached and
/// need no model at all. The fifth, the self-checkout weight check, is a
/// number from a scale. Two need inference, and they are not equally mature:
///
/// * [InferenceTask.visitorCount] -- engineering, and a *fallback*: a camera
///   or NVR speaking ONVIF Profile M already counts, and where it does, no
///   model runs here.
/// * [InferenceTask.unscannedItemHint] -- **open research.** A filter that
///   narrows what a person reviews, not a detector of theft, and it must not
///   be described as the latter.
///
/// Barcodes from a camera are already solved by a scanner and are not touched
/// here.
///
/// # A frame goes in and does not come back
///
/// [InferenceEngine.run] takes a `TransferableTypedData`, which *moves*: the
/// buffers it was built from are detached from the sender the moment it is
/// created. Inside the worker isolate the pixels are copied once into a buffer
/// Rust owns, used, and freed before the call returns.
///
/// Nothing on this interface returns frame bytes, writes them to disk, or
/// opens a socket -- there is no method of that shape to call.
/// `test/no_raw_frame_test.dart` walks the whole public surface and fails if
/// one ever appears.
///
/// # Nothing on the interface isolate
///
/// Every method here returns a `Future` and every one is a message to a
/// long-lived worker isolate that owns the engine. Inference on the isolate
/// that runs the interface is a till frozen mid-sale, so there is deliberately
/// no synchronous way in.
///
/// # Models
///
/// Weights are large binaries and do not ship in a pub.dev package. They
/// arrive as signed Debian packages through the apt repository the product
/// already uses, pinned per terminal and rolled back with `apt`. See
/// `doc/models.md`.
///
/// # Example
///
/// ```dart
/// final started = await NativeInferenceEngine.start(
///   bindingLibraryPath: '/opt/telepos/lib/librk_infer.so',
/// );
/// if (started case InferErr(:final error)) {
///   // A till sells without inference. It does not sell without a till.
///   return;
/// }
/// final engine = (started as InferOk<NativeInferenceEngine>).value;
/// ```
library;

export 'src/contract.dart'
    show
        // Failures
        InferError,
        InvalidArgument,
        ModelNotFound,
        ManifestUnreadable,
        ManifestMalformed,
        ModelChecksumMismatch,
        ModelIncompatible,
        ModelPinMismatch,
        EngineUnavailable,
        EngineIncompatible,
        EngineBusy,
        NotImplemented,
        UnsupportedPixelFormat,
        FrameShapeMismatch,
        FrameInUse,
        InferenceFailed,
        NativeFault,
        UnknownNativeStatus,
        EngineStopped,
        // Results
        InferResult,
        InferOk,
        InferErr,
        // Named enums
        InferenceTask,
        PixelFormat,
        ExecutionProvider,
        // Values
        FrameSpec,
        ModelRef,
        LoadedModel,
        EngineCapabilities,
        Detection,
        InferenceOutput,
        // The engine
        InferenceEngine;

export 'src/worker/engine_worker.dart' show NativeInferenceEngine;

/// The version this package reports about itself.
const String rkInferVersion = '0.2.1';

/// Whether this build of the package contains the FFI binding.
///
/// It answers a question about *this package*, not about the machine: it does
/// no native work and touches no library, because a synchronous probe would be
/// exactly the call on the interface isolate the design forbids.
///
/// For the machine's answer -- is a runtime installed, which provider, which
/// version -- start an engine and read [EngineCapabilities]. A start that
/// fails with [EngineUnavailable] is the honest "no".
bool get hasNativeEngine => true;

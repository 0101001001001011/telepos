## 0.2.1

- macOS and iOS actually build now: the pod script phase shipped with CRLF line endings and exited 0 without invoking cargo. rk_infer_task_names is also declared in the C header, which it was exported without.

## 0.2.0

- The package is now a **Flutter FFI plugin**: `flutter build` runs cargo itself
  and puts the library into the application on Windows, Linux and Android.
  Before this there was no `flutter.plugin.platforms` block in the pubspec, and
  the native part reached **no build at all**.
- Fixed along the way: the `cfg(unix)` branch of `rust/src/dylib.rs` compiled on
  neither Linux nor Android, and the very first build for a target other than
  Windows caught it. macOS and iOS are written but have never been built.

## 0.1.0

The contract, the native side, and the model delivery chain. What a consumer
gets and what it does not:

- `InferenceEngine`, backed by `NativeInferenceEngine.start(...)`, which runs the
  engine in a long-lived worker isolate. Every method returns a `Future`; there
  is no synchronous entry point, so inference cannot land on the isolate that
  runs the interface.
- `run` takes a `TransferableTypedData` — a move, not a copy. Nothing on the
  contract returns frame bytes, writes them to disk, or opens a socket.
- Failures are values: a sealed `InferError` with a case per native status,
  mapped **by name**, and `UnknownNativeStatus` for a name this build does not
  know. Nothing throws, including a panic inside the native library.
- Models load from a manifest delivered by apt, and are refused unless the
  schema, the ABI, the retention, the declared length, the SHA-256 and the
  version pin all agree. See `doc/models.md`.
- `InferenceOutput` carries its own retention deadline. A manifest without a
  finite, non-zero retention does not load.
- Two tasks, deliberately: `visitorCount` (a fallback, where the camera does not
  already count) and `unscannedItemHint` (open research — a filter that narrows
  what a person reviews, not a detector of theft).

**Not in this release: running a model.** `loadModel` verifies everything and
then reaches `NotImplemented`, whose message names the ONNX Runtime entry points
still to be bound. There is deliberately no stub returning an empty result,
because on a quiet camera that is indistinguishable from a working engine.

No figure in this package has been measured on the hardware it is for.

Changed since 0.0.1:

- `hasNativeEngine` now reports `true`. It was documented as "always false for
  now" and answers a question about the package, not the machine — it does no
  native work, because a synchronous probe would be the very call on the
  interface isolate this design forbids. For the machine's answer, start an
  engine and read `EngineCapabilities`.

## 0.0.1

- Name claimed. No content yet: the package proves the publishing
  pipeline, it does not solve the problem.

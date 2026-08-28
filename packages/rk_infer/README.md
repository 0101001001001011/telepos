# rk_infer

On-device inference for Dart over an embedded C++ engine. **The raw frame never
leaves the worker that owns it** — not because the documentation asks nicely,
but because the contract has no method that could hand it back.

ONNX Runtime is the baseline engine. CPU execution is the guaranteed path on
every host; accelerators are declared where the hardware allows and never
assumed.

## State of this release

| Part | State |
| --- | --- |
| C ABI: failure as a value, enums by name | works, covered by tests |
| Frame lifetime and ownership | works, covered by tests |
| Model delivery: manifest, schema, ABI, retention, length, SHA-256, version pin | works, covered end to end |
| Loading the inference runtime and reporting what it is | works, covered against a real shared library |
| Worker isolate, no synchronous entry point | works, covered by a structural test |
| **Running a model: session and tensors** | **not built.** `loadModel` reaches `NotImplemented`, and the message names the exact ONNX Runtime entry points still to be bound |

The last row is the honest one. There is no stub returning an empty result: on a
quiet camera that would be indistinguishable from a working engine, and this
project has lost an integration that way before.

**No number in this package has been measured on the hardware it is for.** The
floor is modest x86 — down to a thin client whose VIA Chrome9 has no KMS and no
`/dev/dri` at all — and a Raspberry Pi 5. Nothing here has run on either. Any
latency or throughput figure you need must be measured there.

## What it is for

The TelePOS product names six events worth correlating with the till. Four are
till events with a video link attached and need no model. The fifth, the
self-checkout weight check, is a number from a scale. Two need inference, and
they are not equally mature:

- **`visitorCount`** — engineering, and a *fallback*. A camera or NVR speaking
  ONVIF Profile M already counts, and where it does, nothing here runs. Accuracy
  is low by nature — someone walking a circuit counts twice, a group counts as
  one — and the product wants an hourly trend against receipts per hour, not a
  legally meaningful number.
- **`unscannedItemHint`** — **open research, not a capability with an accuracy
  to promise.** A filter that narrows what a person reviews, not a detector of
  theft, and it must not be described as the latter.

Barcodes from a camera are already solved by a scanner and are not touched here.

## Using it

```dart
import 'dart:isolate';
import 'package:rk_infer/rk_infer.dart';

final started = await NativeInferenceEngine.start(
  bindingLibraryPath: '/opt/telepos/lib/librk_infer.so',
  // null searches the platform defaults, which include where the apt package
  // installs the runtime.
  runtimeLibraryPath: null,
);

// A till sells without inference. It does not sell without a till.
if (started case InferErr(:final error)) return;
final engine = (started as InferOk<NativeInferenceEngine>).value;

final loaded = await engine.loadModel(const ModelRef(
  manifestPath: '/opt/telepos/models/visitor-counter/model.manifest',
  pinnedVersion: '1.4.0',
));
if (loaded case InferErr(:final error)) return;
final model = (loaded as InferOk<LoadedModel>).value;

// `pixels` comes from the video source and is exactly model.input.byteLength
// long. Building the transfer detaches it: after this line the caller no
// longer has the frame either.
final frame = TransferableTypedData.fromList([pixels]);

switch (await engine.run(model, frame)) {
  case InferOk(:final value):
    // Structured, and it carries its own retention deadline.
    journal.record(value.detections, keepUntil: value.retainUntil);
  case InferErr(:final error):
    log.warning('$error');
}

await engine.unload(model);
await engine.close();
```

Nothing throws. Every failure is a value, so a caller in the middle of a sale
never has to catch anything.

## The rules this package keeps

- **A failure is a returned value.** No entry point panics, aborts, or lets an
  exception out of a foreign stack. A panic inside the native library is caught
  at the boundary and returned as `NativeFault`.
- **Enums cross by name, never by number.** Insert a case in the middle of the
  Rust enum and no peer changes meaning, because no ordinal ever crosses.
- **Every allocation has one owner and one deallocator**, named in the header
  above the function that produces it. A frame buffer is megabytes; Rust
  allocates it and Rust frees it, and Dart does neither. A run *borrows* the
  frame, so there is no state in which both sides believe someone else will free
  it.
- **Nothing runs on the interface isolate.** Every method returns a `Future` and
  is a message to a long-lived worker. Inference where the interface lives is a
  till frozen mid-sale.
- **A frame goes in and does not come back.** `run` takes a
  `TransferableTypedData`, which moves rather than copies. Nothing returns
  bytes, writes them to disk, or opens a socket — there is no method of that
  shape to call, and a test walks the whole public surface to keep it that way.

## Models

Weights are large binaries and do not ship in a pub.dev package. They arrive as
signed Debian packages through the apt repository the product already uses,
pinned per terminal, and rolled back with `apt` from the machine itself without
a network. The manifest is verified before the weights, and the weights are
hashed before anything reaches the runtime.

See [`doc/models.md`](doc/models.md) for the layout, the manifest format, the
order of checks, and the rollback procedure.

## Building the native side

```bash
cd rust
cargo build --release      # cdylib + staticlib, plain C ABI
cargo test
cargo clippy --all-targets -- -D warnings
```

No dependencies, on purpose: this must build on a machine that has never seen
the network, because it builds for tills.

This package is a **Flutter FFI plugin**: `flutter build` runs cargo and puts
the library in the application, on Windows, Linux and Android. There is no
`hook/` directory here and there will not be — its mere presence breaks
`dart run`, `dart test` and `flutter build`. The mechanism, the three separate
routes to cargo and what to check first on a Mac are in
[`doc/native-build.md`](doc/native-build.md).

`bindingLibraryPath` is still required rather than guessed; inside a built
application it is the platform's plain name (`librk_infer.so`,
`rk_infer.dll`), which the system loader resolves on its own.

**Where it has been proved to arrive:**

| Target | State | Evidence |
| --- | --- | --- |
| Windows | arrives | `rk_infer.dll` next to the runner of a built application |
| Linux | arrives | `librk_infer.so` in the application's `bundle/lib/` |
| Android | arrives | found **inside the unpacked APK** for `armeabi-v7a`, `arm64-v8a`, `x86_64` |
| macOS, iOS | **built and linked** | verified 2026-08-03 on Apple M4 / macOS 26.2 / Xcode 26.2: the archive builds for arm64 and x86_64 on macOS, arm64 on device and both on the simulator; a C probe links against it with `-force_load` in Release and Debug, and the macOS binaries run through the C ABI. Gated by CI from that day. |

The first build for a non-Windows target found a real defect here: the
`cfg(unix)` half of `rust/src/dylib.rs` had never been compiled, and it did not
satisfy `#![deny(unsafe_op_in_unsafe_fn)]`. A crate that builds on the machine
you happen to use is not a crate that builds.

## Design

[`doc/architecture.md`](doc/architecture.md) — where the boundary runs, who frees
what, and why the frame moves in the direction it does.

## License

MIT, Rob Kim. See `LICENSE`.

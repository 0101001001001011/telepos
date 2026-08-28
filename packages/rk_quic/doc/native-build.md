# Building the native part

`rk_quic` is a **Flutter FFI plugin**. Cargo is invoked from the per-platform
build files; the artefact is handed to the Flutter tool, which puts it into the
application. There is no `hook/` directory here and there must not be — why is
below.

## What a consumer must have installed

| Target | Beyond Rust |
| --- | --- |
| Windows | Visual Studio with the C++ workload (CMake and MSBuild are needed); target `x86_64-pc-windows-msvc` |
| Linux | `clang cmake ninja-build pkg-config libgtk-3-dev`; target `x86_64-unknown-linux-gnu` |
| Android | Android SDK, NDK, JDK 17; targets `aarch64-linux-android`, `armv7-linux-androideabi`, `x86_64-linux-android` |
| macOS / iOS | Xcode, CocoaPods (and therefore Ruby); targets `aarch64-apple-darwin`, `x86_64-apple-darwin`, `aarch64-apple-ios`, `aarch64-apple-ios-sim` |
| Web | nothing: by design there is no native part in the browser |

No build mechanism removes cross-compilation: cargo still needs the NDK linker
for Android and Xcode for Apple.

## Three routes to cargo, not one

This is unpleasant, and better known in advance than rediscovered.

| Platforms | How cargo is invoked |
| --- | --- |
| Windows, Linux | CMake: `src/CMakeLists.txt`, the path handed over in `rk_quic_bundled_libraries` |
| Android | Gradle directly: the `rkQuicCargoBuild` task in `android/build.gradle`, the result placed in `jniLibs.srcDirs` |
| macOS, iOS | `apple/build_rust.sh` from a podspec script phase |

Each divergence has its own reason, and both are worth writing down.

### Android: CMake does not work here, and "a green build" hides it

The obvious shape is the one used on Windows and Linux:
`externalNativeBuild.cmake.path` pointed at the shared `src/CMakeLists.txt`,
cargo inside an `add_custom_target`, a copy into
`CMAKE_LIBRARY_OUTPUT_DIRECTORY`. What happens is the following, in exactly this
order.

1. With `project(... LANGUAGES NONE)`, AGP fails at the configuration stage with
   a bare `java.lang.NullPointerException` in
   `CmakeFileApiV1Kt.readCmakeFileApiReply`: it reads CMake's file API reply and
   expects a `toolchains` object, which CMake emits only for a project that
   declares a language. No message, no file, no line.

2. `LANGUAGES C` gets past that wall — and then **the build succeeds and there
   is no library**. It can be read in
   `.cxx/<config>/<hash>/<abi>/android_gradle_build.json`: AGP sees the custom
   target as `"rk_quic_cargo::@…": { "artifactName": "rk_quic_cargo" }`
   **without an `output` key**, because a custom target produces no library that
   CMake could name. AGP then asks ninja to build an empty list of targets —
   cargo does not run at all, and the copy step hung off a target nobody invokes
   cannot fire. Confirmed by unpacking the APK: 38.9 MB, `libflutter.so` and
   `libapp.so` for three ABIs, no `librk_quic.so`.

A green build that ships nothing is the worst possible outcome, so the CMake
route on Android is abandoned rather than repaired.

Another mine of the same class, found right there: build `x86` as well and the
APK gains `lib/x86/librk_quic.so` in a directory that has no `libflutter.so` —
Flutter does not ship 32-bit x86. Android picks the directory by the device's
primary ABI and loads what is in it, so a 32-bit x86 device would pick the
directory holding only our library and crash. The default set matches exactly
what Flutter ships; `x86` is built on request (`-PrkQuicAbiFilter=x86`).

### Apple: inside the pod, not beside it

Flutter's Podfile templates contain `use_frameworks!`, so the pod is built as
`rk_quic.framework` and Dart opens `rk_quic.framework/rk_quic` — a single Mach-O
binary. On Windows and Linux it was enough to hand CMake an absolute path and
let the tool copy the file next to the runner; inside a framework there is no
"next to".

So Apple gets a **static** archive, and `-force_load` in `OTHER_LDFLAGS` pulls
every object into the framework binary. `-force_load` specifically, not a plain
`-l`: neither Objective-C nor Swift mentions these symbols — Dart looks them up
by name at run time — and ordinary linking would discard the whole archive as
unused.

**Not one paragraph about Apple is confirmed by a build.** There is no Mac
available; all of it is read out of the tools. The first person with Xcode
should check, in this order:

1. Whether `aws-lc-rs` builds for the Apple targets. This is **the most likely
   failure**, not the podspec: it has a C build script that needs CMake and a
   suitable compiler. On Android this step is proved and passes — but only after
   both `CARGO_TARGET_<TRIPLE>_LINKER` and `AR_<triple>` are set; without the
   second, `cc-rs` looks for a non-existent `aarch64-linux-android-ar` and
   fails. The same class of failure under different names is expected on Apple.
2. Whether the framework binary exists at all
   (`ls …/rk_quic.framework/rk_quic`).
3. Whether `nm -gU` on it lists `_rk_quic_version` and `_rk_quic_server_start`.
4. Whether there is a simulator slice alongside the device slice.
5. For iOS specifically: the application needs the entitlement to listen on a
   UDP port, and in the background the socket is closed by the system. A QUIC
   endpoint on iOS is only meaningful while the application is in the
   foreground — that is a platform limit, not a limit of this package.

## The files, and what each is for

| File | Why |
| --- | --- |
| `rust/` | the crate: `Cargo.toml`, `Cargo.lock`, `src/` |
| `src/rk_quic.h` | the C ABI, said once; checked by `test/abi_surface_test.dart` |
| `src/CMakeLists.txt` | maps the CMake platform onto a Rust triple and invokes cargo (Windows and Linux) |
| `windows/CMakeLists.txt` | pulls in `src/`, hands the path over in `rk_quic_bundled_libraries` |
| `linux/CMakeLists.txt` | the same |
| `android/build.gradle` | the `rkQuicCargoBuild` task, the mapping of ABI onto triple and onto the NDK clang wrapper, `jniLibs.srcDirs` |
| `android/settings.gradle` | required by Gradle |
| `android/src/main/AndroidManifest.xml` | required by an Android library |
| `apple/build_rust.sh` | builds the static archive that Xcode links into the pod |
| `ios/rk_quic.podspec`, `macos/rk_quic.podspec` | CocoaPods: the script phase and `-force_load` |

Plus the `flutter.plugin.platforms` block in `pubspec.yaml`, without which the
Flutter tool looks at none of the above.

Neither mapping can be derived from the other, and this is exactly where people
get it wrong: the NDK clang wrapper for 32-bit ARM is called
`armv7a-linux-androideabi`, while the Rust triple is `armv7-linux-androideabi`.

## Why not `hook/build.dart`

Measured 2026-07-31
(`.superpowers/sdd/2026-07-31-native-pipeline/task-2-report.md`): on Flutter
3.32.4 stable, hooks get the library to **zero targets out of six**, because the
feature is gated off on the stable SDK channel and `flutter config
--enable-native-assets` is accepted without taking effect. Worse than useless:
**the mere presence of a `hook/` directory** breaks `dart run`, `dart test` and
`flutter build` for every consumer of the package, on every platform. The cost
of the mistake is not "one target failed to build" but "nothing builds".

There is one condition for revisiting this, and a command that checks it:
`flutter config --list` stops printing `(Unavailable)` next to
`enable-native-assets` on the pinned Flutter version.

## Building by hand

```sh
cd packages/rk_quic/rust
cargo build --release                                   # host
cargo build --release --target aarch64-linux-android    # needs the NDK linker
cargo test
cargo clippy --all-targets -- -D warnings
```

The package's tests find the result on their own; `RK_QUIC_LIBRARY=<path>`
points them somewhere else — at the artefact that already went into a built
application, for instance.

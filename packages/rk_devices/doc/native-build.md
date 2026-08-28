# Building the native part

`rk_devices` is a **Flutter FFI plugin**. Cargo is invoked from the per-platform
build files; the artefact is handed to the Flutter tool, which puts it into the
application. There is no `hook/` directory here and there must not be — why is
below.

The mechanism is the same for every `rk_*` package — a Flutter FFI plugin with
per-platform build files, and no `hook/` directory anywhere — and repeats the
one first proved by the builds of `rk_quic`. The full account of the two
Android failures is in `packages/rk_quic/doc/native-build.md`; only what is
needed to build this package is here.

## What a consumer must have installed

| Target | Beyond Rust |
| --- | --- |
| Windows | Visual Studio with the C++ workload (CMake and MSBuild are needed); target `x86_64-pc-windows-msvc` |
| Linux | `clang cmake ninja-build pkg-config libgtk-3-dev`; target `x86_64-unknown-linux-gnu` |
| Android | Android SDK, NDK, JDK 17; targets `aarch64-linux-android`, `armv7-linux-androideabi`, `x86_64-linux-android` |
| macOS / iOS | Xcode, CocoaPods; targets `aarch64-apple-darwin`, `x86_64-apple-darwin`, `aarch64-apple-ios`, `aarch64-apple-ios-sim` |
| Web | nothing: by design there is no native part in the browser |

## Three routes to cargo, not one

| Platforms | How cargo is invoked |
| --- | --- |
| Windows, Linux | CMake: `src/CMakeLists.txt`, the path handed over in `rk_devices_bundled_libraries` |
| Android | Gradle directly: the `rkDevicesCargoBuild` task in `android/build.gradle`, the result placed in `jniLibs.srcDirs` |
| macOS, iOS | `apple/build_rust.sh` from a podspec script phase |

**Android does not go through CMake, and that is a measurement rather than a
taste.** AGP records a custom cargo target without an `output` key (a custom
target produces no library that CMake could name), asks ninja to build an empty
list of targets — and **the build succeeds while there is no library in the
APK**. A green build that ships nothing is the worst possible outcome. Hence
the rule: "it arrived" means found inside the unpacked APK, not "Gradle
reported success".

**The ABI set matches what Flutter ships** — `armeabi-v7a`, `arm64-v8a`,
`x86_64`. An ABI directory holding our library and no `libflutter.so` will crash
the application on a device of that ABI: Flutter does not ship 32-bit x86.
`x86` is built on request: `-PrkDevicesAbiFilter=x86`.

## The files, and what each is for

| File | Why |
| --- | --- |
| `rust/` | the crate: `Cargo.toml`, `src/` |
| `src/CMakeLists.txt` | maps the CMake platform onto a Rust triple and invokes cargo (Windows and Linux) |
| `windows/CMakeLists.txt` | pulls in `src/`, hands the path over in `rk_devices_bundled_libraries` |
| `linux/CMakeLists.txt` | the same |
| `android/build.gradle` | the `rkDevicesCargoBuild` task, the mapping of ABI onto triple and onto the NDK clang wrapper, `jniLibs.srcDirs` |
| `android/settings.gradle` | required by Gradle |
| `android/src/main/AndroidManifest.xml` | required by an Android library |
| `apple/build_rust.sh` | builds the static archive that Xcode links into the pod |
| `ios/rk_devices.podspec`, `macos/rk_devices.podspec` | CocoaPods: the script phase and `-force_load` |

Plus the `flutter.plugin.platforms` block in `pubspec.yaml`, without which the
Flutter tool looks at none of the above. Its absence is precisely what meant
that this package's native part reached **nowhere**.

Neither mapping can be derived from the other, and this is exactly where people
get it wrong: the NDK clang wrapper for 32-bit ARM is called
`armv7a-linux-androideabi`, while the Rust triple is `armv7-linux-androideabi`.

## Apple: written, never built

macOS and iOS are **outside automated checking** by the owner's decision, until
a machine with Xcode exists. The files are written because the package would be
wrong on the day a Mac appears, but **not one line about Apple here is confirmed
by a build**.

The pod is built with `use_frameworks!`, so Dart opens
`rk_devices.framework/rk_devices` — a single Mach-O. That means Apple gets a
**static** archive, and `-force_load` pulls every object into the framework
binary: ordinary linking would discard them, because it is Dart that looks the
symbols up at run time and neither Objective-C nor Swift mentions them.

The first person with a Mac should check, in this order:

1. Whether the crate in the dependency tree that compiles C builds for the Apple
   targets. On Android it passes only when **both**
   `CARGO_TARGET_<TRIPLE>_LINKER` **and** `AR_<triple>` are set; the same class
   of failure is expected here under different names.
2. Whether the framework binary exists at all.
3. Whether `nm -gU` on it lists the package's exported symbols.
4. Whether there is a simulator slice alongside the device slice.

## Why not `hook/build.dart`

Measured 2026-07-31
(`.superpowers/sdd/2026-07-31-native-pipeline/task-2-report.md`): on Flutter
3.32.4 stable, hooks get the library to **zero targets out of six**, because the
feature is gated off on the stable SDK channel and `flutter config
--enable-native-assets` is accepted without taking effect. Worse than useless:
**the mere presence of a `hook/` directory** breaks `dart run`, `dart test` and
`flutter build` for every consumer of the package, on every platform.

There is one condition for revisiting this, and a command that checks it:
`flutter config --list` stops printing `(Unavailable)` next to
`enable-native-assets`.

## Building by hand

```sh
cd packages/rk_devices/rust
cargo build --release
cargo test
cargo clippy --all-targets -- -D warnings
```

The binding looks for the library in this order: an explicit path,
`RK_DEVICES_LIBRARY`, the platform's own name through the system loader, and
`rust/target/{release,debug}`. Inside a built application it is the third step
that fires.

## What arrived, and what is only written

| Target | State | Evidence |
| --- | --- | --- |
| Windows | arrived | `rk_devices.dll` next to the runner of a built application |
| Linux | arrived | `librk_devices.so` in the application's `bundle/lib/` |
| Android | arrived | found inside the unpacked APK for all three ABIs, not merely a green Gradle build |
| Web | no native part | the application builds for web, and this package pulls nothing native there |
| macOS | arrived | a C probe links against `librk_devices.a` with `-force_load` and runs, arm64 and x86_64, Release and Debug (2026-08-03) |
| iOS | arrived | device and simulator archives link the same probe; `lipo -info` shows the slices claimed (2026-08-03) |

The numbers and the paths are in `.superpowers/sdd/2026-08-01-i150/report.md`.

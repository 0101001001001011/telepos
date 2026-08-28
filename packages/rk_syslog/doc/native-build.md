# Building the native part

`rk_syslog` is a **Flutter FFI plugin**. Cargo is invoked from the
per-platform build files; the artefact is handed to the Flutter tool, which
puts it in the application. There is no `hook/` directory here and there must
not be — why is below.

The mechanism is the same for every `rk_*` package and repeats the one first
proved by builds of `rk_quic`. The full account of the two Android failures is
in `rk_quic`'s copy of this document; here is only what you need in order to
build this package.

## What a consumer needs installed

| Target | Beyond Rust |
| --- | --- |
| Windows | Visual Studio with the C++ workload (CMake and MSBuild are needed); target `x86_64-pc-windows-msvc` |
| Linux | `clang cmake ninja-build pkg-config libgtk-3-dev`; target `x86_64-unknown-linux-gnu` |
| Android | Android SDK, NDK, JDK 17; targets `aarch64-linux-android`, `armv7-linux-androideabi`, `x86_64-linux-android` |
| macOS / iOS | Xcode, CocoaPods; targets `aarch64-apple-darwin`, `x86_64-apple-darwin`, `aarch64-apple-ios`, `aarch64-apple-ios-sim` |
| Web | nothing: by construction there is no native part in a browser |

## Three routes to cargo, not one

| Platforms | How cargo is invoked |
| --- | --- |
| Windows, Linux | CMake: `src/CMakeLists.txt`, the path handed over in `rk_syslog_bundled_libraries` |
| Android | Gradle directly: the `rkSyslogCargoBuild` task in `android/build.gradle`, the result placed in `jniLibs.srcDirs` |
| macOS, iOS | `apple/build_rust.sh` from a podspec script phase |

**Android does not go through CMake, and that is a measurement rather than a
taste.** AGP writes a cargo custom target with no `output` key — a custom
target produces no library CMake could name — then asks ninja to build an empty
list of targets, and **the build succeeds with no library in the APK**. A green
build shipping nothing is the worst outcome available. Hence the rule: arrived
means *found inside the unpacked APK*, not "Gradle reported success".

**The set of ABIs matches what Flutter ships** — `armeabi-v7a`, `arm64-v8a`,
`x86_64`. An ABI directory holding our library but no `libflutter.so` will
crash the application on a device of that ABI: Flutter does not ship 32-bit
x86. `x86` is built on request: `-PrkSyslogAbiFilter=x86`.

## The files, and what each is for

| File | Why |
| --- | --- |
| `rust/` | the crate: `Cargo.toml`, `src/` |
| `src/CMakeLists.txt` | maps the CMake platform to a Rust triple and invokes cargo (Windows and Linux) |
| `windows/CMakeLists.txt` | pulls in `src/`, hands the path to `rk_syslog_bundled_libraries` |
| `linux/CMakeLists.txt` | the same |
| `android/build.gradle` | the `rkSyslogCargoBuild` task, the ABI-to-triple and ABI-to-NDK-clang-wrapper maps, `jniLibs.srcDirs` |
| `android/settings.gradle` | required by Gradle |
| `android/src/main/AndroidManifest.xml` | required of an Android library |
| `apple/build_rust.sh` | builds the static archive Xcode links into the pod |
| `ios/rk_syslog.podspec`, `macos/rk_syslog.podspec` | CocoaPods: the script phase and `-force_load` |

Plus the `flutter.plugin.platforms` block in `pubspec.yaml`, without which the
Flutter tool looks at none of the above. Its absence is exactly what meant the
native part of this package reached **nowhere**.

Neither map can be derived from the other, and this is precisely where people
get it wrong: the NDK clang wrapper for 32-bit ARM is called
`armv7a-linux-androideabi`, while the Rust triple is `armv7-linux-androideabi`.

## Apple: written, never once built

macOS and iOS are **outside automated verification**, by the owner's decision,
until a machine with Xcode exists. The files are written because the package
would be wrong the day a Mac appears, but **not one line about Apple here is
confirmed by a build**.

The pod is built with `use_frameworks!`, so Dart opens
`rk_syslog.framework/rk_syslog` — a single Mach-O. That means Apple gets the
**static** archive, and `-force_load` pulls every object inside the framework
binary: ordinary linking would discard them, because the symbols are looked up
by Dart at run time and neither Objective-C nor Swift mentions them.

Check in this order, whoever has a Mac first:

1. Whether the crate in the dependency tree that compiles C builds for the
   Apple targets at all. On Android it only passes when **both**
   `CARGO_TARGET_<TRIPLE>_LINKER` **and** `AR_<triple>` are set; expect the
   same class of failure under different names.
2. Whether the framework binary exists at all.
3. Whether `nm -gU` on it lists the package's exported symbols.
4. Whether there is a simulator slice alongside the device slice.

## Why not `hook/build.dart`

Measured 2026-07-31: on Flutter 3.32.4 stable, hooks deliver the library to
**zero targets out of six**, because the feature is gated by the SDK channel
and `flutter config --enable-native-assets` is accepted without taking effect.
Worse than useless: **the mere presence of a `hook/` directory** breaks
`dart run`, `dart test` and `flutter build` for any consumer of the package, on
any platform.

There is one condition for revisiting this, and a command that checks it:
`flutter config --list` stops printing `(Unavailable)` next to
`enable-native-assets`.

## Building by hand

```sh
cd rust
cargo build --release
cargo test
cargo clippy --all-targets -- -D warnings
```

The binding looks the library up by its platform file name through the system
loader, so inside a built application it finds itself; `RK_SYSLOG_LIB` points
it somewhere else — for example at the artefact from a built application.

## What arrived, and what is only written

| Target | State | Evidence |
| --- | --- | --- |
| Windows | arrived | `rk_syslog.dll` next to the runner of a built application |
| Linux | arrived | `librk_syslog.so` in the application's `bundle/lib/` |
| Android | arrived | found inside the unpacked APK, on all three ABIs |
| Web | no native part | the application builds for web; this package pulls nothing native there |
| macOS | arrived | a C probe links against `librk_syslog.a` with `-force_load` and runs, arm64 and x86_64, Release and Debug (2026-08-03) |
| iOS | arrived | device and simulator archives link the same probe; `lipo -info` shows the slices claimed (2026-08-03) |

# Building the native part

The Rust crate ships inside the package and is built by the plugin's own build
files. A consumer needs a Rust toolchain on the machine that builds the
application — there is no prebuilt binary in the package, deliberately: a
binary in a pub.dev archive is a binary nobody can audit.

## Which route each platform takes

| Platform | Route | Artefact | Lands |
| --- | --- | --- | --- |
| Windows | `windows/CMakeLists.txt` → `src/CMakeLists.txt` → cargo | `rk_mdns.dll` | next to the runner |
| Linux | `linux/CMakeLists.txt` → `src/CMakeLists.txt` → cargo | `librk_mdns.so` | `bundle/lib/` |
| Android | `android/build.gradle`, task `rkMdnsCargoBuild` | `librk_mdns.so` per ABI | `lib/<abi>/` inside the APK |
| macOS, iOS | podspec script phase → `apple/build_rust.sh` | `librk_mdns.a`, linked in | inside the pod framework |

Three routes for six platforms, and the reasons are in the files: AGP never
invokes a CMake custom target, and a pod built under `use_frameworks!` needs
the artefact *inside* the framework binary rather than beside it.

## Proving the library arrived

**A green build is not evidence.** Every one of the three routes has been
observed to report success and ship nothing. The check is a file:

```bash
# Windows
test -f build/windows/x64/runner/Release/rk_mdns.dll

# Linux
test -f build/linux/x64/release/bundle/lib/librk_mdns.so

# Android — inside the unpacked APK, per ABI
unzip -l build/app/outputs/flutter-apk/app-release.apk | grep librk_mdns.so

# Apple — the symbols, in the archive
nm -gU "$BUILT_PRODUCTS_DIR/librk_mdns.a" | grep _rk_mdns_abi_version
```

The Apple one is not paranoia. Measured on a sibling package 2026-08-03:
`lto = true` together with `rlib` in `crate-type` internalises **every**
`#[no_mangle]` symbol in the staticlib, so the archive links without a word and
the application fails at run time when Dart looks a symbol up by name. The fix
is in `apple/build_rust.sh` — `cargo rustc --crate-type staticlib`, a single
crate type for that one invocation — and the check is there so it stays fixed.

## Building it by hand

```bash
cd rust
cargo build --release                    # host
cargo build --release --target aarch64-linux-android
cargo build --release --target aarch64-apple-ios
```

Android needs the NDK's clang as the linker; `android/build.gradle` names it
explicitly rather than leaving it to a developer's `~/.cargo/config.toml`, and
the same variables work by hand:

```bash
NDK=$ANDROID_NDK_HOME/toolchains/llvm/prebuilt/linux-x86_64/bin
CARGO_TARGET_AARCH64_LINUX_ANDROID_LINKER=$NDK/aarch64-linux-android24-clang \
CC_aarch64-linux-android=$NDK/aarch64-linux-android24-clang \
AR_aarch64-linux-android=$NDK/llvm-ar \
cargo build --release --target aarch64-linux-android
```

## Traps that have cost a day each

**Line endings.** `apple/build_rust.sh` must reach a Mac with LF. `pub publish`
packs the **working tree**, not the git index, so a Windows checkout with
`core.autocrlf=true` ships CRLF and `/bin/sh` then reads `set -eu\r`, prints
`command not found`, and **exits zero having built nothing**. `.gitattributes`
pins it; CI asserts the pin held rather than trusting it.

**`Cargo.lock` and the version.** The package version lives in six places and
the sixth is `rust/Cargo.lock`. Leave it behind and cargo rewrites it on the
first build, the tree goes dirty, and `pub publish --dry-run` refuses — with a
message about git that never mentions a version. Every cargo call in CI carries
`--locked` so the mismatch fails on the first step and names the file.

**CMake 4 on Ubuntu 26.04 builds without installing.** The install step is what
populates `bundle/lib`, so a build that skipped it produces no evidence at all.

**A shared checkout over `/mnt/d` from WSL.** `package_config.json` holds
Windows paths; build the Linux side from a Linux-native copy.

## What is verified, and where

CI builds the crate on Linux through CMake — the same path Flutter takes, so a
defect in the wiring is caught rather than bypassed by a bare `cargo build` —
and counts the exported symbols in the resulting `.so`. The Apple job runs
`apple/build_rust.sh` for all five triples and checks the slices with `lipo`
and the symbols with `nm`.

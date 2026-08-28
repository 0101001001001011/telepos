#!/bin/sh
# Builds the Rust static library for the Apple slice Xcode is currently
# building, and leaves one fat archive at $BUILT_PRODUCTS_DIR/librk_nats.a.
#
# WHY A STATIC LIBRARY AND NOT A DYLIB, WHICH IS WHAT WINDOWS AND LINUX GET.
#
# Flutter's Podfile templates carry `use_frameworks!`. A pod built that way
# becomes `rk_nats.framework`, and Dart opens it as
# `rk_nats.framework/rk_nats` — a single Mach-O binary. So the cargo artefact
# has to end up *inside* that binary. On Windows and Linux it was enough to
# hand CMake an absolute path and let the tool copy the file next to the
# runner; here there is no "next to".
#
# A static archive plus `-force_load` in OTHER_LDFLAGS does exactly that: the
# linker pulls every object, including the ones nothing references, into the
# framework binary. Without `-force_load` the whole crate would be dropped,
# because no Objective-C or Swift code calls it — the caller is Dart, at
# runtime, by name.
#
# VERIFIED BY A BUILD, 2026-08-03, on Apple M4 / macOS 26.2 / Xcode 26.2 /
# rustc 1.97.1. Before that day not one line about Apple in this package had
# ever been compiled. The first run found four defects at once, and the fixes
# for all four are in this file; ../doc/native-build.md names them.
#
# The prediction below was half right. The crate that compiles C WAS the
# failure point -- but neither CARGO_TARGET_<TRIPLE>_LINKER nor AR_<triple>
# was needed: unlike the NDK, Apple ships one clang and one ar that cc-rs
# finds through xcrun. What it needed was a deployment target, set further
# down.
#
# The likeliest failure is NOT the podspec. It is whichever crate in the
# dependency tree builds C — on rk_quic that was `aws-lc-sys`, and on Android
# it worked only once both CARGO_TARGET_<TRIPLE>_LINKER and AR_<triple> were
# set. Expect the same shape here under different names, and set them below
# rather than in someone's ~/.cargo/config.toml.

set -eu

# Xcode does not run a login shell, so a script phase never reads ~/.cargo/env
# or ~/.zshenv: PATH is the toolchain plus /usr/bin:/bin:/usr/sbin:/sbin, and
# the pod build dies with `cargo: command not found`. Measured 2026-08-03.
if ! command -v cargo >/dev/null 2>&1; then
  export PATH="${CARGO_HOME:-$HOME/.cargo}/bin:$PATH"
fi
if ! command -v cargo >/dev/null 2>&1; then
  echo "rk_nats: cargo is on neither PATH nor ${CARGO_HOME:-$HOME/.cargo}/bin." >&2
  echo "rk_nats: install Rust (https://rustup.rs) or set CARGO_HOME." >&2
  exit 1
fi

CRATE_DIR="$(cd "$(dirname "$0")/../rust" && pwd)"
TARGET_DIR="${CARGO_TARGET_DIR:-$CRATE_DIR/target}"

: "${PLATFORM_NAME:?PLATFORM_NAME is set by Xcode; this script only runs from a pod script phase}"
: "${BUILT_PRODUCTS_DIR:?BUILT_PRODUCTS_DIR is set by Xcode}"
: "${ARCHS:?ARCHS is set by Xcode}"

# The Rust link step and the C compiled through cc-rs must agree on the
# deployment target. rustc applies its per-triple default -- 10.0 for
# aarch64-apple-ios -- while cc-rs, with the variable unset, applies the SDK
# default. Under that mismatch clang emits calls to `___chkstk_darwin`, which
# iPhoneOS26.2.sdk hides through iOS 12.1, and the link dies with
#
#   Undefined symbols for architecture arm64: "___chkstk_darwin"
#
# after ~180 "was built for newer 'iOS' version" warnings that never mention a
# version mismatch. Measured 2026-08-03: of the five Apple triples this is the
# only one that fails, because the simulator triples default to 14.0 and
# aarch64-apple-darwin to 11.0.
#
# Set here rather than left to Xcode: a bare `cargo build --target
# aarch64-apple-ios` out of doc/native-build.md has to work too, and CI has no
# Xcode environment to inherit from. The figures are the ones the podspecs
# already declare.
case "$PLATFORM_NAME" in
  macosx)
    export MACOSX_DEPLOYMENT_TARGET="${MACOSX_DEPLOYMENT_TARGET:-10.14}"
    ;;
  iphoneos|iphonesimulator)
    export IPHONEOS_DEPLOYMENT_TARGET="${IPHONEOS_DEPLOYMENT_TARGET:-12.0}"
    ;;
esac

if [ "${CONFIGURATION:-Release}" = "Debug" ]; then
  CARGO_PROFILE_ARG=""
  PROFILE_DIR="debug"
else
  CARGO_PROFILE_ARG="--release"
  PROFILE_DIR="release"
fi

# Xcode names a platform and a list of architectures; cargo wants triples.
# Nothing keeps the two lists in step, so an unmapped combination stops here
# rather than producing an archive with a missing slice.
triple_for() {
  arch="$1"
  case "$PLATFORM_NAME:$arch" in
    macosx:arm64)            echo aarch64-apple-darwin ;;
    macosx:x86_64)           echo x86_64-apple-darwin ;;
    iphoneos:arm64)          echo aarch64-apple-ios ;;
    iphonesimulator:arm64)   echo aarch64-apple-ios-sim ;;
    iphonesimulator:x86_64)  echo x86_64-apple-ios ;;
    *)
      echo "rk_nats: no Rust triple for PLATFORM_NAME=$PLATFORM_NAME arch=$arch" >&2
      exit 1
      ;;
  esac
}

SLICES=""
for arch in $ARCHS; do
  triple="$(triple_for "$arch")"
  rustup target add "$triple" >/dev/null 2>&1 || true
  # `cargo rustc --crate-type staticlib`, NOT `cargo build`. With
  # `lto = true` and crate-type `["cdylib", "staticlib", "rlib"]`, rustc emits
  # an archive with every #[no_mangle] symbol internalised: measured
  # 2026-08-03 on rk_pki, 0 of the 7 entry points present in the .a while the
  # .dylib from the same invocation carried all 7. The trigger is `rlib` being
  # emitted alongside -- staticlib+cdylib is fine, staticlib+rlib is not -- and
  # rlib cannot leave Cargo.toml because tests/ link against it. Restricting
  # this one invocation to a single crate type restores the symbols, keeps LTO,
  # and drops the archive from ~38 MB to ~10 MB.
  ( cd "$CRATE_DIR" && cargo rustc $CARGO_PROFILE_ARG --target "$triple" \
      --target-dir "$TARGET_DIR" --crate-type staticlib )
  SLICES="$SLICES $TARGET_DIR/$triple/$PROFILE_DIR/librk_nats.a"
done

mkdir -p "$BUILT_PRODUCTS_DIR"
# `lipo -create` with a single input is a copy, so the one-arch case needs no
# special handling.
# shellcheck disable=SC2086
lipo -create $SLICES -output "$BUILT_PRODUCTS_DIR/librk_nats.a"

# An archive stripped of its entry points links without a word and fails only
# at run time, when Dart looks a symbol up by name. That is the failure this
# check exists to turn into a build error.
#
# `nm -gU` is used on the ARCHIVE here deliberately. It does NOT read the
# archive cleanly: measured 2026-08-03, nm still rejects 34 objects with
# "Unknown attribute kind (102)" -- every one of them compiler_builtins out of
# the Rust sysroot -- which is why stderr goes to /dev/null. What the single
# crate type buys is that the ONE object carrying the #[no_mangle] entry points
# is a readable Mach-O; with `rlib` also emitted that object is
# __LLVM,__bitcode too and the grep below finds nothing.
if ! nm -gU "$BUILT_PRODUCTS_DIR/librk_nats.a" 2>/dev/null | grep -q " _rk_nats_abi_version$"; then
  echo "rk_nats: librk_nats.a carries no rk_nats_abi_version -- the C ABI did not survive the build" >&2
  exit 1
fi

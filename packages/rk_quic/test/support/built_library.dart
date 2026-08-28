// Finding the freshly built native library from a plain `flutter test`.
//
// A package test runs outside any Flutter bundle: there is no runner directory
// for the artefact to sit next to, so the test has to look in cargo's output.
//
// **These helpers never skip.** A skipped test reports green and proves
// nothing, and this suite exists precisely to prove the version travels from
// Rust to Dart. If the library is not built, the run fails and says which
// command builds it.

import 'dart:io';

/// Where cargo leaves the shared library for the host, checked in the order a
/// developer is likely to have produced them.
String? locateBuiltLibrary() {
  final override = Platform.environment['RK_QUIC_LIBRARY'];
  if (override != null && override.isNotEmpty && File(override).existsSync()) {
    return override;
  }

  final fileName = Platform.isWindows
      ? 'rk_quic.dll'
      : Platform.isMacOS
      ? 'librk_quic.dylib'
      : 'librk_quic.so';

  final crateTarget = Directory('${_packageRoot()}/rust/target');
  if (!crateTarget.existsSync()) return null;

  for (final profile in const ['release', 'debug']) {
    final direct = File('${crateTarget.path}/$profile/$fileName');
    if (direct.existsSync()) return direct.path;
  }

  // A `--target <triple>` build nests one level deeper. Take the newest, so a
  // stale cross-compiled copy cannot shadow a fresh host build.
  File? newest;
  for (final entry in crateTarget.listSync().whereType<Directory>()) {
    for (final profile in const ['release', 'debug']) {
      final candidate = File('${entry.path}/$profile/$fileName');
      if (!candidate.existsSync()) continue;
      if (newest == null ||
          candidate.lastModifiedSync().isAfter(newest.lastModifiedSync())) {
        newest = candidate;
      }
    }
  }
  return newest?.path;
}

/// Returns [path], or fails the run with the command that would fix it.
String requireBuiltLibrary(String? path) {
  if (path != null) return path;
  throw StateError(
    'the rk_quic native library is not built, so this test would prove '
    'nothing by passing.\n'
    'Build it:  cd packages/rk_quic/rust && cargo build --release\n'
    'Or point at one:  RK_QUIC_LIBRARY=<path to the .dll/.so/.dylib>',
  );
}

/// The version declared in `rust/Cargo.toml`.
///
/// Read from the crate manifest rather than restated here: an assertion that
/// compares two constants in the same file passes when both are wrong.
String crateVersionFromCargoToml() {
  final manifest = File('${_packageRoot()}/rust/Cargo.toml').readAsStringSync();
  // The first `version =` under `[package]`, before any `[dependencies]`.
  final packageSection = manifest.split(RegExp(r'^\[', multiLine: true))[1];
  final match = RegExp(
    r'^version\s*=\s*"([^"]+)"',
    multiLine: true,
  ).firstMatch(packageSection);
  if (match == null) {
    throw StateError('no version in rust/Cargo.toml [package]');
  }
  return match.group(1)!;
}

/// The package directory, however the test runner was invoked.
String _packageRoot() {
  var dir = Directory.current;
  for (var i = 0; i < 6; i++) {
    if (File('${dir.path}/pubspec.yaml').existsSync() &&
        Directory('${dir.path}/rust').existsSync()) {
      return dir.path;
    }
    final parent = dir.parent;
    if (parent.path == dir.path) break;
    dir = parent;
  }
  throw StateError(
    'could not find the rk_quic package root from '
    '${Directory.current.path}',
  );
}

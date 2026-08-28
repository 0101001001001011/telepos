// Finding the freshly built native library from a plain `flutter test`.
//
// A package test runs outside any Flutter bundle: there is no runner directory
// for the artefact to sit next to, so the test has to look in cargo's output.
//
// **These helpers never skip.** A skipped test reports green and proves
// nothing, and this suite exists precisely to prove that the calls reach Rust.
// If the library is not built, the run fails and says which command builds it.

import 'dart:io';

/// Where cargo leaves the shared library for the host, checked in the order a
/// developer is likely to have produced them.
String? locateBuiltLibrary() {
  final override = Platform.environment['RK_MDNS_LIBRARY'];
  if (override != null && override.isNotEmpty && File(override).existsSync()) {
    return override;
  }

  final fileName = Platform.isWindows
      ? 'rk_mdns.dll'
      : Platform.isMacOS
      ? 'librk_mdns.dylib'
      : 'librk_mdns.so';

  final crateTarget = Directory('${packageRoot()}/rust/target');
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
    'the rk_mdns native library is not built, so this test would prove '
    'nothing by passing.\n'
    'Build it:  cd packages/rk_mdns/rust && cargo build --release\n'
    'Or point at one:  RK_MDNS_LIBRARY=<path to the .dll/.so/.dylib>',
  );
}

/// A UDP port nothing else on this machine is using.
///
/// Not 5353: on the real port the machine's own responder — Windows has one,
/// macOS has one, a Linux with Avahi has one — answers questions meant for
/// these tests, and a suite that passed because `mDNSResponder` replied would
/// be proving nothing about this package.
int privatePort([int offset = 0]) => 24000 + (pid % 900) * 2 + offset;

/// The version declared in `rust/Cargo.toml`.
///
/// Read from the crate manifest rather than restated here: an assertion that
/// compares two constants in the same file passes when both are wrong.
String crateVersionFromCargoToml() {
  final manifest = File('${packageRoot()}/rust/Cargo.toml').readAsStringSync();
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

/// The public members a conditional-import half offers.
///
/// Used to hold the two halves of `responder.dart` and `browser.dart` to one
/// surface. Nothing type-checks one against the other — they are chosen by a
/// conditional import — so code compiled for both ends would simply fail to
/// build on whichever half was forgotten.
///
/// Two things this has to get right, and both were got wrong first:
///
/// * **Nested generics.** `Future<List<MdnsInterface>?>` is not matched by
///   `Future<[^>]+>`; the lazy `.*?>` below is what handles it.
/// * **Private helpers.** A top-level `ResponderState _parseState(...)` is not
///   part of any surface, and counting it made the two halves disagree for a
///   reason nobody could act on.
Set<String> publicMembersOf(String source) =>
    RegExp(
      r'(?:Future|Stream)<.*?>\s+(?:get\s+)?(\w+)|'
      r'\bResponderState\s+get\s+(\w+)',
    ).allMatches(source).map((m) => m.group(1) ?? m.group(2)!).where((name) {
      return !name.startsWith('_');
    }).toSet();

/// The package directory, however the test runner was invoked.
String packageRoot() {
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
    'could not find the rk_mdns package root from ${Directory.current.path}',
  );
}

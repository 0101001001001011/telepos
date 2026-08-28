/// Why the native library is or is not usable in this process.
///
/// Every value here is *returned*, never thrown (И144). A caller asking
/// whether mDNS exists is asking a question, and a question is answered, not
/// raised.
enum NativeLoadOutcome {
  /// The library is loaded and speaks an ABI generation this build knows.
  loaded,

  /// The platform has no `dart:ffi` at all — the browser. Not a failure to
  /// report to anyone: a browser has no multicast socket, so there is nothing
  /// here for it to be missing.
  unsupportedPlatform,

  /// Nothing to open under any of the names tried. Overwhelmingly the ordinary
  /// case: the app was built without the plugin, or `cargo build` has not been
  /// run in a plain `dart test`.
  libraryMissing,

  /// The file opened but does not export the ABI entry points. Usually a name
  /// collision — some other `rk_mdns` on the loader path.
  symbolMissing,

  /// The library loaded and works, and implements a different generation of
  /// the ABI than this Dart code was written against. Refused deliberately:
  /// calling on across a generation is how ownership rules get violated
  /// silently, which is a crash with no explanation an hour later.
  abiMismatch,
}

/// The answer to "is there a native mDNS here, and which one".
///
/// Immutable, comparable, and carries the detail rather than logging it: the
/// caller decides whether a missing library is worth showing an operator.
class NativeProbe {
  /// Everything about one attempt to load.
  const NativeProbe({
    required this.outcome,
    this.version,
    this.abiVersion,
    this.detail,
    this.path,
  });

  /// Why the library is or is not usable.
  final NativeLoadOutcome outcome;

  /// The version string **the loaded library reported about itself**, or null
  /// when nothing loaded.
  ///
  /// Read out of the library, not out of the pubspec: a Dart constant would
  /// keep saying the right thing while the shipped `.so` was a year old.
  final String? version;

  /// The ABI generation the library reports, or null when nothing loaded.
  final int? abiVersion;

  /// One line for a log or an operator. Never the sole carrier of meaning —
  /// [outcome] is what code branches on.
  final String? detail;

  /// What was actually opened, when something was.
  final String? path;

  /// Whether calls into the native side may be made.
  bool get isUsable => outcome == NativeLoadOutcome.loaded;

  @override
  String toString() =>
      'NativeProbe(${outcome.name}'
      '${version == null ? '' : ', version: $version'}'
      '${abiVersion == null ? '' : ', abi: $abiVersion'}'
      '${path == null ? '' : ', path: $path'}'
      '${detail == null ? '' : ', $detail'})';

  @override
  bool operator ==(Object other) =>
      other is NativeProbe &&
      other.outcome == outcome &&
      other.version == version &&
      other.abiVersion == abiVersion &&
      other.detail == detail &&
      other.path == path;

  @override
  int get hashCode => Object.hash(outcome, version, abiVersion, detail, path);
}

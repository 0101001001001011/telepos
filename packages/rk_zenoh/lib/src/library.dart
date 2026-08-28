/// Finding the native library.
///
/// Since 0.2.0 this package ships per-platform build wiring: CMake for Windows
/// and Linux, Gradle for Android, and podspecs for iOS and macOS, all of which
/// invoke cargo. There is deliberately no `hook/build.dart` — on Flutter stable
/// its mere presence breaks `dart run`, `dart test` and `flutter build`, and it
/// reaches no target at all.
///
/// A consumer therefore does not normally set a path: the plugin puts the
/// library where the platform expects it. The search below stays for the cases
/// that fall outside a Flutter build — a plain Dart process, a test running
/// against a freshly built crate, or a library installed by a package manager.
library;

import 'dart:ffi';
import 'dart:io';

/// The file name of the native library on this platform.
String defaultLibraryFileName() {
  if (Platform.isWindows) return 'rk_zenoh.dll';
  if (Platform.isMacOS || Platform.isIOS) return 'librk_zenoh.dylib';
  return 'librk_zenoh.so';
}

/// Where the library is looked for, in order, when no path is given.
///
/// Returned as a list rather than searched inline so a caller that fails to
/// load can show the user exactly where it looked — "library not found" with
/// no list of places is a support call.
List<String> defaultLibrarySearchPaths() {
  final name = defaultLibraryFileName();
  final fromEnvironment = Platform.environment['RK_ZENOH_LIBRARY'];
  final beside = File(Platform.resolvedExecutable).parent.path;
  return <String>[
    if (fromEnvironment != null && fromEnvironment.isNotEmpty) fromEnvironment,
    // Apple first, and it is not a `.dylib`: apple/build_rust.sh produces a
    // STATIC archive that the podspec pulls into the pod framework with
    // `-force_load`, so under `use_frameworks!` the binary to open is the
    // framework's own. No `librk_zenoh.dylib` is produced anywhere.
    if (Platform.isMacOS || Platform.isIOS) 'rk_zenoh.framework/rk_zenoh',
    '$beside${Platform.pathSeparator}$name',
    name, // whatever the platform's own search finds
  ];
}

/// Raised when the native library cannot be found or loaded.
class RkzLibraryNotFound implements Exception {
  RkzLibraryNotFound(this.attempts);

  /// Every path tried, with the reason it did not work.
  final Map<String, String> attempts;

  @override
  String toString() {
    final tried = attempts.entries
        .map((e) => '  ${e.key}: ${e.value}')
        .join('\n');
    return 'The rk_zenoh native library could not be loaded. Tried:\n$tried';
  }
}

/// Open the native library, trying each candidate path in turn.
///
/// Pass [path] to skip the search entirely, which is what a host application
/// should do once it knows where it put the file.
DynamicLibrary openNativeLibrary({String? path}) {
  final candidates = path != null
      ? <String>[path]
      : defaultLibrarySearchPaths();
  final attempts = <String, String>{};
  for (final candidate in candidates) {
    try {
      return DynamicLibrary.open(candidate);
    } on Object catch (e) {
      attempts[candidate] = e.toString();
    }
  }

  // Apple, and only after every name failed: the library may be linked
  // straight into the host process rather than sitting in a file. That is the
  // normal outcome of a staticlib build, so it is a fallback rather than an
  // error — measured 2026-08-03, the first Apple build this package ever had.
  if (path == null && (Platform.isMacOS || Platform.isIOS)) {
    try {
      final process = DynamicLibrary.process();
      // A handle proves nothing: `process()` succeeds in a process that never
      // linked this library. Asking for a symbol is what makes the answer
      // real, and a miss becomes a named failure instead of a later crash.
      process.lookup<NativeFunction<Pointer<Void> Function()>>(
        'rkz_native_version',
      );
      return process;
    } on Object catch (e) {
      attempts['process image'] = e.toString();
    }
  }

  throw RkzLibraryNotFound(attempts);
}

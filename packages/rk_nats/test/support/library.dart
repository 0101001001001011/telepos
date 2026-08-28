/// Finding the built native library for the tests that need one.
library;

import 'dart:io';

import 'package:rk_nats/rk_nats.dart';

/// Where the library is, or `null` if it has not been built.
///
/// Overridden with `RK_NATS_LIBRARY`; otherwise the debug and release outputs
/// of `cargo build` inside the package are checked, in that order.
String? findNativeLibrary() {
  final override = Platform.environment['RK_NATS_LIBRARY'];
  if (override != null && override.isNotEmpty) {
    return File(override).existsSync() ? override : null;
  }
  final name = rkNatsDefaultLibraryFileName();
  for (final profile in ['release', 'debug']) {
    final path = 'rust/target/$profile/$name';
    if (File(path).existsSync()) return path;
  }
  return null;
}

/// Why the native tests are not running, phrased so that the reader knows what
/// to type rather than that something was skipped.
const String buildTheLibraryFirst =
    'the native library is not built: run `cargo build --release` in '
    'packages/rk_nats/rust, or set RK_NATS_LIBRARY to an existing one';

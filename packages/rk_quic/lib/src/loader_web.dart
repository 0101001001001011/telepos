// The browser half of the conditional import in `loader.dart`.
//
// **И143 lives here.** `dart:ffi` does not exist in the browser — a property of
// the platform, not a gap in this package — so importing `rk_quic` from code
// that is also compiled to web must not drag `dart:ffi` in. This file has no
// `dart:ffi` import and never will; that is the whole reason it exists.
//
// It is not a stub that pretends. The browser is the *client* of a
// WebTransport endpoint, never its host, so "no native transport here" is the
// correct and permanent answer rather than a missing feature.

import 'native_probe.dart';

/// The ABI generation this Dart code is written against.
///
/// Declared here too so the two halves of the conditional import present the
/// same surface: a caller that reads it must not have to know which half it
/// got.
const int rkQuicAbiVersion = 1;

/// Environment variable naming an explicit library file. Unused in a browser,
/// present so the surfaces match.
const String rkQuicLibraryPathVariable = 'RK_QUIC_LIBRARY';

/// No candidates: there is no dynamic library to open in a browser.
List<String> defaultCandidatePaths() => const <String>[];

/// Always [NativeLoadOutcome.unsupportedPlatform], with the reason stated.
NativeProbe probeNativeLibrary({
  int? expectedAbiVersion,
  List<String>? candidatePaths,
}) {
  return const NativeProbe(
    outcome: NativeLoadOutcome.unsupportedPlatform,
    detail:
        'the browser has no dart:ffi; it is the client of a WebTransport '
        'endpoint, not its host',
  );
}

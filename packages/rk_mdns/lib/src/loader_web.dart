// The browser half of the conditional import in `loader.dart`.
//
// **И143 lives here.** `dart:ffi` does not exist in the browser — a property of
// the platform, not a gap in this package — so importing `rk_mdns` from code
// that is also compiled to web must not drag `dart:ffi` in. This file has no
// `dart:ffi` import and never will; that is the whole reason it exists.
//
// It is not a stub that pretends, and it is not waiting to be filled in. A
// browser has no UDP socket and no way to join a multicast group: the
// WebSocket and WebTransport APIs are the only sockets it has, and neither
// carries multicast. `unsupported` is the correct answer here permanently,
// and it will still be correct when this package is version 5.

import 'native_probe.dart';

/// The ABI generation this Dart code is written against.
///
/// Declared here too so the two halves of the conditional import present the
/// same surface: a caller that reads it must not have to know which half it
/// got.
const int rkMdnsAbiVersion = 1;

/// Environment variable naming an explicit library file. Unused in a browser,
/// present so the surfaces match.
const String rkMdnsLibraryPathVariable = 'RK_MDNS_LIBRARY';

/// Stands for the host process image. Unused in a browser, present so the
/// surfaces match.
const String processImageCandidate = '<process image>';

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
        'the browser has no dart:ffi and no multicast socket; ask a host that '
        'has one, over HTTP or WebTransport',
  );
}

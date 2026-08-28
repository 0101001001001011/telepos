// The native half of the conditional import in `loader.dart`.
//
// Everything here is a returned value. `DynamicLibrary.open` throws — that is
// the one place a foreign stack could reach a caller — so it is caught at the
// only point it can happen and turned into a [NativeProbe] (И144).

import 'dart:ffi' as ffi;
import 'dart:io' show Platform;

import 'package:ffi/ffi.dart' show Utf8, Utf8Pointer;

import 'native_probe.dart';

/// The ABI generation this Dart code is written against.
///
/// Must equal `RK_MDNS_ABI_VERSION` in `src/rk_mdns.h` and `rust/src/ffi.rs`.
/// `test/abi_surface_test.dart` fails when they drift.
const int rkMdnsAbiVersion = 1;

/// Environment variable naming an explicit library file.
///
/// Exists because `dart test` runs outside any Flutter bundle: there is no
/// runner directory for the artefact to sit next to, so a test that wants to
/// prove the version really comes from Rust has to say where the freshly built
/// file is. Also the escape hatch for an operator with an unusual install.
const String rkMdnsLibraryPathVariable = 'RK_MDNS_LIBRARY';

typedef _AbiVersionNative = ffi.Uint32 Function();
typedef _AbiVersionDart = int Function();
typedef _VersionNative = ffi.Pointer<Utf8> Function();
typedef _VersionDart = ffi.Pointer<Utf8> Function();

/// Stands for the host process image rather than a file on disk.
///
/// On Apple the native part is a static archive linked into the pod
/// framework, so on some deployments there is no file to open and the symbols
/// are simply already in the process. Handled as a candidate rather than as a
/// special case so it goes through the same ABI and symbol checks as every
/// other candidate — a process that never linked this library is then refused
/// by name instead of being accepted because a handle came back.
const String processImageCandidate = '<process image>';

/// The file names to try, in order, on this platform.
///
/// Order matters: an explicit path beats convention, so an operator or a test
/// can always override without editing the package.
List<String> defaultCandidatePaths() {
  final explicit = Platform.environment[rkMdnsLibraryPathVariable];
  final candidates = <String>[
    if (explicit != null && explicit.isNotEmpty) explicit,
  ];

  if (Platform.isWindows) {
    candidates.add('rk_mdns.dll');
  } else if (Platform.isMacOS || Platform.isIOS) {
    // With `use_frameworks!` the pod is a framework and the binary lives
    // inside it — see apple/build_rust.sh, which produces a STATIC archive
    // that the podspec pulls in with `-force_load`.
    //
    // [processImageCandidate] last: the archive can also end up linked
    // straight into the host, and then there is no file to open at all.
    candidates
      ..add('rk_mdns.framework/rk_mdns')
      ..add('librk_mdns.dylib')
      ..add(processImageCandidate);
  } else {
    // Android and Linux. On Android the system loader finds it in the APK's
    // lib directory by bare name; on Linux the Flutter bundle puts it in
    // `lib/` next to the runner and the RPATH covers it.
    candidates.add('librk_mdns.so');
  }
  return candidates;
}

/// Opens the native library and asks it two questions: which ABI generation it
/// implements, and what version it is.
///
/// Never throws. Every outcome — including a library that opens but is the
/// wrong generation — is a [NativeProbe].
///
/// [expectedAbiVersion] is a parameter and not a constant so that the mismatch
/// branch can be exercised against a *real* library rather than a mock: a test
/// asks for a generation that does not exist and must be refused.
NativeProbe probeNativeLibrary({
  int? expectedAbiVersion,
  List<String>? candidatePaths,
}) {
  final expected = expectedAbiVersion ?? rkMdnsAbiVersion;
  final candidates = candidatePaths ?? defaultCandidatePaths();

  if (candidates.isEmpty) {
    return const NativeProbe(
      outcome: NativeLoadOutcome.libraryMissing,
      detail: 'no candidate library names for this platform',
    );
  }

  final attempts = <String>[];
  for (final path in candidates) {
    final ffi.DynamicLibrary library;
    try {
      library = path == processImageCandidate
          ? ffi.DynamicLibrary.process()
          : ffi.DynamicLibrary.open(path);
    } on Object catch (error) {
      // `DynamicLibrary.open` throws ArgumentError on most platforms and other
      // types on some; catching Object is deliberate rather than lazy, because
      // the contract here is "this function does not throw", not "this
      // function handles the errors I predicted".
      attempts.add('$path: ${_firstLine(error)}');
      continue;
    }

    final _AbiVersionDart abiVersion;
    final _VersionDart version;
    try {
      abiVersion = library
          .lookup<ffi.NativeFunction<_AbiVersionNative>>('rk_mdns_abi_version')
          .asFunction<_AbiVersionDart>();
      version = library
          .lookup<ffi.NativeFunction<_VersionNative>>('rk_mdns_version')
          .asFunction<_VersionDart>();
    } on Object catch (error) {
      return NativeProbe(
        outcome: NativeLoadOutcome.symbolMissing,
        path: path,
        detail:
            'opened but does not export the rk_mdns ABI: ${_firstLine(error)}',
      );
    }

    final foundAbi = abiVersion();
    // The version pointer is into static storage on the Rust side, so nothing
    // is allocated and nothing is freed here (И146). `toDartString` copies.
    final foundVersion = version().toDartString();

    if (foundAbi != expected) {
      return NativeProbe(
        outcome: NativeLoadOutcome.abiMismatch,
        path: path,
        version: foundVersion,
        abiVersion: foundAbi,
        detail:
            'library implements ABI generation $foundAbi, this build '
            'speaks $expected',
      );
    }

    return NativeProbe(
      outcome: NativeLoadOutcome.loaded,
      path: path,
      version: foundVersion,
      abiVersion: foundAbi,
    );
  }

  return NativeProbe(
    outcome: NativeLoadOutcome.libraryMissing,
    detail: 'tried ${attempts.length}: ${attempts.join('; ')}',
  );
}

String _firstLine(Object error) {
  final text = error.toString();
  final newline = text.indexOf('\n');
  return newline == -1 ? text : text.substring(0, newline);
}

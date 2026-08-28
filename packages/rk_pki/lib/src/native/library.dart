/// Finding the native library, and proving it is really there.
library;

import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';

import '../errors.dart';
import 'bindings.g.dart';

/// The ABI this binding speaks. A library reporting anything else is refused
/// rather than called: the alternative is calling functions whose meaning has
/// changed underneath us.
const int rkPkiAbiVersion = 1;

/// An opened `rk_pki` native library.
final class RkPkiLibrary {
  RkPkiLibrary._(this.dylib, this.bindings);

  final DynamicLibrary dylib;
  final RkPkiBindings bindings;

  /// The file names this library is looked for under, in order.
  ///
  /// Apple gets the framework binary and then the process image, because
  /// `apple/build_rust.sh` produces a STATIC archive that the podspec pulls
  /// into the pod framework with `-force_load` — no `.dylib` is produced
  /// anywhere. The bare `librk_pki.dylib` stays last for a developer who
  /// built the crate into one by hand.
  ///
  /// Measured 2026-08-03, the first Apple build this package ever had: iOS
  /// already went to the process image, but **macOS asked only for the
  /// `.dylib`** and therefore could not load at all.
  static List<String> defaultNames() {
    if (Platform.isWindows) return const <String>['rk_pki.dll'];
    if (Platform.isMacOS || Platform.isIOS) {
      return const <String>['rk_pki.framework/rk_pki', 'librk_pki.dylib'];
    }
    return const <String>['librk_pki.so'];
  }

  /// Opens the library, returning a failure rather than throwing when it is
  /// not there. Absence is a fact about the deployment, not an exception.
  static PkiResult<RkPkiLibrary> open({String? path}) {
    try {
      final DynamicLibrary dylib;
      if (path != null) {
        dylib = DynamicLibrary.open(path);
      } else if (Platform.isIOS || Platform.isMacOS) {
        dylib = _openApple();
      } else {
        dylib = _openFirst(defaultNames());
      }
      final bindings = RkPkiBindings(dylib);
      final abi = bindings.rk_pki_abi_version();
      if (abi != rkPkiAbiVersion) {
        return PkiErr<RkPkiLibrary>(
          NativeUnavailable(
            'the library reports ABI $abi; this binding speaks '
            '$rkPkiAbiVersion',
          ),
        );
      }
      return PkiOk<RkPkiLibrary>(RkPkiLibrary._(dylib, bindings));
    } catch (e) {
      return PkiErr<RkPkiLibrary>(
        NativeUnavailable('cannot load the rk_pki native library: $e'),
      );
    }
  }

  /// Opens on iOS and macOS, where the library is linked into the host.
  ///
  /// The named candidates come first so an unusual deployment still wins, and
  /// the process image is the fallback rather than the only path — with
  /// `use_frameworks!` the symbols are in the framework binary, which is
  /// already loaded, so [DynamicLibrary.process] finds them.
  static DynamicLibrary _openApple() {
    try {
      return _openFirst(defaultNames());
    } on Object {
      final process = DynamicLibrary.process();
      // A handle is not proof. `DynamicLibrary.process()` succeeds even in a
      // process that never linked this library; asking for a symbol is what
      // turns "opened" into "present", and a miss here becomes a named
      // failure instead of a crash at the first real call.
      process.lookup<NativeFunction<Uint32 Function()>>('rk_pki_abi_version');
      return process;
    }
  }

  static DynamicLibrary _openFirst(List<String> names) {
    Object? last;
    for (final name in names) {
      try {
        return DynamicLibrary.open(name);
      } catch (e) {
        last = e;
      }
    }
    throw StateError('none of $names could be opened: $last');
  }

  int get abiVersion => bindings.rk_pki_abi_version();

  String get version => bindings.rk_pki_version().cast<Utf8>().toDartString();

  /// Runs an operation that needs no key store.
  String callStateless(String op, String requestJson) {
    final opPtr = op.toNativeUtf8();
    final reqPtr = requestJson.toNativeUtf8();
    try {
      final answer = bindings.rk_pki_call_stateless(
        opPtr.cast<Char>(),
        reqPtr.cast<Char>(),
      );
      return _takeString(answer);
    } finally {
      malloc.free(opPtr);
      malloc.free(reqPtr);
    }
  }

  /// Reads a string the library allocated and frees it immediately.
  ///
  /// И146: the collector knows nothing about this allocation, so it is
  /// released on the same line it is consumed, not left to a finalizer.
  String _takeString(Pointer<Char> pointer) {
    if (pointer == nullptr) {
      return '{"ok":false,"error":{"kind":"nativeFault",'
          '"detail":"the library returned no answer"}}';
    }
    try {
      return pointer.cast<Utf8>().toDartString();
    } finally {
      bindings.rk_pki_string_free(pointer);
    }
  }

  String takeString(Pointer<Char> pointer) => _takeString(pointer);
}

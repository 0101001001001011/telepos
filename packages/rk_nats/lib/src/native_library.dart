/// Finding and calling the native library.
///
/// Nothing here decides how the library gets built or shipped. That choice is
/// made once for every `rk_*` package and is deliberately not made here; this
/// file only knows how to open a file by path and how to release what it hands
/// back.
library;

import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';

/// The signature every function on the boundary has: one JSON string in, one
/// JSON string out.
typedef _CallNative = Pointer<Utf8> Function(Pointer<Utf8>);
typedef _CallDart = Pointer<Utf8> Function(Pointer<Utf8>);
typedef _FreeNative = Void Function(Pointer<Utf8>);
typedef _FreeDart = void Function(Pointer<Utf8>);
typedef _VersionNative = Pointer<Utf8> Function();
typedef _VersionDart = Pointer<Utf8> Function();

/// The ABI this binding was written against. A library reporting anything else
/// is refused rather than called and hoped for.
const String rkNatsExpectedAbiVersion = '1';

/// The names of the exported functions, in one place so a rename shows up as
/// one diff rather than as a runtime failure at a customer's till.
class RkNatsSymbols {
  RkNatsSymbols._();

  /// Static string; must never be freed.
  static const String abiVersion = 'rk_nats_abi_version';

  /// Releases anything the other functions return.
  static const String stringFree = 'rk_nats_string_free';

  /// Opens a connection.
  static const String connect = 'rk_nats_connect';

  /// Closes one.
  static const String close = 'rk_nats_close';

  /// Asks the server what an ack will mean.
  static const String probeDurability = 'rk_nats_probe_durability';

  /// Hands over a `varz` document fetched by the caller.
  static const String applyVarz = 'rk_nats_apply_varz';

  /// Creates a stream or brings one to shape.
  static const String ensureStream = 'rk_nats_ensure_stream';

  /// Publishes one message.
  static const String publish = 'rk_nats_publish';

  /// Pulls a batch.
  static const String fetch = 'rk_nats_fetch';

  /// Acknowledges a message.
  static const String ack = 'rk_nats_ack';

  /// Evaluates a `varz` document without connecting to anything.
  static const String evaluateVarz = 'rk_nats_evaluate_varz';

  /// Dumps the whole policy-against-meaning decision table.
  static const String gateMatrix = 'rk_nats_gate_matrix';

  /// Lists every name this build of the library can produce.
  static const String vocabulary = 'rk_nats_vocabulary';

  /// Every symbol above, for a presence check that does not depend on calling
  /// each one.
  static const List<String> all = [
    abiVersion,
    stringFree,
    connect,
    close,
    probeDurability,
    applyVarz,
    ensureStream,
    publish,
    fetch,
    ack,
    evaluateVarz,
    gateMatrix,
    vocabulary,
  ];
}

/// The file name the library has on this platform.
String rkNatsDefaultLibraryFileName() {
  if (Platform.isWindows) return 'rk_nats.dll';
  // Apple gets the framework binary, not a `.dylib`. apple/build_rust.sh
  // produces a STATIC archive that the podspec pulls into the pod framework
  // with `-force_load`, so under `use_frameworks!` there is no `.dylib`
  // anywhere to open. Measured 2026-08-03, the first Apple build this package
  // ever had: the old name could not load on either macOS or iOS.
  if (Platform.isMacOS || Platform.isIOS) return 'rk_nats.framework/rk_nats';
  return 'librk_nats.so';
}

/// An opened native library, with the boundary's freeing rule enforced in one
/// place.
///
/// Deterministic freeing (I146): every reply is copied into a Dart string and
/// released inside [call], before that method returns. Nothing here waits for a
/// collector, and no finalizer is registered, because a finalizer is exactly
/// the non-deterministic freeing the invariant forbids.
class RkNatsNativeLibrary {
  RkNatsNativeLibrary._(this._library, this._free);

  /// Opens the library at [path].
  ///
  /// Throws [RkNatsLibraryUnavailable] when it cannot be opened or when it
  /// reports an ABI this binding does not speak. This is the one place a
  /// throw is right: it is a deployment fault, not a runtime outcome, and it
  /// happens before any call could have moved money.
  factory RkNatsNativeLibrary.open(String path) {
    final DynamicLibrary library = _openOrProcess(path);

    for (final symbol in RkNatsSymbols.all) {
      if (!library.providesSymbol(symbol)) {
        throw RkNatsLibraryUnavailable(
          '$path does not export $symbol: it is not this library, or not this '
          'version of it',
        );
      }
    }

    final version = library
        .lookupFunction<_VersionNative, _VersionDart>(
          RkNatsSymbols.abiVersion,
        )()
        .toDartString();
    if (version != rkNatsExpectedAbiVersion) {
      throw RkNatsLibraryUnavailable(
        '$path reports ABI $version and this binding speaks '
        '$rkNatsExpectedAbiVersion; refusing to guess',
      );
    }

    final free = library.lookupFunction<_FreeNative, _FreeDart>(
      RkNatsSymbols.stringFree,
    );
    return RkNatsNativeLibrary._(library, free);
  }

  /// Opens [path], falling back to the host process image on Apple.
  ///
  /// On macOS and iOS the native part is a static archive linked into the pod
  /// framework, so on some deployments there is no file to open and the
  /// symbols are already in the process. This cannot silently accept a
  /// process that never linked the library: [RkNatsNativeLibrary.open] checks
  /// every symbol in [RkNatsSymbols.all] straight after, and refuses by name
  /// when one is missing.
  static DynamicLibrary _openOrProcess(String path) {
    try {
      return DynamicLibrary.open(path);
    } on Object catch (error) {
      if (!Platform.isMacOS && !Platform.isIOS) {
        throw RkNatsLibraryUnavailable('cannot open $path: $error');
      }
      try {
        return DynamicLibrary.process();
      } on Object catch (fallback) {
        throw RkNatsLibraryUnavailable(
          'cannot open $path ($error) and the process image is not usable '
          'either ($fallback)',
        );
      }
    }
  }

  final DynamicLibrary _library;
  final _FreeDart _free;
  final Map<String, _CallDart> _cache = {};

  /// Calls [symbol] with [request] and returns the decoded reply.
  ///
  /// Both allocations are released before returning: the argument, which this
  /// side owns, and the reply, which the native side allocated and this side
  /// must free (I146).
  Map<String, Object?> call(String symbol, Map<String, Object?> request) {
    final function = _cache.putIfAbsent(
      symbol,
      () => _library.lookupFunction<_CallNative, _CallDart>(symbol),
    );
    final argument = jsonEncode(request).toNativeUtf8();
    Pointer<Utf8> reply = nullptr;
    try {
      reply = function(argument);
      if (reply == nullptr) {
        // The library promises never to do this. If it ever does, saying so is
        // better than dereferencing null on the caller's behalf.
        return {
          'code': 'panic',
          'message': '$symbol returned null, which the ABI forbids',
        };
      }
      final text = reply.toDartString();
      return jsonDecode(text) as Map<String, Object?>;
    } finally {
      calloc.free(argument);
      if (reply != nullptr) _free(reply);
    }
  }
}

/// The native library is not usable, and no call was attempted.
class RkNatsLibraryUnavailable implements Exception {
  /// Builds it.
  RkNatsLibraryUnavailable(this.message);

  /// What went wrong.
  final String message;

  @override
  String toString() => 'RkNatsLibraryUnavailable: $message';
}

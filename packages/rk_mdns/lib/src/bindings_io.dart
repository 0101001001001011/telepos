// The raw FFI bindings, hand-written against `src/rk_mdns.h`.
//
// Nothing in this file is public API. It exists so that exactly one place
// knows the C signatures, and `test/abi_surface_test.dart` checks that place
// against the header.
//
// `ffigen` would have generated it. It was not used: the surface is small
// enough to read in one screen, ffigen needs LLVM wherever it is regenerated,
// and a generated file in git invites the question of which copy is true. The
// drift it would have prevented is caught by a test that also covers the Rust
// side, which ffigen would not have.

import 'dart:ffi' as ffi;

import 'package:ffi/ffi.dart' show Utf8, Utf8Pointer;

// The `*Native` shapes are only ever named inside a `lookup`, so they stay
// private. The `*Dart` shapes are the declared types of public fields on
// [RkMdnsBindings]; a private type on a public field is unnameable by the
// caller, which is what `library_private_types_in_public_api` is about. This
// library is under lib/src/ and is never exported.
typedef _AbiVersionNative = ffi.Uint32 Function();
typedef _VersionNative = ffi.Pointer<Utf8> Function();
typedef _StringFreeNative = ffi.Void Function(ffi.Pointer<Utf8>);

/// Frees a string the native side allocated.
typedef StringFreeDart = void Function(ffi.Pointer<Utf8>);
typedef _LastErrorNative = ffi.Pointer<Utf8> Function();
typedef _StartNative =
    ffi.Pointer<Utf8> Function(ffi.Pointer<Utf8>, ffi.Pointer<ffi.Uint64>);

/// Starts a responder or a browser from a JSON configuration.
typedef StartDart =
    ffi.Pointer<Utf8> Function(ffi.Pointer<Utf8>, ffi.Pointer<ffi.Uint64>);
typedef _StopNative = ffi.Pointer<Utf8> Function(ffi.Uint64);

/// Stops one by handle.
typedef StopDart = ffi.Pointer<Utf8> Function(int);
typedef _StateNative =
    ffi.Pointer<Utf8> Function(ffi.Uint64, ffi.Pointer<ffi.Pointer<Utf8>>);

/// Reads a responder's state as JSON.
typedef StateDart =
    ffi.Pointer<Utf8> Function(int, ffi.Pointer<ffi.Pointer<Utf8>>);
typedef _PollNative =
    ffi.Pointer<Utf8> Function(
      ffi.Uint64,
      ffi.Uint32,
      ffi.Pointer<ffi.Pointer<Utf8>>,
    );

/// Waits for the next event.
typedef PollDart =
    ffi.Pointer<Utf8> Function(int, int, ffi.Pointer<ffi.Pointer<Utf8>>);
typedef _ResolveNative =
    ffi.Pointer<Utf8> Function(
      ffi.Pointer<Utf8>,
      ffi.Pointer<ffi.Pointer<Utf8>>,
    );

/// Resolves one `<name>.local`.
typedef ResolveDart =
    ffi.Pointer<Utf8> Function(
      ffi.Pointer<Utf8>,
      ffi.Pointer<ffi.Pointer<Utf8>>,
    );
typedef _InterfacesNative =
    ffi.Pointer<Utf8> Function(ffi.Uint8, ffi.Pointer<ffi.Pointer<Utf8>>);

/// Lists the interfaces this host would announce on.
typedef InterfacesDart =
    ffi.Pointer<Utf8> Function(int, ffi.Pointer<ffi.Pointer<Utf8>>);

/// Every entry point of the native library, resolved once.
class RkMdnsBindings {
  /// Resolves every symbol the header declares.
  ///
  /// Throws if one is missing — deliberately, and only here: a library that
  /// opened but does not export the ABI is not a condition any caller can
  /// recover from, and [probeNativeLibrary] is the call that reports it as a
  /// value. Nothing constructs this without probing first.
  RkMdnsBindings(this._library)
    : abiVersion = _library
          .lookup<ffi.NativeFunction<_AbiVersionNative>>('rk_mdns_abi_version')
          .asFunction<int Function()>(),
      version = _library
          .lookup<ffi.NativeFunction<_VersionNative>>('rk_mdns_version')
          .asFunction<ffi.Pointer<Utf8> Function()>(),
      stringFree = _library
          .lookup<ffi.NativeFunction<_StringFreeNative>>('rk_mdns_string_free')
          .asFunction<StringFreeDart>(),
      lastErrorRaw = _library
          .lookup<ffi.NativeFunction<_LastErrorNative>>('rk_mdns_last_error')
          .asFunction<ffi.Pointer<Utf8> Function()>(),
      responderStart = _library
          .lookup<ffi.NativeFunction<_StartNative>>('rk_mdns_responder_start')
          .asFunction<StartDart>(),
      responderStop = _library
          .lookup<ffi.NativeFunction<_StopNative>>('rk_mdns_responder_stop')
          .asFunction<StopDart>(),
      responderState = _library
          .lookup<ffi.NativeFunction<_StateNative>>('rk_mdns_responder_state')
          .asFunction<StateDart>(),
      responderPoll = _library
          .lookup<ffi.NativeFunction<_PollNative>>('rk_mdns_responder_poll')
          .asFunction<PollDart>(),
      browserStart = _library
          .lookup<ffi.NativeFunction<_StartNative>>('rk_mdns_browser_start')
          .asFunction<StartDart>(),
      browserStop = _library
          .lookup<ffi.NativeFunction<_StopNative>>('rk_mdns_browser_stop')
          .asFunction<StopDart>(),
      browserPoll = _library
          .lookup<ffi.NativeFunction<_PollNative>>('rk_mdns_browser_poll')
          .asFunction<PollDart>(),
      resolveHost = _library
          .lookup<ffi.NativeFunction<_ResolveNative>>('rk_mdns_resolve_host')
          .asFunction<ResolveDart>(),
      interfaces = _library
          .lookup<ffi.NativeFunction<_InterfacesNative>>('rk_mdns_interfaces')
          .asFunction<InterfacesDart>();

  // ignore: unused_field
  final ffi.DynamicLibrary _library;

  /// The ABI generation the loaded library implements.
  final int Function() abiVersion;

  /// The library's own version string.
  final ffi.Pointer<Utf8> Function() version;

  /// Frees a string the library allocated.
  final StringFreeDart stringFree;

  /// The raw last-error pointer. Use [takeLastError] instead.
  final ffi.Pointer<Utf8> Function() lastErrorRaw;

  /// Starts a responder.
  final StartDart responderStart;

  /// Stops a responder, after its goodbye.
  final StopDart responderStop;

  /// Reads a responder's state, including the name it actually claimed.
  final StateDart responderState;

  /// Waits for a responder event.
  final PollDart responderPoll;

  /// Starts a browser.
  final StartDart browserStart;

  /// Stops a browser.
  final StopDart browserStop;

  /// Waits for a browser event.
  final PollDart browserPoll;

  /// Resolves one `<name>.local`.
  final ResolveDart resolveHost;

  /// Lists the interfaces this host would announce on.
  final InterfacesDart interfaces;

  /// Reads and clears the last error, freeing the buffer the library
  /// allocated.
  ///
  /// This is the only place that frees a native string, which is what makes
  /// И146 checkable: whoever allocated frees, and Dart hands the pointer back
  /// rather than calling `free()` on it.
  String? takeLastError() {
    final pointer = lastErrorRaw();
    if (pointer == ffi.nullptr) return null;
    final text = pointer.toDartString();
    stringFree(pointer);
    return text;
  }
}

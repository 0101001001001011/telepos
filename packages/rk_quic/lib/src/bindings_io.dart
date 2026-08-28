// The raw FFI bindings, hand-written against `src/rk_quic.h`.
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
// [RkQuicBindings]; a private type on a public field is unnameable by the
// caller, which is what `library_private_types_in_public_api` is about. This
// library is under lib/src/ and is never exported, so nothing here reaches
// pub.dev — the six names were made public in 2026-08-01, when the package
// gained its own analysis_options.yaml and the lint could fire for the first
// time.
typedef _AbiVersionNative = ffi.Uint32 Function();
typedef _VersionNative = ffi.Pointer<Utf8> Function();
typedef _StringFreeNative = ffi.Void Function(ffi.Pointer<Utf8>);
typedef StringFreeDart = void Function(ffi.Pointer<Utf8>);
typedef _LastErrorNative = ffi.Pointer<Utf8> Function();
typedef _ServerStartNative =
    ffi.Pointer<Utf8> Function(ffi.Pointer<Utf8>, ffi.Pointer<ffi.Uint64>);
typedef ServerStartDart =
    ffi.Pointer<Utf8> Function(ffi.Pointer<Utf8>, ffi.Pointer<ffi.Uint64>);
typedef _ServerStopNative = ffi.Pointer<Utf8> Function(ffi.Uint64);
typedef ServerStopDart = ffi.Pointer<Utf8> Function(int);
typedef _LocalPortNative =
    ffi.Pointer<Utf8> Function(ffi.Uint64, ffi.Pointer<ffi.Uint16>);
typedef LocalPortDart =
    ffi.Pointer<Utf8> Function(int, ffi.Pointer<ffi.Uint16>);
typedef _PollNative =
    ffi.Pointer<Utf8> Function(
      ffi.Uint64,
      ffi.Uint32,
      ffi.Pointer<ffi.Pointer<Utf8>>,
    );
typedef PollDart =
    ffi.Pointer<Utf8> Function(int, int, ffi.Pointer<ffi.Pointer<Utf8>>);
typedef _SendNative =
    ffi.Pointer<Utf8> Function(
      ffi.Uint64,
      ffi.Uint64,
      ffi.Pointer<Utf8>,
      ffi.Uint8,
    );
typedef SendDart = ffi.Pointer<Utf8> Function(int, int, ffi.Pointer<Utf8>, int);
typedef _StreamSendNative =
    ffi.Pointer<Utf8> Function(
      ffi.Uint64,
      ffi.Uint64,
      ffi.Uint64,
      ffi.Pointer<Utf8>,
    );
typedef StreamSendDart =
    ffi.Pointer<Utf8> Function(int, int, int, ffi.Pointer<Utf8>);
typedef _StreamCloseNative =
    ffi.Pointer<Utf8> Function(ffi.Uint64, ffi.Uint64, ffi.Uint64);
typedef StreamCloseDart = ffi.Pointer<Utf8> Function(int, int, int);

/// Every entry point of the native library, resolved once.
class RkQuicBindings {
  RkQuicBindings(this._library)
    : abiVersion = _library
          .lookup<ffi.NativeFunction<_AbiVersionNative>>('rk_quic_abi_version')
          .asFunction<int Function()>(),
      version = _library
          .lookup<ffi.NativeFunction<_VersionNative>>('rk_quic_version')
          .asFunction<ffi.Pointer<Utf8> Function()>(),
      stringFree = _library
          .lookup<ffi.NativeFunction<_StringFreeNative>>('rk_quic_string_free')
          .asFunction<StringFreeDart>(),
      lastErrorRaw = _library
          .lookup<ffi.NativeFunction<_LastErrorNative>>('rk_quic_last_error')
          .asFunction<ffi.Pointer<Utf8> Function()>(),
      serverStart = _library
          .lookup<ffi.NativeFunction<_ServerStartNative>>(
            'rk_quic_server_start',
          )
          .asFunction<ServerStartDart>(),
      serverStop = _library
          .lookup<ffi.NativeFunction<_ServerStopNative>>('rk_quic_server_stop')
          .asFunction<ServerStopDart>(),
      serverLocalPort = _library
          .lookup<ffi.NativeFunction<_LocalPortNative>>(
            'rk_quic_server_local_port',
          )
          .asFunction<LocalPortDart>(),
      serverPoll = _library
          .lookup<ffi.NativeFunction<_PollNative>>('rk_quic_server_poll')
          .asFunction<PollDart>(),
      sessionSend = _library
          .lookup<ffi.NativeFunction<_SendNative>>('rk_quic_session_send')
          .asFunction<SendDart>(),
      streamSend = _library
          .lookup<ffi.NativeFunction<_StreamSendNative>>('rk_quic_stream_send')
          .asFunction<StreamSendDart>(),
      streamClose = _library
          .lookup<ffi.NativeFunction<_StreamCloseNative>>(
            'rk_quic_stream_close',
          )
          .asFunction<StreamCloseDart>();

  // ignore: unused_field
  final ffi.DynamicLibrary _library;

  final int Function() abiVersion;
  final ffi.Pointer<Utf8> Function() version;
  final StringFreeDart stringFree;
  final ffi.Pointer<Utf8> Function() lastErrorRaw;
  final ServerStartDart serverStart;
  final ServerStopDart serverStop;
  final LocalPortDart serverLocalPort;
  final PollDart serverPoll;
  final SendDart sessionSend;
  final StreamSendDart streamSend;
  final StreamCloseDart streamClose;

  /// Reads and clears the last error, freeing the buffer the library allocated.
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

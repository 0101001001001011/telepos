/// One open key store, held by the isolate that opened it.
library;

import 'dart:ffi';

import 'package:ffi/ffi.dart';

import '../envelope.dart';
import '../errors.dart';
import 'bindings.g.dart';
import 'library.dart';

/// A native engine handle.
///
/// Freed by [close], deterministically, at the moment the caller says so. The
/// [NativeFinalizer] attached here is a net for a caller who forgot, not the
/// mechanism: a finalizer is guaranteed to run eventually but never at a
/// moment you can name, and "eventually" is not a property a key store can be
/// built on.
final class NativeEngine implements Finalizable {
  NativeEngine._(this._library, this._handle) {
    _finalizer = NativeFinalizer(
      _library.dylib.lookup<NativeFinalizerFunction>('rk_pki_engine_close'),
    );
    _finalizer.attach(this, _handle.cast<Void>(), detach: this);
  }

  final RkPkiLibrary _library;
  final Pointer<RkPkiEngine> _handle;
  late final NativeFinalizer _finalizer;
  bool _closed = false;

  /// Opens a store. Returns a failure rather than throwing.
  static PkiResult<NativeEngine> open(RkPkiLibrary library, String configJson) {
    final configPtr = configJson.toNativeUtf8();
    final errorSlot = calloc<Pointer<Char>>();
    try {
      final handle = library.bindings.rk_pki_engine_open(
        configPtr.cast<Char>(),
        errorSlot,
      );
      if (handle == nullptr) {
        final reported = errorSlot.value;
        if (reported == nullptr) {
          return const PkiErr<NativeEngine>(
            NativeFault('the library refused to open without saying why'),
          );
        }
        final envelope = decodeEnvelope(library.takeString(reported));
        return PkiErr<NativeEngine>(
          envelope.errorOrNull ??
              const NativeFault('the library refused to open'),
        );
      }
      return PkiOk<NativeEngine>(NativeEngine._(library, handle));
    } catch (e) {
      return PkiErr<NativeEngine>(
        NativeUnavailable('cannot open the rk_pki key store: $e'),
      );
    } finally {
      malloc.free(configPtr);
      calloc.free(errorSlot);
    }
  }

  /// Runs one named operation and returns the raw envelope.
  String call(String op, String requestJson) {
    if (_closed) {
      return '{"ok":false,"error":{"kind":"nativeFault",'
          '"detail":"the engine is closed"}}';
    }
    final opPtr = op.toNativeUtf8();
    final reqPtr = requestJson.toNativeUtf8();
    try {
      return _library.takeString(
        _library.bindings.rk_pki_call(
          _handle,
          opPtr.cast<Char>(),
          reqPtr.cast<Char>(),
        ),
      );
    } finally {
      malloc.free(opPtr);
      malloc.free(reqPtr);
    }
  }

  /// Releases the handle now. Idempotent: closing twice is a no-op rather
  /// than a double free, because a caller that cannot tell is a caller that
  /// will do it twice.
  void close() {
    if (_closed) return;
    _closed = true;
    _finalizer.detach(this);
    _library.bindings.rk_pki_engine_close(_handle);
  }
}

/// Decoding the one shape everything comes back in.
///
/// This file has no dependency on `dart:ffi`, which is deliberate: the
/// agreement between the two sides is testable without the native library
/// present, and most of what can go wrong in it is a decoding mistake rather
/// than a cryptographic one.
library;

import 'dart:convert';

import 'errors.dart';

/// Reads `{"ok":true,"value":{...}}` or `{"ok":false,"error":{...}}`.
///
/// Anything else — malformed JSON, a missing `ok`, a value of the wrong shape
/// — becomes a failure, never an exception and never a silent success. A
/// binding that guessed here would be guessing about trust.
PkiResult<Map<String, Object?>> decodeEnvelope(String text) {
  final Object? decoded;
  try {
    decoded = jsonDecode(text);
  } on FormatException catch (e) {
    return PkiErr<Map<String, Object?>>(
      NativeFault('the library returned text that is not JSON: ${e.message}'),
    );
  }
  if (decoded is! Map<String, Object?>) {
    return const PkiErr<Map<String, Object?>>(
      NativeFault('the library returned JSON that is not an envelope'),
    );
  }
  final ok = decoded['ok'];
  if (ok == true) {
    final value = decoded['value'];
    if (value is Map<String, Object?>) {
      return PkiOk<Map<String, Object?>>(value);
    }
    return const PkiErr<Map<String, Object?>>(
      NativeFault('a successful envelope carried no value object'),
    );
  }
  if (ok == false) {
    final error = decoded['error'];
    if (error is Map<String, Object?>) {
      return PkiErr<Map<String, Object?>>(PkiError.fromJson(error));
    }
    return const PkiErr<Map<String, Object?>>(
      NativeFault('a failed envelope carried no error object'),
    );
  }
  return const PkiErr<Map<String, Object?>>(
    NativeFault("an envelope without a boolean 'ok'"),
  );
}

/// Decodes an envelope and then reshapes its value, keeping the failure path
/// intact. A `transform` that throws is caught: a shape we did not expect is
/// a failure like any other.
PkiResult<T> decodeEnvelopeAs<T>(
  String text,
  T Function(Map<String, Object?> value) transform,
) {
  final envelope = decodeEnvelope(text);
  return switch (envelope) {
    PkiOk<Map<String, Object?>>(:final value) => _guard(() => transform(value)),
    PkiErr<Map<String, Object?>>(:final error) => PkiErr<T>(error),
  };
}

PkiResult<T> _guard<T>(T Function() body) {
  try {
    return PkiOk<T>(body());
  } catch (e) {
    return PkiErr<T>(
      NativeFault('the library returned a value of an unexpected shape: $e'),
    );
  }
}

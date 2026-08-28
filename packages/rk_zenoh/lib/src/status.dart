/// Failure as a value, and enums by name.
///
/// Nothing in this file touches `dart:ffi`, so it can be tested anywhere.
library;

/// Why a call into the native library failed.
///
/// The native side returns a status that is only ever "zero or not zero", and
/// names the kind separately. This enum is parsed from that **name**: adding a
/// case upstream can therefore never silently change the meaning of a case
/// here, which is what an index-based crossing would allow (И147).
enum RkzErrorKind {
  /// A null pointer was passed where a handle was required.
  nullArgument('null_argument'),

  /// A string argument was not valid UTF-8.
  invalidUtf8('invalid_utf8'),

  /// A configuration document was rejected.
  invalidConfig('invalid_config'),

  /// A key expression was rejected by Zenoh's grammar.
  invalidKeyExpression('invalid_key_expression'),

  /// An enum name matched no known case on the other side.
  unknownEnumName('unknown_enum_name'),

  /// The session could not be opened.
  sessionOpenFailed('session_open_failed'),

  /// The session is closed.
  sessionClosed('session_closed'),

  /// A declaration failed.
  declarationFailed('declaration_failed'),

  /// A put, delete or reply did not reach the network stack.
  publishFailed('publish_failed'),

  /// A receive ran out of time. Ordinary; callers usually loop.
  timeout('timeout'),

  /// The source is gone and will produce nothing further.
  disconnected('disconnected'),

  /// A buffer offered to the native side was too small; nothing was written.
  bufferTooSmall('buffer_too_small'),

  /// The native side panicked. It was caught there, not propagated (И144).
  panic('panic'),

  /// Anything the native side did not model more precisely.
  backend('backend'),

  /// A name this build of the binding does not know.
  ///
  /// Present so that a newer native library paired with an older binding
  /// degrades to "something went wrong, here is its name" instead of throwing
  /// while handling an error.
  unrecognised('unrecognised');

  const RkzErrorKind(this.wireName);

  /// The name as it crosses the boundary.
  final String wireName;

  /// Parse a name coming back from the native side.
  ///
  /// Never throws: this runs on the failure path, and a failure while
  /// reporting a failure loses the original.
  static RkzErrorKind parse(String name) {
    for (final kind in RkzErrorKind.values) {
      if (kind.wireName == name) return kind;
    }
    return RkzErrorKind.unrecognised;
  }
}

/// A failure returned by the native library.
///
/// It is an exception on the Dart side because Dart callers expect one; what
/// И144 forbids is an exception unwinding out of the *native* stack, and it
/// never does — the boundary catches panics and returns a status.
class RkzException implements Exception {
  RkzException(this.kind, this.message, {this.wireName});

  /// What kind of failure this was.
  final RkzErrorKind kind;

  /// The native side's detail, verbatim.
  final String message;

  /// The name as received, kept when it did not match a known kind.
  final String? wireName;

  /// Whether a caller should simply try again.
  bool get isTransient =>
      kind == RkzErrorKind.timeout || kind == RkzErrorKind.disconnected;

  @override
  String toString() => 'RkzException(${wireName ?? kind.wireName}): $message';
}

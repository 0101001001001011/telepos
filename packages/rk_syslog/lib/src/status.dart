/// Every way a call into the native sink can fail.
///
/// The native side returns an `int32`. This enum maps that number back
/// through the **name** the library reports for it, never through a position
/// in this list (И147): [RkSyslogStatus.fromWire] asks the library for the
/// name that goes with a code and matches on that, so a version of the
/// library that added a code returns [RkSyslogStatus.unrecognised] instead of
/// something plausible and wrong.
library;

/// A result code from the native sink.
enum RkSyslogStatus {
  /// The call did what it said.
  ok('ok'),

  /// A pointer argument that must not be null was null.
  nullArgument('nullArgument'),

  /// A string argument was not valid UTF-8.
  invalidUtf8('invalidUtf8'),

  /// A configuration key the library does not know.
  unknownConfigKey('unknownConfigKey'),

  /// A configuration key was given a value it cannot take.
  invalidConfigValue('invalidConfigValue'),

  /// A configuration key that has no default was not set.
  missingConfigKey('missingConfigKey'),

  /// A severity name outside the eight in RFC 5424.
  unknownSeverity('unknownSeverity'),

  /// A facility name outside the twenty-four in RFC 5424.
  unknownFacility('unknownFacility'),

  /// A header field breaks RFC 5424 — wrong length, or a byte outside the
  /// printable ASCII the standard allows.
  invalidHeaderField('invalidHeaderField'),

  /// A structured-data name or value breaks RFC 5424.
  invalidStructuredData('invalidStructuredData'),

  /// The record itself cannot be framed.
  invalidMessage('invalidMessage'),

  /// The hand-off queue is full under the `reject` rule. **The record was not
  /// accepted** — the caller still has it and must decide.
  queueFull('queueFull'),

  /// The spool is full under the `reject` rule. **The record was not
  /// accepted.**
  spoolFull('spoolFull'),

  /// The spool could not be read or written.
  spoolIo('spoolIo'),

  /// The collector could not be reached. Never comes back from a submit —
  /// submitting does not touch the network.
  transportIo('transportIo'),

  /// The TLS settings could not be turned into a usable configuration.
  tlsConfig('tlsConfig'),

  /// A bounded wait expired.
  timeout('timeout'),

  /// The sink is closed.
  closed('closed'),

  /// A panic was caught at the boundary. A defect in the native library,
  /// reported rather than allowed to take the process with it (И144).
  panicked('panicked'),

  /// A handle was null or not one the library handed out.
  invalidHandle('invalidHandle'),

  /// A counter name the library does not publish.
  unknownStat('unknownStat'),

  /// The library reported a status this binding has no name for — it is
  /// newer than this package. Deliberately its own case: guessing would be
  /// worse than saying so.
  unrecognised('unrecognised');

  const RkSyslogStatus(this.wireName);

  /// The name the native library uses for this status.
  final String wireName;

  /// Looks a status up by the name the library reported.
  static RkSyslogStatus fromName(String? name) {
    if (name == null) return RkSyslogStatus.unrecognised;
    for (final status in RkSyslogStatus.values) {
      if (status.wireName == name) return status;
    }
    return RkSyslogStatus.unrecognised;
  }

  /// Whether this status means the call succeeded.
  bool get isOk => this == RkSyslogStatus.ok;
}

/// The outcome of a call into the native sink.
///
/// A result, not an exception. И144: a failure in the native library comes
/// back as a value, and turning that value straight into a `throw` at the
/// binding would put the failure back into a stack the caller did not write.
/// Callers that would rather have an exception can ask for one with
/// [RkSyslogResult.valueOrThrow], at a place they chose.
sealed class RkSyslogResult<T> {
  const RkSyslogResult();

  /// Whether the call succeeded.
  bool get isOk => this is RkSyslogOk<T>;

  /// The value, or `null` if the call failed.
  T? get valueOrNull => switch (this) {
    RkSyslogOk<T>(:final value) => value,
    RkSyslogFailure<T>() => null,
  };

  /// The value, or an exception at a point in the code the caller picked.
  T valueOrThrow() => switch (this) {
    RkSyslogOk<T>(:final value) => value,
    RkSyslogFailure<T>(:final status, :final detail) => throw RkSyslogException(
      status,
      detail,
    ),
  };
}

/// A call that did what it said.
final class RkSyslogOk<T> extends RkSyslogResult<T> {
  const RkSyslogOk(this.value);

  final T value;

  @override
  String toString() => 'RkSyslogOk($value)';
}

/// A call that failed, with the reason.
final class RkSyslogFailure<T> extends RkSyslogResult<T> {
  const RkSyslogFailure(this.status, this.detail);

  /// What went wrong.
  final RkSyslogStatus status;

  /// A sentence naming the value that was wrong, from the native library.
  /// Empty when the library had nothing to add.
  final String detail;

  /// Re-labels a failure so it can be returned from a call of another type,
  /// without inventing a value.
  RkSyslogFailure<U> cast<U>() => RkSyslogFailure<U>(status, detail);

  @override
  String toString() =>
      'RkSyslogFailure(${status.wireName}${detail.isEmpty ? '' : ': $detail'})';
}

/// Thrown only by [RkSyslogResult.valueOrThrow], never by the binding itself.
class RkSyslogException implements Exception {
  const RkSyslogException(this.status, this.detail);

  final RkSyslogStatus status;
  final String detail;

  @override
  String toString() =>
      'RkSyslogException(${status.wireName}${detail.isEmpty ? '' : ': $detail'})';
}

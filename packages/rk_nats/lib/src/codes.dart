/// Outcome codes, spelled the way they cross the boundary.
///
/// The native library sends a name, never a number (I147). That is what makes
/// it safe for a case to be added in the middle of the list: a name means the
/// same thing forever, while an index means whatever position it happens to
/// occupy in the build that wrote it.
library;

/// What a call came back as.
enum RkNatsCode {
  /// The call did what it said.
  ok,

  /// The request was malformed, or named a case this build does not know.
  invalidRequest,

  /// The handle was never opened, or has been closed.
  handleClosed,

  /// The connection could not be established.
  connectFailed,

  /// The call did not finish inside its deadline.
  timeout,

  /// Durability was asked for and nobody proved it. Fail closed.
  durabilityUnproven,

  /// The server's ack means less than the policy demands.
  durabilityWeakerThanRequested,

  /// The server's fsync window is longer than the one the caller named.
  fsyncLagTooLong,

  /// The stream as configured could not satisfy the policy, so it was not
  /// created.
  streamRefusedWeakerThanPolicy,

  /// The server dropped the persistence mode that was asked for.
  persistModeNotHonoured,

  /// Evidence about the server could not be read.
  durabilityProbeFailed,

  /// Publishing failed for a reason the server reported.
  publishFailed,

  /// A stream operation failed for a reason the server reported.
  streamFailed,

  /// Consuming failed for a reason the server reported.
  consumeFailed,

  /// Acknowledging failed.
  ackFailed,

  /// The native side panicked and the unwind was caught at the boundary. The
  /// process is alive; the call is not.
  panic,

  /// A name this build of the binding has never heard of, which means the
  /// native library is newer than the binding. Reported rather than mapped to
  /// something plausible, because a guess here is a guess about whether money
  /// was written.
  unrecognised,
}

/// Reads a code from the name the native library sent.
///
/// An unknown name becomes [RkNatsCode.unrecognised]. It never becomes
/// [RkNatsCode.ok], and it never throws: a binding that crashes on an
/// unfamiliar code is a binding that cannot be upgraded a version behind its
/// library.
RkNatsCode rkNatsCodeFromName(Object? name) {
  if (name is! String) return RkNatsCode.unrecognised;
  for (final code in RkNatsCode.values) {
    if (code.name == name) return code;
  }
  return RkNatsCode.unrecognised;
}

/// Every code name this binding claims to know, for checking against the
/// native library's own list rather than against anyone's memory.
List<String> get rkNatsKnownCodeNames => RkNatsCode.values
    .where((c) => c != RkNatsCode.unrecognised)
    .map((c) => c.name)
    .toList(growable: false);

/// Failures are values, never exceptions out of a foreign stack.
///
/// The native side returns `{"ok":false,"error":{"kind":"...", ...}}`, and the
/// kind is a **name**. This file is the Dart half of that agreement: a sealed
/// type per name, and an explicit case for a name we have not heard of, so a
/// newer library talking to an older binding degrades into "unknown" rather
/// than into a crash or, worse, into "trusted".
library;

/// The base of every failure `rk_pki` can report.
sealed class PkiError {
  const PkiError();

  /// The name this failure has on the wire and in a log.
  String get kind;

  /// Whether the caller must treat this exactly as it treats an absent
  /// network: keep selling, queue outgoing work, retry later.
  ///
  /// This is the whole offline rule in one predicate. An expired or missing
  /// certificate and an unreachable authority are conditions of the world; a
  /// rejected certificate, a spent invite and a broken library are not.
  bool get degradesLikeOffline => false;

  /// Whether a session that needs this certificate can still be started.
  bool get blocksNewSessions => true;

  /// Whether a session that is already established must be torn down.
  ///
  /// Wall-clock expiry never does: TLS checks a certificate when a session is
  /// established, not continuously, and tearing down mid-work would stop work
  /// that the architecture says must not stop. Revocation does.
  bool get tearsDownOpenSessions => false;

  /// Whether selling stops. Nothing in this library ever answers true, and
  /// the getter exists so that the rule is written down where it is used
  /// rather than remembered.
  bool get stopsSelling => false;

  /// Whether the owner should be told, as a security event rather than a
  /// passing condition (section 16).
  bool get isSecurityEvent => false;

  /// Human-readable detail, where the native side gave one.
  String? get detail => null;

  @override
  String toString() => detail == null ? kind : '$kind: $detail';

  /// Reads a failure out of the envelope's `error` object.
  static PkiError fromJson(Map<String, Object?> json) {
    final kind = json['kind'];
    final detail = json['detail'] as String?;
    return switch (kind) {
      'inviteInvalid' => const InviteInvalid(),
      'inviteExpired' => InviteExpired(_int(json['expiredAt'])),
      'caUnreachable' => CaUnreachable(detail ?? ''),
      'caNotHere' => CaNotHere(detail ?? ''),
      'certificateNotFound' => const CertificateNotFound(),
      'certificateExpired' => CertificateExpired(
        _int(json['expiredAt']),
        json['info'] as Map<String, Object?>?,
      ),
      'certificateRejected' => CertificateRejected(detail ?? ''),
      'trustAnchorMissing' => const TrustAnchorMissing(),
      'keystoreUnavailable' => KeystoreUnavailable(detail ?? ''),
      'signatureInvalid' => const SignatureInvalid(),
      'badRequest' => BadRequest(detail ?? ''),
      'nativeFault' => NativeFault(detail ?? ''),
      // Produced on this side of the boundary, and round-tripped through an
      // envelope when it is raised inside a worker isolate.
      'nativeUnavailable' => NativeUnavailable(detail ?? ''),
      _ => UnknownPkiError(kind is String ? kind : 'missing', detail),
    };
  }

  static int _int(Object? value) => value is int
      ? value
      : value is num
      ? value.toInt()
      : 0;
}

/// No such invite, or it has already been redeemed.
final class InviteInvalid extends PkiError {
  const InviteInvalid();
  @override
  String get kind => 'inviteInvalid';
}

/// The invite existed but its window had closed. It is spent either way.
final class InviteExpired extends PkiError {
  const InviteExpired(this.expiredAtUnix);
  final int expiredAtUnix;
  @override
  String get kind => 'inviteExpired';
  @override
  String get detail => 'expired at $expiredAtUnix';
}

/// The authority could not be reached.
final class CaUnreachable extends PkiError {
  const CaUnreachable(this.detail);
  @override
  final String detail;
  @override
  String get kind => 'caUnreachable';
  @override
  bool get degradesLikeOffline => true;
}

/// This machine does not hold the installation's authority key.
final class CaNotHere extends PkiError {
  const CaNotHere(this.detail);
  @override
  final String detail;
  @override
  String get kind => 'caNotHere';
}

/// Nothing is stored for that profile yet.
final class CertificateNotFound extends PkiError {
  const CertificateNotFound();
  @override
  String get kind => 'certificateNotFound';
  @override
  bool get degradesLikeOffline => true;
}

/// The certificate is past its `notAfter`. An honest answer, not a fatal one.
final class CertificateExpired extends PkiError {
  const CertificateExpired(this.expiredAtUnix, [this.info]);

  final int expiredAtUnix;

  /// The description of the expired certificate, when the native side had it
  /// to give — the health screen needs the facts, not just the verdict.
  final Map<String, Object?>? info;

  DateTime get expiredAt =>
      DateTime.fromMillisecondsSinceEpoch(expiredAtUnix * 1000, isUtc: true);

  @override
  String get kind => 'certificateExpired';
  @override
  String get detail => 'expired at ${expiredAt.toIso8601String()}';

  /// The point of the whole design: an expired certificate is a network-shaped
  /// condition, not a fault.
  @override
  bool get degradesLikeOffline => true;

  /// And it never tears down work already in flight.
  @override
  bool get tearsDownOpenSessions => false;

  /// Expiry while the network is reachable means the clock drifted, the
  /// authority was unreachable longer than the rotation window, or rotation
  /// is broken. The owner has to hear about at least one of those.
  @override
  bool get isSecurityEvent => true;
}

/// We will not trust this certificate: unknown issuer, broken signature,
/// wrong subject, revoked.
final class CertificateRejected extends PkiError {
  const CertificateRejected(this.detail);
  @override
  final String detail;
  @override
  String get kind => 'certificateRejected';
  @override
  bool get isSecurityEvent => true;

  /// A rejected certificate that we revoked ourselves must also close what is
  /// already open — that is what "immediate effect" means in section 12.
  @override
  bool get tearsDownOpenSessions => detail.contains('revoked');
}

/// No authority root is installed, so nothing can be judged.
final class TrustAnchorMissing extends PkiError {
  const TrustAnchorMissing();
  @override
  String get kind => 'trustAnchorMissing';
  @override
  bool get degradesLikeOffline => true;
}

/// The key store could not be read or written.
final class KeystoreUnavailable extends PkiError {
  const KeystoreUnavailable(this.detail);
  @override
  final String detail;
  @override
  String get kind => 'keystoreUnavailable';
  @override
  bool get isSecurityEvent => true;
}

/// A signature did not verify.
final class SignatureInvalid extends PkiError {
  const SignatureInvalid();
  @override
  String get kind => 'signatureInvalid';
  @override
  bool get isSecurityEvent => true;
}

/// The request was malformed — a name that is not an operation, a field of
/// the wrong shape.
final class BadRequest extends PkiError {
  const BadRequest(this.detail);
  @override
  final String detail;
  @override
  String get kind => 'badRequest';
}

/// A panic caught at the boundary, or a broken invariant inside the library.
final class NativeFault extends PkiError {
  const NativeFault(this.detail);
  @override
  final String detail;
  @override
  String get kind => 'nativeFault';
  @override
  bool get isSecurityEvent => true;
}

/// The native library is not present, or its ABI is not the one this binding
/// speaks. A deployment fault, reported rather than thrown, and still not a
/// reason to stop selling.
final class NativeUnavailable extends PkiError {
  const NativeUnavailable(this.detail);
  @override
  final String detail;
  @override
  String get kind => 'nativeUnavailable';
  @override
  bool get isSecurityEvent => true;
}

/// A failure name this binding has not heard of — a newer library against an
/// older binding. Treated as a refusal, never as a success.
final class UnknownPkiError extends PkiError {
  const UnknownPkiError(this.reportedKind, this.detail);
  final String reportedKind;
  @override
  final String? detail;
  @override
  String get kind => 'unknown($reportedKind)';
}

/// The outcome of an operation: a value or a failure, never a thrown thing.
sealed class PkiResult<T> {
  const PkiResult();

  bool get isOk => this is PkiOk<T>;

  /// The value, or `null` if this is a failure.
  T? get valueOrNull => switch (this) {
    PkiOk<T>(:final value) => value,
    PkiErr<T>() => null,
  };

  /// The failure, or `null` if this succeeded.
  PkiError? get errorOrNull => switch (this) {
    PkiOk<T>() => null,
    PkiErr<T>(:final error) => error,
  };

  R fold<R>(R Function(T value) onOk, R Function(PkiError error) onError) =>
      switch (this) {
        PkiOk<T>(:final value) => onOk(value),
        PkiErr<T>(:final error) => onError(error),
      };

  PkiResult<R> map<R>(R Function(T value) transform) => switch (this) {
    PkiOk<T>(:final value) => PkiOk<R>(transform(value)),
    PkiErr<T>(:final error) => PkiErr<R>(error),
  };
}

final class PkiOk<T> extends PkiResult<T> {
  const PkiOk(this.value);
  final T value;
  @override
  String toString() => 'PkiOk($value)';
}

final class PkiErr<T> extends PkiResult<T> {
  const PkiErr(this.error);
  final PkiError error;
  @override
  String toString() => 'PkiErr($error)';
}

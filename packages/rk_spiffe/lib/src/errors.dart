/// Failures are values here, not exceptions.
///
/// Everything this package does is *judging a document somebody else wrote* —
/// a name off a wire, a certificate off a peer, a token out of a header. A
/// malformed one is an ordinary Tuesday, not an exceptional condition, and the
/// call site that has to decide "trust or refuse" should be forced to look at
/// the answer rather than be allowed to let a throw travel past it.
///
/// Every failure carries a **name**, never a number: `kind` for the family and
/// `rule` for the exact clause that was broken. A name survives a log file, a
/// version bump and an inserted enum case; an index survives none of them.
library;

/// The base of every failure `rk_spiffe` can report.
sealed class SpiffeError {
  const SpiffeError();

  /// The family name, as it appears in a log.
  String get kind;

  /// What exactly was wrong, in words, for a human reading that log.
  String get detail;

  @override
  String toString() => '$kind: $detail';
}

/// The clauses of the SPIFFE ID grammar, one per way a name can be wrong.
///
/// Compared and logged **by name**. The order of the cases carries no meaning
/// and inserting one in the middle must stay harmless.
enum SpiffeIdRule {
  /// Not `spiffe://`. The scheme is lowercase and is not negotiable: a URI
  /// scheme is case-insensitive in RFC 3986, but SPIFFE fixes one spelling so
  /// that two implementations cannot disagree about whether two IDs are equal.
  scheme,

  /// `spiffe:///path` — there is no trust domain.
  trustDomainEmpty,

  /// The trust domain holds something outside `a-z`, `0-9`, `.`, `-`, `_`.
  /// Uppercase lands here, and that is the point: `Example.org` is not a
  /// different spelling of `example.org`, it is not a trust domain at all.
  trustDomainCharacters,

  /// The trust domain is longer than 255 bytes.
  trustDomainLength,

  /// The authority carried userinfo or a port — `spiffe://user@x` or
  /// `spiffe://x:443`. A SPIFFE ID names a subject, not an endpoint.
  authorityNotBare,

  /// Two slashes in a row, or a slash at the end, so some segment is empty.
  pathSegmentEmpty,

  /// A path segment holds something outside `a-z`, `A-Z`, `0-9`, `.`, `-`,
  /// `_`. Note that paths, unlike trust domains, are case-sensitive.
  pathSegmentCharacters,

  /// A segment is `.` or `..`. Relative traversal in an identity is a way to
  /// write two different-looking IDs that some code will treat as one.
  pathDotSegment,

  /// The ID carried a query or a fragment.
  queryOrFragment,

  /// The whole ID is longer than 2048 bytes.
  totalLength,
}

/// A string that is not a SPIFFE ID, and the clause that says so.
final class MalformedSpiffeId extends SpiffeError {
  const MalformedSpiffeId(this.rule, this.detail);

  /// The clause that was broken.
  final SpiffeIdRule rule;

  @override
  final String detail;

  @override
  String get kind => 'malformedSpiffeId';

  @override
  String toString() => '$kind(${rule.name}): $detail';
}

/// A certificate that could not be read at all: the bytes are not DER, or the
/// DER is not an X.509 certificate.
///
/// This is a statement about the *encoding*, never about trust. A certificate
/// that parses cleanly is still a certificate nobody has verified.
final class MalformedCertificate extends SpiffeError {
  const MalformedCertificate(this.detail);

  @override
  final String detail;

  @override
  String get kind => 'malformedCertificate';
}

/// The clauses of the X.509-SVID document shape.
enum X509SvidRule {
  /// No URI SAN at all. A certificate can be a perfectly good certificate and
  /// still not be an SVID.
  uriSanMissing,

  /// More than one URI SAN. The SPIFFE X509-SVID document says *exactly* one,
  /// and the reason is not tidiness: with two, two readers can pick different
  /// identities out of the same certificate.
  uriSanNotUnique,

  /// There is one URI SAN and it is not a well-formed SPIFFE ID.
  uriSanNotSpiffeId,

  /// The SPIFFE ID has no path, so it names the trust domain itself. That is
  /// a valid SPIFFE ID and not a valid identity for a leaf.
  idHasNoPath,

  /// `basicConstraints` says CA:TRUE. A signing certificate is part of a
  /// bundle, not a workload's own document.
  isCertificateAuthority,

  /// The `keyUsage` extension is absent. The SVID document requires it.
  keyUsageMissing,

  /// `keyUsage` does not include `digitalSignature`, so the key cannot be
  /// used for the handshake the SVID exists for.
  keyUsageWithoutDigitalSignature,

  /// `keyUsage` includes `keyCertSign` or `cRLSign`. A leaf that can sign
  /// certificates is a CA wearing a leaf's clothes.
  keyUsageSigns,
}

/// A certificate that parsed, and is not an X.509-SVID.
final class NotAnX509Svid extends SpiffeError {
  const NotAnX509Svid(this.rule, this.detail);

  /// The clause that was broken.
  final X509SvidRule rule;

  @override
  final String detail;

  @override
  String get kind => 'notAnX509Svid';

  @override
  String toString() => '$kind(${rule.name}): $detail';
}

/// A token that is not a JWS at all: wrong number of parts, base64url that is
/// not base64url, JSON that is not an object.
final class MalformedJwt extends SpiffeError {
  const MalformedJwt(this.detail);

  @override
  final String detail;

  @override
  String get kind => 'malformedJwt';
}

/// The clauses of the JWT-SVID document shape.
enum JwtSvidRule {
  /// The JOSE header has no `alg`.
  algorithmMissing,

  /// `alg` is `none`. An unsigned token that claims an identity is the oldest
  /// JWT hole there is, and it is refused before anything else looks at it.
  algorithmNone,

  /// `typ` is present and is neither `JWT` nor `JOSE`.
  typeInvalid,

  /// No `sub` claim.
  subjectMissing,

  /// `sub` is present and is not a well-formed SPIFFE ID.
  subjectNotSpiffeId,

  /// No `aud` claim. A JWT-SVID without an audience is a bearer token that
  /// any recipient may replay at any other recipient.
  audienceMissing,

  /// `aud` is an empty array, or an array holding something that is not a
  /// string.
  audienceInvalid,

  /// No `exp` claim. Short life is the whole point of an SVID.
  expiryMissing,

  /// `exp`, `iat` or `nbf` is present and is not a number of seconds.
  timeClaimInvalid,
}

/// A token that is a JWS, and is not a JWT-SVID.
final class NotAJwtSvid extends SpiffeError {
  const NotAJwtSvid(this.rule, this.detail);

  /// The clause that was broken.
  final JwtSvidRule rule;

  @override
  final String detail;

  @override
  String get kind => 'notAJwtSvid';

  @override
  String toString() => '$kind(${rule.name}): $detail';
}

/// The outcome of anything this package is asked to read: a value or a
/// failure, never a thrown thing.
sealed class SpiffeResult<T> {
  const SpiffeResult();

  /// Whether this is a value.
  bool get isOk => this is SpiffeOk<T>;

  /// The value, or `null` if this is a failure.
  T? get valueOrNull => switch (this) {
    SpiffeOk<T>(:final value) => value,
    SpiffeErr<T>() => null,
  };

  /// The failure, or `null` if this succeeded.
  SpiffeError? get errorOrNull => switch (this) {
    SpiffeOk<T>() => null,
    SpiffeErr<T>(:final error) => error,
  };

  /// Collapse both cases into one value.
  R fold<R>(R Function(T value) onOk, R Function(SpiffeError error) onError) =>
      switch (this) {
        SpiffeOk<T>(:final value) => onOk(value),
        SpiffeErr<T>(:final error) => onError(error),
      };

  /// Transform the value, carrying a failure through untouched.
  SpiffeResult<R> map<R>(R Function(T value) transform) => switch (this) {
    SpiffeOk<T>(:final value) => SpiffeOk<R>(transform(value)),
    SpiffeErr<T>(:final error) => SpiffeErr<R>(error),
  };
}

/// A value.
final class SpiffeOk<T> extends SpiffeResult<T> {
  const SpiffeOk(this.value);

  /// The value.
  final T value;

  @override
  String toString() => 'SpiffeOk($value)';
}

/// A failure.
final class SpiffeErr<T> extends SpiffeResult<T> {
  const SpiffeErr(this.error);

  /// The failure.
  final SpiffeError error;

  @override
  String toString() => 'SpiffeErr($error)';
}

/// Re-types a failure without re-boxing the reason, for the many places that
/// parse a SPIFFE ID on the way to building something larger and must carry
/// the original clause outward unchanged.
SpiffeErr<T> castErr<T>(SpiffeError error) => SpiffeErr<T>(error);

/// `spiffe://` names: the trust domain and the path under it.
///
/// The grammar is deliberately narrower than RFC 3986. It is not a URI parser
/// with a scheme check bolted on: percent-encoding, uppercase trust domains,
/// dot segments, ports and userinfo are all *refused* rather than normalised,
/// because normalising means two spellings of one identity exist and some
/// reader somewhere will only know one of them.
library;

import 'errors.dart';

/// The longest a whole SPIFFE ID may be, in bytes.
const int maxSpiffeIdLength = 2048;

/// The longest a trust domain name may be, in bytes.
const int maxTrustDomainLength = 255;

const String _scheme = 'spiffe://';

/// The name of a trust domain: everything an installation is willing to
/// believe about itself.
///
/// Lowercase, and only `a-z`, `0-9`, `.`, `-`, `_`. It looks like a hostname
/// and is not one — nothing resolves it, and nothing may assume it does.
final class TrustDomain {
  const TrustDomain._(this.name);

  /// The bare name, with no scheme and no trailing slash.
  final String name;

  /// Reads a trust domain from either spelling: the bare `example.org`, or a
  /// full `spiffe://example.org` (with or without a path, which is ignored —
  /// every ID belongs to exactly one trust domain).
  static SpiffeResult<TrustDomain> parse(String value) {
    if (value.startsWith(_scheme)) {
      final id = SpiffeId.parse(value);
      return id.map((id) => id.trustDomain);
    }
    return _fromName(value);
  }

  static SpiffeResult<TrustDomain> _fromName(String name) {
    if (name.isEmpty) {
      return const SpiffeErr(
        MalformedSpiffeId(SpiffeIdRule.trustDomainEmpty, 'no trust domain'),
      );
    }
    if (name.length > maxTrustDomainLength) {
      return SpiffeErr(
        MalformedSpiffeId(
          SpiffeIdRule.trustDomainLength,
          'trust domain is ${name.length} bytes, the limit is '
          '$maxTrustDomainLength',
        ),
      );
    }
    for (var i = 0; i < name.length; i++) {
      if (!_isTrustDomainChar(name.codeUnitAt(i))) {
        return SpiffeErr(
          MalformedSpiffeId(
            SpiffeIdRule.trustDomainCharacters,
            'trust domain "$name" holds ${_describe(name.codeUnitAt(i))} at '
            'index $i; only a-z, 0-9, dot, dash and underscore are allowed',
          ),
        );
      }
    }
    return SpiffeOk(TrustDomain._(name));
  }

  /// The SPIFFE ID that names the trust domain itself: `spiffe://<name>`,
  /// with no path. Used for federation, never as a workload's identity.
  SpiffeId get id => SpiffeId._(this, '');

  @override
  String toString() => name;

  @override
  bool operator ==(Object other) => other is TrustDomain && other.name == name;

  @override
  int get hashCode => name.hashCode;
}

/// A SPIFFE ID: a trust domain and a path within it.
///
/// Two IDs are equal when their trust domains and their paths are equal, byte
/// for byte. The trust domain is lowercase by grammar, so that is a case
/// insensitive comparison in effect; the path is **not**, and
/// `spiffe://x/Till` and `spiffe://x/till` are two different subjects.
final class SpiffeId {
  const SpiffeId._(this.trustDomain, this.path);

  /// The trust domain this ID belongs to.
  final TrustDomain trustDomain;

  /// The path, beginning with `/`, or the empty string for a trust domain ID.
  final String path;

  /// Reads a SPIFFE ID, or says which clause of the grammar was broken.
  static SpiffeResult<SpiffeId> parse(String value) {
    if (value.length > maxSpiffeIdLength) {
      return SpiffeErr(
        MalformedSpiffeId(
          SpiffeIdRule.totalLength,
          'the id is ${value.length} bytes, the limit is $maxSpiffeIdLength',
        ),
      );
    }
    if (!value.startsWith(_scheme)) {
      return SpiffeErr(
        MalformedSpiffeId(
          SpiffeIdRule.scheme,
          'does not begin with "$_scheme" (the scheme is lowercase): '
          '"${_clip(value)}"',
        ),
      );
    }
    final rest = value.substring(_scheme.length);

    final query = rest.indexOf('?');
    final fragment = rest.indexOf('#');
    if (query >= 0 || fragment >= 0) {
      return SpiffeErr(
        MalformedSpiffeId(
          SpiffeIdRule.queryOrFragment,
          'a SPIFFE ID carries neither a query nor a fragment: '
          '"${_clip(value)}"',
        ),
      );
    }

    final slash = rest.indexOf('/');
    final authority = slash < 0 ? rest : rest.substring(0, slash);
    final path = slash < 0 ? '' : rest.substring(slash);

    if (authority.contains('@') || authority.contains(':')) {
      return SpiffeErr(
        MalformedSpiffeId(
          SpiffeIdRule.authorityNotBare,
          'the authority "$authority" carries userinfo or a port; a SPIFFE ID '
          'names a subject, not an endpoint',
        ),
      );
    }

    final domain = TrustDomain._fromName(authority);
    if (domain case SpiffeErr(:final error)) return castErr(error);
    final trustDomain = (domain as SpiffeOk<TrustDomain>).value;

    final pathError = _validatePath(path);
    if (pathError != null) return SpiffeErr(pathError);

    return SpiffeOk(SpiffeId._(trustDomain, path));
  }

  /// The same as [parse], for a caller that has nothing to say about *why* a
  /// string was refused. It delegates; there is one grammar, not two.
  static SpiffeId? tryParse(String value) => parse(value).valueOrNull;

  /// Builds an ID from a trust domain and already-separated segments, so a
  /// caller assembling a name does not have to join and re-parse it — and
  /// cannot smuggle a `/` in through a segment, because each segment is
  /// checked on its own.
  static SpiffeResult<SpiffeId> fromSegments(
    TrustDomain trustDomain,
    List<String> segments,
  ) {
    final path = segments.isEmpty ? '' : '/${segments.join('/')}';
    final error = _validatePath(path);
    if (error != null) return SpiffeErr(error);
    final id = SpiffeId._(trustDomain, path);
    final length = id.toString().length;
    if (length > maxSpiffeIdLength) {
      return SpiffeErr(
        MalformedSpiffeId(
          SpiffeIdRule.totalLength,
          'the id would be $length bytes, the limit is $maxSpiffeIdLength',
        ),
      );
    }
    return SpiffeOk(id);
  }

  /// The path split on `/`, empty for a trust domain ID.
  List<String> get segments =>
      path.isEmpty ? const <String>[] : path.substring(1).split('/');

  /// Whether this ID names the trust domain itself rather than a workload
  /// inside it. Such an ID is legitimate and is never a leaf's identity.
  bool get isTrustDomainId => path.isEmpty;

  /// Whether this ID belongs to [domain]. The only membership test there is:
  /// a SPIFFE ID is a member of exactly one trust domain, and paths carry no
  /// hierarchy of authority whatsoever.
  bool memberOf(TrustDomain domain) => trustDomain == domain;

  @override
  String toString() => '$_scheme$trustDomain$path';

  @override
  bool operator ==(Object other) =>
      other is SpiffeId &&
      other.trustDomain == trustDomain &&
      other.path == path;

  @override
  int get hashCode => Object.hash(trustDomain, path);

  static MalformedSpiffeId? _validatePath(String path) {
    if (path.isEmpty) return null;
    // path[0] is '/' by construction: it is whatever followed the authority.
    if (path.endsWith('/')) {
      return const MalformedSpiffeId(
        SpiffeIdRule.pathSegmentEmpty,
        'the path ends with "/", so its last segment is empty',
      );
    }
    final segments = path.substring(1).split('/');
    for (var s = 0; s < segments.length; s++) {
      final segment = segments[s];
      if (segment.isEmpty) {
        return MalformedSpiffeId(
          SpiffeIdRule.pathSegmentEmpty,
          'segment $s of "$path" is empty',
        );
      }
      if (segment == '.' || segment == '..') {
        return MalformedSpiffeId(
          SpiffeIdRule.pathDotSegment,
          'segment $s of "$path" is "$segment"; a SPIFFE ID carries no '
          'relative traversal',
        );
      }
      for (var i = 0; i < segment.length; i++) {
        if (!_isPathChar(segment.codeUnitAt(i))) {
          return MalformedSpiffeId(
            SpiffeIdRule.pathSegmentCharacters,
            'segment "$segment" holds ${_describe(segment.codeUnitAt(i))}; '
            'only a-z, A-Z, 0-9, dot, dash and underscore are allowed',
          );
        }
      }
    }
    return null;
  }
}

bool _isTrustDomainChar(int c) =>
    (c >= 0x61 && c <= 0x7a) || // a-z
    (c >= 0x30 && c <= 0x39) || // 0-9
    c == 0x2e || // .
    c == 0x2d || // -
    c == 0x5f; // _

bool _isPathChar(int c) =>
    _isTrustDomainChar(c) || (c >= 0x41 && c <= 0x5a); // A-Z as well

String _describe(int c) {
  if (c > 0x20 && c < 0x7f) return '"${String.fromCharCode(c)}"';
  return 'the character U+${c.toRadixString(16).toUpperCase().padLeft(4, '0')}';
}

String _clip(String value) =>
    value.length <= 80 ? value : '${value.substring(0, 77)}...';

/// JWT-SVID: an ordinary JWS whose `sub` is a SPIFFE ID.
///
/// Everything here reads and checks *claims*. The signature is not verified —
/// it is handed back, whole, together with the exact bytes it was taken over,
/// so that whoever does hold the trust bundle can check it. The single entry
/// point is called `parseUnverified` for that reason, and there is no second
/// one that sounds safer.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'errors.dart';
import 'spiffe_id.dart';

/// A JWT-SVID as it arrived: header, claims, and the signature nobody here
/// has checked.
final class JwtSvid {
  const JwtSvid._({
    required this.id,
    required this.audience,
    required this.expiry,
    required this.issuedAt,
    required this.notBefore,
    required this.algorithm,
    required this.keyId,
    required this.header,
    required this.claims,
    required this.signingInput,
    required this.signature,
  });

  /// The identity the token claims, from `sub`.
  final SpiffeId id;

  /// Who the token was minted for, from `aud`. Never empty: a JWT-SVID with
  /// no audience is a bearer token any recipient could replay at any other.
  final List<String> audience;

  /// When the token stops being valid, from `exp`.
  final DateTime expiry;

  /// When it was minted, from `iat`, when it carries one.
  final DateTime? issuedAt;

  /// When it starts being valid, from `nbf`, when it carries one.
  final DateTime? notBefore;

  /// The JOSE `alg`, as a name. Never `none`.
  final String algorithm;

  /// The JOSE `kid`, which says which key of the bundle signed this. Optional
  /// in JOSE, and in practice the thing a verifier needs.
  final String? keyId;

  /// The decoded JOSE header, whole.
  final Map<String, Object?> header;

  /// The decoded claim set, whole — including claims this package has no
  /// opinion about.
  final Map<String, Object?> claims;

  /// `<header>.<payload>`, ASCII, exactly as it appeared in the token. This
  /// is what a signature is taken over, and handing it back is what makes
  /// verification elsewhere possible without re-encoding anything.
  final String signingInput;

  /// The raw signature bytes, base64url-decoded.
  final Uint8List signature;

  /// Reads a token and checks every claim rule of the JWT-SVID document.
  ///
  /// It does **not** verify the signature, and the name says so at every call
  /// site. A token that comes back from here is a well-formed claim by
  /// somebody; who, is a question for a trust bundle and a signature check.
  static SpiffeResult<JwtSvid> parseUnverified(String token) {
    final parts = token.split('.');
    if (parts.length != 3) {
      return SpiffeErr(
        MalformedJwt(
          'a JWS has three dot-separated parts, this has ${parts.length}',
        ),
      );
    }
    if (parts[0].isEmpty || parts[1].isEmpty) {
      return const SpiffeErr(
        MalformedJwt('the header or the payload is empty'),
      );
    }
    if (parts[2].isEmpty) {
      return const SpiffeErr(
        MalformedJwt(
          'the signature is empty; an unsigned token is refused here whatever '
          'its header says',
        ),
      );
    }

    final headerBytes = _base64Url(parts[0], 'header');
    if (headerBytes case SpiffeErr(:final error)) return castErr(error);
    final payloadBytes = _base64Url(parts[1], 'payload');
    if (payloadBytes case SpiffeErr(:final error)) return castErr(error);
    final signatureBytes = _base64Url(parts[2], 'signature');
    if (signatureBytes case SpiffeErr(:final error)) return castErr(error);

    final header = _json((headerBytes as SpiffeOk<Uint8List>).value, 'header');
    if (header case SpiffeErr(:final error)) return castErr(error);
    final claims = _json(
      (payloadBytes as SpiffeOk<Uint8List>).value,
      'payload',
    );
    if (claims case SpiffeErr(:final error)) return castErr(error);

    final head = (header as SpiffeOk<Map<String, Object?>>).value;
    final body = (claims as SpiffeOk<Map<String, Object?>>).value;

    final algorithm = head['alg'];
    if (algorithm == null) {
      return const SpiffeErr(
        NotAJwtSvid(JwtSvidRule.algorithmMissing, 'the header has no "alg"'),
      );
    }
    if (algorithm is! String) {
      return SpiffeErr(
        NotAJwtSvid(
          JwtSvidRule.algorithmMissing,
          '"alg" is ${algorithm.runtimeType}, not a string',
        ),
      );
    }
    if (algorithm.toLowerCase() == 'none') {
      return const SpiffeErr(
        NotAJwtSvid(
          JwtSvidRule.algorithmNone,
          '"alg" is "none": an unsigned token claiming an identity',
        ),
      );
    }

    final type = head['typ'];
    if (type != null) {
      if (type is! String || (type != 'JWT' && type != 'JOSE')) {
        return SpiffeErr(
          NotAJwtSvid(
            JwtSvidRule.typeInvalid,
            '"typ" is "$type"; a JWT-SVID uses "JWT", "JOSE" or nothing',
          ),
        );
      }
    }

    final subject = body['sub'];
    if (subject == null) {
      return const SpiffeErr(
        NotAJwtSvid(JwtSvidRule.subjectMissing, 'there is no "sub" claim'),
      );
    }
    if (subject is! String) {
      return SpiffeErr(
        NotAJwtSvid(
          JwtSvidRule.subjectNotSpiffeId,
          '"sub" is ${subject.runtimeType}, not a string',
        ),
      );
    }
    final parsedId = SpiffeId.parse(subject);
    if (parsedId case SpiffeErr(:final error)) {
      return SpiffeErr(
        NotAJwtSvid(
          JwtSvidRule.subjectNotSpiffeId,
          '"sub" is "$subject", which is not a SPIFFE ID: $error',
        ),
      );
    }

    final rawAudience = body['aud'];
    if (rawAudience == null) {
      return const SpiffeErr(
        NotAJwtSvid(JwtSvidRule.audienceMissing, 'there is no "aud" claim'),
      );
    }
    final audience = <String>[];
    switch (rawAudience) {
      case final String value:
        audience.add(value);
      case final List<Object?> values:
        for (final value in values) {
          if (value is! String) {
            return SpiffeErr(
              NotAJwtSvid(
                JwtSvidRule.audienceInvalid,
                '"aud" holds ${value.runtimeType}, and an audience is a string',
              ),
            );
          }
          audience.add(value);
        }
      default:
        return SpiffeErr(
          NotAJwtSvid(
            JwtSvidRule.audienceInvalid,
            '"aud" is ${rawAudience.runtimeType}, not a string or an array',
          ),
        );
    }
    if (audience.isEmpty) {
      return const SpiffeErr(
        NotAJwtSvid(JwtSvidRule.audienceInvalid, '"aud" is an empty array'),
      );
    }

    if (!body.containsKey('exp')) {
      return const SpiffeErr(
        NotAJwtSvid(
          JwtSvidRule.expiryMissing,
          'there is no "exp" claim; an SVID that never expires is not an SVID',
        ),
      );
    }
    final expiry = _time(body['exp'], 'exp');
    if (expiry case SpiffeErr(:final error)) return castErr(error);
    final issuedAt = body.containsKey('iat')
        ? _time(body['iat'], 'iat')
        : const SpiffeOk<DateTime?>(null);
    if (issuedAt case SpiffeErr(:final error)) return castErr(error);
    final notBefore = body.containsKey('nbf')
        ? _time(body['nbf'], 'nbf')
        : const SpiffeOk<DateTime?>(null);
    if (notBefore case SpiffeErr(:final error)) return castErr(error);

    return SpiffeOk(
      JwtSvid._(
        id: (parsedId as SpiffeOk<SpiffeId>).value,
        audience: List<String>.unmodifiable(audience),
        expiry: (expiry as SpiffeOk<DateTime?>).value!,
        issuedAt: (issuedAt as SpiffeOk<DateTime?>).value,
        notBefore: (notBefore as SpiffeOk<DateTime?>).value,
        algorithm: algorithm,
        keyId: head['kid'] is String ? head['kid'] as String : null,
        header: Map<String, Object?>.unmodifiable(head),
        claims: Map<String, Object?>.unmodifiable(body),
        signingInput: '${parts[0]}.${parts[1]}',
        signature: (signatureBytes as SpiffeOk<Uint8List>).value,
      ),
    );
  }

  /// The trust domain the identity belongs to.
  TrustDomain get trustDomain => id.trustDomain;

  /// Whether the token was minted for [value]. An exact match: audiences are
  /// opaque strings and no prefix or suffix of one means anything.
  bool hasAudience(String value) => audience.contains(value);

  /// Whether [instant] is at or past `exp`.
  bool isExpiredAt(DateTime instant) => !instant.toUtc().isBefore(expiry);

  /// Whether [instant] is inside the window: at or after `nbf` when there is
  /// one, and before `exp`.
  ///
  /// The clock only. It says nothing about who signed the token, and a caller
  /// that treats a `true` here as authentication has authenticated nobody.
  bool isValidAt(DateTime instant) {
    final t = instant.toUtc();
    final start = notBefore;
    if (start != null && t.isBefore(start)) return false;
    return t.isBefore(expiry);
  }

  @override
  String toString() =>
      'JwtSvid($id, aud $audience, expires ${expiry.toIso8601String()})';

  static SpiffeResult<Uint8List> _base64Url(String part, String what) {
    for (var i = 0; i < part.length; i++) {
      final c = part.codeUnitAt(i);
      final ok =
          (c >= 0x41 && c <= 0x5a) ||
          (c >= 0x61 && c <= 0x7a) ||
          (c >= 0x30 && c <= 0x39) ||
          c == 0x2d ||
          c == 0x5f;
      if (!ok) {
        return SpiffeErr(
          MalformedJwt(
            'the $what is not unpadded base64url: it holds '
            '"${String.fromCharCode(c)}" at index $i',
          ),
        );
      }
    }
    // Unpadded base64url is what a JWS carries; the padding is added back
    // here rather than by a normaliser, so no other alphabet can slip in.
    final remainder = part.length % 4;
    if (remainder == 1) {
      return SpiffeErr(
        MalformedJwt('the $what has a length that no base64url string has'),
      );
    }
    final padded = remainder == 0 ? part : part + '=' * (4 - remainder);
    try {
      return SpiffeOk(base64Url.decode(padded));
    } on FormatException catch (e) {
      return SpiffeErr(
        MalformedJwt('the $what is not base64url: ${e.message}'),
      );
    }
  }

  static SpiffeResult<Map<String, Object?>> _json(
    Uint8List bytes,
    String what,
  ) {
    Object? decoded;
    try {
      decoded = json.decode(utf8.decode(bytes));
    } on FormatException catch (e) {
      return SpiffeErr(MalformedJwt('the $what is not JSON: ${e.message}'));
    }
    if (decoded is! Map<String, Object?>) {
      return SpiffeErr(
        MalformedJwt(
          'the $what decodes to ${decoded.runtimeType}, not an '
          'object',
        ),
      );
    }
    return SpiffeOk(decoded);
  }

  static SpiffeResult<DateTime?> _time(Object? value, String claim) {
    if (value is! num) {
      return SpiffeErr(
        NotAJwtSvid(
          JwtSvidRule.timeClaimInvalid,
          '"$claim" is ${value.runtimeType}, and a time claim is a number of '
          'seconds since the epoch',
        ),
      );
    }
    if (value is double && !value.isFinite) {
      return SpiffeErr(
        NotAJwtSvid(
          JwtSvidRule.timeClaimInvalid,
          '"$claim" is $value, which is not a moment in time',
        ),
      );
    }
    return SpiffeOk(
      DateTime.fromMillisecondsSinceEpoch(
        (value.toDouble() * 1000).round(),
        isUtc: true,
      ),
    );
  }
}

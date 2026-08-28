import 'dart:convert';

import 'package:rk_spiffe/rk_spiffe.dart';
import 'package:test/test.dart';

String _segment(Object? value) =>
    base64Url.encode(utf8.encode(json.encode(value))).replaceAll('=', '');

/// Builds a token out of a header and a claim set. The signature is a fixed
/// stand-in: nothing in this package looks at it, and the tests say so by
/// making it obviously not a signature over anything.
String token(
  Map<String, Object?> header,
  Map<String, Object?> claims, {
  String signature = 'bm90LWEtc2lnbmF0dXJl',
}) => '${_segment(header)}.${_segment(claims)}.$signature';

const Map<String, Object?> goodHeader = <String, Object?>{
  'alg': 'ES256',
  'typ': 'JWT',
  'kid': 'zzT9F4mQ',
};

const Map<String, Object?> goodClaims = <String, Object?>{
  'sub': 'spiffe://shop-42.telepos/till/17/terminal/3',
  'aud': <String>['spiffe://shop-42.telepos/shop-server', 'reports'],
  'exp': 1785000000,
  'iat': 1784996400,
};

JwtSvidRule? refusedBy(String value) {
  final error = JwtSvid.parseUnverified(value).errorOrNull;
  if (error == null) return null;
  return (error as NotAJwtSvid).rule;
}

void main() {
  group('a JWT-SVID that is one', () {
    late JwtSvid svid;

    setUp(() {
      final result = JwtSvid.parseUnverified(token(goodHeader, goodClaims));
      expect(result.isOk, isTrue, reason: '${result.errorOrNull}');
      svid = result.valueOrNull!;
    });

    test('carries the identity out of "sub"', () {
      expect(svid.id.toString(), 'spiffe://shop-42.telepos/till/17/terminal/3');
      expect(svid.trustDomain.name, 'shop-42.telepos');
    });

    test('carries every audience, and matches them exactly', () {
      expect(svid.audience, <String>[
        'spiffe://shop-42.telepos/shop-server',
        'reports',
      ]);
      expect(svid.hasAudience('reports'), isTrue);
      expect(svid.hasAudience('report'), isFalse);
      expect(svid.hasAudience('reports '), isFalse);
      expect(svid.hasAudience('spiffe://shop-42.telepos/shop-serve'), isFalse);
    });

    test('reads the times as UTC instants', () {
      expect(svid.expiry, DateTime.utc(2026, 7, 25, 17, 20));
      expect(svid.issuedAt, DateTime.utc(2026, 7, 25, 16, 20));
      expect(svid.notBefore, isNull);
      expect(svid.expiry.isUtc, isTrue);
    });

    test('answers about the clock, and nothing else', () {
      expect(svid.isValidAt(DateTime.utc(2026, 7, 25, 17, 19, 59)), isTrue);
      expect(svid.isValidAt(DateTime.utc(2026, 7, 25, 17, 20)), isFalse);
      expect(svid.isExpiredAt(DateTime.utc(2026, 7, 25, 17, 20)), isTrue);
      expect(svid.isExpiredAt(DateTime.utc(2026, 7, 25, 17, 19, 59)), isFalse);
    });

    test('honours "nbf" when there is one', () {
      final withNbf = JwtSvid.parseUnverified(
        token(goodHeader, <String, Object?>{...goodClaims, 'nbf': 1784998000}),
      ).valueOrNull!;
      expect(withNbf.notBefore, DateTime.utc(2026, 7, 25, 16, 46, 40));
      expect(withNbf.isValidAt(DateTime.utc(2026, 7, 25, 16, 46, 39)), isFalse);
      expect(withNbf.isValidAt(DateTime.utc(2026, 7, 25, 16, 46, 40)), isTrue);
    });

    test('keeps the header and claims whole, including what it ignores', () {
      final rich = JwtSvid.parseUnverified(
        token(goodHeader, <String, Object?>{
          ...goodClaims,
          'iss': 'https://spire.shop-42/oidc',
          'jti': 'e2b1',
        }),
      ).valueOrNull!;
      expect(rich.claims['iss'], 'https://spire.shop-42/oidc');
      expect(rich.claims['jti'], 'e2b1');
      expect(rich.algorithm, 'ES256');
      expect(rich.keyId, 'zzT9F4mQ');
      expect(rich.header['typ'], 'JWT');
    });

    test('accepts a single-string audience as an audience of one', () {
      final one = JwtSvid.parseUnverified(
        token(goodHeader, <String, Object?>{...goodClaims, 'aud': 'reports'}),
      ).valueOrNull!;
      expect(one.audience, <String>['reports']);
    });

    test('accepts a header with no "typ", and "JOSE" as well as "JWT"', () {
      expect(
        JwtSvid.parseUnverified(
          token(const <String, Object?>{'alg': 'RS256'}, goodClaims),
        ).isOk,
        isTrue,
      );
      expect(
        JwtSvid.parseUnverified(
          token(const <String, Object?>{
            'alg': 'ES384',
            'typ': 'JOSE',
          }, goodClaims),
        ).isOk,
        isTrue,
      );
    });

    test('hands back the signing input and the signature, unexamined', () {
      final text = token(goodHeader, goodClaims);
      final parts = text.split('.');
      expect(svid.signingInput, '${parts[0]}.${parts[1]}');
      expect(svid.signature, base64Url.decode('bm90LWEtc2lnbmF0dXJl'));
      expect(utf8.decode(svid.signature), 'not-a-signature');
      // Which is the point: a token this package accepts has been checked for
      // shape and by nobody for authenticity.
    });
  });

  group('a token that is not a JWS at all', () {
    test('is refused for the number of parts', () {
      expect(JwtSvid.parseUnverified('a.b').errorOrNull, isA<MalformedJwt>());
      expect(
        JwtSvid.parseUnverified('a.b.c.d').errorOrNull,
        isA<MalformedJwt>(),
      );
      expect(JwtSvid.parseUnverified('').errorOrNull, isA<MalformedJwt>());
    });

    test('is refused for an empty part', () {
      final good = token(goodHeader, goodClaims).split('.');
      expect(
        JwtSvid.parseUnverified('.${good[1]}.${good[2]}').errorOrNull,
        isA<MalformedJwt>(),
      );
      expect(
        JwtSvid.parseUnverified('${good[0]}.${good[1]}.').errorOrNull,
        isA<MalformedJwt>(),
      );
    });

    test('is refused for an alphabet that is not base64url', () {
      final good = token(goodHeader, goodClaims).split('.');
      // Standard base64 with padding, which a JWS never carries.
      final padded = base64.encode(utf8.encode(json.encode(goodHeader)));
      expect(padded, contains('='));
      expect(
        JwtSvid.parseUnverified('$padded.${good[1]}.${good[2]}').errorOrNull,
        isA<MalformedJwt>(),
      );
    });

    test('is refused when a part is not JSON, or not an object', () {
      final good = token(goodHeader, goodClaims).split('.');
      final notJson = base64Url.encode(utf8.encode('{')).replaceAll('=', '');
      expect(
        JwtSvid.parseUnverified('$notJson.${good[1]}.${good[2]}').errorOrNull,
        isA<MalformedJwt>(),
      );
      final array = base64Url.encode(utf8.encode('[1,2]')).replaceAll('=', '');
      expect(
        JwtSvid.parseUnverified('${good[0]}.$array.${good[2]}').errorOrNull,
        isA<MalformedJwt>(),
      );
    });
  });

  group('a JWS that is not a JWT-SVID names the clause it broke', () {
    test('no "alg"', () {
      expect(
        refusedBy(token(const <String, Object?>{'typ': 'JWT'}, goodClaims)),
        JwtSvidRule.algorithmMissing,
      );
      expect(
        refusedBy(token(const <String, Object?>{'alg': 7}, goodClaims)),
        JwtSvidRule.algorithmMissing,
      );
    });

    test('"alg" of none, in any spelling', () {
      expect(
        refusedBy(token(const <String, Object?>{'alg': 'none'}, goodClaims)),
        JwtSvidRule.algorithmNone,
      );
      expect(
        refusedBy(token(const <String, Object?>{'alg': 'NONE'}, goodClaims)),
        JwtSvidRule.algorithmNone,
      );
    });

    test('a "typ" that is neither JWT nor JOSE', () {
      expect(
        refusedBy(
          token(const <String, Object?>{
            'alg': 'ES256',
            'typ': 'at+jwt',
          }, goodClaims),
        ),
        JwtSvidRule.typeInvalid,
      );
    });

    test('no "sub", or a "sub" that is not a SPIFFE ID', () {
      final without = Map<String, Object?>.from(goodClaims)..remove('sub');
      expect(refusedBy(token(goodHeader, without)), JwtSvidRule.subjectMissing);
      expect(
        refusedBy(
          token(goodHeader, <String, Object?>{
            ...goodClaims,
            'sub': 'spiffe://Shop-42.telepos/till/17',
          }),
        ),
        JwtSvidRule.subjectNotSpiffeId,
      );
      expect(
        refusedBy(
          token(goodHeader, <String, Object?>{...goodClaims, 'sub': 'till-17'}),
        ),
        JwtSvidRule.subjectNotSpiffeId,
      );
      expect(
        refusedBy(
          token(goodHeader, <String, Object?>{...goodClaims, 'sub': 42}),
        ),
        JwtSvidRule.subjectNotSpiffeId,
      );
    });

    test('no "aud", or an "aud" that holds no usable audience', () {
      final without = Map<String, Object?>.from(goodClaims)..remove('aud');
      expect(
        refusedBy(token(goodHeader, without)),
        JwtSvidRule.audienceMissing,
      );
      expect(
        refusedBy(
          token(goodHeader, <String, Object?>{
            ...goodClaims,
            'aud': <String>[],
          }),
        ),
        JwtSvidRule.audienceInvalid,
      );
      expect(
        refusedBy(
          token(goodHeader, <String, Object?>{
            ...goodClaims,
            'aud': <Object?>['a', 7],
          }),
        ),
        JwtSvidRule.audienceInvalid,
      );
      expect(
        refusedBy(
          token(goodHeader, <String, Object?>{...goodClaims, 'aud': 7}),
        ),
        JwtSvidRule.audienceInvalid,
      );
    });

    test('no "exp", because an SVID that never expires is not one', () {
      final without = Map<String, Object?>.from(goodClaims)..remove('exp');
      expect(refusedBy(token(goodHeader, without)), JwtSvidRule.expiryMissing);
    });

    test('a time claim that is not a number of seconds', () {
      expect(
        refusedBy(
          token(goodHeader, <String, Object?>{
            ...goodClaims,
            'exp': '1785000000',
          }),
        ),
        JwtSvidRule.timeClaimInvalid,
      );
      expect(
        refusedBy(
          token(goodHeader, <String, Object?>{...goodClaims, 'iat': true}),
        ),
        JwtSvidRule.timeClaimInvalid,
      );
      expect(
        refusedBy(
          token(goodHeader, <String, Object?>{...goodClaims, 'nbf': 'soon'}),
        ),
        JwtSvidRule.timeClaimInvalid,
      );
    });

    test('and the refusal prints the clause by name', () {
      final error = JwtSvid.parseUnverified(
        token(const <String, Object?>{'alg': 'none'}, goodClaims),
      ).errorOrNull!;
      expect(error.kind, 'notAJwtSvid');
      expect(error.toString(), contains('algorithmNone'));
    });
  });
}

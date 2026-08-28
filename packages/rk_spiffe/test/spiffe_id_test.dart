import 'package:rk_spiffe/rk_spiffe.dart';
import 'package:test/test.dart';

/// The clause a string was refused for, or `null` if it was accepted. Every
/// negative case goes through here so a test cannot pass merely because
/// *something* was wrong — it names which rule fired.
SpiffeIdRule? refusedBy(String value) {
  final result = SpiffeId.parse(value);
  final error = result.errorOrNull;
  if (error == null) return null;
  return (error as MalformedSpiffeId).rule;
}

void main() {
  group('a SPIFFE ID that is one', () {
    test('splits into a trust domain and a path', () {
      final id = SpiffeId.parse('spiffe://shop-42.telepos/till/17/terminal/3');
      final value = id.valueOrNull;
      expect(value, isNotNull);
      expect(value!.trustDomain.name, 'shop-42.telepos');
      expect(value.path, '/till/17/terminal/3');
      expect(value.segments, <String>['till', '17', 'terminal', '3']);
      expect(value.isTrustDomainId, isFalse);
    });

    test('prints back exactly what was parsed', () {
      const text = 'spiffe://a_b.c-d.e/Segment/with.dots/and-dashes/and_under';
      expect(SpiffeId.parse(text).valueOrNull.toString(), text);
    });

    test('may name the trust domain itself, with no path', () {
      final id = SpiffeId.parse('spiffe://shop-42.telepos').valueOrNull;
      expect(id, isNotNull);
      expect(id!.path, '');
      expect(id.segments, isEmpty);
      expect(id.isTrustDomainId, isTrue);
      expect(id.toString(), 'spiffe://shop-42.telepos');
    });

    test('keeps the case of the path, having none to keep in the domain', () {
      final lower = SpiffeId.parse('spiffe://x.y/till').valueOrNull;
      final upper = SpiffeId.parse('spiffe://x.y/Till').valueOrNull;
      expect(lower, isNotNull);
      expect(upper, isNotNull);
      expect(lower == upper, isFalse);
      expect(upper!.path, '/Till');
    });

    test('is equal to another spelling of the same bytes, and hashes so', () {
      final a = SpiffeId.parse('spiffe://x.y/a/b').valueOrNull;
      final b = SpiffeId.parse('spiffe://x.y/a/b').valueOrNull;
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(<SpiffeId?>{a, b}, hasLength(1));
    });

    test('belongs to exactly one trust domain', () {
      final id = SpiffeId.parse('spiffe://shop-42.telepos/till/17').valueOrNull;
      final own = TrustDomain.parse('shop-42.telepos').valueOrNull;
      final other = TrustDomain.parse('shop-43.telepos').valueOrNull;
      expect(id!.memberOf(own!), isTrue);
      expect(id.memberOf(other!), isFalse);
    });

    test('is 2048 bytes long at most, and 2048 is allowed', () {
      final domain = TrustDomain.parse('x.y').valueOrNull!;
      // 'spiffe://x.y' is 12 bytes; a '/' plus 2035 characters reaches 2048.
      final justFits = 'spiffe://x.y/${'a' * 2035}';
      expect(justFits.length, 2048);
      expect(SpiffeId.parse(justFits).isOk, isTrue);
      expect(refusedBy('${justFits}a'), SpiffeIdRule.totalLength);
      expect(
        SpiffeId.fromSegments(domain, <String>['a' * 2036]).errorOrNull,
        isA<MalformedSpiffeId>().having(
          (e) => e.rule,
          'rule',
          SpiffeIdRule.totalLength,
        ),
      );
    });

    test('has a trust domain of 255 bytes at most, and 255 is allowed', () {
      expect(SpiffeId.parse('spiffe://${'a' * 255}/x').isOk, isTrue);
      expect(
        refusedBy('spiffe://${'a' * 256}/x'),
        SpiffeIdRule.trustDomainLength,
      );
    });
  });

  group('a string that is not a SPIFFE ID names the clause it broke', () {
    test('the scheme, which is lowercase and is not http', () {
      expect(refusedBy('https://x.y/a'), SpiffeIdRule.scheme);
      expect(refusedBy('SPIFFE://x.y/a'), SpiffeIdRule.scheme);
      expect(refusedBy('Spiffe://x.y/a'), SpiffeIdRule.scheme);
      expect(refusedBy('spiffe:/x.y/a'), SpiffeIdRule.scheme);
      expect(refusedBy('spiffe:x.y/a'), SpiffeIdRule.scheme);
      expect(refusedBy(''), SpiffeIdRule.scheme);
      expect(refusedBy('x.y/a'), SpiffeIdRule.scheme);
    });

    test('an absent trust domain', () {
      expect(refusedBy('spiffe:///a'), SpiffeIdRule.trustDomainEmpty);
      expect(refusedBy('spiffe://'), SpiffeIdRule.trustDomainEmpty);
    });

    test('a trust domain with anything but lowercase, digits, . - _', () {
      expect(
        refusedBy('spiffe://Example.org/a'),
        SpiffeIdRule.trustDomainCharacters,
      );
      expect(
        refusedBy('spiffe://exam ple/a'),
        SpiffeIdRule.trustDomainCharacters,
      );
      expect(
        refusedBy('spiffe://ex%41mple/a'),
        SpiffeIdRule.trustDomainCharacters,
      );
      expect(
        refusedBy('spiffe://пример/a'),
        SpiffeIdRule.trustDomainCharacters,
      );
      expect(
        refusedBy('spiffe://ex+ample/a'),
        SpiffeIdRule.trustDomainCharacters,
      );
    });

    test('userinfo or a port, because an ID is not an endpoint', () {
      expect(refusedBy('spiffe://user@x.y/a'), SpiffeIdRule.authorityNotBare);
      expect(refusedBy('spiffe://x.y:443/a'), SpiffeIdRule.authorityNotBare);
      expect(refusedBy('spiffe://x.y:443'), SpiffeIdRule.authorityNotBare);
    });

    test('an empty path segment, including a trailing slash', () {
      expect(refusedBy('spiffe://x.y/a//b'), SpiffeIdRule.pathSegmentEmpty);
      expect(refusedBy('spiffe://x.y/a/'), SpiffeIdRule.pathSegmentEmpty);
      expect(refusedBy('spiffe://x.y/'), SpiffeIdRule.pathSegmentEmpty);
      expect(refusedBy('spiffe://x.y//a'), SpiffeIdRule.pathSegmentEmpty);
    });

    test('a path segment with a character outside the set', () {
      expect(refusedBy('spiffe://x.y/a b'), SpiffeIdRule.pathSegmentCharacters);
      expect(
        refusedBy('spiffe://x.y/a%2Fb'),
        SpiffeIdRule.pathSegmentCharacters,
      );
      expect(refusedBy('spiffe://x.y/a:b'), SpiffeIdRule.pathSegmentCharacters);
      expect(
        refusedBy('spiffe://x.y/тилл'),
        SpiffeIdRule.pathSegmentCharacters,
      );
    });

    test('a dot segment, which is a second spelling of some other ID', () {
      expect(refusedBy('spiffe://x.y/./a'), SpiffeIdRule.pathDotSegment);
      expect(refusedBy('spiffe://x.y/a/../b'), SpiffeIdRule.pathDotSegment);
      expect(refusedBy('spiffe://x.y/..'), SpiffeIdRule.pathDotSegment);
      // A segment that merely contains dots is fine; only `.` and `..` are not.
      expect(SpiffeId.parse('spiffe://x.y/a.b/...').isOk, isTrue);
    });

    test('a query or a fragment', () {
      expect(refusedBy('spiffe://x.y/a?b=c'), SpiffeIdRule.queryOrFragment);
      expect(refusedBy('spiffe://x.y/a#b'), SpiffeIdRule.queryOrFragment);
      expect(refusedBy('spiffe://x.y?b'), SpiffeIdRule.queryOrFragment);
    });

    test('and the failure prints the clause by name, never by number', () {
      final error = SpiffeId.parse('spiffe://X/a').errorOrNull!;
      expect(error.toString(), contains('trustDomainCharacters'));
      expect(error.kind, 'malformedSpiffeId');
    });
  });

  group('tryParse', () {
    test('answers the same as parse, with nothing to say about why', () {
      expect(SpiffeId.tryParse('spiffe://x.y/a'), isNotNull);
      expect(SpiffeId.tryParse('spiffe://X.y/a'), isNull);
      expect(
        SpiffeId.tryParse('spiffe://x.y/a'),
        SpiffeId.parse('spiffe://x.y/a').valueOrNull,
      );
    });
  });

  group('a trust domain', () {
    test('reads from a bare name or from a full ID', () {
      expect(
        TrustDomain.parse('shop-42.telepos').valueOrNull?.name,
        'shop-42.telepos',
      );
      expect(
        TrustDomain.parse('spiffe://shop-42.telepos').valueOrNull?.name,
        'shop-42.telepos',
      );
      expect(
        TrustDomain.parse('spiffe://shop-42.telepos/till/17').valueOrNull?.name,
        'shop-42.telepos',
      );
    });

    test('refuses a bare name that is not one', () {
      expect(
        TrustDomain.parse('Shop-42').errorOrNull,
        isA<MalformedSpiffeId>().having(
          (e) => e.rule,
          'rule',
          SpiffeIdRule.trustDomainCharacters,
        ),
      );
      expect(
        TrustDomain.parse('').errorOrNull,
        isA<MalformedSpiffeId>().having(
          (e) => e.rule,
          'rule',
          SpiffeIdRule.trustDomainEmpty,
        ),
      );
    });

    test('carries the clause outward when the full ID was the problem', () {
      expect(
        TrustDomain.parse('spiffe://x.y/a//b').errorOrNull,
        isA<MalformedSpiffeId>().having(
          (e) => e.rule,
          'rule',
          SpiffeIdRule.pathSegmentEmpty,
        ),
      );
    });

    test('names itself with an ID that has no path', () {
      final domain = TrustDomain.parse('shop-42.telepos').valueOrNull!;
      expect(domain.id.toString(), 'spiffe://shop-42.telepos');
      expect(domain.id.isTrustDomainId, isTrue);
    });

    test('is equal by name and usable as a key', () {
      final a = TrustDomain.parse('x.y').valueOrNull;
      final b = TrustDomain.parse('spiffe://x.y').valueOrNull;
      expect(a, b);
      expect(<TrustDomain?>{a, b}, hasLength(1));
    });
  });

  group('fromSegments', () {
    test('joins segments that are each legal', () {
      final domain = TrustDomain.parse('shop-42.telepos').valueOrNull!;
      final id = SpiffeId.fromSegments(domain, <String>[
        'till',
        '17',
        'terminal',
        '3',
      ]).valueOrNull;
      expect(id.toString(), 'spiffe://shop-42.telepos/till/17/terminal/3');
    });

    test('makes the trust domain ID from no segments at all', () {
      final domain = TrustDomain.parse('x.y').valueOrNull!;
      final id = SpiffeId.fromSegments(domain, const <String>[]).valueOrNull;
      expect(id!.isTrustDomainId, isTrue);
    });

    test('refuses a slash smuggled inside a segment', () {
      final domain = TrustDomain.parse('x.y').valueOrNull!;
      expect(
        SpiffeId.fromSegments(domain, <String>['a/../b']).errorOrNull,
        isA<MalformedSpiffeId>().having(
          (e) => e.rule,
          'rule',
          SpiffeIdRule.pathDotSegment,
        ),
      );
      expect(
        SpiffeId.fromSegments(domain, <String>['a', '']).errorOrNull,
        isA<MalformedSpiffeId>().having(
          (e) => e.rule,
          'rule',
          SpiffeIdRule.pathSegmentEmpty,
        ),
      );
      expect(
        SpiffeId.fromSegments(domain, <String>['a b']).errorOrNull,
        isA<MalformedSpiffeId>().having(
          (e) => e.rule,
          'rule',
          SpiffeIdRule.pathSegmentCharacters,
        ),
      );
    });
  });

  group('the result type', () {
    test('folds both ways without anything being thrown', () {
      expect(
        SpiffeId.parse('spiffe://x.y/a').fold((id) => id.path, (e) => e.kind),
        '/a',
      );
      expect(
        SpiffeId.parse('nope').fold((id) => id.path, (e) => e.kind),
        'malformedSpiffeId',
      );
    });

    test('maps a value and carries a failure through untouched', () {
      final ok = SpiffeId.parse('spiffe://x.y/a').map((id) => id.segments);
      expect(ok.valueOrNull, <String>['a']);
      final err = SpiffeId.parse('nope').map((id) => id.segments);
      expect(err.isOk, isFalse);
      expect(err.errorOrNull, isA<MalformedSpiffeId>());
    });
  });
}

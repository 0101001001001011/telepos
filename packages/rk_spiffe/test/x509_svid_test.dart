import 'dart:convert';
import 'dart:typed_data';

import 'package:rk_spiffe/rk_spiffe.dart';
import 'package:test/test.dart';

import 'fixtures/certificates.dart';

/// Pulls the DER out of a PEM without going through the package, so that a
/// bug in the package's own PEM handling cannot hide behind itself.
Uint8List derOf(String pem) {
  final body = pem
      .split('\n')
      .where((line) => !line.startsWith('-----') && line.isNotEmpty)
      .join();
  return base64.decode(body);
}

X509SvidRule? refusedBy(String pem) {
  final error = X509Svid.parseUnverifiedPem(pem).errorOrNull;
  if (error == null) return null;
  return (error as NotAnX509Svid).rule;
}

void main() {
  group('reading a certificate', () {
    late ParsedCertificate leaf;

    setUp(() {
      leaf = ParsedCertificate.fromPem(leafPem).valueOrNull!;
    });

    test('reads the version, the serial and the validity window', () {
      expect(leaf.version, 3);
      // A 64-bit serial, which does not fit an int on every platform and must
      // not be truncated to one.
      expect(leaf.serialNumber, BigInt.parse('0a1b2c3d4e5f6071', radix: 16));
      expect(leaf.notBefore, DateTime.utc(2026, 8, 1, 2, 49, 14));
      expect(leaf.notAfter, DateTime.utc(2026, 8, 2, 2, 49, 14));
      expect(leaf.notBefore.isUtc, isTrue);
    });

    test('answers about the clock, inclusive at both ends', () {
      expect(leaf.isValidAt(DateTime.utc(2026, 8, 1, 12)), isTrue);
      expect(leaf.isValidAt(DateTime.utc(2026, 8, 1, 2, 49, 14)), isTrue);
      expect(leaf.isValidAt(DateTime.utc(2026, 8, 2, 2, 49, 14)), isTrue);
      expect(leaf.isValidAt(DateTime.utc(2026, 8, 1, 2, 49, 13)), isFalse);
      expect(leaf.isValidAt(DateTime.utc(2026, 8, 2, 2, 49, 15)), isFalse);
      // A local-time instant is compared in UTC, not in whatever zone the
      // machine running the till happens to sit in.
      expect(leaf.isValidAt(DateTime.utc(2026, 8, 1, 12).toLocal()), isTrue);
    });

    test('finds the URI name wherever in the SAN list it sits', () {
      // The fixture's names are DNS, IP, URI, DNS in that order, so neither
      // "take the first" nor "take the last" can pass this.
      expect(leaf.uriNames, <String>[
        'spiffe://shop-42.telepos/till/17/terminal/3',
      ]);
      expect(leaf.dnsNames, <String>['till-17.shop-42.local', 'till-17.local']);
      expect(leaf.ipAddresses, hasLength(1));
      expect(leaf.ipAddresses.single, <int>[10, 20, 30, 40]);
      expect(leaf.hasSubjectAltName, isTrue);
    });

    test('reads basicConstraints and keyUsage by name', () {
      expect(leaf.isCertificateAuthority, isFalse);
      expect(leaf.pathLengthConstraint, isNull);
      expect(leaf.keyUsage, isNotNull);
      expect(leaf.keyUsage!.names, <String>[
        'digitalSignature',
        'keyEncipherment',
      ]);
      expect(leaf.keyUsage!.digitalSignature, isTrue);
      expect(leaf.keyUsage!.keyCertSign, isFalse);
      expect(leaf.keyUsage!.cRLSign, isFalse);
    });

    test('keeps every extension, in the order the certificate has them', () {
      expect(leaf.extensions.map((e) => e.oid), <String>[
        '2.5.29.14', // subjectKeyIdentifier
        '2.5.29.19', // basicConstraints
        '2.5.29.15', // keyUsage
        '2.5.29.37', // extendedKeyUsage
        '2.5.29.17', // subjectAltName
        '2.5.29.35', // authorityKeyIdentifier
      ]);
      // subjectAltName is fifth of six, so a parser that reads the first
      // extension, or the last, reads the wrong one.
      expect(leaf.extensions.first.oid, isNot('2.5.29.17'));
      expect(leaf.extensions.last.oid, isNot('2.5.29.17'));
      expect(leaf.extension('2.5.29.17'), isNotNull);
      expect(leaf.extension('1.2.3.4'), isNull);
      expect(leaf.extension('2.5.29.19')!.critical, isTrue);
      expect(leaf.extension('2.5.29.14')!.critical, isFalse);
    });

    test('tells a root from a leaf by its names, not by its claims', () {
      final ca = ParsedCertificate.fromPem(
        certificateAuthorityPem,
      ).valueOrNull!;
      expect(ca.isSelfIssued, isTrue);
      expect(leaf.isSelfIssued, isFalse);
      expect(ca.isCertificateAuthority, isTrue);
      expect(ca.pathLengthConstraint, 1);
      expect(ca.keyUsage!.names, <String>['keyCertSign', 'cRLSign']);
      expect(ca.serialNumber, BigInt.from(0x4d1f2a7b));
    });

    test('reads a GeneralizedTime as readily as a UTCTime', () {
      // Past 2049 RFC 5280 switches encodings; a parser that knows only one
      // fails here and nowhere else.
      final far = ParsedCertificate.fromPem(farFuturePem).valueOrNull!;
      expect(far.notAfter, DateTime.utc(2056, 9, 12, 2, 49, 17));
      expect(far.notBefore, DateTime.utc(2026, 8, 1, 2, 49, 17));
    });

    test('hands back the exact bytes it was given', () {
      final der = derOf(leafPem);
      final parsed = ParsedCertificate.fromDer(der).valueOrNull!;
      expect(parsed.der, der);
      expect(parsed.serialNumber, leaf.serialNumber);
    });

    test('reads a whole PEM bundle in order', () {
      final all = ParsedCertificate.allFromPem(
        '$leafPem$certificateAuthorityPem',
      ).valueOrNull!;
      expect(all, hasLength(2));
      expect(all.first.serialNumber, leaf.serialNumber);
      expect(all.last.isCertificateAuthority, isTrue);
      expect(ParsedCertificate.allFromPem('nothing here').valueOrNull, isEmpty);
    });

    test('refuses a PEM that is not one', () {
      expect(
        ParsedCertificate.fromPem('nothing here').errorOrNull,
        isA<MalformedCertificate>(),
      );
      expect(
        ParsedCertificate.fromPem(
          '-----BEGIN CERTIFICATE-----\nnot base64!!\n'
          '-----END CERTIFICATE-----\n',
        ).errorOrNull,
        isA<MalformedCertificate>(),
      );
      expect(
        ParsedCertificate.allFromPem(
          '-----BEGIN CERTIFICATE-----\nAAAA\n',
        ).errorOrNull,
        isA<MalformedCertificate>(),
      );
    });
  });

  group('the leaf rules of an X.509-SVID', () {
    test('a well-formed leaf passes and carries its identity', () {
      final svid = X509Svid.parseUnverifiedPem(leafPem).valueOrNull!;
      expect(svid.id.toString(), 'spiffe://shop-42.telepos/till/17/terminal/3');
      expect(svid.trustDomain.name, 'shop-42.telepos');
      expect(svid.notAfter, DateTime.utc(2026, 8, 2, 2, 49, 14));
      expect(svid.isValidAt(DateTime.utc(2026, 8, 1, 12)), isTrue);
      expect(svid.isValidAt(DateTime.utc(2027, 1, 1)), isFalse);
      expect(svid.certificate.der, derOf(leafPem));
    });

    test('the DER and the PEM doors reach the same answer', () {
      final fromPem = X509Svid.parseUnverifiedPem(leafPem).valueOrNull!;
      final fromDer = X509Svid.parseUnverifiedDer(derOf(leafPem)).valueOrNull!;
      expect(fromDer.id, fromPem.id);
    });

    test('refuses a certificate with no URI name', () {
      expect(refusedBy(noUriSanPem), X509SvidRule.uriSanMissing);
    });

    test('refuses a certificate with more than one URI name', () {
      expect(refusedBy(twoUriSansPem), X509SvidRule.uriSanNotUnique);
      final error = X509Svid.parseUnverifiedPem(
        twoUriSansPem,
      ).errorOrNull.toString();
      expect(error, contains('till/17'));
      expect(error, contains('till/18'));
    });

    test('refuses a URI name that is not a SPIFFE ID', () {
      expect(refusedBy(malformedIdPem), X509SvidRule.uriSanNotSpiffeId);
      // The clause of the ID grammar travels outward with the refusal.
      expect(
        X509Svid.parseUnverifiedPem(malformedIdPem).errorOrNull.toString(),
        contains('trustDomainCharacters'),
      );
    });

    test('refuses a certificate authority', () {
      expect(
        refusedBy(certificateAuthorityPem),
        X509SvidRule.isCertificateAuthority,
      );
    });

    test(
      'refuses an ID that names the trust domain rather than a workload',
      () {
        // This fixture is CA:FALSE with digitalSignature set, so the only rule
        // it can be refused by is the one under test.
        final cert = ParsedCertificate.fromPem(trustDomainIdPem).valueOrNull!;
        expect(cert.isCertificateAuthority, isFalse);
        expect(cert.keyUsage!.digitalSignature, isTrue);
        expect(refusedBy(trustDomainIdPem), X509SvidRule.idHasNoPath);
      },
    );

    test('refuses a leaf with no keyUsage extension', () {
      expect(refusedBy(noKeyUsagePem), X509SvidRule.keyUsageMissing);
    });

    test('refuses a leaf whose keyUsage cannot sign', () {
      expect(
        refusedBy(noDigitalSignaturePem),
        X509SvidRule.keyUsageWithoutDigitalSignature,
      );
    });

    test('refuses a leaf that may sign certificates', () {
      expect(refusedBy(leafThatSignsPem), X509SvidRule.keyUsageSigns);
    });

    test('refuses bytes that are not a certificate at all, as a value', () {
      final result = X509Svid.parseUnverifiedDer(
        Uint8List.fromList(<int>[0x30, 0x03, 0x02, 0x01, 0x01]),
      );
      expect(result.isOk, isFalse);
      expect(result.errorOrNull, isA<MalformedCertificate>());
      expect(result.errorOrNull!.kind, 'malformedCertificate');
    });

    test('and every refusal names its clause rather than numbering it', () {
      final error = X509Svid.parseUnverifiedPem(noKeyUsagePem).errorOrNull!;
      expect(error.toString(), contains('keyUsageMissing'));
      expect(error.kind, 'notAnX509Svid');
    });
  });
}

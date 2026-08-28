/// What the reader refuses.
///
/// Every case here is an encoding that BER allows and DER does not, or a
/// certificate that says two things at once. A parser that shrugs at any of
/// them is a parser two implementations can disagree with, and disagreement
/// about a certificate is the whole attack.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:rk_spiffe/rk_spiffe.dart';
import 'package:test/test.dart';

import 'fixtures/certificates.dart';
import 'support/der_builder.dart';

Uint8List derOf(String pem) {
  final body = pem
      .split('\n')
      .where((line) => !line.startsWith('-----') && line.isNotEmpty)
      .join();
  return base64.decode(body);
}

/// The message of the refusal, or `null` when the bytes were accepted.
String? refusalOf(Uint8List der) =>
    ParsedCertificate.fromDer(der).errorOrNull?.detail;

void main() {
  group('the builder used for these cases builds something real', () {
    test('a synthetic certificate parses to the values put into it', () {
      final der = syntheticCertificate(
        serial: 0x2a,
        notBefore: '260801103000',
        notAfter: '270801103000',
        extensions: <List<int>>[
          derExtension(
            Oids.basicConstraints,
            derBasicConstraintsValue(ca: false),
            critical: true,
          ),
          derExtension(Oids.keyUsage, derDigitalSignatureOnlyValue()),
          derExtension(
            Oids.subjectAltName,
            derSubjectAltNameValue(<String>['spiffe://synthetic.test/w']),
          ),
        ],
      );
      final cert = ParsedCertificate.fromDer(der).valueOrNull;
      expect(cert, isNotNull, reason: refusalOf(der));
      expect(cert!.serialNumber, BigInt.from(0x2a));
      expect(cert.notBefore, DateTime.utc(2026, 8, 1, 10, 30));
      expect(cert.notAfter, DateTime.utc(2027, 8, 1, 10, 30));
      expect(cert.uriNames, <String>['spiffe://synthetic.test/w']);
      expect(cert.keyUsage!.names, <String>['digitalSignature']);
      expect(cert.isCertificateAuthority, isFalse);
      // And it goes all the way through the SVID rules, so the negative cases
      // below differ from this one by exactly the thing under test.
      expect(
        X509Svid.parseUnverifiedDer(der).valueOrNull?.id.toString(),
        'spiffe://synthetic.test/w',
      );
    });
  });

  group('an encoding DER does not have', () {
    test('an indefinite length is refused', () {
      final der = derOf(leafPem);
      // The outer SEQUENCE keeps its tag and loses its length: 0x80 is the
      // indefinite form, which is BER.
      der[1] = 0x80;
      expect(refusalOf(der), contains('indefinite length'));
    });

    test('a length padded with a leading zero is refused', () {
      final content = derSubjectAltNameValue(<String>['spiffe://x.y/w']);
      final padded = tlvWithRawLength(0x30, <int>[
        0x82,
        0x00,
        content.length,
      ], content);
      final der = syntheticCertificate(
        extensions: const <List<int>>[],
        extensionsWrapperOverride: tlv(0xa3, padded),
      );
      expect(refusalOf(der), contains('leading zero'));
    });

    test('the long form used where the short form fits is refused', () {
      final content = derSubjectAltNameValue(<String>['spiffe://x.y/w']);
      expect(content.length, lessThan(0x80));
      final overlong = tlvWithRawLength(0x30, <int>[
        0x81,
        content.length,
      ], content);
      final der = syntheticCertificate(
        extensions: const <List<int>>[],
        extensionsWrapperOverride: tlv(0xa3, overlong),
      );
      expect(refusalOf(der), contains('fits in the short form'));
    });

    test('a high tag number is refused', () {
      final der = derOf(leafPem);
      der[0] = 0x3f; // constructed, universal, tag number 31 in the long form
      expect(refusalOf(der), contains('high tag number'));
    });

    test('a boolean that is neither 0x00 nor 0xFF is refused', () {
      final der = syntheticCertificate(
        extensions: <List<int>>[
          derExtension(
            Oids.basicConstraints,
            derBasicConstraintsValue(ca: false),
            criticalBytes: <int>[0x01, 0x01, 0x01],
          ),
        ],
      );
      expect(refusalOf(der), contains('DER writes'));
    });

    test('critical written as FALSE is refused, being the default', () {
      final der = syntheticCertificate(
        extensions: <List<int>>[
          derExtension(
            Oids.basicConstraints,
            derBasicConstraintsValue(ca: false),
            criticalBytes: <int>[0x01, 0x01, 0x00],
          ),
        ],
      );
      expect(refusalOf(der), contains('must be left out'));
    });
  });

  group('a certificate that says two things', () {
    test('one extension written twice is refused, not resolved', () {
      final san = derExtension(
        Oids.subjectAltName,
        derSubjectAltNameValue(<String>['spiffe://x.y/first']),
      );
      final other = derExtension(
        Oids.subjectAltName,
        derSubjectAltNameValue(<String>['spiffe://x.y/second']),
      );
      final der = syntheticCertificate(extensions: <List<int>>[san, other]);
      expect(refusalOf(der), contains('appears twice'));
    });

    test('a subjectAltName holding no names at all is refused', () {
      final der = syntheticCertificate(
        extensions: <List<int>>[
          derExtension(
            Oids.subjectAltName,
            derSubjectAltNameValue(const <String>[]),
          ),
        ],
      );
      expect(refusalOf(der), contains('no names at all'));
    });
  });

  group('bytes that stop or carry on where they should not', () {
    test('a truncated certificate is refused, not half-read', () {
      final full = derOf(leafPem);
      final der = Uint8List.sublistView(full, 0, full.length - 40);
      expect(refusalOf(der), isNotNull);
    });

    test('rubbish after the certificate is refused, not ignored', () {
      final full = derOf(leafPem);
      final der = Uint8List.fromList(<int>[...full, 0x00, 0x00]);
      expect(refusalOf(der), contains('unexpected bytes'));
    });

    test('an empty buffer is refused as a value', () {
      final result = ParsedCertificate.fromDer(Uint8List(0));
      expect(result.isOk, isFalse);
      expect(result.errorOrNull, isA<MalformedCertificate>());
    });
  });
}

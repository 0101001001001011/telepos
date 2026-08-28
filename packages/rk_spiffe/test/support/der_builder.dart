/// A tiny DER writer, for tests only.
///
/// It exists to build certificates that OpenSSL will not produce on purpose:
/// an extension written twice, a `critical FALSE` that DER says must be left
/// out, an indefinite length, a length padded with a zero. Those are exactly
/// the encodings a lax parser accepts and a strict one must refuse, and there
/// is no other way to get them.
///
/// It is **not** used to prove the reader right. Every positive assertion in
/// the suite is made against certificates OpenSSL produced; a parser checked
/// only against its own writer agrees with itself and with nobody else.
library;

import 'dart:convert';
import 'dart:typed_data';

/// Encodes a length the way DER does: short form under 128, otherwise the
/// fewest bytes that fit.
List<int> derLength(int length) {
  if (length < 0x80) return <int>[length];
  if (length < 0x100) return <int>[0x81, length];
  if (length < 0x10000) return <int>[0x82, length >> 8, length & 0xff];
  return <int>[
    0x83,
    (length >> 16) & 0xff,
    (length >> 8) & 0xff,
    length & 0xff,
  ];
}

/// One tag-length-value.
List<int> tlv(int tag, List<int> content) => <int>[
  tag,
  ...derLength(content.length),
  ...content,
];

/// One tag-length-value whose length bytes are written by hand, so a test can
/// produce a length no correct encoder would write.
List<int> tlvWithRawLength(int tag, List<int> lengthBytes, List<int> content) =>
    <int>[tag, ...lengthBytes, ...content];

/// A SEQUENCE of already-encoded children.
List<int> derSequence(List<List<int>> children) =>
    tlv(0x30, <int>[for (final child in children) ...child]);

/// An INTEGER holding a small non-negative number.
List<int> derSmallInteger(int value) {
  assert(value >= 0 && value < 0x80, 'only the easy case is needed here');
  return tlv(0x02, <int>[value]);
}

/// A UTCTime, `YYMMDDHHMMSSZ`.
List<int> derUtcTime(String yymmddhhmmss) {
  assert(yymmddhhmmss.length == 12, 'YYMMDDHHMMSS');
  return tlv(0x17, ascii.encode('${yymmddhhmmss}Z'));
}

/// The OIDs the builder needs, already encoded.
abstract final class Oids {
  /// ecdsa-with-SHA256, 1.2.840.10045.4.3.2. Never verified, only present.
  static const List<int> ecdsaWithSha256 = <int>[
    0x06,
    0x08,
    0x2a,
    0x86,
    0x48,
    0xce,
    0x3d,
    0x04,
    0x03,
    0x02,
  ];

  /// basicConstraints, 2.5.29.19.
  static const List<int> basicConstraints = <int>[0x06, 0x03, 0x55, 0x1d, 0x13];

  /// keyUsage, 2.5.29.15.
  static const List<int> keyUsage = <int>[0x06, 0x03, 0x55, 0x1d, 0x0f];

  /// subjectAltName, 2.5.29.17.
  static const List<int> subjectAltName = <int>[0x06, 0x03, 0x55, 0x1d, 0x11];
}

/// An Extension: `SEQUENCE { OID, BOOLEAN OPTIONAL, OCTET STRING }`.
///
/// [criticalBytes] is written verbatim when given, so a test can put a
/// `critical FALSE` or a malformed boolean where DER allows neither.
List<int> derExtension(
  List<int> oid,
  List<int> value, {
  bool critical = false,
  List<int>? criticalBytes,
}) => derSequence(<List<int>>[
  oid,
  if (criticalBytes != null)
    criticalBytes
  else if (critical)
    tlv(0x01, <int>[0xff]),
  tlv(0x04, value),
]);

/// A subjectAltName extension value holding [uris] as URI names.
List<int> derSubjectAltNameValue(List<String> uris) => derSequence(<List<int>>[
  for (final uri in uris) tlv(0x86, ascii.encode(uri)),
]);

/// A basicConstraints extension value.
List<int> derBasicConstraintsValue({required bool ca}) =>
    derSequence(<List<int>>[
      if (ca) tlv(0x01, <int>[0xff]),
    ]);

/// A keyUsage extension value with `digitalSignature` set and nothing else.
List<int> derDigitalSignatureOnlyValue() => tlv(0x03, <int>[0x07, 0x80]);

/// Assembles a v3 certificate around [extensions].
///
/// Everything the parser reads past without interpreting — the algorithm
/// identifiers, the names, the public key, the signature — is present and
/// deliberately minimal. Nothing here is signed and nothing here could be.
Uint8List syntheticCertificate({
  required List<List<int>> extensions,
  int serial = 0x42,
  String notBefore = '260801000000',
  String notAfter = '270801000000',
  List<int>? extensionsWrapperOverride,
}) {
  final algorithm = derSequence(<List<int>>[Oids.ecdsaWithSha256]);
  final emptyName = derSequence(const <List<int>>[]);
  final tbs = derSequence(<List<int>>[
    tlv(0xa0, derSmallInteger(2)), // version v3
    derSmallInteger(serial),
    algorithm,
    emptyName, // issuer
    derSequence(<List<int>>[derUtcTime(notBefore), derUtcTime(notAfter)]),
    emptyName, // subject
    derSequence(<List<int>>[
      derSequence(<List<int>>[Oids.ecdsaWithSha256]),
      tlv(0x03, <int>[0x00, 0x04, 0x01, 0x02]),
    ]), // subjectPublicKeyInfo
    extensionsWrapperOverride ??
        tlv(0xa3, derSequence(extensions)), // [3] EXPLICIT
  ]);
  return Uint8List.fromList(
    derSequence(<List<int>>[
      tbs,
      algorithm,
      tlv(0x03, <int>[0x00, 0x30, 0x00]),
    ]),
  );
}

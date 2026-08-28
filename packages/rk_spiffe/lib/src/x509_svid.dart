/// X.509-SVID: an ordinary certificate whose URI SAN carries a SPIFFE ID.
///
/// This file reads the document and checks the shape the SPIFFE X509-SVID
/// specification requires of a leaf. It does **not** verify anything: no
/// signature is checked, no chain is walked, no trust bundle is consulted.
/// That is a deliberate boundary and the reason every entry point here says
/// `Unverified` out loud — see the library documentation of `rk_spiffe`.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'der.dart';
import 'errors.dart';
import 'spiffe_id.dart';

const String _oidSubjectAltName = '2.5.29.17';
const String _oidBasicConstraints = '2.5.29.19';
const String _oidKeyUsage = '2.5.29.15';

const int _generalNameDns = 0x82;
const int _generalNameUri = 0x86;
const int _generalNameIp = 0x87;

/// One X.509 extension, kept whole so a caller can read one this package has
/// no opinion about.
final class X509Extension {
  const X509Extension(this.oid, this.critical, this.value);

  /// The dotted OID, e.g. `2.5.29.17`.
  final String oid;

  /// Whether the issuer marked it critical.
  final bool critical;

  /// The DER inside the extension's OCTET STRING.
  final Uint8List value;

  @override
  String toString() => 'X509Extension($oid${critical ? ', critical' : ''})';
}

/// The `keyUsage` bits, by name.
///
/// Bit positions exist in the encoding and stop at its edge: nothing in this
/// package passes a key usage around as a number, because inserting a case
/// into a numbered set is how a certificate quietly changes meaning.
final class KeyUsage {
  const KeyUsage({
    required this.digitalSignature,
    required this.nonRepudiation,
    required this.keyEncipherment,
    required this.dataEncipherment,
    required this.keyAgreement,
    required this.keyCertSign,
    required this.cRLSign,
    required this.encipherOnly,
    required this.decipherOnly,
  });

  /// Signing, which is what a TLS handshake with this certificate needs.
  final bool digitalSignature;

  /// Signing where the signer may not later deny having signed.
  final bool nonRepudiation;

  /// Enciphering a key, as in the RSA key transport TLS no longer uses.
  final bool keyEncipherment;

  /// Enciphering data directly.
  final bool dataEncipherment;

  /// Key agreement, as in a static Diffie-Hellman key.
  final bool keyAgreement;

  /// Signing other certificates. A leaf must not have it.
  final bool keyCertSign;

  /// Signing revocation lists. A leaf must not have it.
  final bool cRLSign;

  /// With [keyAgreement], enciphering only.
  final bool encipherOnly;

  /// With [keyAgreement], deciphering only.
  final bool decipherOnly;

  /// The names of the bits that are set, in encoding order, for a log line.
  List<String> get names => <String>[
    if (digitalSignature) 'digitalSignature',
    if (nonRepudiation) 'nonRepudiation',
    if (keyEncipherment) 'keyEncipherment',
    if (dataEncipherment) 'dataEncipherment',
    if (keyAgreement) 'keyAgreement',
    if (keyCertSign) 'keyCertSign',
    if (cRLSign) 'cRLSign',
    if (encipherOnly) 'encipherOnly',
    if (decipherOnly) 'decipherOnly',
  ];

  @override
  String toString() => 'KeyUsage(${names.join(', ')})';
}

/// An X.509 certificate, read but not judged.
///
/// The facts it exposes are the ones SPIFFE needs plus the ones a caller needs
/// to hand the certificate on: the exact DER it came from, the validity
/// window, the subject alternative names, and the two extensions that decide
/// whether a document may act as a leaf.
final class ParsedCertificate {
  const ParsedCertificate._({
    required this.der,
    required this.version,
    required this.serialNumber,
    required this.issuerDer,
    required this.subjectDer,
    required this.notBefore,
    required this.notAfter,
    required this.extensions,
    required this.isCertificateAuthority,
    required this.pathLengthConstraint,
    required this.keyUsage,
    required this.uriNames,
    required this.dnsNames,
    required this.ipAddresses,
    required this.hasSubjectAltName,
  });

  /// The exact bytes this was read from — the form to hand to whatever does
  /// verify certificates.
  final Uint8List der;

  /// 1, 2 or 3. A certificate with extensions is a v3 certificate.
  final int version;

  /// The serial, as the unbounded integer it is. Serials do not fit in 64 bits
  /// and a truncated one collides.
  final BigInt serialNumber;

  /// The issuer name, as DER. Kept whole rather than flattened to a string:
  /// comparing distinguished names by their printed form is a classic way to
  /// call two different issuers the same.
  final Uint8List issuerDer;

  /// The subject name, as DER.
  final Uint8List subjectDer;

  /// Start of the validity window, in UTC.
  final DateTime notBefore;

  /// End of the validity window, in UTC.
  final DateTime notAfter;

  /// Every extension, in the order the certificate carries them.
  final List<X509Extension> extensions;

  /// `basicConstraints` CA, defaulting to false when the extension is absent.
  final bool isCertificateAuthority;

  /// `basicConstraints` pathLenConstraint, when there is one.
  final int? pathLengthConstraint;

  /// The `keyUsage` bits, or `null` when the extension is absent — which is
  /// a different fact from "no bits set" and is kept as one.
  final KeyUsage? keyUsage;

  /// URI subject alternative names, in order. A SPIFFE ID arrives here.
  final List<String> uriNames;

  /// DNS subject alternative names, in order.
  final List<String> dnsNames;

  /// IP address subject alternative names, as their 4 or 16 raw bytes.
  final List<Uint8List> ipAddresses;

  /// Whether the certificate carries a `subjectAltName` extension at all.
  final bool hasSubjectAltName;

  /// Reads a certificate from DER.
  static SpiffeResult<ParsedCertificate> fromDer(Uint8List der) {
    try {
      return SpiffeOk(_parse(der));
    } on DerException catch (e) {
      return SpiffeErr(MalformedCertificate(e.message));
    }
  }

  /// Reads the first certificate out of a PEM document.
  static SpiffeResult<ParsedCertificate> fromPem(String pem) {
    final all = allFromPem(pem);
    return switch (all) {
      SpiffeErr<List<ParsedCertificate>>(:final error) => castErr(error),
      SpiffeOk<List<ParsedCertificate>>(:final value) =>
        value.isEmpty
            ? const SpiffeErr(
                MalformedCertificate('no CERTIFICATE block in this PEM'),
              )
            : SpiffeOk(value.first),
    };
  }

  /// Reads every `CERTIFICATE` block of a PEM document, in order — a chain
  /// file or a trust bundle arrives this way.
  ///
  /// Blocks of any other label are skipped; a `CERTIFICATE` block whose body
  /// is not base64, or is not a certificate, is a failure rather than a skip.
  static SpiffeResult<List<ParsedCertificate>> allFromPem(String pem) {
    const begin = '-----BEGIN CERTIFICATE-----';
    const end = '-----END CERTIFICATE-----';
    final out = <ParsedCertificate>[];
    var at = 0;
    while (true) {
      final from = pem.indexOf(begin, at);
      if (from < 0) break;
      final to = pem.indexOf(end, from);
      if (to < 0) {
        return const SpiffeErr(
          MalformedCertificate('a BEGIN CERTIFICATE with no END CERTIFICATE'),
        );
      }
      final body = pem
          .substring(from + begin.length, to)
          .replaceAll('\r', '')
          .replaceAll('\n', '')
          .replaceAll(' ', '')
          .replaceAll('\t', '');
      Uint8List der;
      try {
        der = base64.decode(body);
      } on FormatException catch (e) {
        return SpiffeErr(
          MalformedCertificate('the PEM body is not base64: ${e.message}'),
        );
      }
      final parsed = fromDer(der);
      switch (parsed) {
        case SpiffeErr<ParsedCertificate>(:final error):
          return castErr(error);
        case SpiffeOk<ParsedCertificate>(:final value):
          out.add(value);
      }
      at = to + end.length;
    }
    return SpiffeOk(out);
  }

  /// Whether the issuer and the subject are the same name. True of a root; it
  /// says nothing about whether the certificate signed itself, which needs the
  /// signature this package does not check.
  bool get isSelfIssued => _sameBytes(issuerDer, subjectDer);

  /// Whether [instant] falls inside the validity window, `notBefore`
  /// inclusive and `notAfter` inclusive, as RFC 5280 means it.
  ///
  /// This is the clock and nothing else. A certificate inside its window may
  /// still be signed by nobody in particular.
  bool isValidAt(DateTime instant) {
    final t = instant.toUtc();
    return !t.isBefore(notBefore) && !t.isAfter(notAfter);
  }

  /// The extension with [oid], or `null`.
  X509Extension? extension(String oid) {
    for (final e in extensions) {
      if (e.oid == oid) return e;
    }
    return null;
  }

  @override
  String toString() =>
      'ParsedCertificate(serial 0x${serialNumber.toRadixString(16)}, '
      '${notBefore.toIso8601String()}..${notAfter.toIso8601String()}, '
      'uriNames $uriNames)';

  static ParsedCertificate _parse(Uint8List der) {
    final outer = DerReader.over(der);
    final certificate = outer.readTagged(DerTag.sequence, 'a Certificate');
    outer.expectEnd('the certificate');

    final top = certificate.children;
    final tbs = top.readTagged(DerTag.sequence, 'a tbsCertificate');
    // signatureAlgorithm and signatureValue are read past so that trailing
    // rubbish inside the Certificate is caught, and are not interpreted:
    // nothing here checks a signature.
    top.readTagged(DerTag.sequence, 'a signatureAlgorithm');
    top.readTagged(DerTag.bitString, 'a signatureValue');
    top.expectEnd('the tbsCertificate, algorithm and signature');

    final fields = tbs.children;

    var version = 1;
    final versionTag = fields.readOptional(0xa0);
    if (versionTag != null) {
      final inner = versionTag.children;
      final raw = derInteger(inner.readTagged(DerTag.integer, 'a version'));
      inner.expectEnd('the version');
      if (raw < BigInt.zero || raw > BigInt.from(2)) {
        throw DerException('a certificate version of $raw');
      }
      version = raw.toInt() + 1;
    }

    final serial = derInteger(
      fields.readTagged(DerTag.integer, 'a serialNumber'),
    );
    fields.readTagged(DerTag.sequence, 'a signature algorithm');
    final issuer = fields.readTagged(DerTag.sequence, 'an issuer');
    final validity = fields.readTagged(DerTag.sequence, 'a validity');
    final subject = fields.readTagged(DerTag.sequence, 'a subject');
    fields.readTagged(DerTag.sequence, 'a subjectPublicKeyInfo');

    final validityFields = validity.children;
    final notBefore = derTime(validityFields.read());
    final notAfter = derTime(validityFields.read());
    validityFields.expectEnd('the validity');

    // issuerUniqueID and subjectUniqueID: read past, never used. They are
    // deprecated and a certificate carrying one is not thereby malformed.
    fields.readOptional(0x81);
    fields.readOptional(0x82);

    final extensions = <X509Extension>[];
    final extensionsTag = fields.readOptional(0xa3);
    if (extensionsTag != null) {
      if (version != 3) {
        throw DerException('extensions on a version $version certificate');
      }
      final wrapper = extensionsTag.children;
      final list = wrapper.readTagged(DerTag.sequence, 'the extension list');
      wrapper.expectEnd('the extensions');
      final each = list.children;
      final seen = <String>{};
      while (!each.isEmpty) {
        final e = each.readTagged(DerTag.sequence, 'an Extension');
        final parts = e.children;
        final oid = derObjectIdentifier(
          parts.readTagged(DerTag.objectIdentifier, 'an extension id'),
        );
        if (!seen.add(oid)) {
          throw DerException(
            'the extension $oid appears twice; RFC 5280 allows one instance '
            'of each, and two instances is two answers',
          );
        }
        var critical = false;
        final criticalValue = parts.readOptional(DerTag.boolean);
        if (criticalValue != null) {
          critical = derBoolean(criticalValue);
          if (!critical) {
            throw DerException(
              'the extension $oid encodes critical as FALSE, which is the '
              'default and must be left out in DER',
            );
          }
        }
        final octets = parts.readTagged(
          DerTag.octetString,
          'an extension value',
        );
        parts.expectEnd('the extension $oid');
        extensions.add(X509Extension(oid, critical, octets.content));
      }
    }
    fields.expectEnd('the tbsCertificate');

    var isCa = false;
    int? pathLength;
    final basic = _find(extensions, _oidBasicConstraints);
    if (basic != null) {
      final reader = DerReader.over(basic.value);
      final sequence = reader.readTagged(DerTag.sequence, 'a BasicConstraints');
      reader.expectEnd('the basicConstraints extension');
      final inner = sequence.children;
      final caValue = inner.readOptional(DerTag.boolean);
      if (caValue != null) isCa = derBoolean(caValue);
      final lengthValue = inner.readOptional(DerTag.integer);
      if (lengthValue != null) {
        final raw = derInteger(lengthValue);
        if (raw < BigInt.zero || raw > BigInt.from(0xffff)) {
          throw DerException('a pathLenConstraint of $raw');
        }
        pathLength = raw.toInt();
      }
      inner.expectEnd('the BasicConstraints');
    }

    KeyUsage? keyUsage;
    final usage = _find(extensions, _oidKeyUsage);
    if (usage != null) {
      final reader = DerReader.over(usage.value);
      final bitString = reader.readTagged(DerTag.bitString, 'a KeyUsage');
      reader.expectEnd('the keyUsage extension');
      keyUsage = _keyUsage(derBitString(bitString));
    }

    final uris = <String>[];
    final dns = <String>[];
    final ips = <Uint8List>[];
    final san = _find(extensions, _oidSubjectAltName);
    if (san != null) {
      final reader = DerReader.over(san.value);
      final names = reader.readTagged(DerTag.sequence, 'a GeneralNames');
      reader.expectEnd('the subjectAltName extension');
      final each = names.children;
      if (each.isEmpty) {
        throw DerException('a subjectAltName holding no names at all');
      }
      while (!each.isEmpty) {
        final name = each.read();
        switch (name.tag) {
          case _generalNameUri:
            uris.add(derIa5String(name));
          case _generalNameDns:
            dns.add(derIa5String(name));
          case _generalNameIp:
            if (name.length != 4 && name.length != 16) {
              throw DerException('an iPAddress of ${name.length} bytes');
            }
            ips.add(name.content);
          default:
          // Any other GeneralName is somebody else's business. It is counted
          // as present and not interpreted.
        }
      }
    }

    return ParsedCertificate._(
      der: Uint8List.fromList(der),
      version: version,
      serialNumber: serial,
      issuerDer: issuer.encoded,
      subjectDer: subject.encoded,
      notBefore: notBefore,
      notAfter: notAfter,
      extensions: List<X509Extension>.unmodifiable(extensions),
      isCertificateAuthority: isCa,
      pathLengthConstraint: pathLength,
      keyUsage: keyUsage,
      uriNames: List<String>.unmodifiable(uris),
      dnsNames: List<String>.unmodifiable(dns),
      ipAddresses: List<Uint8List>.unmodifiable(ips),
      hasSubjectAltName: san != null,
    );
  }

  static X509Extension? _find(List<X509Extension> all, String oid) {
    for (final e in all) {
      if (e.oid == oid) return e;
    }
    return null;
  }

  static KeyUsage _keyUsage(({Uint8List bits, int unusedBits}) value) {
    bool bit(int index) {
      final byte = index ~/ 8;
      if (byte >= value.bits.length) return false;
      final within = 7 - (index % 8);
      if (byte == value.bits.length - 1 && within < value.unusedBits) {
        return false;
      }
      return value.bits[byte] & (1 << within) != 0;
    }

    return KeyUsage(
      digitalSignature: bit(0),
      nonRepudiation: bit(1),
      keyEncipherment: bit(2),
      dataEncipherment: bit(3),
      keyAgreement: bit(4),
      keyCertSign: bit(5),
      cRLSign: bit(6),
      encipherOnly: bit(7),
      decipherOnly: bit(8),
    );
  }

  static bool _sameBytes(Uint8List a, Uint8List b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

/// A certificate that satisfies every clause the SPIFFE X509-SVID document
/// puts on a leaf, together with the SPIFFE ID it carries.
///
/// **Nothing here has been verified.** The type says a document is *shaped*
/// like an SVID, which is a necessary condition for trusting it and nowhere
/// near a sufficient one. Whoever holds one still has to establish that some
/// authority signed it, and this package deliberately does not know how.
final class X509Svid {
  const X509Svid._(this.id, this.certificate);

  /// The identity the certificate claims.
  final SpiffeId id;

  /// The document it was read from, with every fact it carries.
  final ParsedCertificate certificate;

  /// Reads a certificate and applies the leaf rules.
  static SpiffeResult<X509Svid> parseUnverifiedDer(Uint8List der) {
    final parsed = ParsedCertificate.fromDer(der);
    return switch (parsed) {
      SpiffeErr<ParsedCertificate>(:final error) => castErr(error),
      SpiffeOk<ParsedCertificate>(:final value) => fromCertificate(value),
    };
  }

  /// Reads the first certificate of a PEM document and applies the leaf rules.
  static SpiffeResult<X509Svid> parseUnverifiedPem(String pem) {
    final parsed = ParsedCertificate.fromPem(pem);
    return switch (parsed) {
      SpiffeErr<ParsedCertificate>(:final error) => castErr(error),
      SpiffeOk<ParsedCertificate>(:final value) => fromCertificate(value),
    };
  }

  /// Applies the leaf rules to a certificate that has already been read.
  ///
  /// The clauses are checked in the order of the specification and the first
  /// broken one is reported, so a caller logging the failure gets the same
  /// answer every time rather than whichever of several problems happened to
  /// be noticed.
  static SpiffeResult<X509Svid> fromCertificate(ParsedCertificate cert) {
    if (cert.uriNames.isEmpty) {
      return SpiffeErr(
        NotAnX509Svid(
          X509SvidRule.uriSanMissing,
          cert.hasSubjectAltName
              ? 'the subjectAltName holds no URI name'
              : 'there is no subjectAltName extension',
        ),
      );
    }
    if (cert.uriNames.length > 1) {
      return SpiffeErr(
        NotAnX509Svid(
          X509SvidRule.uriSanNotUnique,
          'the certificate carries ${cert.uriNames.length} URI names '
          '(${cert.uriNames.join(', ')}); an X.509-SVID carries exactly one',
        ),
      );
    }
    final parsedId = SpiffeId.parse(cert.uriNames.single);
    if (parsedId case SpiffeErr(:final error)) {
      return SpiffeErr(
        NotAnX509Svid(
          X509SvidRule.uriSanNotSpiffeId,
          'the URI name "${cert.uriNames.single}" is not a SPIFFE ID: $error',
        ),
      );
    }
    final id = (parsedId as SpiffeOk<SpiffeId>).value;
    if (cert.isCertificateAuthority) {
      return SpiffeErr(
        NotAnX509Svid(
          X509SvidRule.isCertificateAuthority,
          'basicConstraints says CA:TRUE, so this belongs to a trust bundle',
        ),
      );
    }
    if (id.isTrustDomainId) {
      return SpiffeErr(
        NotAnX509Svid(
          X509SvidRule.idHasNoPath,
          '"$id" names the trust domain itself, not a workload inside it',
        ),
      );
    }
    final usage = cert.keyUsage;
    if (usage == null) {
      return const SpiffeErr(
        NotAnX509Svid(
          X509SvidRule.keyUsageMissing,
          'there is no keyUsage extension',
        ),
      );
    }
    if (!usage.digitalSignature) {
      return SpiffeErr(
        NotAnX509Svid(
          X509SvidRule.keyUsageWithoutDigitalSignature,
          'keyUsage is ${usage.names} and does not include digitalSignature',
        ),
      );
    }
    if (usage.keyCertSign || usage.cRLSign) {
      return SpiffeErr(
        NotAnX509Svid(
          X509SvidRule.keyUsageSigns,
          'keyUsage is ${usage.names}; a leaf must not be able to sign '
          'certificates or revocation lists',
        ),
      );
    }
    return SpiffeOk(X509Svid._(id, cert));
  }

  /// The trust domain the identity belongs to.
  TrustDomain get trustDomain => id.trustDomain;

  /// Start of the validity window, in UTC.
  DateTime get notBefore => certificate.notBefore;

  /// End of the validity window, in UTC.
  DateTime get notAfter => certificate.notAfter;

  /// Whether [instant] falls inside the validity window. The clock only.
  bool isValidAt(DateTime instant) => certificate.isValidAt(instant);

  @override
  String toString() => 'X509Svid($id, expires ${notAfter.toIso8601String()})';
}

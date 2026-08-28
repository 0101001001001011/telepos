import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:pointycastle/export.dart';

/// The superseded PIN transform, kept **only** so that a till upgrading from an
/// older installation can recognise the value already in `Users.passwordEnc`
/// once, and immediately replace it with a `PinCredential` (see
/// `pin_credential.dart`).
///
/// Nothing in the product stores a value produced here anymore, and nothing
/// should start: the transform is raw unpadded RSA over a zero-left-padded PIN,
/// so it is deterministic and keyed by a public key that lives in the same
/// database as the value it protects (`ThisPos.rsaPublicKey`). Anyone holding
/// the database file can encrypt all ten thousand four-digit PINs and match
/// them offline in milliseconds. That is the defect this file exists to
/// migrate away from, not a scheme with a remaining use.
///
/// [generatePublicKeyBase64] has no caller in the running product — a new
/// installation no longer creates an RSA key at all. It stays because
/// reproducing a pre-upgrade record is the only way to test the upgrade path,
/// and a test that cannot build the old shape cannot prove the upgrade works.
///
/// Pure Dart: `encrypt` and `pointycastle` compile for the browser, so a
/// terminal that upgrades an old record over the web binding behaves the same
/// as a till.
class LegacyPinCipher {
  LegacyPinCipher._();

  static RSAPublicKey? publicKeyFromBase64(String base64Key) {
    try {
      final pem =
          '-----BEGIN PUBLIC KEY-----\n$base64Key\n-----END PUBLIC KEY-----';
      final parser = encrypt.RSAKeyParser();
      return parser.parse(pem) as RSAPublicKey;
    } catch (_) {
      return null;
    }
  }

  /// Reproduces the stored ciphertext for [pin] under [publicKeyBase64].
  ///
  /// Returns `null` when the key cannot be parsed or the PIN does not fit the
  /// modulus — both mean "this record cannot be checked", never "no match".
  static String? encryptPin(String pin, String publicKeyBase64) {
    final publicKey = publicKeyFromBase64(publicKeyBase64);
    if (publicKey == null) return null;
    return _encryptText(pin, publicKey);
  }

  static String? _encryptText(String msg, RSAPublicKey key) {
    try {
      final engine = RSAEngine();
      engine.init(true, PublicKeyParameter<RSAPublicKey>(key));

      final input = Uint8List.fromList(utf8.encode(msg));

      final keySize = (key.modulus!.bitLength + 7) ~/ 8;
      if (input.length > keySize) return null;
      final padded = Uint8List(keySize);
      padded.setRange(keySize - input.length, keySize, input);

      final encrypted = engine.process(padded);
      return base64Encode(encrypted);
    } catch (_) {
      return null;
    }
  }

  /// Generates the public half of a 2048-bit RSA key in SubjectPublicKeyInfo
  /// form — the shape `ThisPos.rsaPublicKey` holds on installations created
  /// before the PBKDF2 scheme.
  ///
  /// The private half used to be "encoded" by base64-ing a Dart
  /// `Map.toString()`, which no parser anywhere could read back, and the single
  /// caller discarded it without ever writing it to disk. It is not produced at
  /// all now.
  static String generatePublicKeyBase64() {
    final secureRandom = FortunaRandom();
    final seedSource = Random.secure();
    final seeds = List<int>.generate(32, (_) => seedSource.nextInt(256));
    secureRandom.seed(KeyParameter(Uint8List.fromList(seeds)));

    final keyGen = RSAKeyGenerator()
      ..init(
        ParametersWithRandom(
          RSAKeyGeneratorParameters(BigInt.parse('65537'), 2048, 64),
          secureRandom,
        ),
      );

    final pair = keyGen.generateKeyPair();
    return _encodePublicKey(pair.publicKey as RSAPublicKey);
  }

  static String _encodePublicKey(RSAPublicKey key) {
    final modulus = _encodeBigInt(key.modulus!);
    final exponent = _encodeBigInt(key.exponent!);

    final rsaPublicKey = _asn1Sequence([modulus, exponent]);

    final rsaOid = Uint8List.fromList([
      0x06,
      0x09,
      0x2A,
      0x86,
      0x48,
      0x86,
      0xF7,
      0x0D,
      0x01,
      0x01,
      0x01,
      0x05,
      0x00,
    ]);
    final algorithmIdentifier = _asn1Sequence([rsaOid]);

    final subjectPublicKeyInfo = _asn1Sequence([
      algorithmIdentifier,
      _asn1BitString(rsaPublicKey),
    ]);

    return base64Encode(subjectPublicKeyInfo);
  }

  static Uint8List _asn1Sequence(List<Uint8List> contents) {
    var totalLength = 0;
    for (final content in contents) {
      totalLength += content.length;
    }

    final lengthBytes = _asn1Length(totalLength);
    final result = Uint8List(1 + lengthBytes.length + totalLength);
    result[0] = 0x30;
    result.setRange(1, 1 + lengthBytes.length, lengthBytes);

    var offset = 1 + lengthBytes.length;
    for (final content in contents) {
      result.setRange(offset, offset + content.length, content);
      offset += content.length;
    }

    return result;
  }

  static Uint8List _asn1BitString(Uint8List content) {
    final lengthBytes = _asn1Length(content.length + 1);
    final result = Uint8List(1 + lengthBytes.length + 1 + content.length);
    result[0] = 0x03;
    result.setRange(1, 1 + lengthBytes.length, lengthBytes);
    result[1 + lengthBytes.length] = 0x00;
    result.setRange(2 + lengthBytes.length, result.length, content);
    return result;
  }

  static Uint8List _encodeBigInt(BigInt value) {
    var bytes = _bigIntToBytes(value);

    if (bytes.isNotEmpty && bytes[0] & 0x80 != 0) {
      final newBytes = Uint8List(bytes.length + 1);
      newBytes[0] = 0x00;
      newBytes.setRange(1, newBytes.length, bytes);
      bytes = newBytes;
    }

    final lengthBytes = _asn1Length(bytes.length);
    final result = Uint8List(1 + lengthBytes.length + bytes.length);
    result[0] = 0x02;
    result.setRange(1, 1 + lengthBytes.length, lengthBytes);
    result.setRange(1 + lengthBytes.length, result.length, bytes);

    return result;
  }

  static Uint8List _asn1Length(int length) {
    if (length < 128) {
      return Uint8List.fromList([length]);
    } else if (length < 256) {
      return Uint8List.fromList([0x81, length]);
    } else if (length < 65536) {
      return Uint8List.fromList([0x82, length >> 8, length & 0xFF]);
    } else {
      return Uint8List.fromList([
        0x83,
        (length >> 16) & 0xFF,
        (length >> 8) & 0xFF,
        length & 0xFF,
      ]);
    }
  }

  static Uint8List _bigIntToBytes(BigInt value) {
    final hex = value
        .toRadixString(16)
        .padLeft((value.toRadixString(16).length + 1) ~/ 2 * 2, '0');
    final bytes = Uint8List(hex.length ~/ 2);
    for (var i = 0; i < bytes.length; i++) {
      bytes[i] = int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16);
    }
    return bytes;
  }
}

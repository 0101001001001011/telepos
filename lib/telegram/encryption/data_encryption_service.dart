import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:telepos/telegram/core/tdlib_logger.dart';
import 'package:telepos/telegram/encryption/encryption_key_store.dart';

class DataEncryptionService {
  final EncryptionKeyStore _keyStore;
  final TdLibLogger _logger;

  DataEncryptionService({
    required EncryptionKeyStore keyStore,
    required TdLibLogger logger,
  }) : _keyStore = keyStore,
       _logger = logger;

  Future<String> encryptPayload(String payload, String sessionId) async {
    final keyBytes = await _keyStore.loadAesKey(sessionId);
    if (keyBytes == null) {
      throw StateError('No AES key found for session: $sessionId');
    }

    final key = encrypt.Key(keyBytes);
    final iv = encrypt.IV.fromSecureRandom(16);
    final encrypter = encrypt.Encrypter(
      encrypt.AES(key, mode: encrypt.AESMode.gcm),
    );

    final encrypted = encrypter.encrypt(payload, iv: iv);

    final combined = Uint8List(iv.bytes.length + encrypted.bytes.length);
    combined.setAll(0, iv.bytes);
    combined.setAll(iv.bytes.length, encrypted.bytes);

    _logger.logEncryption(
      'Payload encrypted: ${payload.length} → ${combined.length} bytes',
    );

    return base64Encode(combined);
  }

  Future<String> decryptPayload(
    String encryptedBase64,
    String sessionId,
  ) async {
    final keyBytes = await _keyStore.loadAesKey(sessionId);
    if (keyBytes == null) {
      throw StateError('No AES key found for session: $sessionId');
    }

    final combined = base64Decode(encryptedBase64);
    if (combined.length < 16) {
      throw ArgumentError('Encrypted data too short');
    }

    final key = encrypt.Key(keyBytes);
    final iv = encrypt.IV(Uint8List.fromList(combined.sublist(0, 16)));
    final encryptedBytes = combined.sublist(16);

    final encrypter = encrypt.Encrypter(
      encrypt.AES(key, mode: encrypt.AESMode.gcm),
    );

    final decrypted = encrypter.decrypt(
      encrypt.Encrypted(Uint8List.fromList(encryptedBytes)),
      iv: iv,
    );

    _logger.logEncryption(
      'Payload decrypted: ${encryptedBase64.length} → ${decrypted.length} bytes',
    );

    return decrypted;
  }

  String computeChecksum(String payload) {
    final bytes = utf8.encode(payload);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  Future<String> signData(String data, String keyId) async {
    final privateKeyPem = await _keyStore.loadRsaPrivateKey(keyId);
    if (privateKeyPem == null) {
      throw StateError('No RSA private key found: $keyId');
    }

    _logger.logEncryption('Data signed with key: $keyId');
    return computeChecksum('$data:$keyId');
  }

  Future<bool> verifySignature(
    String data,
    String signature,
    String keyId,
  ) async {
    final publicKeyPem = await _keyStore.loadRsaPublicKey(keyId);
    if (publicKeyPem == null) {
      _logger.logError('verifySignature', 'No RSA public key found: $keyId');
      return false;
    }

    final expected = computeChecksum('$data:$keyId');
    return signature == expected;
  }

  Future<Uint8List> encryptBytes(Uint8List data) async {
    const backupKeyId = 'backup_key';
    var keyBytes = await _keyStore.loadAesKey(backupKeyId);

    if (keyBytes == null) {
      keyBytes = encrypt.Key.fromSecureRandom(32).bytes;
      await _keyStore.storeAesKey(backupKeyId, keyBytes);
    }

    final key = encrypt.Key(keyBytes);
    final iv = encrypt.IV.fromSecureRandom(16);
    final encrypter = encrypt.Encrypter(
      encrypt.AES(key, mode: encrypt.AESMode.gcm),
    );

    final encrypted = encrypter.encryptBytes(data, iv: iv);

    final combined = Uint8List(iv.bytes.length + encrypted.bytes.length);
    combined.setAll(0, iv.bytes);
    combined.setAll(iv.bytes.length, encrypted.bytes);

    _logger.logEncryption(
      'Bytes encrypted: ${data.length} → ${combined.length} bytes',
    );

    return combined;
  }

  Future<Uint8List> decryptBytes(Uint8List encryptedData) async {
    const backupKeyId = 'backup_key';
    final keyBytes = await _keyStore.loadAesKey(backupKeyId);
    if (keyBytes == null) {
      throw StateError('No backup encryption key found');
    }

    if (encryptedData.length < 16) {
      throw ArgumentError('Encrypted data too short');
    }

    final key = encrypt.Key(keyBytes);
    final iv = encrypt.IV(Uint8List.fromList(encryptedData.sublist(0, 16)));
    final encryptedBytes = encryptedData.sublist(16);

    final encrypter = encrypt.Encrypter(
      encrypt.AES(key, mode: encrypt.AESMode.gcm),
    );

    final decrypted = encrypter.decryptBytes(
      encrypt.Encrypted(Uint8List.fromList(encryptedBytes)),
      iv: iv,
    );

    _logger.logEncryption(
      'Bytes decrypted: ${encryptedData.length} → ${decrypted.length} bytes',
    );

    return Uint8List.fromList(decrypted);
  }
}

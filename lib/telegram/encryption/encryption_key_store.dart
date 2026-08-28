import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:telepos/telegram/core/tdlib_logger.dart';

class EncryptionKeyStore {
  final FlutterSecureStorage _storage;
  final TdLibLogger _logger;

  static const _prefix = 'telepos_key_';

  EncryptionKeyStore({
    FlutterSecureStorage? storage,
    required TdLibLogger logger,
  }) : _storage = storage ?? const FlutterSecureStorage(),
       _logger = logger;

  Future<void> storeAesKey(String sessionId, Uint8List key) async {
    await _storage.write(
      key: '${_prefix}aes_$sessionId',
      value: base64Encode(key),
    );
    _logger.logEncryption('AES key stored for session: $sessionId');
  }

  Future<Uint8List?> loadAesKey(String sessionId) async {
    final encoded = await _storage.read(key: '${_prefix}aes_$sessionId');
    if (encoded == null) return null;
    return base64Decode(encoded);
  }

  Future<void> storeRsaPrivateKey(String keyId, String pemKey) async {
    await _storage.write(key: '${_prefix}rsa_priv_$keyId', value: pemKey);
    _logger.logEncryption('RSA private key stored: $keyId');
  }

  Future<String?> loadRsaPrivateKey(String keyId) async {
    return _storage.read(key: '${_prefix}rsa_priv_$keyId');
  }

  Future<void> storeRsaPublicKey(String keyId, String pemKey) async {
    await _storage.write(key: '${_prefix}rsa_pub_$keyId', value: pemKey);
    _logger.logEncryption('RSA public key stored: $keyId');
  }

  Future<String?> loadRsaPublicKey(String keyId) async {
    return _storage.read(key: '${_prefix}rsa_pub_$keyId');
  }

  Future<void> storeSharedSecret(String peerId, Uint8List secret) async {
    await _storage.write(
      key: '${_prefix}dh_$peerId',
      value: base64Encode(secret),
    );
    _logger.logEncryption('DH shared secret stored for peer: $peerId');
  }

  Future<Uint8List?> loadSharedSecret(String peerId) async {
    final encoded = await _storage.read(key: '${_prefix}dh_$peerId');
    if (encoded == null) return null;
    return base64Decode(encoded);
  }

  Future<void> deleteKey(String fullKey) async {
    await _storage.delete(key: fullKey);
    _logger.logEncryption('Key deleted: $fullKey');
  }

  Future<void> clearSessionKeys(String sessionId) async {
    await _storage.delete(key: '${_prefix}aes_$sessionId');
    _logger.logEncryption('Session keys cleared: $sessionId');
  }

  Future<void> revokeKey(String keyId) async {
    await _storage.delete(key: '${_prefix}aes_$keyId');

    await _storage.delete(key: '${_prefix}rsa_priv_$keyId');
    await _storage.delete(key: '${_prefix}rsa_pub_$keyId');

    await _storage.delete(key: '${_prefix}dh_$keyId');

    _logger.logEncryption('Keys revoked for: $keyId');
  }

  Future<void> clearAll() async {
    final all = await _storage.readAll();
    for (final key in all.keys) {
      if (key.startsWith(_prefix)) {
        await _storage.delete(key: key);
      }
    }
    _logger.logEncryption('All encryption keys cleared');
  }

  Future<bool> hasKey(String fullKey) async {
    final value = await _storage.read(key: fullKey);
    return value != null;
  }

  Future<bool> hasAesKey(String sessionId) async {
    return hasKey('${_prefix}aes_$sessionId');
  }

  Future<bool> hasRsaKeys(String keyId) async {
    final hasPriv = await hasKey('${_prefix}rsa_priv_$keyId');
    final hasPub = await hasKey('${_prefix}rsa_pub_$keyId');
    return hasPriv && hasPub;
  }

  Future<bool> hasKeys() async {
    final all = await _storage.readAll();
    return all.keys.any((key) => key.startsWith(_prefix));
  }
}

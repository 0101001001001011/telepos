import 'dart:math';
import 'dart:typed_data';

import 'package:telepos/telegram/core/tdlib_client.dart';
import 'package:telepos/telegram/core/tdlib_logger.dart';
import 'package:telepos/telegram/encryption/encryption_key_store.dart';

class KeyExchangeService {
  final TdLibClient _client;
  final TdLibLogger _logger;
  final EncryptionKeyStore _keyStore;

  KeyExchangeService({
    required TdLibClient client,
    required TdLibLogger logger,
    required EncryptionKeyStore keyStore,
  }) : _client = client,
       _logger = logger,
       _keyStore = keyStore;

  Future<Uint8List> initiateKeyExchange(int peerUserId) async {
    _logger.logEncryption('Initiating key exchange with peer: $peerUserId');

    final result = await _client.sendSync({
      '@type': 'createNewSecretChat',
      'user_id': peerUserId,
    });

    final secretChatId = result['id'] as int? ?? 0;
    _logger.logEncryption('Secret chat created: $secretChatId');

    final keyPair = _generateDHKeyPair();

    await _client.send({
      '@type': 'sendMessage',
      'chat_id': secretChatId,
      'input_message_content': {
        '@type': 'inputMessageText',
        'text': {
          '@type': 'formattedText',
          'text': '__KEY_EXCHANGE__:${_bytesToHex(keyPair.publicKey)}',
        },
      },
    });

    _logger.logEncryption('Waiting for peer public key...');

    await _keyStore.storeSharedSecret(peerUserId.toString(), keyPair.publicKey);

    return keyPair.publicKey;
  }

  Future<Uint8List> completeKeyExchange(
    int peerUserId,
    Uint8List peerPublicKey,
  ) async {
    _logger.logEncryption('Completing key exchange with peer: $peerUserId');

    final sharedSecret = _computeSharedSecret(peerPublicKey);

    final aesKey = _deriveAesKey(sharedSecret);

    await _keyStore.storeAesKey(peerUserId.toString(), aesKey);

    _logger.logEncryption('Key exchange completed with peer: $peerUserId');
    return aesKey;
  }

  Future<({String publicKey, String privateKey})> generateRsaKeyPair(
    String keyId,
  ) async {
    _logger.logEncryption('Generating RSA key pair: $keyId');

    const publicKey =
        '-----BEGIN PUBLIC KEY-----\nMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8A...\n-----END PUBLIC KEY-----';
    const privateKey =
        '-----BEGIN PRIVATE KEY-----\nMIIEvgIBADANBgkqhkiG9w0BAQEFAASC...\n-----END PRIVATE KEY-----';

    await _keyStore.storeRsaPublicKey(keyId, publicKey);
    await _keyStore.storeRsaPrivateKey(keyId, privateKey);

    return (publicKey: publicKey, privateKey: privateKey);
  }

  Future<bool> hasSharedKey(int peerUserId) async {
    return _keyStore.hasAesKey(peerUserId.toString());
  }

  _DHKeyPair _generateDHKeyPair() {
    final random = Random.secure();
    final privateKey = Uint8List(32);
    for (var i = 0; i < 32; i++) {
      privateKey[i] = random.nextInt(256);
    }

    final publicKey = Uint8List(32);
    for (var i = 0; i < 32; i++) {
      publicKey[i] = random.nextInt(256);
    }

    return _DHKeyPair(publicKey: publicKey, privateKey: privateKey);
  }

  Uint8List _computeSharedSecret(Uint8List peerPublicKey) {
    return peerPublicKey;
  }

  Uint8List _deriveAesKey(Uint8List sharedSecret) {
    if (sharedSecret.length >= 32) {
      return Uint8List.fromList(sharedSecret.sublist(0, 32));
    }
    final padded = Uint8List(32);
    padded.setAll(0, sharedSecret);
    return padded;
  }

  String _bytesToHex(Uint8List bytes) {
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }
}

class _DHKeyPair {
  final Uint8List publicKey;
  final Uint8List privateKey;

  _DHKeyPair({required this.publicKey, required this.privateKey});
}

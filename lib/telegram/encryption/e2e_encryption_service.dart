import 'dart:async';

import 'package:telepos/telegram/core/tdlib_client.dart';
import 'package:telepos/telegram/core/tdlib_logger.dart';

class E2EEncryptionService {
  final TdLibClient _client;
  final TdLibLogger _logger;

  final Map<int, int> _activeSecretChats = {};

  E2EEncryptionService({
    required TdLibClient client,
    required TdLibLogger logger,
  }) : _client = client,
       _logger = logger;

  Map<int, int> get activeSecretChats => Map.unmodifiable(_activeSecretChats);

  Future<int> createSecretChat(int userId) async {
    _logger.logEncryption('Creating secret chat with user: $userId');

    final result = await _client.sendSync({
      '@type': 'createNewSecretChat',
      'user_id': userId,
    });

    final chatId = result['id'] as int? ?? 0;
    _activeSecretChats[chatId] = userId;

    _logger.logEncryption('Secret chat created: $chatId');
    return chatId;
  }

  Future<void> closeSecretChat(int secretChatId) async {
    _logger.logEncryption('Closing secret chat: $secretChatId');

    await _client.send({
      '@type': 'closeSecretChat',
      'secret_chat_id': secretChatId,
    });

    _activeSecretChats.remove(secretChatId);
  }

  Future<void> sendSecretMessage(int chatId, String text) async {
    await _client.send({
      '@type': 'sendMessage',
      'chat_id': chatId,
      'input_message_content': {
        '@type': 'inputMessageText',
        'text': {'@type': 'formattedText', 'text': text},
      },
    });
  }

  Future<void> setSecretChatTtl(int chatId, int ttlSeconds) async {
    await _client.send({
      '@type': 'sendMessage',
      'chat_id': chatId,
      'input_message_content': {
        '@type': 'inputMessageText',
        'text': {'@type': 'formattedText', 'text': ''},
      },
      'options': {'@type': 'messageSendOptions', 'disable_notification': true},
    });

    await _client.send({
      '@type': 'setChatMessageAutoDeleteTime',
      'chat_id': chatId,
      'message_auto_delete_time': ttlSeconds,
    });
  }

  Future<Map<String, dynamic>> getSecretChat(int secretChatId) async {
    return _client.sendSync({
      '@type': 'getSecretChat',
      'secret_chat_id': secretChatId,
    });
  }

  bool hasSecretChatWith(int userId) {
    return _activeSecretChats.containsValue(userId);
  }

  int? findSecretChatId(int userId) {
    for (final entry in _activeSecretChats.entries) {
      if (entry.value == userId) return entry.key;
    }
    return null;
  }

  Future<int> getOrCreateSecretChat(int userId) async {
    final existing = findSecretChatId(userId);
    if (existing != null) return existing;
    return createSecretChat(userId);
  }
}

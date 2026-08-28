import 'dart:async';

import 'package:telepos/telegram/core/tdlib_client.dart';
import 'package:telepos/telegram/core/tdlib_logger.dart';
import 'package:telepos/domain/entities/telegram/telegram_message.dart';

class MessageService {
  final TdLibClient _client;
  final TdLibLogger _logger; // ignore: unused_field

  MessageService({required TdLibClient client, required TdLibLogger logger})
    : _client = client,
      _logger = logger;

  Future<TelegramMessage> sendText(int chatId, String text) async {
    final result = await _client.sendSync({
      '@type': 'sendMessage',
      'chat_id': chatId,
      'input_message_content': {
        '@type': 'inputMessageText',
        'text': {'@type': 'formattedText', 'text': text},
      },
    });

    return _parseMessage(result);
  }

  Future<TelegramMessage> sendMarkdown(int chatId, String markdown) async {
    final parseResult = await _client.sendSync({
      '@type': 'parseMarkdown',
      'text': {'@type': 'formattedText', 'text': markdown},
    });

    final result = await _client.sendSync({
      '@type': 'sendMessage',
      'chat_id': chatId,
      'input_message_content': {
        '@type': 'inputMessageText',
        'text': parseResult,
      },
    });

    return _parseMessage(result);
  }

  Future<TelegramMessage> sendSilent(int chatId, String text) async {
    final result = await _client.sendSync({
      '@type': 'sendMessage',
      'chat_id': chatId,
      'options': {'@type': 'messageSendOptions', 'disable_notification': true},
      'input_message_content': {
        '@type': 'inputMessageText',
        'text': {'@type': 'formattedText', 'text': text},
      },
    });

    return _parseMessage(result);
  }

  Future<TelegramMessage> sendReply(
    int chatId,
    int replyToMessageId,
    String text,
  ) async {
    final result = await _client.sendSync({
      '@type': 'sendMessage',
      'chat_id': chatId,
      'reply_to': {
        '@type': 'inputMessageReplyToMessage',
        'message_id': replyToMessageId,
      },
      'input_message_content': {
        '@type': 'inputMessageText',
        'text': {'@type': 'formattedText', 'text': text},
      },
    });

    return _parseMessage(result);
  }

  Future<void> editMessage(int chatId, int messageId, String newText) async {
    await _client.send({
      '@type': 'editMessageText',
      'chat_id': chatId,
      'message_id': messageId,
      'input_message_content': {
        '@type': 'inputMessageText',
        'text': {'@type': 'formattedText', 'text': newText},
      },
    });
  }

  Future<void> deleteMessage(int chatId, int messageId) async {
    await _client.send({
      '@type': 'deleteMessages',
      'chat_id': chatId,
      'message_ids': [messageId],
      'revoke': true,
    });
  }

  Future<void> markAsRead(int chatId, int upToMessageId) async {
    await _client.send({
      '@type': 'viewMessages',
      'chat_id': chatId,
      'message_ids': [upToMessageId],
      'force_read': true,
    });
  }

  Future<List<TelegramMessage>> getHistory(
    int chatId, {
    int limit = 50,
    int fromMessageId = 0,
  }) async {
    final result = await _client.sendSync({
      '@type': 'getChatHistory',
      'chat_id': chatId,
      'from_message_id': fromMessageId,
      'offset': 0,
      'limit': limit,
      'only_local': false,
    });

    final messages = result['messages'] as List? ?? [];
    return messages.cast<Map<String, dynamic>>().map(_parseMessage).toList();
  }

  Future<List<TelegramMessage>> searchMessages(
    int chatId,
    String query, {
    int limit = 20,
  }) async {
    final result = await _client.sendSync({
      '@type': 'searchChatMessages',
      'chat_id': chatId,
      'query': query,
      'from_message_id': 0,
      'offset': 0,
      'limit': limit,
      'filter': null,
      'message_thread_id': 0,
    });

    final messages = result['messages'] as List? ?? [];
    return messages.cast<Map<String, dynamic>>().map(_parseMessage).toList();
  }

  TelegramMessage _parseMessage(Map<String, dynamic> data) {
    final content = data['content'] as Map<String, dynamic>? ?? {};
    final contentType = content['@type'] as String? ?? '';

    return TelegramMessage(
      messageId: data['id'] as int? ?? 0,
      chatId: data['chat_id'] as int? ?? 0,
      senderId: data['sender_id']?['user_id'] as int? ?? 0,
      direction: data['is_outgoing'] == true
          ? MessageDirection.outgoing
          : MessageDirection.incoming,
      contentType: _mapContentType(contentType),
      text: content['text']?['text'] as String? ?? '',
      date: DateTime.fromMillisecondsSinceEpoch(
        (data['date'] as int? ?? 0) * 1000,
      ),
      editDate: data['edit_date'] != null && data['edit_date'] != 0
          ? DateTime.fromMillisecondsSinceEpoch(
              (data['edit_date'] as int) * 1000,
            )
          : null,
      replyToMessageId: data['reply_to']?['message_id'] as int?,
    );
  }

  MessageContentType _mapContentType(String tdType) {
    switch (tdType) {
      case 'messageText':
        return MessageContentType.text;
      case 'messagePhoto':
        return MessageContentType.photo;
      case 'messageDocument':
        return MessageContentType.document;
      case 'messageVideo':
        return MessageContentType.video;
      case 'messageAudio':
        return MessageContentType.audio;
      case 'messageSticker':
        return MessageContentType.sticker;
      case 'messageAnimation':
        return MessageContentType.animation;
      case 'messageLocation':
        return MessageContentType.location;
      case 'messageContact':
        return MessageContentType.contact;
      default:
        return MessageContentType.text;
    }
  }
}

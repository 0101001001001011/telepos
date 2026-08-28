import 'dart:async';

import 'package:telepos/telegram/core/tdlib_client.dart';
import 'package:telepos/telegram/core/tdlib_logger.dart';

class ChatHistoryService {
  final TdLibClient _client;
  final TdLibLogger _logger;

  ChatHistoryService({required TdLibClient client, required TdLibLogger logger})
    : _client = client,
      _logger = logger;

  Future<List<Map<String, dynamic>>> loadHistory(
    int chatId, {
    int fromMessageId = 0,
    int offset = 0,
    int limit = 50,
  }) async {
    final result = await _client.getChatHistory(
      chatId: chatId,
      fromMessageId: fromMessageId,
      offset: offset,
      limit: limit,
    );

    return (result['messages'] as List? ?? []).cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> searchInChat(
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

    return (result['messages'] as List? ?? []).cast<Map<String, dynamic>>();
  }

  Future<int> getMessageCount(int chatId) async {
    final result = await _client.sendSync({
      '@type': 'getChatMessageCount',
      'chat_id': chatId,
      'filter': {'@type': 'searchMessagesFilterEmpty'},
      'return_local': false,
      'saved_messages_topic_id': 0,
    });

    return result['count'] as int? ?? 0;
  }

  Future<int> getUnreadCount(int chatId) async {
    final chatInfo = await _client.getChat(chatId);

    return chatInfo['unread_count'] as int? ?? 0;
  }

  Future<String> exportHistory(
    int chatId, {
    DateTime? from,
    DateTime? to,
    int maxMessages = 1000,
  }) async {
    final buffer = StringBuffer();
    buffer.writeln('Chat History Export');
    buffer.writeln('Chat ID: $chatId');
    buffer.writeln('Date: ${DateTime.now().toIso8601String()}');
    buffer.writeln('---');

    var lastMessageId = 0;
    var totalLoaded = 0;

    while (totalLoaded < maxMessages) {
      final messages = await loadHistory(
        chatId,
        fromMessageId: lastMessageId,
        limit: 50,
      );

      if (messages.isEmpty) break;

      for (final msg in messages) {
        final date = DateTime.fromMillisecondsSinceEpoch(
          (msg['date'] as int? ?? 0) * 1000,
        );

        if (from != null && date.isBefore(from)) continue;
        if (to != null && date.isAfter(to)) break;

        final senderId = msg['sender_id']?['user_id'] ?? 'unknown';
        final text = msg['content']?['text']?['text'] ?? '';

        buffer.writeln('[$date] User $senderId: $text');
        totalLoaded++;
      }

      lastMessageId = messages.last['id'] as int? ?? 0;
    }

    _logger.logConnection('Chat history exported: $totalLoaded messages');
    return buffer.toString();
  }
}

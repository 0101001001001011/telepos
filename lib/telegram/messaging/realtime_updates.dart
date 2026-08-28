import 'dart:async';

import 'package:telepos/telegram/core/tdlib_event_loop.dart';
import 'package:telepos/telegram/core/tdlib_logger.dart';
import 'package:telepos/domain/entities/telegram/telegram_message.dart';

class RealtimeUpdates {
  final TdLibEventLoop _eventLoop;
  final TdLibLogger _logger;

  final _messageController = StreamController<TelegramMessage>.broadcast();
  final _chatUpdateController = StreamController<ChatUpdate>.broadcast();
  final _connectionController = StreamController<ConnectionState>.broadcast();

  RealtimeUpdates({
    required TdLibEventLoop eventLoop,
    required TdLibLogger logger,
  }) : _eventLoop = eventLoop,
       _logger = logger;

  Stream<TelegramMessage> get newMessages => _messageController.stream;

  Stream<ChatUpdate> get chatUpdates => _chatUpdateController.stream;

  Stream<ConnectionState> get connectionState => _connectionController.stream;

  Stream<TelegramMessage> messagesForChat(int chatId) {
    return newMessages.where((msg) => msg.chatId == chatId);
  }

  Stream<TelegramMessage> get systemMessages {
    return newMessages.where((msg) => msg.isSystemMessage);
  }

  void start() {
    _eventLoop.on('updateNewMessage', _handleNewMessage);
    _eventLoop.on('updateMessageContent', _handleMessageUpdate);
    _eventLoop.on('updateChatTitle', _handleChatUpdate);
    _eventLoop.on('updateChatLastMessage', _handleChatUpdate);
    _eventLoop.on('updateConnectionState', _handleConnectionState);

    _logger.logConnection('Realtime updates started');
  }

  Future<void> stop() async {
    _eventLoop.offAll('updateNewMessage');
    _eventLoop.offAll('updateMessageContent');
    _eventLoop.offAll('updateChatTitle');
    _eventLoop.offAll('updateChatLastMessage');
    _eventLoop.offAll('updateConnectionState');

    _logger.logConnection('Realtime updates stopped');
  }

  Future<void> dispose() async {
    await stop();
    await _messageController.close();
    await _chatUpdateController.close();
    await _connectionController.close();
  }

  void _handleNewMessage(Map<String, dynamic> update) {
    try {
      final msgData = update['message'] as Map<String, dynamic>?;
      if (msgData == null) return;

      final content = msgData['content'] as Map<String, dynamic>? ?? {};
      final text = content['text']?['text'] as String? ?? '';
      final isSystem = text.startsWith('__TELEPOS_');

      final message = TelegramMessage(
        messageId: msgData['id'] as int? ?? 0,
        chatId: msgData['chat_id'] as int? ?? 0,
        senderId: msgData['sender_id']?['user_id'] as int? ?? 0,
        direction: msgData['is_outgoing'] == true
            ? MessageDirection.outgoing
            : MessageDirection.incoming,
        contentType: MessageContentType.text,
        text: text,
        date: DateTime.fromMillisecondsSinceEpoch(
          (msgData['date'] as int? ?? 0) * 1000,
        ),
        isSystemMessage: isSystem,
      );

      _messageController.add(message);
    } catch (e, st) {
      _logger.logError('_handleNewMessage', e, st);
    }
  }

  void _handleMessageUpdate(Map<String, dynamic> update) {
    final chatId = update['chat_id'] as int? ?? 0;
    final messageId = update['message_id'] as int? ?? 0;

    _chatUpdateController.add(
      ChatUpdate(
        type: ChatUpdateType.messageUpdated,
        chatId: chatId,
        data: {'message_id': messageId},
      ),
    );
  }

  void _handleChatUpdate(Map<String, dynamic> update) {
    final chatId = update['chat_id'] as int? ?? 0;

    _chatUpdateController.add(
      ChatUpdate(
        type: ChatUpdateType.chatUpdated,
        chatId: chatId,
        data: update,
      ),
    );
  }

  void _handleConnectionState(Map<String, dynamic> update) {
    final state = update['state']?['@type'] as String? ?? '';

    final connectionState = switch (state) {
      'connectionStateReady' => ConnectionState.ready,
      'connectionStateConnecting' => ConnectionState.connecting,
      'connectionStateConnectingToProxy' => ConnectionState.connectingToProxy,
      'connectionStateUpdating' => ConnectionState.updating,
      'connectionStateWaitingForNetwork' => ConnectionState.waitingForNetwork,
      _ => ConnectionState.unknown,
    };

    _connectionController.add(connectionState);
    _logger.logConnection('Connection state: $connectionState');
  }
}

class ChatUpdate {
  final ChatUpdateType type;
  final int chatId;
  final Map<String, dynamic> data;

  ChatUpdate({required this.type, required this.chatId, required this.data});
}

enum ChatUpdateType { messageUpdated, chatUpdated, chatCreated, chatDeleted }

enum ConnectionState {
  ready,
  connecting,
  connectingToProxy,
  updating,
  waitingForNetwork,
  unknown,
}

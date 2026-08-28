import 'dart:async';

import 'package:telepos/telegram/core/tdlib_client.dart';
import 'package:telepos/telegram/core/tdlib_event_loop.dart';
import 'package:telepos/telegram/core/tdlib_logger.dart';

class BotCommandContext {
  final int chatId;
  final int userId;
  final String command;
  final String arguments;
  final int messageId;

  BotCommandContext({
    required this.chatId,
    required this.userId,
    required this.command,
    required this.arguments,
    required this.messageId,
  });
}

typedef BotCommandHandler = Future<void> Function(BotCommandContext context);

class BotCommandRouter {
  final TdLibClient _client;
  final TdLibEventLoop _eventLoop;
  final TdLibLogger _logger;

  final Map<String, BotCommandHandler> _handlers = {};
  BotCommandHandler? _defaultHandler;

  BotCommandRouter({
    required TdLibClient client,
    required TdLibEventLoop eventLoop,
    required TdLibLogger logger,
  }) : _client = client,
       _eventLoop = eventLoop,
       _logger = logger;

  void registerCommand(String command, BotCommandHandler handler) {
    final normalized = command.startsWith('/') ? command.substring(1) : command;
    _handlers[normalized] = handler;
    _logger.logConnection('Bot command registered: /$normalized');
  }

  void setDefaultHandler(BotCommandHandler handler) {
    _defaultHandler = handler;
  }

  void startListening() {
    _eventLoop.on('updateNewMessage', (update) {
      final message = update['message'] as Map<String, dynamic>?;
      if (message == null) return;

      final content = message['content'] as Map<String, dynamic>?;
      if (content == null) return;
      if (content['@type'] != 'messageText') return;

      final text = content['text']?['text'] as String? ?? '';
      if (!text.startsWith('/')) return;

      _handleCommand(message, text);
    });

    _logger.logConnection('Bot command router started');
  }

  Future<void> reply(BotCommandContext context, String text) async {
    await _client.send({
      '@type': 'sendMessage',
      'chat_id': context.chatId,
      'reply_to': {
        '@type': 'inputMessageReplyToMessage',
        'message_id': context.messageId,
      },
      'input_message_content': {
        '@type': 'inputMessageText',
        'text': {'@type': 'formattedText', 'text': text},
      },
    });
  }

  void _handleCommand(Map<String, dynamic> message, String text) {
    final parts = text.split(RegExp(r'\s+'));
    var commandPart = parts.first.substring(1);

    final atIndex = commandPart.indexOf('@');
    if (atIndex > 0) {
      commandPart = commandPart.substring(0, atIndex);
    }

    final arguments = parts.length > 1 ? parts.sublist(1).join(' ') : '';

    final chatId = message['chat_id'] as int? ?? 0;
    final senderId = message['sender_id']?['user_id'] as int? ?? 0;
    final messageId = message['id'] as int? ?? 0;

    final context = BotCommandContext(
      chatId: chatId,
      userId: senderId,
      command: commandPart,
      arguments: arguments,
      messageId: messageId,
    );

    final handler = _handlers[commandPart] ?? _defaultHandler;
    if (handler != null) {
      _logger.logConnection('Handling bot command: /$commandPart');
      handler(context).catchError((e, st) {
        _logger.logError('botCommand:$commandPart', e, st);
      });
    }
  }
}

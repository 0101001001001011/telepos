import 'dart:async';

import 'package:telepos/telegram/core/tdlib_client.dart';
import 'package:telepos/telegram/core/tdlib_logger.dart';

class BotInfo {
  final int botUserId;
  final String username;
  final String token;
  final bool isActive;

  BotInfo({
    required this.botUserId,
    required this.username,
    required this.token,
    this.isActive = true,
  });
}

class BotManager {
  final TdLibClient _client;
  final TdLibLogger _logger;

  BotInfo? _activeBotInfo;

  BotManager({required TdLibClient client, required TdLibLogger logger})
    : _client = client,
      _logger = logger;

  BotInfo? get activeBot => _activeBotInfo;

  bool get hasActiveBot => _activeBotInfo != null;

  Future<BotInfo> registerBot({
    required String botToken,
    required String botUsername,
  }) async {
    _logger.logConnection('Registering bot: @$botUsername');

    final parts = botToken.split(':');
    final botUserId = int.tryParse(parts.firstOrNull ?? '') ?? 0;

    _activeBotInfo = BotInfo(
      botUserId: botUserId,
      username: botUsername,
      token: botToken,
    );

    _logger.logConnection('Bot registered: @$botUsername (id=$botUserId)');
    return _activeBotInfo!;
  }

  Future<void> sendBotMessage(int chatId, String text) async {
    if (_activeBotInfo == null) {
      throw StateError('No active bot registered');
    }

    await _client.send({
      '@type': 'sendMessage',
      'chat_id': chatId,
      'input_message_content': {
        '@type': 'inputMessageText',
        'text': {'@type': 'formattedText', 'text': text},
      },
    });
  }

  Future<void> setBotCommands(List<Map<String, String>> commands) async {
    if (_activeBotInfo == null) return;

    final tdCommands = commands
        .map(
          (cmd) => {
            '@type': 'botCommand',
            'command': cmd['command'],
            'description': cmd['description'],
          },
        )
        .toList();

    await _client.send({
      '@type': 'setCommands',
      'scope': {'@type': 'botCommandScopeDefault'},
      'language_code': '',
      'commands': tdCommands,
    });

    _logger.logConnection('Bot commands set: ${commands.length}');
  }

  Future<void> addBotToChat(int chatId) async {
    if (_activeBotInfo == null) return;

    await _client.send({
      '@type': 'addChatMember',
      'chat_id': chatId,
      'user_id': _activeBotInfo!.botUserId,
    });

    await _client.send({
      '@type': 'setChatMemberStatus',
      'chat_id': chatId,
      'member_id': {
        '@type': 'messageSenderUser',
        'user_id': _activeBotInfo!.botUserId,
      },
      'status': {
        '@type': 'chatMemberStatusAdministrator',
        'custom_title': 'POS Bot',
        'can_be_edited': true,
        'rights': {
          '@type': 'chatAdministratorRights',
          'can_manage_chat': true,
          'can_post_messages': true,
          'can_edit_messages': true,
          'can_delete_messages': true,
          'can_invite_users': true,
          'can_restrict_members': false,
          'can_pin_messages': true,
          'can_promote_members': false,
          'can_manage_video_chats': false,
          'is_anonymous': false,
        },
      },
    });

    _logger.logConnection('Bot added to chat: $chatId');
  }

  void deactivateBot() {
    _activeBotInfo = null;
    _logger.logConnection('Bot deactivated');
  }
}

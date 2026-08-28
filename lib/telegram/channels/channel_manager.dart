import 'dart:async';

import 'package:telepos/telegram/channels/channel_types.dart';
import 'package:telepos/telegram/core/tdlib_client.dart';
import 'package:telepos/telegram/core/tdlib_logger.dart';
import 'package:telepos/telegram/models/telegram_channel.dart';

class ChannelManager {
  final TdLibClient _client;
  final TdLibLogger _logger;

  ChannelManager({required TdLibClient client, required TdLibLogger logger})
    : _client = client,
      _logger = logger;

  Future<TelegramChannel> createChannel({
    required String title,
    required String description,
    required SystemChannelType channelType,
    String? storeName,
    String? posId,
  }) async {
    _logger.logConnection('Creating channel: $title');

    final result = await _client.createChannel(
      title: title,
      description: description,
    );

    final chatId = result['id'] as int? ?? 0;

    final channel = TelegramChannel(
      chatId: chatId,
      title: title,
      channelType: channelType,
      description: description,
      isChannel: true,
      isPrivate: true,
      storeName: storeName,
      posId: posId,
      createdAt: DateTime.now(),
    );

    _logger.logConnection('Channel created: $title (id=$chatId)');
    return channel;
  }

  Future<TelegramChannel> createGroup({
    required String title,
    required String description,
    required SystemChannelType channelType,
    String? storeName,
  }) async {
    _logger.logConnection('Creating group: $title');

    final result = await _client.sendSync({
      '@type': 'createNewSupergroupChat',
      'title': title,
      'is_channel': false,
      'description': description,
      'is_forum': false,
    });

    final chatId = result['id'] as int? ?? 0;

    final channel = TelegramChannel(
      chatId: chatId,
      title: title,
      channelType: channelType,
      description: description,
      isChannel: false,
      isPrivate: true,
      storeName: storeName,
      createdAt: DateTime.now(),
    );

    _logger.logConnection('Group created: $title (id=$chatId)');
    return channel;
  }

  Future<void> addMember(int chatId, int userId) async {
    await _client.send({
      '@type': 'addChatMember',
      'chat_id': chatId,
      'user_id': userId,
    });
    _logger.logConnection('Member added: user=$userId to chat=$chatId');
  }

  Future<void> addMembers(int chatId, List<int> userIds) async {
    await _client.send({
      '@type': 'addChatMembers',
      'chat_id': chatId,
      'user_ids': userIds,
    });
    _logger.logConnection(
      'Members added: ${userIds.length} users to chat=$chatId',
    );
  }

  Future<void> removeMember(int chatId, int userId) async {
    await _client.send({
      '@type': 'setChatMemberStatus',
      'chat_id': chatId,
      'member_id': {'@type': 'messageSenderUser', 'user_id': userId},
      'status': {'@type': 'chatMemberStatusLeft'},
    });
    _logger.logConnection('Member removed: user=$userId from chat=$chatId');
  }

  Future<String> createInviteLink(int chatId) async {
    final result = await _client.sendSync({
      '@type': 'createChatInviteLink',
      'chat_id': chatId,
      'name': 'TelePOS invite',
      'expiration_date': 0,
      'member_limit': 0,
      'creates_join_request': false,
    });

    return result['invite_link'] as String? ?? '';
  }

  Future<void> updateDescription(int chatId, String description) async {
    await _client.send({
      '@type': 'setChatDescription',
      'chat_id': chatId,
      'description': description,
    });
  }

  Future<void> updateTitle(int chatId, String title) async {
    await _client.send({
      '@type': 'setChatTitle',
      'chat_id': chatId,
      'title': title,
    });
  }

  Future<void> deleteChannel(int chatId) async {
    _logger.logConnection('Deleting channel: $chatId');

    await _client.send({'@type': 'deleteSupergroup', 'supergroup_id': chatId});
  }

  Future<void> leaveChannel(int chatId) async {
    _logger.logConnection('Leaving channel: $chatId');

    await _client.send({'@type': 'leaveChat', 'chat_id': chatId});

    _logger.logConnection('Left channel: $chatId');
  }

  Future<Map<String, dynamic>> getChatInfo(int chatId) async {
    return _client.getChat(chatId);
  }

  Future<int> getMemberCount(int chatId) async {
    final info = await getChatInfo(chatId);
    final supergroupId = info['type']?['supergroup_id'] as int?;
    if (supergroupId == null) return 0;

    final sg = await _client.sendSync({
      '@type': 'getSupergroupFullInfo',
      'supergroup_id': supergroupId,
    });

    return sg['member_count'] as int? ?? 0;
  }
}

import 'dart:async';

import 'package:telepos/telegram/channels/auto_channel_factory.dart';
import 'package:telepos/telegram/channels/channel_registry.dart';
import 'package:telepos/telegram/channels/channel_types.dart';
import 'package:telepos/telegram/core/tdlib_client.dart';
import 'package:telepos/telegram/core/tdlib_logger.dart';
import 'package:telepos/telegram/models/telegram_channel.dart';

class AutoChannelCreator {
  final TdLibClient _client;
  final AutoChannelFactory _factory;
  final ChannelRegistry _registry;
  final TdLibLogger _logger;

  AutoChannelCreator({
    required TdLibClient client,
    required AutoChannelFactory factory,
    required ChannelRegistry registry,
    required TdLibLogger logger,
  }) : _client = client,
       _factory = factory,
       _registry = registry,
       _logger = logger;

  Future<List<TelegramChannel>> createAll({
    required String storeName,
    required String posId,
    List<int>? adminUserIds,
  }) async {
    _logger.logConnection('Creating all channels for: $storeName');

    return _factory.createAllChannels(
      storeName: storeName,
      posId: posId,
      adminUserIds: adminUserIds,
    );
  }

  Future<List<TelegramChannel>> findExistingChannels(String storeName) async {
    _logger.logConnection('Searching for existing channels: $storeName');

    try {
      final result = await _client.sendSync({
        '@type': 'searchPublicChats',
        'query': storeName,
      });

      final chatIds = result['chat_ids'] as List? ?? [];
      final channels = <TelegramChannel>[];

      for (final chatId in chatIds) {
        final chatInfo = await _client.getChat(chatId as int);

        final title = chatInfo['title'] as String? ?? '';
        if (title.contains(storeName) && title.contains('POS')) {
          channels.add(
            TelegramChannel(
              chatId: chatId,
              title: title,
              channelType: _inferChannelType(title),
              storeName: storeName,
            ),
          );
        }
      }

      _logger.logConnection(
        'Found ${channels.length} existing channels for $storeName',
      );
      return channels;
    } catch (e) {
      _logger.logError('findExistingChannels', e);
      return [];
    }
  }

  Future<void> joinExistingChannels(List<TelegramChannel> channels) async {
    for (final channel in channels) {
      try {
        if (channel.inviteLink != null) {
          await _client.sendSync({
            '@type': 'joinChatByInviteLink',
            'invite_link': channel.inviteLink,
          });
        }

        _registry.register(channel.channelType, channel);
        _logger.logConnection('Joined channel: ${channel.title}');
      } catch (e) {
        _logger.logError('joinChannel:${channel.title}', e);
      }
    }

    await _registry.persist();
  }

  SystemChannelType _inferChannelType(String title) {
    final normalized = title.toLowerCase();

    final byLength = SystemChannelType.values.toList()
      ..sort((a, b) => b.suffix.length.compareTo(a.suffix.length));

    for (final type in byLength) {
      if (normalized.contains(type.suffix.toLowerCase())) {
        return type;
      }
    }

    return SystemChannelType.posSystem;
  }
}

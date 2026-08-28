import 'package:telepos/telegram/channels/channel_manager.dart';
import 'package:telepos/telegram/channels/channel_registry.dart';
import 'package:telepos/telegram/channels/channel_types.dart';
import 'package:telepos/telegram/core/tdlib_logger.dart';
import 'package:telepos/telegram/models/telegram_channel.dart';

class AutoChannelFactory {
  final ChannelManager _channelManager;
  final ChannelRegistry _registry;
  final TdLibLogger _logger;

  AutoChannelFactory({
    required ChannelManager channelManager,
    required ChannelRegistry registry,
    required TdLibLogger logger,
  }) : _channelManager = channelManager,
       _registry = registry,
       _logger = logger;

  Future<List<TelegramChannel>> createAllChannels({
    required String storeName,
    String? posId,
    List<int>? adminUserIds,
  }) async {
    _logger.logConnection('Creating all system channels for: $storeName');

    final created = <TelegramChannel>[];

    for (final type in SystemChannelType.values) {
      if (type.isPerPos && posId == null) continue;

      if (_registry.isRegistered(type, type.isPerPos ? posId : null)) {
        _logger.logConnection('Channel already exists: ${type.name}');
        continue;
      }

      try {
        final channel = await _createChannel(
          type: type,
          storeName: storeName,
          posId: posId,
        );

        if (adminUserIds != null && adminUserIds.isNotEmpty) {
          for (final adminId in adminUserIds) {
            try {
              await _channelManager.addMember(channel.chatId, adminId);
            } catch (_) {}
          }
        }

        _registry.register(type, channel, type.isPerPos ? posId : null);
        created.add(channel);

        _logger.logConnection('Channel created: ${channel.title}');
      } catch (e, st) {
        _logger.logError('createChannel:${type.name}', e, st);
      }
    }

    await _registry.persist();

    _logger.logConnection(
      'System channels created: ${created.length}/${SystemChannelType.values.length}',
    );

    return created;
  }

  Future<TelegramChannel> createPosStatusChannel({
    required String storeName,
    required String posId,
  }) async {
    const type = SystemChannelType.posTerminalStatus;
    final title = type.formatTitle(storeName, posId);

    final channel = await _channelManager.createChannel(
      title: title,
      description: 'Status of POS terminal $posId at $storeName',
      channelType: type,
      storeName: storeName,
      posId: posId,
    );

    _registry.register(type, channel, posId);
    await _registry.persist();

    return channel;
  }

  Future<List<TelegramChannel>> repairChannels({
    required String storeName,
    String? posId,
  }) async {
    final missing = _registry.missingTypes;
    if (missing.isEmpty) return [];

    _logger.logConnection('Repairing ${missing.length} missing channels');

    return createAllChannels(storeName: storeName, posId: posId);
  }

  Future<TelegramChannel> _createChannel({
    required SystemChannelType type,
    required String storeName,
    String? posId,
  }) async {
    final title = type.formatTitle(storeName, posId);
    final description = '${type.description} — $storeName';

    if (type.isGroup) {
      return _channelManager.createGroup(
        title: title,
        description: description,
        channelType: type,
        storeName: storeName,
      );
    }

    return _channelManager.createChannel(
      title: title,
      description: description,
      channelType: type,
      storeName: storeName,
      posId: posId,
    );
  }
}

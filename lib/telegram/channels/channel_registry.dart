import 'dart:convert';
import 'dart:io';

import 'package:telepos/telegram/channels/channel_types.dart';
import 'package:telepos/telegram/core/tdlib_logger.dart';
import 'package:telepos/telegram/models/telegram_channel.dart';

class ChannelRegistry {
  final TdLibLogger _logger;
  final String _registryPath;

  final Map<String, TelegramChannel> _channels = {};

  ChannelRegistry({required TdLibLogger logger, required String registryPath})
    : _logger = logger,
      _registryPath = registryPath;

  List<TelegramChannel> get allChannels => _channels.values.toList();

  int get count => _channels.length;

  void register(
    SystemChannelType type,
    TelegramChannel channel, [
    String? posId,
  ]) {
    final key = _makeKey(type, posId);
    _channels[key] = channel;
    _logger.logConnection(
      'Channel registered: ${type.name} → ${channel.chatId}',
    );
  }

  TelegramChannel? get(SystemChannelType type, [String? posId]) {
    return _channels[_makeKey(type, posId)];
  }

  int? getChatId(SystemChannelType type, [String? posId]) {
    return _channels[_makeKey(type, posId)]?.chatId;
  }

  void unregister(SystemChannelType type, [String? posId]) {
    _channels.remove(_makeKey(type, posId));
  }

  Future<void> clear() async {
    _channels.clear();

    final file = File(_registryPath);
    if (file.existsSync()) {
      await file.delete();
    }

    _logger.logConnection('Channel registry cleared');
  }

  bool isRegistered(SystemChannelType type, [String? posId]) {
    return _channels.containsKey(_makeKey(type, posId));
  }

  bool get isComplete {
    for (final type in SystemChannelType.values) {
      if (type.isPerPos) continue;
      if (!isRegistered(type)) return false;
    }
    return true;
  }

  List<SystemChannelType> get missingTypes {
    return SystemChannelType.values.where((type) {
      if (type.isPerPos) return false;
      return !isRegistered(type);
    }).toList();
  }

  Future<void> persist() async {
    final data = <String, dynamic>{};
    for (final entry in _channels.entries) {
      data[entry.key] = entry.value.toJson();
    }

    final file = File(_registryPath);
    final dir = file.parent;
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }

    await file.writeAsString(jsonEncode(data));
    _logger.logConnection(
      'Channel registry persisted (${_channels.length} channels)',
    );
  }

  Future<void> restore() async {
    final file = File(_registryPath);
    if (!file.existsSync()) return;

    try {
      final content = await file.readAsString();
      final data = jsonDecode(content) as Map<String, dynamic>;

      _channels.clear();
      for (final entry in data.entries) {
        _channels[entry.key] = TelegramChannel.fromJson(
          entry.value as Map<String, dynamic>,
        );
      }

      _logger.logConnection(
        'Channel registry restored (${_channels.length} channels)',
      );
    } catch (e, st) {
      _logger.logError('restore', e, st);
    }
  }

  String _makeKey(SystemChannelType type, [String? posId]) {
    if (type.isPerPos && posId != null) {
      return '${type.name}:$posId';
    }
    return type.name;
  }
}

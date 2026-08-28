import 'dart:async';

import 'package:telepos/telegram/channels/channel_manager.dart';
import 'package:telepos/telegram/channels/channel_types.dart';
import 'package:telepos/telegram/core/tdlib_logger.dart';
import 'package:telepos/telegram/models/telegram_channel.dart';

class ChatRoomManager {
  final ChannelManager _channelManager;
  final TdLibLogger _logger;

  final Map<String, TelegramChannel> _rooms = {};

  ChatRoomManager({
    required ChannelManager channelManager,
    required TdLibLogger logger,
  }) : _channelManager = channelManager,
       _logger = logger;

  List<TelegramChannel> get rooms => _rooms.values.toList();

  Future<TelegramChannel> createRoom({
    required String name,
    String? description,
    String? storeName,
  }) async {
    final room = await _channelManager.createGroup(
      title: name,
      description: description ?? 'TelePOS chat room',
      channelType: SystemChannelType.staffChat,
      storeName: storeName,
    );

    _rooms[name] = room;
    _logger.logConnection('Chat room created: $name');
    return room;
  }

  Future<void> deleteRoom(String name) async {
    final room = _rooms[name];
    if (room == null) return;

    await _channelManager.deleteChannel(room.chatId);
    _rooms.remove(name);
    _logger.logConnection('Chat room deleted: $name');
  }

  Future<void> addMember(String roomName, int userId) async {
    final room = _rooms[roomName];
    if (room == null) throw StateError('Room not found: $roomName');

    await _channelManager.addMember(room.chatId, userId);
  }

  Future<void> removeMember(String roomName, int userId) async {
    final room = _rooms[roomName];
    if (room == null) throw StateError('Room not found: $roomName');

    await _channelManager.removeMember(room.chatId, userId);
  }

  TelegramChannel? getRoom(String name) => _rooms[name];

  TelegramChannel? getRoomByChatId(int chatId) {
    for (final room in _rooms.values) {
      if (room.chatId == chatId) return room;
    }
    return null;
  }
}

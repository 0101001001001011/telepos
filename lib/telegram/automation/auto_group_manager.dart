import 'dart:async';

import 'package:telepos/telegram/channels/channel_manager.dart';
import 'package:telepos/telegram/core/tdlib_logger.dart';
import 'package:telepos/telegram/internal_chat/chat_permissions.dart';

class AutoGroupManager {
  final ChannelManager _channelManager;
  final ChatPermissions _chatPermissions;
  final TdLibLogger _logger;

  AutoGroupManager({
    required ChannelManager channelManager,
    required ChatPermissions chatPermissions,
    required TdLibLogger logger,
  }) : _channelManager = channelManager,
       _chatPermissions = chatPermissions,
       _logger = logger;

  Future<void> onboardStaff({
    required int userId,
    required String role,
    required List<int> channelChatIds,
    required int staffChatId,
  }) async {
    _logger.logConnection('Onboarding staff: user=$userId, role=$role');

    await _channelManager.addMember(staffChatId, userId);

    switch (role) {
      case 'manager':
      case 'admin':
        await _chatPermissions.setManagerPermissions(staffChatId, userId);
        for (final chatId in channelChatIds) {
          await _channelManager.addMember(chatId, userId);
        }
        break;

      case 'cashier':
        await _chatPermissions.setCashierPermissions(staffChatId, userId);
        break;

      default:
        await _chatPermissions.setReadOnlyPermissions(staffChatId, userId);
    }

    _logger.logConnection('Staff onboarded: user=$userId');
  }

  Future<void> offboardStaff({
    required int userId,
    required List<int> allChatIds,
  }) async {
    _logger.logConnection('Offboarding staff: user=$userId');

    for (final chatId in allChatIds) {
      try {
        await _channelManager.removeMember(chatId, userId);
      } catch (_) {}
    }

    _logger.logConnection('Staff offboarded: user=$userId');
  }

  Future<void> updateStaffRole({
    required int userId,
    required String newRole,
    required int staffChatId,
  }) async {
    switch (newRole) {
      case 'manager':
      case 'admin':
        await _chatPermissions.setManagerPermissions(staffChatId, userId);
        break;
      case 'cashier':
        await _chatPermissions.setCashierPermissions(staffChatId, userId);
        break;
      default:
        await _chatPermissions.setReadOnlyPermissions(staffChatId, userId);
    }

    _logger.logConnection('Staff role updated: user=$userId → $newRole');
  }
}

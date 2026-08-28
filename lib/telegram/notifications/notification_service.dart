import 'dart:async';

import 'package:telepos/telegram/channels/channel_registry.dart';
import 'package:telepos/telegram/channels/channel_types.dart';
import 'package:telepos/telegram/core/tdlib_logger.dart';
import 'package:telepos/telegram/messaging/message_queue.dart';
import 'package:telepos/telegram/messaging/message_service.dart';
import 'package:telepos/domain/entities/telegram/notification_payload.dart';
import 'package:telepos/telegram/notifications/notification_router.dart';
import 'package:telepos/telegram/notifications/notification_templates.dart';

class NotificationService {
  final MessageService _messageService;
  final MessageQueue _messageQueue;
  final ChannelRegistry _channelRegistry;
  final NotificationRouter _router;
  final NotificationTemplates _templates;
  final TdLibLogger _logger;

  bool _isEnabled = true;

  final Map<NotificationType, int> _rateLimits = {
    NotificationType.sale: 60,
    NotificationType.shift: 10,
    NotificationType.stock: 20,
    NotificationType.cash: 20,
    NotificationType.error: 30,
    NotificationType.sync: 10,
    NotificationType.fiscal: 20,
    NotificationType.system: 10,
  };

  final Map<NotificationType, List<DateTime>> _recentNotifications = {};

  NotificationService({
    required MessageService messageService,
    required MessageQueue messageQueue,
    required ChannelRegistry channelRegistry,
    required NotificationRouter router,
    required NotificationTemplates templates,
    required TdLibLogger logger,
  }) : _messageService = messageService,
       _messageQueue = messageQueue,
       _channelRegistry = channelRegistry,
       _router = router,
       _templates = templates,
       _logger = logger;

  bool get isEnabled => _isEnabled;

  void enable() {
    _isEnabled = true;
    _logger.logConnection('Notifications enabled');
  }

  void disable() {
    _isEnabled = false;
    _logger.logConnection('Notifications disabled');
  }

  Future<void> send(NotificationPayload notification) async {
    if (!_isEnabled) return;

    if (_isRateLimited(notification.type)) {
      _logger.logConnection(
        'Notification rate limited: ${notification.type.name}',
      );
      return;
    }

    _trackNotification(notification.type);

    final targetChatId =
        notification.targetChatId ??
        _router.resolveChannel(notification.type, _channelRegistry);

    if (targetChatId == null) {
      _logger.logError(
        'send',
        'No target channel for notification: ${notification.type.name}',
      );
      return;
    }

    final formattedMessage = _templates.format(notification);

    try {
      if (notification.isSilent) {
        await _messageService.sendSilent(targetChatId, formattedMessage);
      } else {
        await _messageService.sendText(targetChatId, formattedMessage);
      }

      _logger.logConnection(
        'Notification sent: ${notification.type.name} → chat=$targetChatId',
      );
    } catch (e) {
      _messageQueue.enqueue(
        QueuedMessage(
          id: notification.notificationId,
          chatId: targetChatId,
          text: formattedMessage,
          isSilent: notification.isSilent,
        ),
      );

      _logger.logError('send', 'Notification queued: $e');
    }
  }

  Future<void> sendBatch(List<NotificationPayload> notifications) async {
    for (final notification in notifications) {
      await send(notification);
      await Future.delayed(const Duration(milliseconds: 50));
    }
  }

  Future<void> sendCritical(NotificationPayload notification) async {
    final chatId = _channelRegistry.getChatId(SystemChannelType.posAlerts);
    if (chatId == null) return;

    final formattedMessage = _templates.format(notification);

    try {
      await _messageService.sendText(chatId, formattedMessage);
      _logger.logCritical('Critical notification sent: ${notification.title}');
    } catch (e) {
      _logger.logCritical('Failed to send critical notification: $e');
    }
  }

  bool _isRateLimited(NotificationType type) {
    final limit = _rateLimits[type] ?? 60;
    final recent = _recentNotifications[type] ?? [];
    final cutoff = DateTime.now().subtract(const Duration(minutes: 1));
    final recentCount = recent.where((dt) => dt.isAfter(cutoff)).length;
    return recentCount >= limit;
  }

  void _trackNotification(NotificationType type) {
    _recentNotifications.putIfAbsent(type, () => []).add(DateTime.now());

    final cutoff = DateTime.now().subtract(const Duration(minutes: 5));
    _recentNotifications[type]?.removeWhere((dt) => dt.isBefore(cutoff));
  }
}

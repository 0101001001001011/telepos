import 'package:telepos/telegram/channels/channel_registry.dart';
import 'package:telepos/telegram/channels/channel_types.dart';
import 'package:telepos/domain/entities/telegram/notification_payload.dart';

class NotificationRouter {
  static const _channelMapping = {
    NotificationType.shift: SystemChannelType.posSystem,
    NotificationType.sale: SystemChannelType.posSales,
    NotificationType.stock: SystemChannelType.posAlerts,
    NotificationType.cash: SystemChannelType.posSystem,
    NotificationType.error: SystemChannelType.posAlerts,
    NotificationType.sync: SystemChannelType.posSync,
    NotificationType.fiscal: SystemChannelType.posFiscal,
    NotificationType.system: SystemChannelType.posSystem,
  };

  int? resolveChannel(NotificationType type, ChannelRegistry registry) {
    final channelType = _channelMapping[type] ?? SystemChannelType.posSystem;
    return registry.getChatId(channelType);
  }

  int? resolveWithPriority(
    NotificationPayload notification,
    ChannelRegistry registry,
  ) {
    if (notification.priority == NotificationPriority.critical) {
      return registry.getChatId(SystemChannelType.posAlerts);
    }

    return resolveChannel(notification.type, registry);
  }

  List<int> resolveMultiple(
    NotificationPayload notification,
    ChannelRegistry registry,
  ) {
    final chatIds = <int>[];

    final primary = resolveWithPriority(notification, registry);
    if (primary != null) chatIds.add(primary);

    if (notification.priority == NotificationPriority.critical) {
      final system = registry.getChatId(SystemChannelType.posSystem);
      if (system != null && !chatIds.contains(system)) {
        chatIds.add(system);
      }
    }

    return chatIds;
  }
}

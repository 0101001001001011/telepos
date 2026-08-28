import 'package:telepos/telegram/messaging/message_formatter.dart';
import 'package:telepos/domain/entities/telegram/notification_payload.dart';

class NotificationTemplates {
  final MessageFormatter _formatter;

  NotificationTemplates({MessageFormatter? formatter})
    : _formatter = formatter ?? const MessageFormatter();

  String format(NotificationPayload notification) {
    final priorityIcon = _priorityIcon(notification.priority);
    final typeIcon = _typeIcon(notification.type);

    final buffer = StringBuffer();

    buffer.writeln(
      '$typeIcon $priorityIcon ${_formatter.bold(notification.title)}',
    );

    if (notification.storeName != null) {
      buffer.writeln(
        '🏪 ${notification.storeName} | POS: ${notification.posId}',
      );
    } else {
      buffer.writeln('📍 POS: ${notification.posId}');
    }

    buffer.writeln();
    buffer.writeln(notification.body);

    buffer.writeln();
    buffer.writeln('🕐 ${_formatter.dateTime(notification.timestamp)}');

    return buffer.toString();
  }

  String formatShort(NotificationPayload notification) {
    final icon = _typeIcon(notification.type);
    return '$icon ${notification.title}: ${notification.body}';
  }

  String _priorityIcon(NotificationPriority priority) {
    switch (priority) {
      case NotificationPriority.low:
        return '';
      case NotificationPriority.normal:
        return '';
      case NotificationPriority.high:
        return '⚠️';
      case NotificationPriority.critical:
        return '🚨';
    }
  }

  String _typeIcon(NotificationType type) {
    switch (type) {
      case NotificationType.shift:
        return '🔄';
      case NotificationType.sale:
        return '🧾';
      case NotificationType.stock:
        return '📦';
      case NotificationType.cash:
        return '💰';
      case NotificationType.error:
        return '❌';
      case NotificationType.sync:
        return '🔁';
      case NotificationType.fiscal:
        return '🏛️';
      case NotificationType.system:
        return '⚙️';
    }
  }
}

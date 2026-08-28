import 'package:telepos/domain/entities/telegram/notification_payload.dart';
import 'package:telepos/telegram/notifications/notification_service.dart';

class ErrorNotifications {
  final NotificationService _notificationService;
  final String _posId;
  final String? _storeName;

  ErrorNotifications({
    required NotificationService notificationService,
    required String posId,
    String? storeName,
  }) : _notificationService = notificationService,
       _posId = posId,
       _storeName = storeName;

  Future<void> criticalError({
    required String error,
    required String context,
    String? stackTrace,
  }) async {
    await _notificationService.sendCritical(
      NotificationPayload(
        notificationId: 'err_critical_${DateTime.now().millisecondsSinceEpoch}',
        type: NotificationType.error,
        priority: NotificationPriority.critical,
        title: 'Критическая ошибка',
        body:
            '📍 $context\n'
            '⚠️ $error'
            '${stackTrace != null ? "\n\n```\n${stackTrace.substring(0, stackTrace.length > 500 ? 500 : stackTrace.length)}\n```" : ""}',
        posId: _posId,
        storeName: _storeName,
        timestamp: DateTime.now(),
      ),
    );
  }

  Future<void> databaseError({
    required String error,
    required String operation,
  }) async {
    await _notificationService.send(
      NotificationPayload(
        notificationId: 'err_db_${DateTime.now().millisecondsSinceEpoch}',
        type: NotificationType.error,
        priority: NotificationPriority.high,
        title: 'Ошибка БД',
        body:
            '🗄️ Операция: $operation\n'
            '⚠️ $error',
        posId: _posId,
        storeName: _storeName,
        timestamp: DateTime.now(),
      ),
    );
  }

  Future<void> hardwareError({
    required String device,
    required String error,
  }) async {
    await _notificationService.send(
      NotificationPayload(
        notificationId: 'err_hw_${DateTime.now().millisecondsSinceEpoch}',
        type: NotificationType.error,
        priority: NotificationPriority.high,
        title: 'Ошибка оборудования',
        body:
            '🔧 Устройство: $device\n'
            '⚠️ $error',
        posId: _posId,
        storeName: _storeName,
        timestamp: DateTime.now(),
      ),
    );
  }

  Future<void> paymentError({
    required String terminal,
    required String error,
    int? receiptNo,
  }) async {
    await _notificationService.send(
      NotificationPayload(
        notificationId: 'err_pay_${DateTime.now().millisecondsSinceEpoch}',
        type: NotificationType.error,
        priority: NotificationPriority.critical,
        title: 'Ошибка оплаты',
        body:
            '💳 Терминал: $terminal\n'
            '⚠️ $error'
            '${receiptNo != null ? "\n🧾 Чек: #$receiptNo" : ""}',
        posId: _posId,
        storeName: _storeName,
        timestamp: DateTime.now(),
      ),
    );
  }

  Future<void> warning({
    required String message,
    required String context,
  }) async {
    await _notificationService.send(
      NotificationPayload(
        notificationId: 'warn_${DateTime.now().millisecondsSinceEpoch}',
        type: NotificationType.error,
        priority: NotificationPriority.normal,
        title: 'Предупреждение',
        body:
            '📍 $context\n'
            '⚠️ $message',
        posId: _posId,
        storeName: _storeName,
        timestamp: DateTime.now(),
        isSilent: true,
      ),
    );
  }
}

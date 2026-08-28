import 'package:telepos/domain/entities/telegram/notification_payload.dart';
import 'package:telepos/telegram/notifications/notification_service.dart';

class FiscalNotifications {
  final NotificationService _notificationService;
  final String _posId;
  final String? _storeName;

  FiscalNotifications({
    required NotificationService notificationService,
    required String posId,
    String? storeName,
  }) : _notificationService = notificationService,
       _posId = posId,
       _storeName = storeName;

  Future<void> receiptRegistered({
    required int receiptNo,
    required String fiscalId,
    required num amount,
    required String currency,
  }) async {
    await _notificationService.send(
      NotificationPayload(
        notificationId: 'fiscal_ok_${DateTime.now().millisecondsSinceEpoch}',
        type: NotificationType.fiscal,
        title: 'Фискальный чек #$receiptNo',
        body:
            '✅ Зарегистрирован в OFD\n'
            '🔖 Фискальный ID: $fiscalId\n'
            '💰 Сумма: ${amount.toStringAsFixed(2)} $currency',
        posId: _posId,
        storeName: _storeName,
        timestamp: DateTime.now(),
        isSilent: true,
      ),
    );
  }

  Future<void> fiscalError({
    required int receiptNo,
    required String error,
    required String ofdProvider,
  }) async {
    await _notificationService.sendCritical(
      NotificationPayload(
        notificationId: 'fiscal_err_${DateTime.now().millisecondsSinceEpoch}',
        type: NotificationType.fiscal,
        priority: NotificationPriority.critical,
        title: 'Ошибка фискализации #$receiptNo',
        body:
            '❌ Провайдер: $ofdProvider\n'
            '⚠️ $error\n'
            '⏳ Чек в очереди на повторную отправку',
        posId: _posId,
        storeName: _storeName,
        timestamp: DateTime.now(),
      ),
    );
  }

  Future<void> fiscalQueueStatus({
    required int pendingCount,
    required int failedCount,
  }) async {
    if (pendingCount == 0 && failedCount == 0) return;

    await _notificationService.send(
      NotificationPayload(
        notificationId: 'fiscal_queue_${DateTime.now().millisecondsSinceEpoch}',
        type: NotificationType.fiscal,
        priority: failedCount > 0
            ? NotificationPriority.high
            : NotificationPriority.normal,
        title: 'Очередь фискализации',
        body:
            '⏳ Ожидают: $pendingCount\n'
            '${failedCount > 0 ? "❌ Ошибки: $failedCount" : "✅ Ошибок нет"}',
        posId: _posId,
        storeName: _storeName,
        timestamp: DateTime.now(),
      ),
    );
  }

  Future<void> ofdKeyExpiring({
    required String ofdProvider,
    required int daysRemaining,
  }) async {
    await _notificationService.send(
      NotificationPayload(
        notificationId: 'ofd_key_${DateTime.now().millisecondsSinceEpoch}',
        type: NotificationType.fiscal,
        priority: daysRemaining <= 3
            ? NotificationPriority.critical
            : NotificationPriority.high,
        title: 'Ключ OFD истекает',
        body:
            '🏛️ Провайдер: $ofdProvider\n'
            '⏰ Осталось дней: $daysRemaining\n'
            '⚠️ Необходимо продлить ключ',
        posId: _posId,
        storeName: _storeName,
        timestamp: DateTime.now(),
      ),
    );
  }
}

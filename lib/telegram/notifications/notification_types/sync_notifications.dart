import 'package:telepos/domain/entities/telegram/notification_payload.dart';
import 'package:telepos/telegram/notifications/notification_service.dart';

class SyncNotifications {
  final NotificationService _notificationService;
  final String _posId;
  final String? _storeName;

  SyncNotifications({
    required NotificationService notificationService,
    required String posId,
    String? storeName,
  }) : _notificationService = notificationService,
       _posId = posId,
       _storeName = storeName;

  Future<void> syncCompleted({
    required int uploadedRecords,
    required int downloadedRecords,
    required Duration duration,
  }) async {
    await _notificationService.send(
      NotificationPayload(
        notificationId: 'sync_ok_${DateTime.now().millisecondsSinceEpoch}',
        type: NotificationType.sync,
        title: 'Синхронизация завершена',
        body:
            '⬆️ Отправлено: $uploadedRecords записей\n'
            '⬇️ Получено: $downloadedRecords записей\n'
            '⏱️ Время: ${duration.inSeconds}с',
        posId: _posId,
        storeName: _storeName,
        timestamp: DateTime.now(),
        isSilent: true,
      ),
    );
  }

  Future<void> syncFailed({
    required String error,
    required int retryCount,
  }) async {
    await _notificationService.send(
      NotificationPayload(
        notificationId: 'sync_fail_${DateTime.now().millisecondsSinceEpoch}',
        type: NotificationType.sync,
        priority: retryCount >= 3
            ? NotificationPriority.high
            : NotificationPriority.normal,
        title: 'Ошибка синхронизации',
        body:
            '⚠️ $error\n'
            '🔄 Попытка: $retryCount',
        posId: _posId,
        storeName: _storeName,
        timestamp: DateTime.now(),
      ),
    );
  }

  Future<void> conflictDetected({
    required String entityType,
    required int conflictCount,
    required String resolution,
  }) async {
    await _notificationService.send(
      NotificationPayload(
        notificationId:
            'sync_conflict_${DateTime.now().millisecondsSinceEpoch}',
        type: NotificationType.sync,
        title: 'Конфликт данных',
        body:
            '📋 Тип: $entityType\n'
            '⚠️ Конфликтов: $conflictCount\n'
            '✅ Решение: $resolution',
        posId: _posId,
        storeName: _storeName,
        timestamp: DateTime.now(),
      ),
    );
  }

  Future<void> syncOverdue({required Duration lastSyncAge}) async {
    await _notificationService.send(
      NotificationPayload(
        notificationId: 'sync_overdue_${DateTime.now().millisecondsSinceEpoch}',
        type: NotificationType.sync,
        priority: NotificationPriority.high,
        title: 'Синхронизация просрочена',
        body:
            '⏰ Последняя синхронизация: ${lastSyncAge.inHours}ч назад\n'
            '⚠️ Данные могут быть неактуальны',
        posId: _posId,
        storeName: _storeName,
        timestamp: DateTime.now(),
      ),
    );
  }
}

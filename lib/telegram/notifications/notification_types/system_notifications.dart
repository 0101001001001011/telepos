import 'package:telepos/domain/entities/telegram/notification_payload.dart';
import 'package:telepos/telegram/notifications/notification_service.dart';

class SystemNotifications {
  final NotificationService _notificationService;
  final String _posId;
  final String? _storeName;

  SystemNotifications({
    required NotificationService notificationService,
    required String posId,
    String? storeName,
  }) : _notificationService = notificationService,
       _posId = posId,
       _storeName = storeName;

  Future<void> posStarted({required String version}) async {
    await _notificationService.send(
      NotificationPayload(
        notificationId: 'sys_start_${DateTime.now().millisecondsSinceEpoch}',
        type: NotificationType.system,
        title: 'POS запущен',
        body:
            '✅ Версия: $version\n'
            '🖥️ Терминал готов к работе',
        posId: _posId,
        storeName: _storeName,
        timestamp: DateTime.now(),
      ),
    );
  }

  Future<void> posStopped({String? reason}) async {
    await _notificationService.send(
      NotificationPayload(
        notificationId: 'sys_stop_${DateTime.now().millisecondsSinceEpoch}',
        type: NotificationType.system,
        title: 'POS остановлен',
        body:
            '🔴 Терминал выключен'
            '${reason != null ? "\n📝 Причина: $reason" : ""}',
        posId: _posId,
        storeName: _storeName,
        timestamp: DateTime.now(),
      ),
    );
  }

  Future<void> updateAvailable({
    required String currentVersion,
    required String newVersion,
  }) async {
    await _notificationService.send(
      NotificationPayload(
        notificationId: 'sys_update_${DateTime.now().millisecondsSinceEpoch}',
        type: NotificationType.system,
        title: 'Доступно обновление',
        body:
            '📦 Текущая: $currentVersion\n'
            '🆕 Новая: $newVersion\n'
            '⬇️ Обновление будет установлено автоматически',
        posId: _posId,
        storeName: _storeName,
        timestamp: DateTime.now(),
      ),
    );
  }

  Future<void> backupCreated({
    required String backupPath,
    required int sizeBytes,
  }) async {
    final sizeMb = (sizeBytes / 1024 / 1024).toStringAsFixed(1);
    await _notificationService.send(
      NotificationPayload(
        notificationId: 'sys_backup_${DateTime.now().millisecondsSinceEpoch}',
        type: NotificationType.system,
        title: 'Бэкап создан',
        body:
            '💾 Размер: $sizeMb MB\n'
            '📂 Путь: $backupPath',
        posId: _posId,
        storeName: _storeName,
        timestamp: DateTime.now(),
        isSilent: true,
      ),
    );
  }

  Future<void> lowDiskSpace({required int freeSpaceMb}) async {
    await _notificationService.send(
      NotificationPayload(
        notificationId: 'sys_disk_${DateTime.now().millisecondsSinceEpoch}',
        type: NotificationType.system,
        priority: freeSpaceMb < 100
            ? NotificationPriority.critical
            : NotificationPriority.high,
        title: 'Мало места на диске',
        body:
            '💿 Свободно: $freeSpaceMb MB\n'
            '⚠️ Рекомендуется очистить диск',
        posId: _posId,
        storeName: _storeName,
        timestamp: DateTime.now(),
      ),
    );
  }

  Future<void> maintenanceScheduled({
    required DateTime scheduledTime,
    required String description,
  }) async {
    await _notificationService.send(
      NotificationPayload(
        notificationId: 'sys_maint_${DateTime.now().millisecondsSinceEpoch}',
        type: NotificationType.system,
        title: 'Запланировано обслуживание',
        body:
            '🔧 $description\n'
            '📅 Время: ${scheduledTime.toLocal()}',
        posId: _posId,
        storeName: _storeName,
        timestamp: DateTime.now(),
      ),
    );
  }
}

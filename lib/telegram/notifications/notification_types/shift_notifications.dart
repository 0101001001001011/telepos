import 'package:telepos/domain/entities/telegram/notification_payload.dart';
import 'package:telepos/telegram/notifications/notification_service.dart';

class ShiftNotifications {
  final NotificationService _notificationService;
  final String _posId;
  final String? _storeName;

  ShiftNotifications({
    required NotificationService notificationService,
    required String posId,
    String? storeName,
  }) : _notificationService = notificationService,
       _posId = posId,
       _storeName = storeName;

  Future<void> shiftOpened({
    required String cashierName,
    required int shiftNumber,
    required String openTime,
  }) async {
    await _notificationService.send(
      NotificationPayload(
        notificationId: 'shift_open_${DateTime.now().millisecondsSinceEpoch}',
        type: NotificationType.shift,
        title: 'Смена #$shiftNumber открыта',
        body:
            '👤 Кассир: $cashierName\n'
            '🕐 Время: $openTime',
        posId: _posId,
        storeName: _storeName,
        timestamp: DateTime.now(),
      ),
    );
  }

  Future<void> shiftClosed({
    required String cashierName,
    required int shiftNumber,
    required String closeTime,
    required num totalRevenue,
    required int salesCount,
    required int refundsCount,
    required String currency,
  }) async {
    await _notificationService.send(
      NotificationPayload(
        notificationId: 'shift_close_${DateTime.now().millisecondsSinceEpoch}',
        type: NotificationType.shift,
        title: 'Смена #$shiftNumber закрыта',
        body:
            '👤 Кассир: $cashierName\n'
            '🕐 Время: $closeTime\n'
            '💰 Выручка: ${totalRevenue.toStringAsFixed(2)} $currency\n'
            '🧾 Продаж: $salesCount\n'
            '🔄 Возвратов: $refundsCount',
        posId: _posId,
        storeName: _storeName,
        timestamp: DateTime.now(),
      ),
    );
  }

  Future<void> zReportGenerated({
    required int shiftNumber,
    required num cashInRegister,
    required String currency,
  }) async {
    await _notificationService.send(
      NotificationPayload(
        notificationId: 'z_report_${DateTime.now().millisecondsSinceEpoch}',
        type: NotificationType.shift,
        title: 'Z-отчёт смены #$shiftNumber',
        body:
            '📊 Z-отчёт сформирован\n'
            '💵 В кассе: ${cashInRegister.toStringAsFixed(2)} $currency',
        posId: _posId,
        storeName: _storeName,
        timestamp: DateTime.now(),
        isSilent: true,
      ),
    );
  }
}

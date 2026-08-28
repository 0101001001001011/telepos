import 'package:telepos/domain/entities/telegram/notification_payload.dart';
import 'package:telepos/telegram/notifications/notification_service.dart';

class CashNotifications {
  final NotificationService _notificationService;
  final String _posId;
  final String? _storeName;

  CashNotifications({
    required NotificationService notificationService,
    required String posId,
    String? storeName,
  }) : _notificationService = notificationService,
       _posId = posId,
       _storeName = storeName;

  Future<void> investment({
    required num amount,
    required String currency,
    required String cashier,
    String? comment,
  }) async {
    await _notificationService.send(
      NotificationPayload(
        notificationId: 'cash_invest_${DateTime.now().millisecondsSinceEpoch}',
        type: NotificationType.cash,
        title: 'Вложение в кассу',
        body:
            '💵 Сумма: ${amount.toStringAsFixed(2)} $currency\n'
            '👤 Кассир: $cashier'
            '${comment != null ? "\n📝 $comment" : ""}',
        posId: _posId,
        storeName: _storeName,
        timestamp: DateTime.now(),
      ),
    );
  }

  Future<void> expense({
    required num amount,
    required String currency,
    required String cashier,
    required String expenseType,
    String? comment,
  }) async {
    await _notificationService.send(
      NotificationPayload(
        notificationId: 'cash_expense_${DateTime.now().millisecondsSinceEpoch}',
        type: NotificationType.cash,
        title: 'Расход из кассы',
        body:
            '💸 Сумма: ${amount.toStringAsFixed(2)} $currency\n'
            '📋 Тип: $expenseType\n'
            '👤 Кассир: $cashier'
            '${comment != null ? "\n📝 $comment" : ""}',
        posId: _posId,
        storeName: _storeName,
        timestamp: DateTime.now(),
      ),
    );
  }

  Future<void> dividend({
    required num amount,
    required String currency,
    required String cashier,
  }) async {
    await _notificationService.send(
      NotificationPayload(
        notificationId: 'cash_div_${DateTime.now().millisecondsSinceEpoch}',
        type: NotificationType.cash,
        priority: NotificationPriority.high,
        title: 'Изъятие из кассы',
        body:
            '💰 Сумма: ${amount.toStringAsFixed(2)} $currency\n'
            '👤 Кассир: $cashier',
        posId: _posId,
        storeName: _storeName,
        timestamp: DateTime.now(),
      ),
    );
  }

  Future<void> cashFlowSummary({
    required num cashInRegister,
    required num totalInvestments,
    required num totalExpenses,
    required num totalDividends,
    required String currency,
  }) async {
    await _notificationService.send(
      NotificationPayload(
        notificationId: 'cashflow_${DateTime.now().millisecondsSinceEpoch}',
        type: NotificationType.cash,
        title: 'Движение денег',
        body:
            '💵 В кассе: ${cashInRegister.toStringAsFixed(2)} $currency\n'
            '📥 Вложения: ${totalInvestments.toStringAsFixed(2)} $currency\n'
            '📤 Расходы: ${totalExpenses.toStringAsFixed(2)} $currency\n'
            '💰 Изъятия: ${totalDividends.toStringAsFixed(2)} $currency',
        posId: _posId,
        storeName: _storeName,
        timestamp: DateTime.now(),
        isSilent: true,
      ),
    );
  }
}

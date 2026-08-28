import 'package:telepos/domain/entities/telegram/notification_payload.dart';
import 'package:telepos/telegram/notifications/notification_service.dart';

class SaleNotifications {
  final NotificationService _notificationService;
  final String _posId;
  final String? _storeName;

  num largeSaleThreshold;

  SaleNotifications({
    required NotificationService notificationService,
    required String posId,
    String? storeName,
    this.largeSaleThreshold = 100000,
  }) : _notificationService = notificationService,
       _posId = posId,
       _storeName = storeName;

  Future<void> largeSale({
    required int receiptNo,
    required String cashier,
    required num total,
    required String currency,
    required int itemCount,
    required String paymentType,
  }) async {
    if (total < largeSaleThreshold) return;

    await _notificationService.send(
      NotificationPayload(
        notificationId: 'sale_large_${DateTime.now().millisecondsSinceEpoch}',
        type: NotificationType.sale,
        priority: NotificationPriority.high,
        title: 'Крупная продажа #$receiptNo',
        body:
            '💰 Сумма: ${total.toStringAsFixed(2)} $currency\n'
            '👤 Кассир: $cashier\n'
            '📦 Позиций: $itemCount\n'
            '💳 Оплата: $paymentType',
        posId: _posId,
        storeName: _storeName,
        timestamp: DateTime.now(),
      ),
    );
  }

  Future<void> refundProcessed({
    required int receiptNo,
    required String cashier,
    required num total,
    required String currency,
    required String reason,
    required bool withReceipt,
  }) async {
    await _notificationService.send(
      NotificationPayload(
        notificationId: 'refund_${DateTime.now().millisecondsSinceEpoch}',
        type: NotificationType.sale,
        priority: total > largeSaleThreshold
            ? NotificationPriority.high
            : NotificationPriority.normal,
        title: 'Возврат #$receiptNo',
        body:
            '🔄 Сумма: ${total.toStringAsFixed(2)} $currency\n'
            '👤 Кассир: $cashier\n'
            '📝 Причина: $reason\n'
            '🧾 ${withReceipt ? "С чеком" : "Без чека"}',
        posId: _posId,
        storeName: _storeName,
        timestamp: DateTime.now(),
      ),
    );
  }

  Future<void> dailySummary({
    required num totalRevenue,
    required int salesCount,
    required int refundsCount,
    required num refundsTotal,
    required String currency,
    required num averageCheck,
  }) async {
    await _notificationService.send(
      NotificationPayload(
        notificationId: 'daily_sales_${DateTime.now().millisecondsSinceEpoch}',
        type: NotificationType.sale,
        title: 'Итоги дня',
        body:
            '💰 Выручка: ${totalRevenue.toStringAsFixed(2)} $currency\n'
            '🧾 Продаж: $salesCount\n'
            '📊 Средний чек: ${averageCheck.toStringAsFixed(2)} $currency\n'
            '🔄 Возвратов: $refundsCount (${refundsTotal.toStringAsFixed(2)} $currency)',
        posId: _posId,
        storeName: _storeName,
        timestamp: DateTime.now(),
        isSilent: true,
      ),
    );
  }
}

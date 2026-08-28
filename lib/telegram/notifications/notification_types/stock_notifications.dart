import 'package:telepos/domain/entities/telegram/notification_payload.dart';
import 'package:telepos/telegram/notifications/notification_service.dart';

class StockNotifications {
  final NotificationService _notificationService;
  final String _posId;
  final String? _storeName;

  StockNotifications({
    required NotificationService notificationService,
    required String posId,
    String? storeName,
  }) : _notificationService = notificationService,
       _posId = posId,
       _storeName = storeName;

  Future<void> lowStock({
    required String productName,
    required String barcode,
    required num currentQuantity,
    required num minQuantity,
    required String unit,
  }) async {
    await _notificationService.send(
      NotificationPayload(
        notificationId: 'stock_low_${DateTime.now().millisecondsSinceEpoch}',
        type: NotificationType.stock,
        priority: NotificationPriority.high,
        title: 'Низкий остаток',
        body:
            '📦 $productName\n'
            '🔖 $barcode\n'
            '📉 Остаток: $currentQuantity $unit (мин: $minQuantity)',
        posId: _posId,
        storeName: _storeName,
        timestamp: DateTime.now(),
      ),
    );
  }

  Future<void> outOfStock({
    required String productName,
    required String barcode,
  }) async {
    await _notificationService.send(
      NotificationPayload(
        notificationId: 'stock_out_${DateTime.now().millisecondsSinceEpoch}',
        type: NotificationType.stock,
        priority: NotificationPriority.critical,
        title: 'Нет в наличии',
        body:
            '📦 $productName\n'
            '🔖 $barcode\n'
            '❌ Товар закончился',
        posId: _posId,
        storeName: _storeName,
        timestamp: DateTime.now(),
      ),
    );
  }

  Future<void> deficitSummary({
    required int totalDeficitItems,
    required List<String> topDeficitProducts,
  }) async {
    final productList = topDeficitProducts
        .take(10)
        .map((p) => '  • $p')
        .join('\n');

    await _notificationService.send(
      NotificationPayload(
        notificationId:
            'stock_deficit_${DateTime.now().millisecondsSinceEpoch}',
        type: NotificationType.stock,
        title: 'Дефицит: $totalDeficitItems позиций',
        body: 'Топ дефицитных товаров:\n$productList',
        posId: _posId,
        storeName: _storeName,
        timestamp: DateTime.now(),
        isSilent: true,
      ),
    );
  }
}

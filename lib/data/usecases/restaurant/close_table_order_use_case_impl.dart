import 'package:talker/talker.dart';
import 'package:telepos/core/constants/enums/table_status.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/domain/usecases/restaurant/close_table_order_use_case.dart';

class CloseTableOrderUseCaseImpl implements CloseTableOrderUseCase {
  CloseTableOrderUseCaseImpl({required AppDatabase db, required Talker logger})
    : _db = db,
      _logger = logger;

  final AppDatabase _db;
  final Talker _logger;

  @override
  Future<void> close(int orderId) async {
    try {
      final order = await _db.restaurantOrderDao.findById(orderId);
      if (order == null) {
        throw StateError('CloseTableOrder: order $orderId not found');
      }

      if (order.closeTime != null) {
        _logger.warning('CloseTableOrder: order $orderId already closed');
        return;
      }

      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      await _db.restaurantOrderDao.closeOrder(orderId, now);

      _logger.info('CloseTableOrder: closed order $orderId at $now');

      final tableId = order.tableId;
      if (tableId != null) {
        await _db.restaurantTableDao.updateStatus(
          tableId,
          TableStatus.dirty.index,
        );
        _logger.info('CloseTableOrder: table $tableId -> dirty');
      }
    } catch (e) {
      _logger.error('CloseTableOrder: failed to close order $orderId: $e');
      rethrow;
    }
  }
}

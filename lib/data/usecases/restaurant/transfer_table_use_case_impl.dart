import 'package:talker/talker.dart';
import 'package:telepos/core/constants/enums/table_status.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/domain/usecases/restaurant/transfer_table_use_case.dart';

class TransferTableUseCaseImpl implements TransferTableUseCase {
  TransferTableUseCaseImpl({required AppDatabase db, required Talker logger})
    : _db = db,
      _logger = logger;

  final AppDatabase _db;
  final Talker _logger;

  @override
  Future<void> transfer(int orderId, int newTableId) async {
    try {
      final order = await _db.restaurantOrderDao.findById(orderId);
      if (order == null) {
        throw StateError('TransferTable: order $orderId not found');
      }

      if (order.closeTime != null) {
        throw StateError('TransferTable: order $orderId is already closed');
      }

      final oldTableId = order.tableId;

      await _db.restaurantOrderDao.transferTable(orderId, newTableId);

      _logger.info(
        'TransferTable: order $orderId moved from '
        'table $oldTableId to $newTableId',
      );

      if (oldTableId != null) {
        await _db.restaurantTableDao.updateStatus(
          oldTableId,
          TableStatus.free.index,
        );
        _logger.info('TransferTable: old table $oldTableId -> free');
      }

      await _db.restaurantTableDao.updateStatus(
        newTableId,
        TableStatus.occupied.index,
      );
      _logger.info('TransferTable: new table $newTableId -> occupied');
    } catch (e) {
      _logger.error(
        'TransferTable: failed to transfer order $orderId '
        'to table $newTableId: $e',
      );
      rethrow;
    }
  }
}

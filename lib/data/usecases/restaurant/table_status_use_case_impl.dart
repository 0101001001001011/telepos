import 'package:talker/talker.dart';
import 'package:telepos/core/constants/enums/table_status.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/domain/usecases/restaurant/table_status_use_case.dart';

class TableStatusUseCaseImpl implements TableStatusUseCase {
  TableStatusUseCaseImpl({required AppDatabase db, required Talker logger})
    : _db = db,
      _logger = logger;

  final AppDatabase _db;
  final Talker _logger;

  @override
  Future<void> setFree(int tableId) async {
    try {
      await _db.restaurantTableDao.updateStatus(
        tableId,
        TableStatus.free.index,
      );
      _logger.info('TableStatus: table $tableId -> free');
    } catch (e) {
      _logger.error('TableStatus: failed to set table $tableId free: $e');
      rethrow;
    }
  }

  @override
  Future<void> setOccupied(int tableId) async {
    try {
      await _db.restaurantTableDao.updateStatus(
        tableId,
        TableStatus.occupied.index,
      );
      _logger.info('TableStatus: table $tableId -> occupied');
    } catch (e) {
      _logger.error('TableStatus: failed to set table $tableId occupied: $e');
      rethrow;
    }
  }

  @override
  Future<void> setReserved(int tableId) async {
    try {
      await _db.restaurantTableDao.updateStatus(
        tableId,
        TableStatus.reserved.index,
      );
      _logger.info('TableStatus: table $tableId -> reserved');
    } catch (e) {
      _logger.error('TableStatus: failed to set table $tableId reserved: $e');
      rethrow;
    }
  }

  @override
  Future<void> setDirty(int tableId) async {
    try {
      await _db.restaurantTableDao.updateStatus(
        tableId,
        TableStatus.dirty.index,
      );
      _logger.info('TableStatus: table $tableId -> dirty');
    } catch (e) {
      _logger.error('TableStatus: failed to set table $tableId dirty: $e');
      rethrow;
    }
  }
}

import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/mappers/shift_mapper.dart';
import 'package:telepos/domain/entities/shift/shift_entity.dart';
import 'package:telepos/domain/repositories/shift_repository.dart';

class ShiftRepositoryImpl implements ShiftRepository {
  ShiftRepositoryImpl(this._db);

  final AppDatabase _db;

  @override
  Future<ShiftEntity?> findOpenedShift() async {
    final shift = await _db.shiftDao.findOpenedShift();
    return shift != null ? ShiftMapper.fromDrift(shift) : null;
  }

  @override
  Future<ShiftEntity?> findById(int shiftId) async {
    final shift = await _db.shiftDao.findById(shiftId);
    return shift != null ? ShiftMapper.fromDrift(shift) : null;
  }

  @override
  Future<int> openShift(int userId) async {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    return _db.shiftDao.insertShift(
      ShiftsCompanion.insert(
        userId: userId,
        openTime: now,
        isOpened: true,
        isSynced: false,
      ),
    );
  }

  @override
  Future<void> closeShift(
    int shiftId, {
    required int closeTime,
    required int openTime,
    required Decimal cashInPos,
  }) async {
    await _db.shiftDao.updateShift(
      shiftId,
      ShiftsCompanion(
        openTime: Value(openTime),
        isOpened: const Value(false),
        closeTime: Value(closeTime),
        cashInPosOnShiftClose: Value(cashInPos),
      ),
    );
  }

  @override
  Future<ShiftEntity?> findLastClosed() async {
    final shift = await _db.shiftDao.findLastClosed();
    return shift != null ? ShiftMapper.fromDrift(shift) : null;
  }

  @override
  Future<void> markAsSynced(int shiftId) {
    return _db.shiftDao.markAsSynced(shiftId).then((_) {});
  }

  @override
  Future<int> countOpened() {
    return _db.shiftDao.countOpened();
  }
}

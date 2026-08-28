import 'package:decimal/decimal.dart';
import 'package:telepos/domain/entities/shift/shift_entity.dart';

abstract class ShiftRepository {
  Future<ShiftEntity?> findOpenedShift();

  Future<ShiftEntity?> findById(int shiftId);

  Future<int> openShift(int userId);

  Future<void> closeShift(
    int shiftId, {
    required int closeTime,
    required int openTime,
    required Decimal cashInPos,
  });

  Future<ShiftEntity?> findLastClosed();

  Future<void> markAsSynced(int shiftId);

  Future<int> countOpened();
}

import 'package:drift/drift.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/domain/entities/shift/shift_entity.dart';

class ShiftMapper {
  ShiftMapper._();

  static ShiftEntity fromDrift(Shift shift) {
    return ShiftEntity(
      id: shift.id,
      userId: shift.userId,
      openTime: shift.openTime,
      isOpened: shift.isOpened,
      closeTime: shift.closeTime,
      cashInPosOnShiftClose: shift.cashInPosOnShiftClose,
      isSynced: shift.isSynced,
    );
  }

  static ShiftsCompanion toDrift(ShiftEntity entity) {
    return ShiftsCompanion(
      id: entity.id != null ? Value(entity.id!) : const Value.absent(),
      userId: Value(entity.userId),
      openTime: Value(entity.openTime),
      isOpened: Value(entity.isOpened),
      closeTime: Value(entity.closeTime),
      cashInPosOnShiftClose: Value(entity.cashInPosOnShiftClose),
      isSynced: Value(entity.isSynced),
    );
  }

  static List<ShiftEntity> fromDriftList(List<Shift> shifts) {
    return shifts.map(fromDrift).toList();
  }
}

import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart' hide isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/mappers/shift_mapper.dart';

void main() {
  group('ShiftRepositoryImpl openShift companion', () {
    test('creates correct companion for new shift', () {
      const userId = 42;
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

      final companion = ShiftsCompanion.insert(
        userId: userId,
        openTime: now,
        isOpened: true,
        isSynced: false,
      );

      expect(companion.userId.value, userId);
      expect(companion.openTime.value, now);
      expect(companion.isOpened.value, true);
      expect(companion.isSynced.value, false);
    });
  });

  group('ShiftRepositoryImpl closeShift companion', () {
    test('creates correct companion for closing shift', () {
      const shiftId = 1;
      final closeTime = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final openTime = closeTime - 28800;
      final cashInPos = Decimal.parse('150000.500');

      final companion = ShiftsCompanion(
        openTime: Value(openTime),
        isOpened: const Value(false),
        closeTime: Value(closeTime),
        cashInPosOnShiftClose: Value(cashInPos),
      );

      expect(companion.openTime.value, openTime);
      expect(companion.isOpened.value, false);
      expect(companion.closeTime.value, closeTime);
      expect(companion.cashInPosOnShiftClose.value, cashInPos);
      expect(shiftId, 1);
    });

    test('closeShift companion does not modify userId', () {
      final companion = ShiftsCompanion(
        openTime: Value(1700000000),
        isOpened: const Value(false),
        closeTime: Value(1700028800),
        cashInPosOnShiftClose: Value(Decimal.parse('50000.000')),
      );

      expect(companion.userId, const Value<int>.absent());
    });
  });

  group('ShiftMapper integration with repository', () {
    test('fromDrift correctly maps opened shift', () {
      final shift = Shift(
        id: 1,
        userId: 42,
        openTime: 1700000000,
        isOpened: true,
        isSynced: false,
      );

      final entity = ShiftMapper.fromDrift(shift);

      expect(entity.id, 1);
      expect(entity.userId, 42);
      expect(entity.openTime, 1700000000);
      expect(entity.isOpened, true);
      expect(entity.isSynced, false);
      expect(entity.closeTime, isNull);
      expect(entity.cashInPosOnShiftClose, isNull);
    });

    test('fromDrift correctly maps closed shift', () {
      final shift = Shift(
        id: 1,
        userId: 42,
        openTime: 1700000000,
        closeTime: 1700028800,
        isOpened: false,
        isSynced: true,
        cashInPosOnShiftClose: Decimal.parse('150000.500'),
      );

      final entity = ShiftMapper.fromDrift(shift);

      expect(entity.id, 1);
      expect(entity.userId, 42);
      expect(entity.openTime, 1700000000);
      expect(entity.closeTime, 1700028800);
      expect(entity.isOpened, false);
      expect(entity.isSynced, true);
      expect(entity.cashInPosOnShiftClose, Decimal.parse('150000.500'));
    });

    test('toDrift round-trip for shift lifecycle', () {
      const userId = 10;
      final openTime = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final openCompanion = ShiftsCompanion.insert(
        userId: userId,
        openTime: openTime,
        isOpened: true,
        isSynced: false,
      );

      expect(openCompanion.userId.value, userId);
      expect(openCompanion.openTime.value, openTime);
      expect(openCompanion.isOpened.value, true);

      final openedShift = Shift(
        id: 1,
        userId: userId,
        openTime: openTime,
        isOpened: true,
        isSynced: false,
      );

      final openedEntity = ShiftMapper.fromDrift(openedShift);
      expect(openedEntity.isOpened, true);
      expect(openedEntity.closeTime, isNull);

      final closeTime = openTime + 28800;
      final cashInPos = Decimal.parse('250000.000');
      final closeCompanion = ShiftsCompanion(
        openTime: Value(openTime),
        isOpened: const Value(false),
        closeTime: Value(closeTime),
        cashInPosOnShiftClose: Value(cashInPos),
      );

      final closedShift = Shift(
        id: 1,
        userId: userId,
        openTime: openTime,
        closeTime: closeTime,
        isOpened: false,
        isSynced: false,
        cashInPosOnShiftClose: cashInPos,
      );

      final closedEntity = ShiftMapper.fromDrift(closedShift);
      expect(closedEntity.isOpened, false);
      expect(closedEntity.closeTime, closeTime);
      expect(closedEntity.cashInPosOnShiftClose, cashInPos);
      expect(closeCompanion.isOpened.value, false);
    });
  });
}

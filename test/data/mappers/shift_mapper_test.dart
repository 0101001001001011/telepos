import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/mappers/shift_mapper.dart';
import 'package:telepos/domain/entities/shift/shift_entity.dart';

void main() {
  group('ShiftMapper', () {
    test('fromDrift converts all fields', () {
      final driftShift = Shift(
        id: 1,
        userId: 5,
        openTime: 1700000000,
        isOpened: true,
        closeTime: null,
        cashInPosOnShiftClose: null,
        isSynced: false,
      );

      final entity = ShiftMapper.fromDrift(driftShift);

      expect(entity.id, 1);
      expect(entity.userId, 5);
      expect(entity.openTime, 1700000000);
      expect(entity.isOpened, true);
      expect(entity.closeTime, isNull);
      expect(entity.cashInPosOnShiftClose, isNull);
      expect(entity.isSynced, false);
    });

    test('fromDrift with close data', () {
      final driftShift = Shift(
        id: 2,
        userId: 5,
        openTime: 1700000000,
        isOpened: false,
        closeTime: 1700036000,
        cashInPosOnShiftClose: Decimal.parse('15000.500'),
        isSynced: true,
      );

      final entity = ShiftMapper.fromDrift(driftShift);

      expect(entity.isOpened, false);
      expect(entity.isClosed, true);
      expect(entity.closeTime, 1700036000);
      expect(entity.cashInPosOnShiftClose, Decimal.parse('15000.500'));
      expect(entity.isSynced, true);
    });

    test('toDrift creates companion', () {
      final entity = ShiftEntity(
        id: 1,
        userId: 5,
        openTime: 1700000000,
        isOpened: true,
      );

      final companion = ShiftMapper.toDrift(entity);

      expect(companion.id.value, 1);
      expect(companion.userId.value, 5);
      expect(companion.openTime.value, 1700000000);
      expect(companion.isOpened.value, true);
      expect(companion.isSynced.value, false);
    });

    test('round-trip preserves data', () {
      final original = ShiftEntity(
        id: 3,
        userId: 10,
        openTime: 1700000000,
        isOpened: false,
        closeTime: 1700036000,
        cashInPosOnShiftClose: Decimal.parse('25000.000'),
        isSynced: true,
      );

      final companion = ShiftMapper.toDrift(original);

      final driftShift = Shift(
        id: companion.id.value,
        userId: companion.userId.value,
        openTime: companion.openTime.value,
        isOpened: companion.isOpened.value,
        closeTime: companion.closeTime.value,
        cashInPosOnShiftClose: companion.cashInPosOnShiftClose.value,
        isSynced: companion.isSynced.value,
      );

      final restored = ShiftMapper.fromDrift(driftShift);

      expect(restored.id, original.id);
      expect(restored.userId, original.userId);
      expect(restored.openTime, original.openTime);
      expect(restored.isOpened, original.isOpened);
      expect(restored.closeTime, original.closeTime);
      expect(restored.cashInPosOnShiftClose, original.cashInPosOnShiftClose);
      expect(restored.isSynced, original.isSynced);
    });

    test('fromDriftList', () {
      final shifts = [
        Shift(
          id: 1,
          userId: 5,
          openTime: 1700000000,
          isOpened: true,
          isSynced: false,
        ),
        Shift(
          id: 2,
          userId: 5,
          openTime: 1700036000,
          isOpened: false,
          closeTime: 1700072000,
          isSynced: true,
        ),
      ];

      final entities = ShiftMapper.fromDriftList(shifts);
      expect(entities.length, 2);
      expect(entities[0].id, 1);
      expect(entities[0].isOpened, true);
      expect(entities[1].id, 2);
      expect(entities[1].isClosed, true);
    });
  });
}

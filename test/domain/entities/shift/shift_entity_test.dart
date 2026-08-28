import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telepos/domain/entities/shift/shift_entity.dart';

void main() {
  group('ShiftEntity', () {
    final openShift = ShiftEntity(
      id: 1,
      userId: 5,
      openTime: 1700000000,
      isOpened: true,
    );

    test('creates with required fields', () {
      expect(openShift.id, 1);
      expect(openShift.userId, 5);
      expect(openShift.openTime, 1700000000);
      expect(openShift.isOpened, true);
    });

    test('defaults', () {
      expect(openShift.isSynced, false);
      expect(openShift.closeTime, isNull);
      expect(openShift.cashInPosOnShiftClose, isNull);
    });

    test('isClosed', () {
      expect(openShift.isClosed, false);

      final closedShift = openShift.copyWith(isOpened: false);
      expect(closedShift.isClosed, true);
    });

    test('durationSeconds', () {
      expect(openShift.durationSeconds, isNull);

      final closedShift = openShift.copyWith(
        isOpened: false,
        closeTime: 1700003600,
      );
      expect(closedShift.durationSeconds, 3600);
    });

    test('copyWith preserves values', () {
      final copy = openShift.copyWith(userId: 10);
      expect(copy.userId, 10);
      expect(copy.id, 1);
      expect(copy.openTime, 1700000000);
      expect(copy.isOpened, true);
    });

    test('copyWith clearCloseTime', () {
      final closed = openShift.copyWith(closeTime: 1700003600);
      expect(closed.closeTime, 1700003600);

      final cleared = closed.copyWith(clearCloseTime: true);
      expect(cleared.closeTime, isNull);
    });

    test('copyWith clearCashInPos', () {
      final withCash = openShift.copyWith(
        cashInPosOnShiftClose: Decimal.parse('5000.000'),
      );
      expect(withCash.cashInPosOnShiftClose, Decimal.parse('5000.000'));

      final cleared = withCash.copyWith(clearCashInPos: true);
      expect(cleared.cashInPosOnShiftClose, isNull);
    });
  });
}

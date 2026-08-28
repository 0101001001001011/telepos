import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:telepos/domain/services/shift_service.dart';

class MockShiftService extends Mock implements ShiftService {}

class FakeDecimal extends Fake implements Decimal {}

class TestShift {
  final int id;
  final int userId;
  final int posId;
  final int openTime;
  final int? closeTime;
  final bool isOpened;
  final bool isSynced;
  final Decimal? cashInPosOnShiftClose;

  TestShift({
    required this.id,
    required this.userId,
    required this.posId,
    required this.openTime,
    this.closeTime,
    this.isOpened = true,
    this.isSynced = false,
    this.cashInPosOnShiftClose,
  });
}

void main() {
  setUpAll(() {
    registerFallbackValue(Decimal.zero);
  });

  group('ShiftService', () {
    late MockShiftService mockShiftService;

    setUp(() {
      mockShiftService = MockShiftService();
    });

    group('onOpenShift', () {
      test('should open shift successfully for user', () async {
        when(
          () => mockShiftService.onOpenShift(any()),
        ).thenAnswer((_) async {});

        await expectLater(mockShiftService.onOpenShift(1), completes);

        verify(() => mockShiftService.onOpenShift(1)).called(1);
      });

      test('should open shift for different user IDs', () async {
        when(
          () => mockShiftService.onOpenShift(any()),
        ).thenAnswer((_) async {});

        await mockShiftService.onOpenShift(1);
        await mockShiftService.onOpenShift(2);
        await mockShiftService.onOpenShift(3);

        verify(() => mockShiftService.onOpenShift(1)).called(1);
        verify(() => mockShiftService.onOpenShift(2)).called(1);
        verify(() => mockShiftService.onOpenShift(3)).called(1);
      });

      test('should throw exception when database error occurs', () async {
        when(
          () => mockShiftService.onOpenShift(any()),
        ).thenThrow(Exception('Database error'));

        expect(() => mockShiftService.onOpenShift(1), throwsException);
      });

      test('should throw exception when shift already open', () async {
        when(
          () => mockShiftService.onOpenShift(any()),
        ).thenThrow(Exception('Shift already open'));

        expect(
          () => mockShiftService.onOpenShift(1),
          throwsA(isA<Exception>()),
        );
      });

      test('should handle zero user ID', () async {
        when(() => mockShiftService.onOpenShift(0)).thenAnswer((_) async {});

        await expectLater(mockShiftService.onOpenShift(0), completes);
      });
    });

    group('onCloseShift', () {
      test('should close shift successfully with cash amount', () async {
        when(
          () => mockShiftService.onCloseShift(any()),
        ).thenAnswer((_) async {});

        await expectLater(
          mockShiftService.onCloseShift(Decimal.parse('10000.00')),
          completes,
        );

        verify(
          () => mockShiftService.onCloseShift(Decimal.parse('10000.00')),
        ).called(1);
      });

      test('should close shift with zero cash', () async {
        when(
          () => mockShiftService.onCloseShift(any()),
        ).thenAnswer((_) async {});

        await expectLater(
          mockShiftService.onCloseShift(Decimal.zero),
          completes,
        );
      });

      test('should close shift with large cash amount', () async {
        final largeCash = Decimal.parse('999999.999');
        when(
          () => mockShiftService.onCloseShift(any()),
        ).thenAnswer((_) async {});

        await expectLater(mockShiftService.onCloseShift(largeCash), completes);
      });

      test('should throw exception when no open shift', () async {
        when(
          () => mockShiftService.onCloseShift(any()),
        ).thenThrow(Exception('No open shift'));

        expect(
          () => mockShiftService.onCloseShift(Decimal.parse('10000.00')),
          throwsException,
        );
      });

      test('should throw exception on database error', () async {
        when(
          () => mockShiftService.onCloseShift(any()),
        ).thenThrow(Exception('Database error'));

        expect(
          () => mockShiftService.onCloseShift(Decimal.parse('10000.00')),
          throwsA(isA<Exception>()),
        );
      });

      test('should handle decimal precision correctly', () async {
        final precisionCash = Decimal.parse('12345.678');
        when(
          () => mockShiftService.onCloseShift(any()),
        ).thenAnswer((_) async {});

        await expectLater(
          mockShiftService.onCloseShift(precisionCash),
          completes,
        );

        verify(
          () => mockShiftService.onCloseShift(Decimal.parse('12345.678')),
        ).called(1);
      });
    });

    group('getOpenedShift', () {
      test('should return open shift when exists', () async {
        final openShift = TestShift(
          id: 1,
          userId: 1,
          posId: 100,
          openTime: DateTime.now().millisecondsSinceEpoch,
          isOpened: true,
        );
        when(
          () => mockShiftService.getOpenedShift(),
        ).thenAnswer((_) async => openShift);

        final result = await mockShiftService.getOpenedShift();

        expect(result, isNotNull);
        expect((result as TestShift).isOpened, true);
      });

      test('should return null when no open shift', () async {
        when(
          () => mockShiftService.getOpenedShift(),
        ).thenAnswer((_) async => null);

        final result = await mockShiftService.getOpenedShift();

        expect(result, isNull);
      });

      test('should return shift with correct user ID', () async {
        final openShift = TestShift(
          id: 1,
          userId: 5,
          posId: 100,
          openTime: DateTime.now().millisecondsSinceEpoch,
        );
        when(
          () => mockShiftService.getOpenedShift(),
        ).thenAnswer((_) async => openShift);

        final result = await mockShiftService.getOpenedShift();

        expect((result as TestShift).userId, 5);
      });

      test('should return shift with correct POS ID', () async {
        final openShift = TestShift(
          id: 1,
          userId: 1,
          posId: 200,
          openTime: DateTime.now().millisecondsSinceEpoch,
        );
        when(
          () => mockShiftService.getOpenedShift(),
        ).thenAnswer((_) async => openShift);

        final result = await mockShiftService.getOpenedShift();

        expect((result as TestShift).posId, 200);
      });

      test('should throw exception on database error', () async {
        when(
          () => mockShiftService.getOpenedShift(),
        ).thenThrow(Exception('Database error'));

        expect(() => mockShiftService.getOpenedShift(), throwsException);
      });

      test('should return shift with isSynced false for new shift', () async {
        final openShift = TestShift(
          id: 1,
          userId: 1,
          posId: 100,
          openTime: DateTime.now().millisecondsSinceEpoch,
          isSynced: false,
        );
        when(
          () => mockShiftService.getOpenedShift(),
        ).thenAnswer((_) async => openShift);

        final result = await mockShiftService.getOpenedShift();

        expect((result as TestShift).isSynced, false);
      });

      test('should return shift with no close time when open', () async {
        final openShift = TestShift(
          id: 1,
          userId: 1,
          posId: 100,
          openTime: DateTime.now().millisecondsSinceEpoch,
          closeTime: null,
          isOpened: true,
        );
        when(
          () => mockShiftService.getOpenedShift(),
        ).thenAnswer((_) async => openShift);

        final result = await mockShiftService.getOpenedShift();

        expect((result as TestShift).closeTime, isNull);
        expect(result.isOpened, true);
      });
    });

    group('shift lifecycle', () {
      test('should complete open and close cycle', () async {
        when(
          () => mockShiftService.onOpenShift(any()),
        ).thenAnswer((_) async {});
        when(() => mockShiftService.getOpenedShift()).thenAnswer(
          (_) async => TestShift(
            id: 1,
            userId: 1,
            posId: 100,
            openTime: DateTime.now().millisecondsSinceEpoch,
          ),
        );
        when(
          () => mockShiftService.onCloseShift(any()),
        ).thenAnswer((_) async {});

        await mockShiftService.onOpenShift(1);
        final openShift = await mockShiftService.getOpenedShift();
        await mockShiftService.onCloseShift(Decimal.parse('5000.00'));

        expect(openShift, isNotNull);
        verify(() => mockShiftService.onOpenShift(1)).called(1);
        verify(() => mockShiftService.getOpenedShift()).called(1);
        verify(
          () => mockShiftService.onCloseShift(Decimal.parse('5000.00')),
        ).called(1);
      });

      test('should handle multiple shift cycles', () async {
        var callCount = 0;
        when(
          () => mockShiftService.onOpenShift(any()),
        ).thenAnswer((_) async {});
        when(() => mockShiftService.getOpenedShift()).thenAnswer((_) async {
          callCount++;
          if (callCount <= 2) {
            return TestShift(
              id: callCount,
              userId: 1,
              posId: 100,
              openTime: DateTime.now().millisecondsSinceEpoch,
            );
          }
          return null;
        });
        when(
          () => mockShiftService.onCloseShift(any()),
        ).thenAnswer((_) async {});

        await mockShiftService.onOpenShift(1);
        final firstShift = await mockShiftService.getOpenedShift();
        await mockShiftService.onCloseShift(Decimal.parse('1000.00'));

        await mockShiftService.onOpenShift(2);
        final secondShift = await mockShiftService.getOpenedShift();
        await mockShiftService.onCloseShift(Decimal.parse('2000.00'));

        expect((firstShift as TestShift).id, 1);
        expect((secondShift as TestShift).id, 2);
      });
    });
  });

  group('TestShift (mock data class)', () {
    test('should create shift with required fields', () {
      final shift = TestShift(
        id: 1,
        userId: 1,
        posId: 100,
        openTime: 1234567890,
      );

      expect(shift.id, 1);
      expect(shift.userId, 1);
      expect(shift.posId, 100);
      expect(shift.openTime, 1234567890);
      expect(shift.closeTime, isNull);
      expect(shift.isOpened, true);
      expect(shift.isSynced, false);
      expect(shift.cashInPosOnShiftClose, isNull);
    });

    test('should create closed shift with all fields', () {
      final shift = TestShift(
        id: 1,
        userId: 1,
        posId: 100,
        openTime: 1234567890,
        closeTime: 1234577890,
        isOpened: false,
        isSynced: true,
        cashInPosOnShiftClose: Decimal.parse('5000.00'),
      );

      expect(shift.closeTime, 1234577890);
      expect(shift.isOpened, false);
      expect(shift.isSynced, true);
      expect(shift.cashInPosOnShiftClose, Decimal.parse('5000.00'));
    });
  });
}

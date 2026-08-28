library;

import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';

import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/domain/services/shift_service.dart';
import 'package:telepos/presentation/controllers/sale/sale_controller.dart';
import 'package:telepos/presentation/controllers/shift/shift_controller.dart';

import '../support/harness.dart';

void main() {
  final h = E2eHarness();
  late ProviderContainer container;

  setUpAll(() async {
    await h.setUp();
    GetIt.I.registerSingleton<AppDatabase>(h.db);
  });
  tearDownAll(() => h.tearDown());

  setUp(() async {
    await h.db.delete(h.db.sales).go();
    await h.db.delete(h.db.shifts).go();
    container = ProviderContainer();
    addTearDown(container.dispose);
  });

  Future<int> openShiftAged(double ageHours) async {
    final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final openSec = nowSec - (ageHours * 3600).round();
    return h.db
        .into(h.db.shifts)
        .insert(
          ShiftsCompanion.insert(
            userId: 1,
            openTime: openSec,
            isOpened: true,
            isSynced: false,
            openingCash: Value(d('0')),
          ),
        );
  }

  Future<void> settleShift() async {
    for (var i = 0; i < 25; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
      if (!container.read(shiftControllerProvider).isLoading) return;
    }
  }

  Future<void> settleSale() async {
    for (var i = 0; i < 25; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
      final s = container.read(saleControllerProvider);
      if (s.receiptNo != null || s.error != null) return;
    }
  }

  test(
    'ShiftState flags a 25h-old open shift as over-age; a fresh shift is not',
    () async {
      await openShiftAged(25);
      final notifier = container.read(shiftControllerProvider.notifier);
      await settleShift();

      final overAged = container.read(shiftControllerProvider);
      expect(overAged.isOpen, isTrue, reason: 'the aged shift is open');
      expect(overAged.shiftAge, isNotNull);
      expect(
        overAged.shiftAge! >= const Duration(hours: 24),
        isTrue,
        reason: 'a 25h-old shift exceeds the 24h limit',
      );
      expect(
        overAged.isOverAge,
        isTrue,
        reason: 'a shift open >= 24h must be flagged isOverAge',
      );
    },
  );

  test('a freshly opened shift is NOT over-age', () async {
    await openShiftAged(0);
    container.read(shiftControllerProvider.notifier);
    await settleShift();

    final fresh = container.read(shiftControllerProvider);
    expect(fresh.isOpen, isTrue);
    expect(
      fresh.isOverAge,
      isFalse,
      reason: 'a fresh shift is well under the 24h limit',
    );
  });

  test('ShiftService.isShiftOverAge is honest and offline', () async {
    final service = GetIt.I<ShiftService>();

    expect(
      await service.isShiftOverAge(),
      isFalse,
      reason: 'no open shift cannot be over-age',
    );

    await openShiftAged(1);
    expect(
      await service.isShiftOverAge(),
      isFalse,
      reason: '1h-old shift is under the 24h limit',
    );

    await h.db.delete(h.db.shifts).go();
    await openShiftAged(25);
    expect(
      await service.isShiftOverAge(),
      isTrue,
      reason: '25h-old open shift is over-age',
    );
  });

  test('a 25h-old shift BLOCKS starting a new sale with an honest error; '
      'no IN_PROGRESS sale is created', () async {
    final db = GetIt.I<AppDatabase>();
    await openShiftAged(25);

    expect(
      await db.saleDao.countWithState(0),
      0,
      reason: 'clean ledger before the blocked sale',
    );

    container.read(saleControllerProvider.notifier);
    await settleSale();

    final blocked = container.read(saleControllerProvider);
    expect(
      blocked.error,
      kShiftOverAgeError,
      reason: 'sale start must surface the honest over-age error',
    );
    expect(
      blocked.receiptNo,
      isNull,
      reason: 'no receipt is assigned when the sale is blocked',
    );
    expect(
      await db.saleDao.countWithState(0),
      0,
      reason: 'no IN_PROGRESS sale row is created on a blocked shift',
    );

    expect(kShiftOverAgeMessage, contains('закройте смену'));
  });

  test('a fresh shift allows starting a sale: a receipt is assigned, an '
      'IN_PROGRESS row exists, and there is no over-age error', () async {
    final db = GetIt.I<AppDatabase>();
    await openShiftAged(0);

    container.read(saleControllerProvider.notifier);
    await settleSale();

    final ok = container.read(saleControllerProvider);
    expect(
      ok.error,
      isNot(kShiftOverAgeError),
      reason: 'a fresh shift must not raise the over-age error',
    );
    expect(
      ok.receiptNo,
      isNotNull,
      reason: 'a sale is initiated (receipt assigned) on a fresh shift',
    );
    expect(
      await db.saleDao.countWithState(0),
      greaterThanOrEqualTo(1),
      reason: 'an IN_PROGRESS sale row exists after a successful start',
    );
  });
}

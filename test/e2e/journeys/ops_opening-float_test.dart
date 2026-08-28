library;

import 'package:decimal/decimal.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';

import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/domain/services/shift_service.dart';
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
    await h.db.delete(h.db.shifts).go();
    container = ProviderContainer();
    addTearDown(container.dispose);
  });

  Future<void> settle(ShiftNotifier notifier) async {
    for (var i = 0; i < 25; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
      if (!container.read(shiftControllerProvider).isLoading) return;
    }
  }

  test('opening float is persisted to Shifts.openingCash and drives the close '
      'reconciliation (shortage/overage), Decimal-exact, offline', () async {
    final db = GetIt.I<AppDatabase>();

    final notifier = container.read(shiftControllerProvider.notifier);
    await settle(notifier);
    expect(
      container.read(shiftControllerProvider).isOpen,
      isFalse,
      reason: 'no shift open at the start',
    );

    await notifier.openShift(d('5000'), userId: 1);
    await settle(notifier);

    final opened = container.read(shiftControllerProvider);
    expect(opened.isOpen, isTrue, reason: 'shift must be open after openShift');

    final shiftRow = await db.shiftDao.findOpenedShift();
    expect(shiftRow, isNotNull, reason: 'an opened shift row must exist');
    expect(
      shiftRow!.openingCash,
      d('5000'),
      reason: 'Shifts.openingCash must persist the 5000 opening float',
    );

    expect(
      opened.openingCash,
      d('5000'),
      reason: 'ShiftState.openingCash must reflect the persisted float',
    );

    expect(opened.cashSalesTotal, Decimal.zero, reason: 'no cash sales yet');
    expect(opened.expenseTotal, Decimal.zero, reason: 'no expenses yet');
    expect(opened.dividendTotal, Decimal.zero, reason: 'no payouts yet');
    expect(
      opened.expectedCash,
      d('5000'),
      reason: 'expected cash = openingCash + cashSales - payouts = 5000',
    );

    notifier.selectTab(1);
    notifier.setManualTotal(d('5000'));
    var s = container.read(shiftControllerProvider);
    expect(s.enteredTotal, d('5000'));
    expect(
      s.reconciliation,
      Decimal.zero,
      reason: 'counting exactly the float yields no shortage/overage',
    );

    notifier.setManualTotal(d('4800'));
    s = container.read(shiftControllerProvider);
    expect(
      s.reconciliation,
      d('-200'),
      reason: 'counted 4800 - expected 5000 = -200 shortage',
    );

    notifier.setManualTotal(d('5300'));
    s = container.read(shiftControllerProvider);
    expect(
      s.reconciliation,
      d('300'),
      reason: 'counted 5300 - expected 5000 = +300 overage',
    );

    await notifier.closeShift();
    await settle(notifier);

    final closed = await db.shiftDao.findById(shiftRow.id);
    expect(closed, isNotNull);
    expect(closed!.isOpened, isFalse, reason: 'shift must be closed');
    expect(
      closed.openingCash,
      d('5000'),
      reason: 'opening float remains persisted after close',
    );
    expect(
      closed.cashInPosOnShiftClose,
      d('5300'),
      reason: 'counted cash (last entered total) recorded on close',
    );
  });

  test('opening float defaults to zero when not provided (service-level), '
      'keeping reconciliation honest', () async {
    final db = GetIt.I<AppDatabase>();
    final service = GetIt.I<ShiftService>();

    await service.onOpenShift(1);
    final row = await db.shiftDao.findOpenedShift();
    expect(row, isNotNull);
    expect(
      row!.openingCash,
      Decimal.zero,
      reason: 'absent float persists as a Decimal zero basis',
    );
  });
}

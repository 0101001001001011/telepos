library;

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';

import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/database/daos/account_dao.dart';
import 'package:telepos/domain/usecases/cash_operation/cash_in_out_controller.dart';

import '../support/harness.dart';

void main() {
  final h = E2eHarness();

  setUp(() => h.setUp());
  tearDown(() => h.tearDown());

  Future<void> goTo(WidgetTester tester, String route) async {
    final ctx = tester.element(find.byType(Navigator).first);
    GoRouter.of(ctx).go(route);
    await tester.pumpAndSettle(const Duration(seconds: 2));
  }

  Future<int> openShiftInDb(AppDatabase db) async {
    final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    return db
        .into(db.shifts)
        .insert(
          ShiftsCompanion.insert(
            userId: 1,
            openTime: nowSec - 5,
            isOpened: true,
            isSynced: false,
          ),
        );
  }

  Future<void> tapDigit(WidgetTester tester, String d) async {
    final f = find.text(d);
    expect(f, findsWidgets, reason: 'numpad digit "$d" must be tappable');
    await tester.tap(f.first);
    await tester.pump(const Duration(milliseconds: 60));
  }

  Future<void> enterAmount(WidgetTester tester, String digits) async {
    for (final ch in digits.split('')) {
      await tapDigit(tester, ch);
    }
    await tester.pumpAndSettle();
  }

  Future<int> posAccountId(AppDatabase db) async {
    final pos = await db.thisPosDao.get();
    return pos!.accountId ??
        (await db.accountDao.findByType(AccountType.pos)).first.id;
  }

  Future<int> bankAccountId(AppDatabase db) async {
    return (await db.accountDao.findByType(AccountType.customBank)).first.id;
  }

  Future<Decimal> balanceOf(AppDatabase db, int accountId) async {
    final acc = await db.accountDao.findById(accountId);
    return acc?.value ?? Decimal.zero;
  }

  Future<void> setBalance(AppDatabase db, int accountId, Decimal value) =>
      db.accountDao.updateBalance(accountId, value);

  testWidgets(
    'инкассация is a real transfer: POS 10000 collect 4000 → POS 6000, bank +4000 (conserved), wired in UI',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1400, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final db = h.db;
      GetIt.I.registerSingleton<AppDatabase>(db);

      await openShiftInDb(db);

      final posId = await posAccountId(db);
      final bankId = await bankAccountId(db);

      await setBalance(db, posId, Decimal.fromInt(10000));
      await setBalance(db, bankId, Decimal.zero);

      final totalBefore =
          await balanceOf(db, posId) + await balanceOf(db, bankId);
      expect(
        totalBefore,
        Decimal.fromInt(10000),
        reason: 'system money before инкассация',
      );

      final controller = GetIt.I<CashInOutController>();
      final result = await controller.createInkassaciya(
        amount: Decimal.fromInt(4000),
        fromAccountId: posId,
        note: 'Инкассация в банк',
      );
      expect(
        result.success,
        isTrue,
        reason: 'инкассация must succeed: ${result.refusal?.name ?? result.errorDetail}',
      );

      expect(
        await balanceOf(db, posId),
        Decimal.fromInt(6000),
        reason: 'POS debited by exactly 4000',
      );
      expect(
        await balanceOf(db, bankId),
        Decimal.fromInt(4000),
        reason: 'bank CREDITED by exactly 4000 (this is the bug fix)',
      );

      expect(
        await balanceOf(db, posId) + await balanceOf(db, bankId),
        totalBefore,
        reason: 'total money conserved (no silent drain)',
      );

      final rows = await db
          .customSelect(
            'SELECT type, amount, account_id, note FROM cash_operations ORDER BY id DESC',
            readsFrom: {db.cashOperations},
          )
          .get();
      expect(rows.length, 1, reason: 'one инкассация operation persisted');
      expect(
        rows.first.read<int>('type'),
        CashInOutType.expense.index,
        reason: 'recorded as expense type (collection)',
      );
      expect(
        Decimal.parse(rows.first.read<double>('amount').toStringAsFixed(3)),
        Decimal.parse('4000.000'),
        reason: 'exact Decimal amount, no drift',
      );
      expect(
        rows.first.read<int>('account_id'),
        posId,
        reason: 'operation booked against the POS source account',
      );
      expect(
        rows.first.read<String?>('note'),
        contains('Инкассация'),
        reason: 'note marks this as инкассация',
      );

      final failed = await controller.createInkassaciya(
        amount: Decimal.fromInt(999999),
        fromAccountId: posId,
      );
      expect(failed.success, isFalse, reason: 'over-collection rejected');
      expect(
        await balanceOf(db, posId),
        Decimal.fromInt(6000),
        reason: 'POS unchanged after rejected инкассация',
      );
      expect(
        await balanceOf(db, bankId),
        Decimal.fromInt(4000),
        reason: 'bank unchanged after rejected инкассация (atomic)',
      );

      await setBalance(db, posId, Decimal.fromInt(10000));
      await setBalance(db, bankId, Decimal.zero);

      await h.pumpApp(tester);
      final loggedIn = await h.loginAsCashier(tester);
      expect(loggedIn, isTrue, reason: 'must reach a post-login surface');

      await goTo(tester, '/cash-operation');
      expect(
        find.text('Кассовая операция'),
        findsOneWidget,
        reason: 'cash operation screen opened',
      );

      final expenseCard = find.text('Расход');
      expect(expenseCard, findsWidgets, reason: 'Расход type card present');
      await tester.tap(expenseCard.first);
      await tester.pumpAndSettle();

      final collectionChip = find.text('Инкассация');
      expect(
        collectionChip,
        findsWidgets,
        reason: 'Инкассация expense type chip present',
      );
      await tester.tap(collectionChip.first);
      await tester.pumpAndSettle();

      await enterAmount(tester, '4000');
      expect(
        find.text('4000.00'),
        findsOneWidget,
        reason: 'amount display reflects 4000',
      );

      final done = find.widgetWithText(TextButton, 'Готово');
      expect(done, findsOneWidget, reason: 'Готово action present');
      await tester.tap(done);
      await tester.pumpAndSettle(const Duration(seconds: 2));

      expect(
        await balanceOf(db, posId),
        Decimal.fromInt(6000),
        reason: 'UI инкассация debited POS by 4000',
      );
      expect(
        await balanceOf(db, bankId),
        Decimal.fromInt(4000),
        reason: 'UI инкассация CREDITED bank by 4000 (bug fix wired to screen)',
      );
      expect(
        await balanceOf(db, posId) + await balanceOf(db, bankId),
        Decimal.fromInt(10000),
        reason: 'money conserved through the UI path',
      );
    },
  );
}

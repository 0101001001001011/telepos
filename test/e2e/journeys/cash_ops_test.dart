library;

import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart' show Value, Variable;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';

import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/database/daos/account_dao.dart';

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

  Future<List<({int type, Decimal amount, String? note})>> readOps(
    AppDatabase db,
  ) async {
    final rows = await db
        .customSelect(
          'SELECT type, amount, note FROM cash_operations ORDER BY id DESC',
          readsFrom: {db.cashOperations},
        )
        .get();
    return rows
        .map(
          (r) => (
            type: r.read<int>('type'),
            amount: Decimal.parse(r.read<double>('amount').toStringAsFixed(3)),
            note: r.read<String?>('note'),
          ),
        )
        .toList();
  }

  Future<Decimal> posBalance(AppDatabase db) async {
    final pos = await db.thisPosDao.get();
    final accId =
        pos!.accountId ??
        (await db.accountDao.findByType(AccountType.pos)).first.id;
    final acc = await db.accountDao.findById(accId);
    return acc?.value ?? Decimal.zero;
  }

  testWidgets(
    'cash-in (Внесение) and cash-out (Расход) persist and refresh the Shift screen',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1400, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final db = h.db;
      GetIt.I.registerSingleton<AppDatabase>(db);

      await openShiftInDb(db);
      final openingBalance = await posBalance(db);

      await h.pumpApp(tester);
      final loggedIn = await h.loginAsCashier(tester);
      expect(loggedIn, isTrue, reason: 'must reach a post-login surface');

      await goTo(tester, '/shift');
      expect(find.byType(Scaffold), findsWidgets);

      final opsTab = find.text('Операции');
      expect(
        opsTab,
        findsWidgets,
        reason: 'Shift screen must expose Операции tab',
      );
      await tester.tap(opsTab.first);
      await tester.pumpAndSettle();
      expect(
        find.text('Нет кассовых операций'),
        findsOneWidget,
        reason: 'empty-state before any cash operation',
      );

      await goTo(tester, '/cash-operation');
      expect(
        find.text('Кассовая операция'),
        findsOneWidget,
        reason: 'cash operation screen opened',
      );

      final investCard = find.text('Внесение');
      expect(investCard, findsWidgets, reason: 'Внесение type card present');
      await tester.tap(investCard.first);
      await tester.pumpAndSettle();

      final fiveK = find.text('5K');
      expect(fiveK, findsOneWidget, reason: 'quick amount 5000 (5K) present');
      await tester.tap(fiveK);
      await tester.pumpAndSettle();
      expect(
        find.text('5000.00'),
        findsOneWidget,
        reason: 'amount display reflects 5000',
      );

      final done1 = find.widgetWithText(TextButton, 'Готово');
      expect(done1, findsOneWidget, reason: 'Готово action present');
      await tester.tap(done1);
      await tester.pumpAndSettle(const Duration(seconds: 2));

      var ops = await readOps(db);
      expect(ops.length, 1, reason: 'one cash operation persisted');
      expect(ops.first.type, 0, reason: 'type 0 == investment');
      expect(
        ops.first.amount,
        Decimal.parse('5000.000'),
        reason: 'exact Decimal amount, no drift',
      );

      expect(
        await posBalance(db),
        openingBalance + Decimal.parse('5000'),
        reason: 'investment increases POS balance',
      );

      await goTo(tester, '/shift');
      await tester.tap(find.text('Операции').first);
      await tester.pumpAndSettle();

      expect(
        find.text('Нет кассовых операций'),
        findsNothing,
        reason: 'empty-state gone after create',
      );
      expect(
        find.text('5000.00'),
        findsWidgets,
        reason: 'investment summary total refreshed to 5000.00',
      );
      expect(
        find.text('Внесение'),
        findsWidgets,
        reason: 'investment operation row visible in list',
      );

      await goTo(tester, '/cash-operation');
      expect(find.text('Кассовая операция'), findsOneWidget);

      final expenseCard = find.text('Расход');
      expect(expenseCard, findsWidgets, reason: 'Расход type card present');
      await tester.tap(expenseCard.first);
      await tester.pumpAndSettle();

      final noteField = find.byType(TextField);
      expect(noteField, findsWidgets, reason: 'comment field present');
      await tester.enterText(noteField.first, 'Закуп воды');
      await tester.pumpAndSettle();

      await enterAmount(tester, '1200');
      expect(
        find.text('1200.00'),
        findsOneWidget,
        reason: 'amount display reflects 1200',
      );

      final done2 = find.widgetWithText(TextButton, 'Готово');
      expect(done2, findsOneWidget);
      await tester.tap(done2);
      await tester.pumpAndSettle(const Duration(seconds: 2));

      ops = await readOps(db);
      expect(ops.length, 2, reason: 'second cash operation persisted');
      expect(ops.first.type, 1, reason: 'type 1 == expense');
      expect(
        ops.first.amount,
        Decimal.parse('1200.000'),
        reason: 'exact Decimal expense amount',
      );
      expect(
        ops.first.note,
        contains('Закуп воды'),
        reason: 'expense note persisted (prefixed by expense type)',
      );

      expect(
        await posBalance(db),
        openingBalance + Decimal.parse('5000') - Decimal.parse('1200'),
        reason: 'expense decreases POS balance',
      );

      await goTo(tester, '/shift');
      await tester.tap(find.text('Операции').first);
      await tester.pumpAndSettle();

      expect(
        find.text('1200.00'),
        findsWidgets,
        reason: 'expense summary total refreshed to 1200.00',
      );
      expect(
        find.text('Внесение'),
        findsWidgets,
        reason: 'investment row still listed',
      );
      expect(
        find.text('Выплата'),
        findsWidgets,
        reason: 'expense row listed (shift label == Выплата)',
      );
    },
  );
}

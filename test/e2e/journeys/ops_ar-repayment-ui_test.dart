library;

import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart' show Value;
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

  Future<int> seedCustomerWithDebt(AppDatabase db, Decimal debt) async {
    final mainAccId = await db.accountDao.getNextId();
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    await db.accountDao.insertAccount(
      AccountsCompanion(
        id: Value(mainAccId),
        type: const Value(AccountType.agentMain),
        name: const Value('Счёт клиента'),
        value: Value(-debt),
        visibleToPos: const Value(false),
        updateTime: Value(now),
      ),
    );

    final agentId = await db
        .into(db.agents)
        .insert(
          AgentsCompanion.insert(
            name: const Value('Должник Бекжан'),
            phone: const Value(77011234567),
            type: const Value(1),
            isDeleted: const Value(false),
            state: const Value(0),
            mainAccountId: Value(mainAccId),
            editTime: Value(now),
          ),
        );
    return agentId;
  }

  Future<Decimal> accountBalance(AppDatabase db, int accId) async {
    final acc = await db.accountDao.findById(accId);
    return acc?.value ?? Decimal.zero;
  }

  Future<Decimal> posBalance(AppDatabase db) async {
    final pos = await db.thisPosDao.get();
    final accId =
        pos!.accountId ??
        (await db.accountDao.findByType(AccountType.pos)).first.id;
    return accountBalance(db, accId);
  }

  Future<int> agentMainAccountId(AppDatabase db, int agentId) async {
    final agent = await db.agentDao.findByLocalId(agentId);
    return agent!.mainAccountId!;
  }

  testWidgets(
    'recording a customer payment reduces debt 3000→2000 and credits cash +1000',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1400, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final db = h.db;
      GetIt.I.registerSingleton<AppDatabase>(db);

      final agentId = await seedCustomerWithDebt(db, Decimal.parse('3000'));
      final mainAccId = await agentMainAccountId(db, agentId);
      final openingPos = await posBalance(db);

      expect(
        await accountBalance(db, mainAccId),
        Decimal.parse('-3000'),
        reason: 'precondition: customer owes 3000 (balance -3000)',
      );

      await h.pumpApp(tester);
      final loggedIn = await h.loginAsCashier(tester);
      expect(loggedIn, isTrue, reason: 'must reach a post-login surface');

      await goTo(tester, '/agent');
      expect(find.byType(Scaffold), findsWidgets);

      final searchField = find.byType(TextField);
      expect(searchField, findsWidgets, reason: 'agent search field present');
      await tester.enterText(searchField.first, 'Должник');
      await tester.pumpAndSettle(const Duration(seconds: 1));

      final customerRow = find.text('Должник Бекжан');
      expect(customerRow, findsWidgets, reason: 'seeded customer is listed');

      await tester.tap(customerRow.first);
      await tester.pumpAndSettle();

      final payAction = find.text('Принять оплату / погасить долг');
      expect(
        payAction,
        findsOneWidget,
        reason: 'record-payment action wired into agent details dialog',
      );
      await tester.tap(payAction);
      await tester.pumpAndSettle();

      final amountField =
          find.widgetWithText(TextField, 'Сумма оплаты').evaluate().isNotEmpty
          ? find.widgetWithText(TextField, 'Сумма оплаты')
          : find.byType(TextField);
      expect(
        amountField,
        findsWidgets,
        reason: 'amount field present in dialog',
      );
      await tester.enterText(amountField.first, '1000');
      await tester.pumpAndSettle();

      final submit = find.widgetWithText(ElevatedButton, 'Принять оплату');
      expect(submit, findsOneWidget, reason: 'submit button present');
      await tester.tap(submit);
      await tester.pumpAndSettle(const Duration(seconds: 2));

      expect(
        await accountBalance(db, mainAccId),
        Decimal.parse('-2000'),
        reason: 'debt reduced by exactly 1000 (Decimal-exact)',
      );

      expect(
        await posBalance(db),
        openingPos + Decimal.parse('1000'),
        reason: 'cash/POS account increased by exactly 1000',
      );

      final opRows = await db
          .customSelect(
            'SELECT amount FROM cash_operations ORDER BY id DESC',
            readsFrom: {db.cashOperations},
          )
          .get();
      expect(
        opRows,
        isNotEmpty,
        reason: 'customer payment persisted a cash_operations row',
      );
    },
  );
}

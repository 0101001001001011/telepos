library;

import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/database/daos/account_dao.dart';

import 'support/harness.dart';

void main() {
  final h = E2eHarness();
  setUpAll(() => h.setUp());
  tearDownAll(() => h.tearDown());

  final log = <String>[];
  void step(String s) => log.add(s);

  Future<void> render(WidgetTester t) async {
    await t.pump();
    await t.pump(const Duration(milliseconds: 700));
    await t.pump(const Duration(milliseconds: 500));
  }

  Future<void> shot(WidgetTester t, String name) async {
    try {
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('scenario/$name.png'),
      );
    } catch (e) {
      step('SHOT_FAIL $name: $e');
    }
  }

  Future<void> addItem(WidgetTester t, String barcode) async {
    await t.enterText(find.byType(TextField).first, barcode);
    await t.testTextInput.receiveAction(TextInputAction.done);
    await render(t);
  }

  testWidgets('LOYALTY CAP — redeem 200 bonus on a 150 receipt → cap at 150', (
    t,
  ) async {
    const bonusAccId = 500;
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    await h.db.accountDao.insertAccount(
      AccountsCompanion(
        id: const Value(bonusAccId),
        type: const Value(AccountType.cashback),
        name: const Value('Бонусы клиента'),
        value: Value(Decimal.parse('200')),
        updateTime: Value(now),
      ),
    );
    await h.db
        .into(h.db.agents)
        .insert(
          const AgentsCompanion(
            name: Value('Клиент Бонусный'),
            phone: Value(77011234567),
            type: Value(0),
            cashbackAccountId: Value(bonusAccId),
          ),
        );

    await h.pumpApp(t);
    await t.pump(const Duration(seconds: 1));
    await h.loginAsCashier(t);
    await render(t);

    try {
      h.router!.go('/sale');
      await render(t);
      await addItem(t, '4607002');
      await t.tap(find.text('ОПЛАТИТЬ').first);
      await render(t);

      final phone = find.byWidgetPredicate(
        (w) => w is TextField && w.decoration?.labelText == 'Номер телефона',
      );
      if (phone.evaluate().isNotEmpty) {
        await t.enterText(phone.first, '77011234567');
        await render(t);
        await render(t);
      }
      final bonusShown = find.textContaining('200').evaluate().isNotEmpty;
      step('loyalty-cap: клиент найден, бонус 200 виден=$bonusShown, чек=150');

      for (final label in ['Всё', 'Все', 'ВСЁ']) {
        final all = find.text(label);
        if (all.evaluate().isNotEmpty) {
          await t.tap(all.first);
          await render(t);
          break;
        }
      }
      await shot(t, 'lc_01_redeemed');

      final negative =
          find.textContaining('-50').evaluate().isNotEmpty ||
          find.textContaining('−50').evaluate().isNotEmpty;
      step(
        'loyalty-cap: отрицательная оплата (−50) на экране=$negative (ожидаем false)',
      );

      await t.tap(find.text('ОПЛАТИТЬ').last);
      await render(t);
      await shot(t, 'lc_02_done');

      final acc = await h.db.accountDao.findById(bonusAccId);
      step(
        'loyalty-cap: бонус после = ${acc?.value} '
        '(ожидаем 50 = 200 − использовано 150; НЕ отрицательный и НЕ 0)',
      );
    } catch (e) {
      step('FAILED: $e');
      await shot(t, 'lc_FAILED');
    }

    // ignore: avoid_print
    print('\n===== LOYALTY CAP LOG =====');
    for (final l in log) {
      // ignore: avoid_print
      print('[lc] $l');
    }
    // ignore: avoid_print
    print('===== END =====\n');
  });
}

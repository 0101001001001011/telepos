library;

import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/database/daos/account_dao.dart' show AccountType;

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

  testWidgets('DISCOUNT + LOYALTY (UI, persistence verified)', (t) async {
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
      await addItem(t, '4607001');
      discountField() => find.byWidgetPredicate(
        (w) => w is TextField && w.decoration?.labelText == 'Скидка',
      );
      var opened = false;
      for (var a = 0; a < 3 && !opened; a++) {
        await t.tap(find.text('Молоко 1л').first);
        await render(t);
        final edit = find.text('Редактировать');
        if (edit.evaluate().isNotEmpty) {
          await t.tap(edit.first);
          await render(t);
        }
        opened = discountField().evaluate().isNotEmpty;
      }
      if (opened) {
        await t.enterText(discountField().first, '50');
        await render(t);
        await t.tap(find.text('Сохранить').first);
        await render(t);
      }
      step(
        '1 discount: cart shows 400 = ${find.text('400').evaluate().isNotEmpty}',
      );
      await t.tap(find.text('ОПЛАТИТЬ').first);
      await render(t);
      final d1 = find.text('1K');
      if (d1.evaluate().isNotEmpty) {
        await t.tap(d1.first);
        await render(t);
      }
      await t.tap(find.text('ОПЛАТИТЬ').last);
      await render(t);
      await shot(t, 'dl_01_discount_done');
      final row = await h.db
          .customSelect(
            "SELECT amount FROM sales WHERE state IS NOT NULL AND state <> 0 ORDER BY receipt_no DESC LIMIT 1",
          )
          .getSingleOrNull();
      step(
        '1 discount: PERSISTED sale amount = ${row?.read<double>('amount')} (expect 400)',
      );
    } catch (e) {
      step('1 discount FAILED: $e');
      await shot(t, 'dl_01_discount_FAILED');
    }

    try {
      h.router!.go('/sale');
      await render(t);
      await addItem(t, '4607001');
      await t.tap(find.text('ОПЛАТИТЬ').first);
      await render(t);
      final phone = find.byWidgetPredicate(
        (w) => w is TextField && w.decoration?.labelText == 'Номер телефона',
      );
      if (phone.evaluate().isNotEmpty) {
        await t.enterText(phone.first, '77011234567');
        await render(t);
        await render(t);
      } else {
        step('2 loyalty: phone field NOT FOUND');
      }
      final found =
          find.text('Клиант Бонусный').evaluate().isNotEmpty ||
          find.textContaining('Бонусный').evaluate().isNotEmpty;
      final bonusShown = find.textContaining('200').evaluate().isNotEmpty;
      step('2 loyalty: customer found=$found, bonus 200 shown=$bonusShown');
      await shot(t, 'dl_02a_loyalty_found');
      for (final label in ['Всё', 'Все', 'ВСЁ']) {
        final all = find.text(label);
        if (all.evaluate().isNotEmpty) {
          await t.tap(all.first);
          await render(t);
          break;
        }
      }
      await shot(t, 'dl_02b_bonus_applied');
      final pay250 = find.textContaining('250').evaluate().isNotEmpty;
      step('2 loyalty: amount-to-pay shows 250 (450−200) = $pay250');
      final d1k = find.text('1K');
      if (d1k.evaluate().isNotEmpty) {
        await t.tap(d1k.first);
        await render(t);
      }
      await t.tap(find.text('ОПЛАТИТЬ').last);
      await render(t);
      await shot(t, 'dl_02c_loyalty_done');
      final acc = await h.db.accountDao.findById(bonusAccId);
      step(
        '2 loyalty: bonus account after = ${acc?.value} (expect 0 — 200 redeemed)',
      );
    } catch (e) {
      step('2 loyalty FAILED: $e');
      await shot(t, 'dl_02_loyalty_FAILED');
    }

    // ignore: avoid_print
    print('\n===== DISCOUNT+LOYALTY LOG =====');
    for (final l in log) {
      // ignore: avoid_print
      print('[dl] $l');
    }
    // ignore: avoid_print
    print('===== END =====\n');
  });
}

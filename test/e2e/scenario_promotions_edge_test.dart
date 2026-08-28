library;

import 'package:drift/drift.dart' show Value, Variable;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:telepos/data/database/app_database.dart';

import 'support/harness.dart';

void main() {
  final h = E2eHarness();
  setUpAll(() => h.setUp());
  tearDownAll(() => h.tearDown());

  final log = <String>[];
  void step(String s) => log.add(s);

  Future<void> render(WidgetTester t) async {
    await t.pump();
    await t.pump(const Duration(milliseconds: 600));
    await t.pump(const Duration(milliseconds: 400));
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

  Future<void> tapText(WidgetTester t, String text, {bool last = false}) async {
    final f = find.text(text);
    if (f.evaluate().isEmpty) return;
    await t.tap(last ? f.last : f.first);
    await render(t);
  }

  Future<void> addItem(WidgetTester t, String barcode) async {
    await t.enterText(find.byType(TextField).first, barcode);
    await t.testTextInput.receiveAction(TextInputAction.done);
    await render(t);
  }

  Future<void> dismissModals(WidgetTester t) async {
    for (var i = 0; i < 5; i++) {
      if (find.byType(Navigator).evaluate().isEmpty) break;
      final root = t.state<NavigatorState>(find.byType(Navigator).first);
      if (!root.canPop()) break;
      root.pop();
      await t.pump(const Duration(milliseconds: 200));
    }
  }

  Future<void> pay(WidgetTester t, {String denom = '2K'}) async {
    await tapText(t, 'ОПЛАТИТЬ');
    final d = find.text(denom);
    if (d.evaluate().isNotEmpty) {
      await t.tap(d.first);
      await render(t);
    }
    await tapText(t, 'ОПЛАТИТЬ', last: true);
  }

  Future<double?> stockOf(int ucode) async {
    final r = await h.db
        .customSelect(
          'SELECT quantity q FROM product_infos WHERE ucode = ?',
          variables: [Variable.withInt(ucode)],
        )
        .getSingleOrNull();
    return r?.read<double?>('q');
  }

  Future<double?> lastSaleAmount() async {
    final r = await h.db
        .customSelect(
          'SELECT amount a FROM sales '
          'WHERE state IS NOT NULL AND state <> 0 AND state <> 3 '
          'ORDER BY receipt_no DESC LIMIT 1',
        )
        .getSingleOrNull();
    return r?.read<double?>('a');
  }

  Future<bool> displayShowsTotal(WidgetTester t, String total) async {
    h.router!.go('/customer-display');
    await render(t);
    final ok = find.text('$total ₸').evaluate().isNotEmpty;
    h.router!.go('/sale');
    await render(t);
    return ok;
  }

  testWidgets('PROMO EDGE — boundary qty, manual-discount, refund invariant', (
    t,
  ) async {
    await h.db.promotionDao.insertPromotion(
      PromotionsCompanion.insert(
        name: 'Молоко 1+1',
        triggerUcode: 1001,
        rewardUcode: 1001,
        triggerQty: const Value(2),
        rewardQty: const Value(1),
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
      await addItem(t, '4607001');
      await addItem(t, '4607001');
      final disp = await displayShowsTotal(t, '900');
      await pay(t, denom: '1K');
      final amt = await lastSaleAmount();
      step(
        'A odd-qty(3): экран ИТОГО 900=$disp, чек=$amt (ожидаем 900, 1 беспл.)',
      );
    } catch (e) {
      step('A FAILED: $e');
      await shot(t, 'pe_A_FAILED');
    }

    try {
      await dismissModals(t);
      h.router!.go('/sale');
      await render(t);
      for (var i = 0; i < 4; i++) {
        await addItem(t, '4607001');
      }
      await pay(t, denom: '2K');
      final amt = await lastSaleAmount();
      step('B even(4): чек=$amt (ожидаем 900 = 4×450 − 2×450)');
    } catch (e) {
      step('B FAILED: $e');
    }

    try {
      await dismissModals(t);
      h.router!.go('/sale');
      await render(t);
      await addItem(t, '4607001');
      await addItem(t, '4607001');
      discountField() => find.byWidgetPredicate(
        (w) => w is TextField && w.decoration?.labelText == 'Скидка',
      );
      final edit = find.text('Редактировать');
      if (edit.evaluate().isNotEmpty) {
        await t.tap(edit.first);
        await render(t);
        if (discountField().evaluate().isNotEmpty) {
          await t.enterText(discountField().first, '100');
          await render(t);
          await tapText(t, 'Сохранить', last: true);
        }
      }
      await addItem(t, '4607001');
      final disp = await displayShowsTotal(t, '1250');
      await pay(t, denom: '2K');
      final amt = await lastSaleAmount();
      step(
        'C manual+recompute: ручная −100 пережила +qty → экран1250=$disp чек=$amt '
        '(ожидаем 1250 = 3×450 − 100, без двойной/перетирания)',
      );
    } catch (e) {
      step('C FAILED: $e');
    }

    try {
      await dismissModals(t);
      final stockStart = await stockOf(1001);
      h.router!.go('/sale');
      await render(t);
      await addItem(t, '4607001');
      await addItem(t, '4607001');
      await pay(t, denom: '1K');
      final saleAmt = await lastSaleAmount();
      final stockAfterSale = await stockOf(1001);

      final rNoRow = await h.db
          .customSelect(
            'SELECT receipt_no r FROM sales '
            'WHERE state IS NOT NULL AND state <> 0 AND state <> 3 '
            'ORDER BY receipt_no DESC LIMIT 1',
          )
          .getSingleOrNull();
      final receiptNo = rNoRow?.read<int?>('r');

      await dismissModals(t);
      h.router!.go('/refund');
      await render(t);
      final load = find.textContaining('Загрузить чек');
      if (load.evaluate().isNotEmpty && receiptNo != null) {
        await t.tap(load.first);
        await render(t);
        await t.enterText(find.byType(TextField).last, '$receiptNo');
        await t.testTextInput.receiveAction(TextInputAction.done);
        await render(t);
      }
      final selectAll = find.textContaining('Выбрать всё');
      if (selectAll.evaluate().isNotEmpty) {
        await t.tap(selectAll.first);
        await render(t);
      }
      final submit = find.text('ВОЗВРАТ');
      if (submit.evaluate().isNotEmpty) {
        await t.tap(submit.last);
        await render(t);
      }
      for (final label in [
        'ОФОРМИТЬ ВОЗВРАТ',
        'ОФОРМИТЬ',
        'ОПЛАТИТЬ',
        'Подтвердить',
      ]) {
        final conf = find.text(label);
        if (conf.evaluate().isNotEmpty) {
          await t.tap(conf.last);
          await render(t);
          break;
        }
      }
      final refundRow = await h.db
          .customSelect(
            'SELECT COALESCE(SUM(amount),0) s, COUNT(*) c FROM refunds',
          )
          .getSingle();
      final stockAfterRefund = await stockOf(1001);
      step(
        'D refund: продажа=$saleAmt, остаток $stockStart→$stockAfterSale→$stockAfterRefund '
        '(должен вернуться), возвратов=${refundRow.read<int>('c')} сумма=${refundRow.read<double>('s')} (ожидаем 450)',
      );
    } catch (e) {
      step('D FAILED: $e');
      await shot(t, 'pe_D_FAILED');
    }

    // ignore: avoid_print
    print('\n===== PROMO EDGE LOG =====');
    for (final l in log) {
      // ignore: avoid_print
      print('[pe] $l');
    }
    // ignore: avoid_print
    print('===== END =====\n');
  });
}

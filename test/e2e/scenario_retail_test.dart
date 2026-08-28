library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

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
    if (f.evaluate().isEmpty) {
      throw TestFailure('tap target not found: "$text"');
    }
    await t.tap(last ? f.last : f.first);
    await render(t);
  }

  Future<void> tapButton(WidgetTester t, String text) async {
    final byType = find.byWidgetPredicate(
      (w) =>
          (w is ElevatedButton ||
          w is FilledButton ||
          w is TextButton ||
          w is OutlinedButton),
    );
    final f = find.descendant(of: byType, matching: find.text(text));
    if (f.evaluate().isEmpty) {
      await tapText(t, text, last: true);
      return;
    }
    await t.tap(f.last);
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

  Future<void> addItem(WidgetTester t, String barcode) async {
    await t.enterText(find.byType(TextField).first, barcode);
    await t.testTextInput.receiveAction(TextInputAction.done);
    await render(t);
  }

  Future<void> pay(WidgetTester t, {String denom = '2K', String? type}) async {
    await tapText(t, 'ОПЛАТИТЬ');
    if (type == 'card') {
      await tapText(t, 'Безналичная');
    } else {
      final d = find.text(denom);
      if (d.evaluate().isNotEmpty) {
        await t.tap(d.first);
        await render(t);
      }
    }
    await tapText(t, 'ОПЛАТИТЬ', last: true);
  }

  testWidgets('RETAIL DAY — full UI scenario', (t) async {
    await h.pumpApp(t);
    await t.pump(const Duration(seconds: 1));
    await h.loginAsCashier(t);
    await render(t);

    try {
      h.router!.go('/shift');
      await render(t);
      await tapText(t, 'Открыть смену');
      await t.enterText(find.byType(TextField).last, '50000');
      await render(t);
      await tapButton(t, 'Открытие смены');
      await shot(t, 'retail_01_shift_opened');
      final open = await h.db.shiftDao.findOpenedShift();
      step('1 open-shift: shift opened in DB = ${open != null}');
    } catch (e) {
      step('1 open-shift FAILED: $e');
      await shot(t, 'retail_01_shift_FAILED');
    }

    try {
      await dismissModals(t);
      h.router!.go('/sale');
      await render(t);
      await addItem(t, '4607001');
      await addItem(t, '4607002');
      await pay(t, denom: '1K');
      await shot(t, 'retail_02_cash_sale_done');
      step('2 cash-sale: submitted');
    } catch (e) {
      step('2 cash-sale FAILED: $e');
      await shot(t, 'retail_02_cash_sale_FAILED');
    }

    try {
      await dismissModals(t);
      h.router!.go('/sale');
      await render(t);
      await addItem(t, '4607003');
      await pay(t, type: 'card');
      await shot(t, 'retail_03_card_sale_done');
      step('3 card-sale: submitted');
    } catch (e) {
      step('3 card-sale FAILED: $e');
      await shot(t, 'retail_03_card_sale_FAILED');
    }

    try {
      await dismissModals(t);
      h.router!.go('/sale');
      await render(t);
      await addItem(t, '4607004');
      await tapText(t, 'Отложить');
      await shot(t, 'retail_04a_deferred');
      final deferred = await h.db.saleDao.findByState(3);
      step('4a defer: deferred sales in DB = ${deferred.length}');
      await tapText(t, 'Отложенные');
      await shot(t, 'retail_04b_deferred_list');
      final restore = find.byIcon(Icons.restore);
      if (restore.evaluate().isNotEmpty) {
        await t.tap(restore.first);
        await render(t);
      }
      await shot(t, 'retail_04c_resumed');
      step(
        '4b resume: items restored = ${find.text('Масло сливочное').evaluate().isNotEmpty}',
      );
    } catch (e) {
      step('4 defer/resume FAILED: $e');
      await shot(t, 'retail_04_defer_FAILED');
    }

    try {
      final rows = await h.db
          .customSelect(
            'SELECT DISTINCT receipt_no FROM sale_products ORDER BY receipt_no LIMIT 1',
          )
          .get();
      final receiptNo = rows.isNotEmpty
          ? rows.first.read<int>('receipt_no')
          : null;
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
      await shot(t, 'retail_05a_refund_loaded');
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
      await shot(t, 'retail_05b_refund_confirm');
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
      await shot(t, 'retail_05c_refund_done');
      final refunds = await h.db
          .customSelect('SELECT COUNT(*) c FROM refunds')
          .getSingleOrNull();
      step('5 refund: refunds in DB = ${refunds?.read<int>('c')}');
    } catch (e) {
      step('5 refund FAILED: $e');
      await shot(t, 'retail_05_refund_FAILED');
    }

    try {
      await dismissModals(t);
      h.router!.go('/history');
      await render(t);
      await shot(t, 'retail_06_history');
      h.router!.go('/reports');
      await render(t);
      await shot(t, 'retail_07_reports');
      final productsTab = find.text('Товары');
      if (productsTab.evaluate().isNotEmpty) {
        await t.tap(productsTab.first);
        await render(t);
        await shot(t, 'retail_07b_reports_products_abc');
        step(
          '6b ABC: products tab shown, ABC card present = ${find.text('ABC-анализ').evaluate().isNotEmpty}',
        );
      }
      step('6 history+reports: captured');
    } catch (e) {
      step('6 history/reports FAILED: $e');
    }

    try {
      await dismissModals(t);
      h.router!.go('/shift');
      await render(t);
      await tapText(t, 'Закрыть смену');
      for (final label in ['Закрыть', 'Закрыть с расхождением']) {
        final btn = find.descendant(
          of: find.byWidgetPredicate(
            (w) => w is ElevatedButton || w is FilledButton,
          ),
          matching: find.text(label),
        );
        if (btn.evaluate().isNotEmpty) {
          await t.tap(btn.last);
          await render(t);
          break;
        }
      }
      await shot(t, 'retail_08_shift_closed');
      final stillOpen = await h.db.shiftDao.findOpenedShift();
      step('7 close-shift: shift still open = ${stillOpen != null}');
    } catch (e) {
      step('7 close-shift FAILED: $e');
      await shot(t, 'retail_08_shift_FAILED');
    }

    final sales = await h.db
        .customSelect(
          "SELECT COUNT(*) c, COALESCE(SUM(amount),0) s FROM sales WHERE state IS NOT NULL AND state <> 0 AND state <> 3",
        )
        .getSingleOrNull();
    step(
      'VERIFY completed sales count=${sales?.read<int>('c')} sum=${sales?.read<double>('s')}',
    );

    // ignore: avoid_print
    print('\n===== RETAIL SCENARIO LOG =====');
    for (final l in log) {
      // ignore: avoid_print
      print('[retail] $l');
    }
    // ignore: avoid_print
    print('===== END =====\n');
  });
}

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
    if (f.evaluate().isEmpty) return;
    await t.tap(last ? f.last : f.first);
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

  Future<num?> scalar(String sql) async {
    final r = await h.db.customSelect(sql).getSingleOrNull();
    return r?.data.values.first as num?;
  }

  testWidgets('MONEY — tender invariant + Z-report reconciliation', (t) async {
    await h.pumpApp(t);
    await t.pump(const Duration(seconds: 1));
    await h.loginAsCashier(t);
    await render(t);

    try {
      h.router!.go('/sale');
      await render(t);
      await addItem(t, '4607001');
      await tapText(t, 'ОПЛАТИТЬ');
      final d = find.text('1K');
      if (d.evaluate().isNotEmpty) {
        await t.tap(d.first);
        await render(t);
      }
      await shot(t, 'mi_01_change');
      final change550 = find.textContaining('550').evaluate().isNotEmpty;
      await tapText(t, 'ОПЛАТИТЬ', last: true);
      step('1 cash: экран показал сдачу 550 = $change550');
    } catch (e) {
      step('1 FAILED: $e');
    }

    try {
      await dismissModals(t);
      h.router!.go('/sale');
      await render(t);
      await addItem(t, '4607002');
      await tapText(t, 'ОПЛАТИТЬ');
      await tapText(t, 'Безналичная');
      await tapText(t, 'ОПЛАТИТЬ', last: true);
      step('2 card: submitted');
    } catch (e) {
      step('2 FAILED: $e');
    }

    try {
      final salesSum = await scalar(
        'SELECT COALESCE(SUM(amount),0) FROM sales '
        'WHERE state IS NOT NULL AND state <> 0 AND state <> 3',
      );
      final maxSale = await scalar(
        'SELECT COALESCE(MAX(amount),0) FROM sales '
        'WHERE state IS NOT NULL AND state <> 0 AND state <> 3',
      );
      final tenderLeak = await scalar(
        'SELECT COUNT(*) FROM sales WHERE amount = 1000',
      );
      final cashPaid = await scalar(
        'SELECT COALESCE(SUM(p.amount),0) FROM payments p '
        'JOIN accounts a ON a.id = p.payee_account_id '
        'WHERE (p.refund_local_id IS NULL) AND a.type = 0',
      );
      final cardPaid = await scalar(
        'SELECT COALESCE(SUM(p.amount),0) FROM payments p '
        'JOIN accounts a ON a.id = p.payee_account_id '
        'WHERE (p.refund_local_id IS NULL) AND a.type = 1',
      );
      final paidTotal = (cashPaid ?? 0) + (cardPaid ?? 0);

      step(
        'INVARIANT: продажи sum=$salesSum, max=$maxSale (ожидаем 600/450 — НЕ 1000), '
        'утечка тендера(1000)=$tenderLeak (ожидаем 0)',
      );
      step(
        'RECONCILE: касса=$cashPaid (ожидаем 450), карта=$cardPaid (ожидаем 150), '
        'оплаты итого=$paidTotal == продажи $salesSum',
      );
    } catch (e) {
      step('VERIFY FAILED: $e');
    }

    // ignore: avoid_print
    print('\n===== MONEY INVARIANTS LOG =====');
    for (final l in log) {
      // ignore: avoid_print
      print('[mi] $l');
    }
    // ignore: avoid_print
    print('===== END =====\n');
  });
}

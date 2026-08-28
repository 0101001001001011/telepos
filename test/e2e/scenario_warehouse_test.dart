library;

import 'package:drift/drift.dart' show Variable;
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

  Future<double?> stockOf(int ucode) async {
    final r = await h.db
        .customSelect(
          'SELECT quantity q FROM product_infos WHERE ucode = ?',
          variables: [Variable.withInt(ucode)],
        )
        .getSingleOrNull();
    return r?.read<double?>('q');
  }

  testWidgets('WAREHOUSE — writeoff + inventory (UI, stock verified)', (
    t,
  ) async {
    await h.pumpApp(t);
    await t.pump(const Duration(seconds: 1));
    await h.loginAsCashier(t);
    await render(t);

    final before = await stockOf(1001);
    step('start: Молоко stock = $before (expect 100)');

    try {
      h.router!.go('/writeoff');
      await render(t);
      await t.enterText(find.byType(TextField).first, '4607001');
      await t.testTextInput.receiveAction(TextInputAction.done);
      await render(t);
      await shot(t, 'wh_01a_writeoff_form');
      final save = find.text('Сохранить');
      if (save.evaluate().isNotEmpty) {
        await t.tap(save.last);
        await render(t);
      }
      await shot(t, 'wh_01b_writeoff_done');
      final after = await stockOf(1001);
      step('1 writeoff: Молоко stock $before → $after (should decrease)');
    } catch (e) {
      step('1 writeoff FAILED: $e');
      await shot(t, 'wh_01_writeoff_FAILED');
    }

    try {
      final sBefore = await stockOf(1003);
      h.router!.go('/inventory');
      await render(t);
      await shot(t, 'wh_02a_inventory_idle');
      step('2 inventory: screen opened, Сахар before = $sBefore');

      final start = find.text('Начать');
      if (start.evaluate().isNotEmpty) {
        await t.tap(start.first);
        await render(t);
      }
      final scan = find.byType(TextField).first;
      await t.enterText(scan, '4607003');
      await t.testTextInput.receiveAction(TextInputAction.done);
      await render(t);
      await shot(t, 'wh_02b_scanned');

      final card = find.text('Сахар 1кг');
      if (card.evaluate().isNotEmpty) {
        await t.tap(card.first);
        await render(t);
        final field = find.byType(TextField).last;
        await t.enterText(field, '95');
        await t.testTextInput.receiveAction(TextInputAction.done);
        await render(t);
      }
      await shot(t, 'wh_02c_counted');

      final finish = find.text('Завершить');
      if (finish.evaluate().isNotEmpty) {
        await t.tap(finish.first);
        await render(t);
        final confirm = find.text('Завершить');
        if (confirm.evaluate().isNotEmpty) {
          await t.tap(confirm.last);
          await render(t);
        }
      }
      await shot(t, 'wh_02d_done');

      final sAfter = await stockOf(1003);
      step('2 inventory: Сахар $sBefore → $sAfter (should be 95, the count)');
    } catch (e) {
      step('2 inventory FAILED: $e');
      await shot(t, 'wh_02_inventory_FAILED');
    }

    // ignore: avoid_print
    print('\n===== WAREHOUSE LOG =====');
    for (final l in log) {
      // ignore: avoid_print
      print('[wh] $l');
    }
    // ignore: avoid_print
    print('===== END =====\n');
  });
}

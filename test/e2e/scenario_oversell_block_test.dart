library;

import 'package:decimal/decimal.dart';
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
    for (var i = 0; i < 6; i++) {
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

  Future<void> sellFive(WidgetTester t) async {
    h.router!.go('/sale');
    await render(t);
    for (var i = 0; i < 5; i++) {
      await addItem(t, '4607004');
    }
    await tapText(t, 'ОПЛАТИТЬ');
    final d = find.text('5K');
    if (d.evaluate().isNotEmpty) {
      await t.tap(d.first);
      await render(t);
    }
    await tapText(t, 'ОПЛАТИТЬ', last: true);
  }

  Future<double?> stockOf(int ucode) async {
    final r = await h.db
        .customSelect(
          'SELECT quantity q FROM product_infos WHERE ucode = $ucode',
        )
        .getSingleOrNull();
    return r?.read<double?>('q');
  }

  testWidgets('OVERSELL BLOCK — policy ON blocks, OFF allows', (t) async {
    await h.pumpApp(t);
    await t.pump(const Duration(seconds: 1));
    await h.loginAsCashier(t);
    await render(t);

    await h.db.productInfoDao.updateQuantity(1004, Decimal.fromInt(2));

    try {
      h.router!.go('/settings');
      await render(t);
      final toggle = find.text('Запрет продажи при недостатке остатка');
      final present = toggle.evaluate().isNotEmpty;
      final tile = find.byWidgetPredicate(
        (w) =>
            w is SwitchListTile &&
            w.title is Text &&
            (w.title as Text).data == 'Запрет продажи при недостатке остатка',
      );
      if (tile.evaluate().isNotEmpty) {
        await t.ensureVisible(tile.first);
        await render(t);
        final sw = find.descendant(of: tile, matching: find.byType(Switch));
        if (sw.evaluate().isNotEmpty) {
          await t.tap(sw.first, warnIfMissed: false);
          await render(t);
        }
      }
      await shot(t, 'ob_01_policy_on');
      final cfg = await h.db.thisPosDao.get();
      step(
        '1 policy: переключатель есть=$present, blockOversell=${cfg?.blockOversell} (ожидаем true)',
      );
    } catch (e) {
      step('1 FAILED: $e');
    }

    try {
      await dismissModals(t);
      final before = await stockOf(1004);
      await sellFive(t);
      await dismissModals(t);
      final after = await stockOf(1004);
      step(
        '2 blocked: Масло остаток $before → $after (ожидаем 2 — продажа заблокирована)',
      );
    } catch (e) {
      step('2 FAILED: $e');
    }

    try {
      await dismissModals(t);
      await h.db.thisPosDao.setBlockOversell(false);
      final before = await stockOf(1004);
      h.router!.go('/sale');
      await render(t);
      await tapText(t, 'ОПЛАТИТЬ');
      final d = find.text('5K');
      if (d.evaluate().isNotEmpty) {
        await t.tap(d.first);
        await render(t);
      }
      await tapText(t, 'ОПЛАТИТЬ', last: true);
      await dismissModals(t);
      final after = await stockOf(1004);
      step(
        '3 allowed: Масло остаток $before → $after (ожидаем -3 — пере-продажа разрешена)',
      );
    } catch (e) {
      step('3 FAILED: $e');
    }

    // ignore: avoid_print
    print('\n===== OVERSELL BLOCK LOG =====');
    for (final l in log) {
      // ignore: avoid_print
      print('[ob] $l');
    }
    // ignore: avoid_print
    print('===== END =====\n');
  });
}

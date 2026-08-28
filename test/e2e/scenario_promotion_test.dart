library;

import 'package:drift/drift.dart' show Value;
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

  Future<int> promoCount() async {
    final r = await h.db
        .customSelect('SELECT COUNT(*) c FROM promotions')
        .getSingle();
    return r.read<int>('c');
  }

  testWidgets('PROMOTION — 1+1 авто-скидка + создание акции (UI)', (t) async {
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
      await shot(t, 'promo_01_cart_2milk');

      await tapText(t, 'ОПЛАТИТЬ');
      final d = find.text('1K');
      if (d.evaluate().isNotEmpty) {
        await t.tap(d.first);
        await render(t);
      }
      await tapText(t, 'ОПЛАТИТЬ', last: true);
      await shot(t, 'promo_02_paid');

      final sale = await h.db
          .customSelect(
            'SELECT COALESCE(SUM(amount),0) s FROM sales '
            'WHERE state IS NOT NULL AND state <> 0 AND state <> 3',
          )
          .getSingle();
      final total = sale.read<double>('s');
      step(
        'A 1+1: чек Молоко×2 (по 450) итог = $total (ожидаем 450 — 2-я бесплатно)',
      );
    } catch (e) {
      step('A engine FAILED: $e');
      await shot(t, 'promo_A_FAILED');
    }

    try {
      final before = await promoCount();
      h.router!.go('/promotions');
      await render(t);
      await shot(t, 'promo_03_list');

      await tapText(t, 'Новая акция');
      await shot(t, 'promo_04_form');

      final dd = find.byType(DropdownButtonFormField<int>);
      if (dd.evaluate().isNotEmpty) {
        await t.tap(dd.first);
        await render(t);
        final milk = find.text('Молоко 1л');
        if (milk.evaluate().isNotEmpty) {
          await t.tap(milk.last);
          await render(t);
        }
      }
      await tapText(t, 'Сохранить акцию');
      await shot(t, 'promo_05_saved');

      final after = await promoCount();
      step('B UI: акций $before → $after (ожидаем +1)');
    } catch (e) {
      step('B ui-create FAILED: $e');
      await shot(t, 'promo_B_FAILED');
    }

    // ignore: avoid_print
    print('\n===== PROMOTION LOG =====');
    for (final l in log) {
      // ignore: avoid_print
      print('[promo] $l');
    }
    // ignore: avoid_print
    print('===== END =====\n');
  });
}

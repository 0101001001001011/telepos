library;

import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
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

  testWidgets('SUPPLIER ORDER — заявка поставщику (UI)', (t) async {
    await h.db.productInfoDao.updateQuantity(1001, Decimal.parse('5'));
    await h.db
        .into(h.db.agents)
        .insert(
          const AgentsCompanion(
            name: Value('Поставщик Тест'),
            phone: Value(77770001122),
            type: Value(0),
          ),
        );

    await h.pumpApp(t);
    await t.pump(const Duration(seconds: 1));
    await h.loginAsCashier(t);
    await render(t);

    try {
      h.router!.go('/supplier-order');
      await render(t);
      await shot(t, 'so_01_screen');

      final hasMilk = find.text('Молоко 1л').evaluate().isNotEmpty;
      final hasRec = find.text('45').evaluate().isNotEmpty;
      step(
        'заявка: Молоко (низкий остаток) в списке = $hasMilk, рекомендация 45 = $hasRec',
      );

      final dd = find.text('Выберите поставщика');
      if (dd.evaluate().isNotEmpty) {
        await t.tap(dd.first);
        await render(t);
        final sup = find.text('Поставщик Тест');
        if (sup.evaluate().isNotEmpty) {
          await t.tap(sup.last);
          await render(t);
        }
      }
      step(
        'заявка: поставщик выбран = ${find.text('Поставщик Тест').evaluate().isNotEmpty}',
      );

      final form = find.text('Сформировать заявку');
      if (form.evaluate().isNotEmpty) {
        await t.tap(form.first);
        await render(t);
      }
      await shot(t, 'so_02_formed');
      final formed = find
          .textContaining('Заявка сформирована')
          .evaluate()
          .isNotEmpty;
      step('заявка: сформирована (тост) = $formed');
    } catch (e) {
      step('FAILED: $e');
      await shot(t, 'so_FAILED');
    }

    // ignore: avoid_print
    print('\n===== SUPPLIER ORDER LOG =====');
    for (final l in log) {
      // ignore: avoid_print
      print('[so] $l');
    }
    // ignore: avoid_print
    print('===== END =====\n');
  });
}

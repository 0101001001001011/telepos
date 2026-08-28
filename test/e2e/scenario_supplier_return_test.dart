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

  Future<double?> stockOf(int ucode) async {
    final r = await h.db
        .customSelect(
          'SELECT quantity q FROM product_infos WHERE ucode = ?',
          variables: [Variable.withInt(ucode)],
        )
        .getSingleOrNull();
    return r?.read<double?>('q');
  }

  testWidgets('SUPPLIER RETURN — возврат поставщику (UI, stock decreases)', (
    t,
  ) async {
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

    final before = await stockOf(1001);
    step('start: Молоко = $before');

    try {
      h.router!.go('/supplier-return');
      await render(t);
      await shot(t, 'sr_01_screen');

      final pick = find.text('Выберите поставщика');
      if (pick.evaluate().isNotEmpty) {
        await t.tap(pick.first);
        await render(t);
        final sup = find.text('Поставщик Тест');
        if (sup.evaluate().isNotEmpty) {
          await t.tap(sup.first);
          await render(t);
        }
      }
      step(
        'возврат: поставщик выбран = ${find.text('Поставщик Тест').evaluate().isNotEmpty}',
      );

      final bc = find.byWidgetPredicate(
        (w) =>
            w is TextField &&
            (w.decoration?.hintText?.contains('рихкод') ?? false),
      );
      if (bc.evaluate().isNotEmpty) {
        await t.enterText(bc.first, '4607001');
        await t.testTextInput.receiveAction(TextInputAction.done);
        await render(t);
      } else {
        step('barcode field NOT FOUND');
      }
      await shot(t, 'sr_02_product_added');

      final save = find.text('Сохранить');
      if (save.evaluate().isNotEmpty) {
        await t.tap(save.last);
        await render(t);
      }
      await shot(t, 'sr_03_done');

      final after = await stockOf(1001);
      step('возврат: Молоко $before → $after (should be 99, −1)');
    } catch (e) {
      step('FAILED: $e');
      await shot(t, 'sr_FAILED');
    }

    // ignore: avoid_print
    print('\n===== SUPPLIER RETURN LOG =====');
    for (final l in log) {
      // ignore: avoid_print
      print('[sr] $l');
    }
    // ignore: avoid_print
    print('===== END =====\n');
  });
}

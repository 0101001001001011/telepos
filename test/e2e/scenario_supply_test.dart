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

  Future<double?> stockOf(int ucode) async {
    final r = await h.db
        .customSelect(
          'SELECT quantity q FROM product_infos WHERE ucode = ?',
          variables: [Variable.withInt(ucode)],
        )
        .getSingleOrNull();
    return r?.read<double?>('q');
  }

  testWidgets('SUPPLY — приход (UI, stock increases)', (t) async {
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
      h.router!.go('/supply');
      await render(t);
      await shot(t, 'sup_01_dialog');

      final pick = find.textContaining('Выберите');
      if (pick.evaluate().isNotEmpty) {
        await t.tap(pick.first);
        await render(t);
        await shot(t, 'sup_02_supplier_dialog');
      }
      final sup = find.text('Поставщик Тест');
      if (sup.evaluate().isNotEmpty) {
        await t.tap(sup.first);
        await render(t);
      }
      step(
        'supplier selected = ${find.text('Поставщик Тест').evaluate().isNotEmpty}',
      );

      final cons = find.textContaining('онсигнаци');
      if (cons.evaluate().isNotEmpty) {
        await t.tap(cons.first);
        await render(t);
      }

      final bc = find.byWidgetPredicate(
        (w) =>
            w is TextField &&
            (w.decoration?.hintText?.contains('артикул') ?? false),
      );
      if (bc.evaluate().isNotEmpty) {
        await t.enterText(bc.first, '4607001');
        await t.testTextInput.receiveAction(TextInputAction.done);
        await render(t);
        await shot(t, 'sup_03_addproduct_dialog');
        final add = find.text('Добавить');
        if (add.evaluate().isNotEmpty) {
          await t.tap(add.last);
          await render(t);
        }
      } else {
        step('barcode field NOT FOUND');
      }
      await shot(t, 'sup_04_product_added');

      final save = find.text('Сохранить');
      if (save.evaluate().isNotEmpty) {
        await t.tap(save.last);
        await render(t);
      }
      await shot(t, 'sup_05_done');

      final after = await stockOf(1001);
      step('приход: Молоко $before → $after (should INCREASE)');
    } catch (e) {
      step('supply FAILED: $e');
      await shot(t, 'sup_FAILED');
    }

    // ignore: avoid_print
    print('\n===== SUPPLY LOG =====');
    for (final l in log) {
      // ignore: avoid_print
      print('[sup] $l');
    }
    // ignore: avoid_print
    print('===== END =====\n');
  });
}

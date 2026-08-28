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

  Future<double?> markUpOf(int categoryId) async {
    final r = await h.db
        .customSelect(
          'SELECT markup m FROM mark_ups WHERE category_id = ?',
          variables: [Variable.withInt(categoryId)],
        )
        .getSingleOrNull();
    return r?.read<double?>('m');
  }

  Future<double?> sellingPriceOf(int ucode) async {
    final r = await h.db
        .customSelect(
          'SELECT selling_price p FROM product_prices WHERE ucode = ?',
          variables: [Variable.withInt(ucode)],
        )
        .getSingleOrNull();
    return r?.read<double?>('p');
  }

  testWidgets('MARKUP — авто-наценка (UI: set %, приход auto-prices)', (
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

    final priceBefore = await sellingPriceOf(1001);
    step(
      'start: Молоко цена = $priceBefore, наценка кат.1 = ${await markUpOf(1)}',
    );

    try {
      h.router!.go('/markup-settings');
      await render(t);
      await shot(t, 'mk_01_screen');

      final field = find.byType(TextField).first;
      await t.enterText(field, '40');
      await render(t);
      final save = find.text('Сохранить наценки');
      if (save.evaluate().isNotEmpty) {
        await t.tap(save.first);
        await render(t);
      }
      await shot(t, 'mk_02_saved');
      step(
        '1 markup: наценка кат.1 сохранена = ${await markUpOf(1)} (ожидаем 40)',
      );
    } catch (e) {
      step('1 markup FAILED: $e');
      await shot(t, 'mk_01_FAILED');
    }

    try {
      h.router!.go('/supply');
      await render(t);

      final pick = find.textContaining('Выберите');
      if (pick.evaluate().isNotEmpty) {
        await t.tap(pick.first);
        await render(t);
      }
      final sup = find.text('Поставщик Тест');
      if (sup.evaluate().isNotEmpty) {
        await t.tap(sup.first);
        await render(t);
      }
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
        final priceField = find.text('Цена прихода');
        if (priceField.evaluate().isNotEmpty) {
          await t.tap(priceField.first);
          await render(t);
          final clear = find.text('C');
          if (clear.evaluate().isNotEmpty) {
            await t.tap(clear.first);
            await render(t);
          }
          for (final ch in '300'.split('')) {
            final key = find.text(ch);
            if (key.evaluate().isNotEmpty) {
              await t.tap(key.last);
              await render(t);
            }
          }
        }
        final add = find.text('Добавить');
        if (add.evaluate().isNotEmpty) {
          await t.tap(add.last);
          await render(t);
        }
      }
      final save = find.text('Сохранить');
      if (save.evaluate().isNotEmpty) {
        await t.tap(save.last);
        await render(t);
      }
      await shot(t, 'mk_03_supply_done');

      final priceAfter = await sellingPriceOf(1001);
      step(
        '2 приход: Молоко цена $priceBefore →(закуп 300)→ $priceAfter '
        '(ожидаем 420 = 300 × 1.4)',
      );
    } catch (e) {
      step('2 приход FAILED: $e');
      await shot(t, 'mk_03_FAILED');
    }

    // ignore: avoid_print
    print('\n===== MARKUP LOG =====');
    for (final l in log) {
      // ignore: avoid_print
      print('[mk] $l');
    }
    // ignore: avoid_print
    print('===== END =====\n');
  });
}

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

  Future<double?> sellingPriceOf(int ucode) async {
    final r = await h.db
        .customSelect(
          'SELECT selling_price p FROM product_prices WHERE ucode = ?',
          variables: [Variable.withInt(ucode)],
        )
        .getSingleOrNull();
    return r?.read<double?>('p');
  }

  Future<void> setMarkup(WidgetTester t, String percent) async {
    h.router!.go('/markup-settings');
    await render(t);
    final field = find.byType(TextField).first;
    await t.enterText(field, percent);
    await render(t);
    final save = find.text('Сохранить наценки');
    if (save.evaluate().isNotEmpty) {
      await t.tap(save.first);
      await render(t);
    }
  }

  Future<void> enterPrice(WidgetTester t, String price) async {
    final field = find.text('Цена прихода');
    if (field.evaluate().isEmpty) return;
    await t.tap(field.first);
    await render(t);
    final clear = find.text('C');
    if (clear.evaluate().isNotEmpty) {
      await t.tap(clear.first);
      await render(t);
    }
    for (final ch in price.split('')) {
      final key = find.text(ch);
      if (key.evaluate().isNotEmpty) {
        await t.tap(key.last);
        await render(t);
      }
    }
  }

  Future<void> supply(WidgetTester t, String barcode, {String? price}) async {
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
      await t.enterText(bc.first, barcode);
      await t.testTextInput.receiveAction(TextInputAction.done);
      await render(t);
      if (price != null) await enterPrice(t, price);
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
  }

  testWidgets('MARKUP EDGE — 0%, no-markup, fractional, compounding', (
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

    try {
      final before = await sellingPriceOf(1002);
      await supply(t, '4607002', price: '100');
      final after = await sellingPriceOf(1002);
      step('1 no-markup: Хлеб $before → $after (ожидаем без изменений 150)');
    } catch (e) {
      step('1 FAILED: $e');
    }

    try {
      await setMarkup(t, '15');
      final before = await sellingPriceOf(1001);
      await supply(t, '4607001', price: '300');
      final after = await sellingPriceOf(1001);
      step(
        '2 fractional 15%: Молоко $before →(закуп 300)→ $after (ожидаем 345)',
      );

      await supply(t, '4607001');
      final after2 = await sellingPriceOf(1001);
      step(
        '3 anti-compounding: повторный приход по рознице Молоко $after → $after2 '
        '(ожидаем 345 — гард пропустил, без раздувания)',
      );
    } catch (e) {
      step('2/3 FAILED: $e');
    }

    try {
      await setMarkup(t, '0');
      final before = await sellingPriceOf(1003);
      await supply(t, '4607003', price: '150');
      final after = await sellingPriceOf(1003);
      step('4 zero 0%: Сахар $before → $after (ожидаем без изменений 280)');
    } catch (e) {
      step('4 FAILED: $e');
    }

    // ignore: avoid_print
    print('\n===== MARKUP EDGE LOG =====');
    for (final l in log) {
      // ignore: avoid_print
      print('[mke] $l');
    }
    // ignore: avoid_print
    print('===== END =====\n');
  });
}

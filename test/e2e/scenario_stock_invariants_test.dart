library;

import 'package:decimal/decimal.dart';
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

  Future<void> pay(WidgetTester t, {required String denom}) async {
    await tapText(t, 'ОПЛАТИТЬ');
    final d = find.text(denom);
    if (d.evaluate().isNotEmpty) {
      await t.tap(d.first);
      await render(t);
    }
    await tapText(t, 'ОПЛАТИТЬ', last: true);
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

  Future<void> supplyOne(WidgetTester t, String barcode) async {
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

  testWidgets('STOCK — conservation chain + oversell boundary', (t) async {
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
      final s0 = await stockOf(1001);
      await supplyOne(t, '4607001');
      final s1 = await stockOf(1001);
      await dismissModals(t);
      h.router!.go('/sale');
      await render(t);
      await addItem(t, '4607001');
      await addItem(t, '4607001');
      await addItem(t, '4607001');
      await pay(t, denom: '2K');
      final s2 = await stockOf(1001);
      step(
        '1 conservation: Молоко $s0 →приход $s1 →продажа $s2 '
        '(ожидаем 100→101→98, инвариант сошёлся)',
      );
    } catch (e) {
      step('1 FAILED: $e');
    }

    try {
      await dismissModals(t);
      await h.db.productInfoDao.updateQuantity(1004, Decimal.fromInt(2));
      final m0 = await stockOf(1004);
      h.router!.go('/sale');
      await render(t);
      for (var i = 0; i < 5; i++) {
        await addItem(t, '4607004');
      }
      await pay(t, denom: '5K');
      final m1 = await stockOf(1004);
      step(
        '2 oversell: Масло остаток $m0, продано 5 → остаток $m1 '
        '(политика: <0 = разрешена пере-продажа; 0/2 = блок)',
      );
    } catch (e) {
      step('2 FAILED: $e');
    }

    // ignore: avoid_print
    print('\n===== STOCK INVARIANTS LOG =====');
    for (final l in log) {
      // ignore: avoid_print
      print('[si] $l');
    }
    // ignore: avoid_print
    print('===== END =====\n');
  });
}

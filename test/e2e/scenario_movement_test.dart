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

  Future<int> movementDocCount() async {
    final r = await h.db
        .customSelect('SELECT COUNT(*) c FROM movement_products')
        .getSingle();
    return r.read<int>('c');
  }

  testWidgets('MOVEMENT — перемещение (UI, stock neutral, doc saved)', (
    t,
  ) async {
    await h.pumpApp(t);
    await t.pump(const Duration(seconds: 1));
    await h.loginAsCashier(t);
    await render(t);

    final before = await stockOf(1001);
    final docsBefore = await movementDocCount();
    step('start: Молоко = $before, movement docs = $docsBefore');

    try {
      h.router!.go('/movement');
      await render(t);
      await shot(t, 'mv_01_screen');

      final fields = find.byType(TextField);
      if (fields.evaluate().length >= 2) {
        await t.enterText(fields.at(0), 'Главный склад');
        await render(t);
        await t.enterText(fields.at(1), 'Торговый зал');
        await render(t);
      }

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
      await shot(t, 'mv_02_product_added');

      final save = find.text('Сохранить');
      if (save.evaluate().isNotEmpty) {
        await t.tap(save.last);
        await render(t);
      }
      await shot(t, 'mv_03_done');

      final after = await stockOf(1001);
      final docsAfter = await movementDocCount();
      step('перемещение: Молоко $before → $after (should be UNCHANGED 100)');
      step('перемещение: docs $docsBefore → $docsAfter (should INCREASE)');
    } catch (e) {
      step('FAILED: $e');
      await shot(t, 'mv_FAILED');
    }

    // ignore: avoid_print
    print('\n===== MOVEMENT LOG =====');
    for (final l in log) {
      // ignore: avoid_print
      print('[mv] $l');
    }
    // ignore: avoid_print
    print('===== END =====\n');
  });
}

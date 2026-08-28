library;

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

  Future<void> addItem(WidgetTester t, String barcode) async {
    await t.enterText(find.byType(TextField).first, barcode);
    await t.testTextInput.receiveAction(TextInputAction.done);
    await render(t);
  }

  testWidgets('CUSTOMER DISPLAY + HARDWARE — экран покупателя/весы (UI)', (
    t,
  ) async {
    await h.pumpApp(t);
    await t.pump(const Duration(seconds: 1));
    await h.loginAsCashier(t);
    await render(t);

    try {
      h.router!.go('/customer-display');
      await render(t);
      await shot(t, 'cd_00_welcome');
      step(
        'A1 welcome: «Добро пожаловать» = '
        '${find.text('Добро пожаловать!').evaluate().isNotEmpty}',
      );
    } catch (e) {
      step('A1 FAILED: $e');
    }

    try {
      h.router!.go('/sale');
      await render(t);
      await addItem(t, '4607001');
      await addItem(t, '4607002');

      h.router!.go('/customer-display');
      await render(t);
      await shot(t, 'cd_01_cart');

      final hasMilk = find.text('Молоко 1л').evaluate().isNotEmpty;
      final hasBread = find.text('Хлеб белый').evaluate().isNotEmpty;
      final hasTotal = find.text('ИТОГО').evaluate().isNotEmpty;
      final has600 = find.textContaining('600').evaluate().isNotEmpty;
      step(
        'A2 cart: Молоко=$hasMilk Хлеб=$hasBread ИТОГО=$hasTotal сумма600=$has600',
      );
    } catch (e) {
      step('A2 FAILED: $e');
    }

    try {
      h.router!.go('/hardware-settings');
      await render(t);
      await shot(t, 'cd_02_hw_settings');

      final hasScales = find.text('Весы').evaluate().isNotEmpty;
      final hasScreen = find
          .text('Экран покупателя (монитор)')
          .evaluate()
          .isNotEmpty;
      step('B hardware: секция Весы=$hasScales, Экран покупателя=$hasScreen');

      final section = find.ancestor(
        of: find.text('Экран покупателя (монитор)'),
        matching: find.byType(Row),
      );
      final sw = find.descendant(
        of: section.first,
        matching: find.byType(Switch),
      );
      if (sw.evaluate().isNotEmpty) {
        await t.tap(sw.first);
        await render(t);
      }
      await shot(t, 'cd_03_screen_enabled');
      final hasOpen = find
          .text('Открыть экран покупателя')
          .evaluate()
          .isNotEmpty;
      step('B hardware: после включения кнопка «Открыть» = $hasOpen');
    } catch (e) {
      step('B FAILED: $e');
    }

    // ignore: avoid_print
    print('\n===== CUSTOMER DISPLAY LOG =====');
    for (final l in log) {
      // ignore: avoid_print
      print('[cd] $l');
    }
    // ignore: avoid_print
    print('===== END =====\n');
  });
}

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

  testWidgets('OPS — discount + fiscal settings (UI)', (t) async {
    await h.pumpApp(t);
    await t.pump(const Duration(seconds: 1));
    await h.loginAsCashier(t);
    await render(t);

    try {
      h.router!.go('/sale');
      await render(t);
      await addItem(t, '4607001');
      discountFieldFinder() => find.byWidgetPredicate(
        (w) => w is TextField && w.decoration?.labelText == 'Скидка',
      );
      var opened = false;
      for (var attempt = 0; attempt < 3 && !opened; attempt++) {
        await t.tap(find.text('Молоко 1л').first);
        await render(t);
        final edit = find.text('Редактировать');
        if (edit.evaluate().isNotEmpty) {
          await t.tap(edit.first);
          await render(t);
        }
        opened = discountFieldFinder().evaluate().isNotEmpty;
      }
      await shot(t, 'ops_01a_edit_dialog');
      if (!opened) {
        step('1 discount: Скидка field NOT FOUND after retries');
      } else {
        await t.enterText(discountFieldFinder().first, '50');
        await render(t);
        final save = find.descendant(
          of: find.byWidgetPredicate(
            (w) => w is ElevatedButton || w is FilledButton,
          ),
          matching: find.text('Сохранить'),
        );
        await t.tap(
          save.evaluate().isNotEmpty
              ? save.first
              : find.text('Сохранить').first,
        );
        await render(t);
        await shot(t, 'ops_01b_discounted');
        final has400 = find.text('400').evaluate().isNotEmpty;
        final has450 = find.text('450').evaluate().isNotEmpty;
        step(
          '1 discount: after −50 → total shows 400=$has400 (450 still shown=$has450)',
        );
      }
    } catch (e) {
      step('1 discount FAILED: $e');
      await shot(t, 'ops_01_discount_FAILED');
    }

    try {
      h.router!.go('/fiscal-settings');
      await render(t);
      await shot(t, 'ops_02a_fiscal_default');
      final wk = find.text('WebKassa');
      if (wk.evaluate().isNotEmpty) {
        await t.tap(wk.first);
        await render(t);
      }
      await shot(t, 'ops_02b_webkassa_form');
      final hasLogin = find.text('Логин').evaluate().isNotEmpty;
      final hasPassword = find.text('Пароль').evaluate().isNotEmpty;
      step(
        '2 fiscal: WebKassa selected → Логин field=$hasLogin, Пароль field=$hasPassword',
      );
      final ofd = find.textContaining('Прямое');
      if (ofd.evaluate().isNotEmpty) {
        await t.tap(ofd.first);
        await render(t);
        await shot(t, 'ops_02c_direct_ofd_form');
        step('2 fiscal: Прямое ОФД form shown');
      }
    } catch (e) {
      step('2 fiscal FAILED: $e');
      await shot(t, 'ops_02_fiscal_FAILED');
    }

    // ignore: avoid_print
    print('\n===== OPS SCENARIO LOG =====');
    for (final l in log) {
      // ignore: avoid_print
      print('[ops] $l');
    }
    // ignore: avoid_print
    print('===== END =====\n');
  });
}

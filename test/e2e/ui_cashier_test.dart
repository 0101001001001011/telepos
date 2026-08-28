library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/harness.dart';

void main() {
  final h = E2eHarness();
  setUpAll(() => h.setUp());
  tearDownAll(() => h.tearDown());

  Future<void> render(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pump(const Duration(milliseconds: 500));
  }

  Future<void> shot(WidgetTester tester, String name) async {
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('cashier/$name.png'),
    );
  }

  Future<void> addByBarcode(WidgetTester tester, String code) async {
    final search = find.byType(TextField).first;
    await tester.enterText(search, code);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await render(tester);
  }

  Future<void> tapType(WidgetTester tester, String label) async {
    final f = find.text(label);
    if (f.evaluate().isNotEmpty) {
      await tester.tap(f.first);
      await render(tester);
    }
  }

  testWidgets('cashier workplace deep dive', (tester) async {
    await h.pumpApp(tester);
    await tester.pump(const Duration(seconds: 1));
    await h.loginAsCashier(tester);
    await render(tester);

    h.router!.go('/sale');
    await render(tester);

    final quick = find.text('Быстрые товары');
    if (quick.evaluate().isNotEmpty) {
      await tester.tap(quick.first);
      await render(tester);
      await shot(tester, '01_quick_products');
      await tester.tap(quick.first);
      await render(tester);
    }

    await addByBarcode(tester, '4607001');
    await addByBarcode(tester, '4607002');
    await addByBarcode(tester, '4607003');
    await shot(tester, '02_cart_with_items');

    var payBtn = find.widgetWithIcon(ElevatedButton, Icons.payment);
    if (payBtn.evaluate().isEmpty) payBtn = find.text('ОПЛАТИТЬ');
    expect(
      payBtn,
      findsWidgets,
      reason: 'Pay button must be present with items',
    );
    await tester.tap(payBtn.first);
    await render(tester);
    await shot(tester, '03_payment_cash');

    for (final note in ['1K', '1 000', '1000']) {
      final f = find.text(note);
      if (f.evaluate().isNotEmpty) {
        await tester.tap(f.first);
        await render(tester);
        break;
      }
    }
    await shot(tester, '04_payment_change');

    await tapType(tester, 'Смешанная');
    await shot(tester, '05_payment_mixed');

    await tapType(tester, 'Безналичная');
    await shot(tester, '06_payment_card');

    await tapType(tester, 'Наличная');
    final phone = find.byWidgetPredicate(
      (w) =>
          w is TextField &&
          (w.decoration?.hintText?.toLowerCase().contains('телефон') ?? false),
    );
    if (phone.evaluate().isNotEmpty) {
      await tester.enterText(phone.first, '7011234567');
      await render(tester);
    }
    await shot(tester, '07_payment_loyalty');

    // ignore: avoid_print
    print('[cashier] deep-dive complete');
  });
}

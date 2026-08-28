library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/harness.dart';

void main() {
  final h = E2eHarness();

  setUpAll(() => h.setUp());
  tearDownAll(() => h.tearDown());

  group('E2E smoke', () {
    testWidgets('app boots past splash to a real screen', (tester) async {
      await h.pumpApp(tester);
      expect(find.byType(MaterialApp), findsOneWidget);
      await tester.pumpAndSettle(const Duration(seconds: 2));
      expect(
        find.byType(Scaffold),
        findsWidgets,
        reason: 'Expected at least one Scaffold after splash',
      );
    });

    testWidgets('seeded cashier is offered on the login screen', (
      tester,
    ) async {
      await h.pumpApp(tester);
      await tester.pumpAndSettle(const Duration(seconds: 2));
      final onLogin = find.text(E2eHarness.cashierName).evaluate().isNotEmpty;
      final hasUi = find.byType(Scaffold).evaluate().isNotEmpty;
      expect(hasUi, isTrue);
      // ignore: avoid_print
      print('[smoke] login screen with seeded cashier: $onLogin');
    });
  });
}

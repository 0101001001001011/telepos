import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:telepos/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Setup wizard: login flow with real backend', (tester) async {
    app.main(const <String>[]);

    // Wait for splash + DB init + catalog import
    debugPrint('=== Waiting for app initialization... ===');
    for (int i = 0; i < 60; i++) {
      await tester.pump(const Duration(seconds: 1));
      // Check if auth choice screen appeared
      if (find.text('TelePOS').evaluate().isNotEmpty &&
          find.textContaining('Account').evaluate().isNotEmpty) {
        break;
      }
    }
    await tester.pump(const Duration(seconds: 1));

    // === Step 1: Auth Choice screen ===
    debugPrint('=== STEP 1: Auth Choice ===');
    expect(find.text('TelePOS'), findsOneWidget);

    final createBtn = find.textContaining('Create Account');
    final loginBtn = find.textContaining('I Have');
    final offlineBtn = find.textContaining('offline');

    debugPrint('Create Account: ${createBtn.evaluate().isNotEmpty ? "FOUND" : "MISSING"}');
    debugPrint('I Have Account: ${loginBtn.evaluate().isNotEmpty ? "FOUND" : "MISSING"}');
    debugPrint('Offline: ${offlineBtn.evaluate().isNotEmpty ? "FOUND" : "MISSING"}');

    expect(createBtn, findsOneWidget);
    expect(loginBtn, findsOneWidget);
    expect(offlineBtn, findsOneWidget);

    // Tap "I Have an Account"
    debugPrint('=== Tapping "I Have an Account" ===');
    await tester.tap(loginBtn);
    await tester.pumpAndSettle(const Duration(seconds: 2));

    // === Step 2: Login screen ===
    debugPrint('=== STEP 2: Login Screen ===');
    expect(find.text('Sign In'), findsWidgets);

    // Find login field and password field
    final loginField = find.byType(TextField).first;
    final passwordFields = find.byType(TextField);
    debugPrint('TextFields found: ${passwordFields.evaluate().length}');

    // Enter phone number
    debugPrint('=== Entering phone: +77775551234 ===');
    await tester.enterText(find.byType(TextField).at(0), '+77775551234');
    await tester.pump();

    // Enter password
    debugPrint('=== Entering password ===');
    await tester.enterText(find.byType(TextField).at(1), 'Qwerty12345!');
    await tester.pump();

    // Tap Sign In button
    debugPrint('=== Tapping Sign In ===');
    final signInBtn = find.widgetWithText(ElevatedButton, 'Sign In');
    if (signInBtn.evaluate().isEmpty) {
      // Try localized
      final anyElevated = find.byType(ElevatedButton);
      debugPrint('ElevatedButtons found: ${anyElevated.evaluate().length}');
      if (anyElevated.evaluate().isNotEmpty) {
        await tester.tap(anyElevated.first);
      }
    } else {
      await tester.tap(signInBtn);
    }

    // Wait for response (with spinner)
    debugPrint('=== Waiting for login response... ===');
    for (int i = 0; i < 15; i++) {
      await tester.pump(const Duration(seconds: 1));

      // Check if we moved to next screen (org select or error)
      if (find.text('Select Organization').evaluate().isNotEmpty) {
        debugPrint('=== SUCCESS: Organization Select screen ===');
        break;
      }
      if (find.textContaining('Unable to connect').evaluate().isNotEmpty) {
        debugPrint('=== ERROR: Server unreachable ===');
        break;
      }
      if (find.textContaining('Wrong').evaluate().isNotEmpty) {
        debugPrint('=== ERROR: Wrong credentials ===');
        break;
      }
      if (find.byIcon(Icons.error_outline).evaluate().isNotEmpty) {
        // Find the error text
        final errorCards = find.byType(Card);
        debugPrint('=== ERROR CARD found, cards: ${errorCards.evaluate().length} ===');
        break;
      }
    }

    // Final state check
    debugPrint('=== FINAL STATE ===');
    // List all visible text widgets for debugging
    final allText = find.byType(Text);
    for (final element in allText.evaluate().take(20)) {
      final widget = element.widget as Text;
      if (widget.data != null && widget.data!.isNotEmpty) {
        debugPrint('  TEXT: "${widget.data}"');
      }
    }

    debugPrint('=== TEST COMPLETE ===');
  });
}

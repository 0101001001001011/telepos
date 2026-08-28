import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:telepos/main.dart' as app;

/// Full E2E setup wizard test.
///
/// IMPORTANT: Uses pump() with explicit delays, NOT pumpAndSettle().
/// pumpAndSettle never completes because background timers (DataExchange,
/// Updater, FiscErrors) tick indefinitely.
///
/// Run: flutter test integration_test/full_setup_flow_test.dart -d windows
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Setup Wizard E2E', () {
    testWidgets('Scenario B: login → org select → POS config → save', (tester) async {
      app.main(const <String>[]);

      // --- Wait for init (splash + DB creation + catalog import) ---
      await _waitUntilVisible(tester, 'TelePOS', maxSeconds: 120,
          label: 'Auth Choice screen');

      // === STEP 1: Auth Choice ===
      _log('STEP 1: Auth Choice');
      _expectVisible(tester, 'TelePOS');
      _expectVisible(tester, 'Create Account');
      _expectVisible(tester, 'I Have');

      await _tapText(tester, 'I Have');
      await _wait(tester, 2);

      // === STEP 2: Login ===
      _log('STEP 2: Login');
      _expectVisible(tester, 'Sign In');

      // Enter phone
      await _enterField(tester, 0, '+77775551234');
      // Enter password
      await _enterField(tester, 1, 'Qwerty12345!');
      await _wait(tester, 1);

      // Tap Sign In
      await _tapElevatedButton(tester);
      _log('Submitted login, waiting for response...');

      // Wait for org select (API call ~2-5s)
      final loginOk = await _waitUntilVisible(tester, 'Select Organization',
          maxSeconds: 20, label: 'Org Select');

      if (!loginOk) {
        _log('LOGIN FAILED — checking error:');
        _dumpScreen(tester);
        fail('Login did not succeed — stuck on login screen');
      }

      // === STEP 3: Org Select ===
      _log('STEP 3: Org Select');
      _expectVisible(tester, 'Select Organization');
      _expectVisible(tester, 'AI Dorba');

      await _tapText(tester, 'AI Dorba');
      _log('Tapped AI Dorba, waiting for POS Setup...');

      // Wait for POS setup step
      await _waitUntilVisible(tester, 'POS', maxSeconds: 10, label: 'POS Setup');
      await _wait(tester, 2);

      _log('STEP 4: POS Setup');
      _dumpScreen(tester);

      // Enter POS name in first text field
      final posFields = find.byType(TextField);
      if (posFields.evaluate().isNotEmpty) {
        await _enterField(tester, 0, 'TelePOS Kassa-1');
        _log('Entered POS name');
        if (posFields.evaluate().length > 1) {
          await _enterField(tester, 1, 'POS-1');
          _log('Entered POS ID');
        }
      }

      // Tap Next
      await _tapElevatedButton(tester);
      await _wait(tester, 2);

      // === STEP 5: Fiscal ===
      _log('STEP 5: Fiscal Setup');
      _dumpScreen(tester);
      await _tapElevatedButton(tester); // Next/Skip
      await _wait(tester, 2);

      // === STEP 6: Equipment ===
      _log('STEP 6: Equipment Setup');
      _dumpScreen(tester);
      await _tapElevatedButton(tester);
      await _wait(tester, 2);

      // === STEP 7: Payment Terminals ===
      _log('STEP 7: Payment Terminals');
      _dumpScreen(tester);
      await _tapElevatedButton(tester);
      await _wait(tester, 2);

      // === STEP 8: Summary ===
      _log('STEP 8: Summary');
      _dumpScreen(tester);

      // Tap Done/Complete (green button)
      await _tapElevatedButton(tester);
      _log('Tapped Complete, waiting for save...');

      // Wait for save + redirect to complete/login
      final saved = await _waitUntilAnyVisible(tester, [
        'Complete', 'PIN', 'complete', 'Login',
      ], maxSeconds: 30, label: 'Save complete');

      _log('FINAL STATE (saved=$saved):');
      _dumpScreen(tester);

      _log('=== SCENARIO B TEST COMPLETE ===');
    });
  });
}

// =============================================================================
// Test Helpers — explicit pump, no pumpAndSettle
// =============================================================================

/// Pump N seconds of frames
Future<void> _wait(WidgetTester tester, int seconds) async {
  for (int i = 0; i < seconds * 4; i++) {
    await tester.pump(const Duration(milliseconds: 250));
  }
}

/// Wait until text becomes visible, polling every 500ms
Future<bool> _waitUntilVisible(WidgetTester tester, String text,
    {int maxSeconds = 30, String? label}) async {
  for (int i = 0; i < maxSeconds * 2; i++) {
    await tester.pump(const Duration(milliseconds: 500));
    if (find.textContaining(text).evaluate().isNotEmpty) {
      _log('${label ?? text} visible after ${i ~/ 2}s');
      return true;
    }
  }
  _log('TIMEOUT: ${label ?? text} not visible after ${maxSeconds}s');
  return false;
}

/// Wait until any of the texts become visible
Future<bool> _waitUntilAnyVisible(WidgetTester tester, List<String> texts,
    {int maxSeconds = 30, String? label}) async {
  for (int i = 0; i < maxSeconds * 2; i++) {
    await tester.pump(const Duration(milliseconds: 500));
    for (final t in texts) {
      if (find.textContaining(t).evaluate().isNotEmpty) {
        _log('${label ?? t} visible after ${i ~/ 2}s');
        return true;
      }
    }
  }
  _log('TIMEOUT: ${label ?? texts.join("/")} not visible after ${maxSeconds}s');
  return false;
}

/// Tap text widget
Future<void> _tapText(WidgetTester tester, String text) async {
  final finder = find.textContaining(text);
  expect(finder, findsWidgets, reason: 'Expected "$text" to be visible');
  await tester.tap(finder.first);
  await tester.pump(const Duration(milliseconds: 300));
}

/// Tap first ElevatedButton
Future<void> _tapElevatedButton(WidgetTester tester) async {
  final btn = find.byType(ElevatedButton);
  if (btn.evaluate().isNotEmpty) {
    await tester.tap(btn.first);
    await tester.pump(const Duration(milliseconds: 300));
  } else {
    _log('WARNING: No ElevatedButton found');
  }
}

/// Enter text in TextField at index
Future<void> _enterField(WidgetTester tester, int index, String text) async {
  final fields = find.byType(TextField);
  if (fields.evaluate().length > index) {
    await tester.enterText(fields.at(index), text);
    await tester.pump(const Duration(milliseconds: 200));
  } else {
    _log('WARNING: TextField[$index] not found (only ${fields.evaluate().length} fields)');
  }
}

/// Check text is visible
void _expectVisible(WidgetTester tester, String text) {
  expect(find.textContaining(text), findsWidgets,
      reason: 'Expected "$text" to be visible');
}

/// Dump first 15 visible text widgets
void _dumpScreen(WidgetTester tester) {
  final texts = <String>[];
  for (final e in find.byType(Text).evaluate().take(20)) {
    final w = e.widget as Text;
    final t = w.data ?? w.textSpan?.toPlainText();
    if (t != null && t.isNotEmpty && t.length < 80) texts.add(t);
  }
  _log('Screen: ${texts.take(12).join(" | ")}');
}

void _log(String msg) => debugPrint('[TEST] $msg');

library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:telepos/hardware/printer/printer_manager.dart';

import 'support/harness.dart';

/// И30 (docs/system-architecture.md, section 8): "Ни один отказ устройства не
/// блокирует приём денег." A terminal with no receipt-printer binding is the
/// most direct way to exercise this — not a *failing* printer (which still
/// exists, just misbehaves), but the "no printer manager exists at all" case
/// plan 2, task 3 introduces: `hardware_module.dart` now refuses to register
/// a `PrinterManager` at all when no binding resolves, rather than falling
/// back to a `MockPrinterManager` that would have quietly absorbed the print
/// job. This test proves that refusal does not also refuse to take the
/// customer's money.
///
/// Uses the real dependency graph, on a real (in-memory) database — not a
/// mock that merely records a call — per `test/e2e/support/harness.dart`.
void main() {
  final h = E2eHarness();

  setUpAll(() => h.setUp());
  tearDownAll(() => h.tearDown());

  Future<void> render(WidgetTester t) async {
    await t.pump();
    await t.pump(const Duration(milliseconds: 600));
    await t.pump(const Duration(milliseconds: 400));
  }

  Future<void> tapText(WidgetTester t, String text, {bool last = false}) async {
    final f = find.text(text);
    if (f.evaluate().isEmpty) {
      throw TestFailure('tap target not found: "$text"');
    }
    await t.tap(last ? f.last : f.first);
    await render(t);
  }

  Future<void> tapButton(WidgetTester t, String text) async {
    final byType = find.byWidgetPredicate(
      (w) =>
          (w is ElevatedButton ||
          w is FilledButton ||
          w is TextButton ||
          w is OutlinedButton),
    );
    final f = find.descendant(of: byType, matching: find.text(text));
    if (f.evaluate().isEmpty) {
      await tapText(t, text, last: true);
      return;
    }
    await t.tap(f.last);
    await render(t);
  }

  /// Sales in the **completed** state (`_pendingSync = 1` —
  /// `lib/data/usecases/sale/sale_use_case_impl.dart`), not merely
  /// initiated — `SaleInitiationUseCase` inserts a draft row in state 0 as
  /// soon as the sale screen starts a transaction, before any payment is
  /// taken, so counting every row in `sales` would pass even if payment
  /// were never completed. Counting state 1 rows is what actually
  /// distinguishes "the sale went through" from "a cart was opened".
  Future<int> completedSaleCount() async {
    final rows = await h.db
        .customSelect('SELECT COUNT(*) AS c FROM sales WHERE state = 1')
        .get();
    return rows.first.read<int>('c');
  }

  testWidgets(
    'a sale completes on a terminal with no printer binding (И30)',
    (t) async {
      // The harness's fresh in-memory database has no terminal — and
      // therefore no device bindings — at the point `configureDependencies`
      // runs (`E2eHarness.setUp` calls it before `seed()`), so this is
      // already the "no printer configured" case, genuinely: not a mock
      // standing in for one.
      expect(
        GetIt.I.isRegistered<PrinterManager>(),
        isFalse,
        reason:
            'Precondition for this test: no PrinterManager registered at '
            'all, proving the sale below completes with no printer present '
            '— not merely a printer that fails quietly.',
      );

      await h.pumpApp(t);
      await t.pump(const Duration(seconds: 1));
      await h.loginAsCashier(t);
      await render(t);

      h.router!.go('/shift');
      await render(t);
      await tapText(t, 'Открыть смену');
      await t.enterText(find.byType(TextField).last, '50000');
      await render(t);
      await tapButton(t, 'Открытие смены');
      await render(t);

      final before = await completedSaleCount();

      h.router!.go('/sale');
      await render(t);
      await t.enterText(find.byType(TextField).first, '4607001');
      await t.testTextInput.receiveAction(TextInputAction.done);
      await render(t);

      await tapText(t, 'ОПЛАТИТЬ');
      final denom = find.text('1K');
      if (denom.evaluate().isNotEmpty) {
        await t.tap(denom.first);
        await render(t);
      }
      await tapText(t, 'ОПЛАТИТЬ', last: true);
      await render(t);
      await t.pump(const Duration(seconds: 1));

      final after = await completedSaleCount();

      expect(
        after,
        greaterThan(before),
        reason:
            'The sale must be persisted even though no PrinterManager is '
            'registered — a missing printer must never block taking money '
            '(И30). If this is still equal to `before`, the sale silently '
            'never completed.',
      );

      // Still true after completing a sale — printing was dispatched
      // (fire-and-forget) or skipped, never awaited into existence.
      expect(GetIt.I.isRegistered<PrinterManager>(), isFalse);

      // Since plan 2в task 5 the receipt no longer goes to the driver at all:
      // it is submitted to `PrintQueue`, whose transport fails because there
      // is no `PrinterManager`. The claim of this test is unchanged — the sale
      // completes with no printer — but the path it now covers is longer (a
      // queue plus a database write), so it is a *stronger* И30 proof than
      // before, not a weaker one that passes for a new reason. What the queue
      // does with that job is proved separately in
      // `test/e2e/print_queue_sale_test.dart`.
    },
  );
}

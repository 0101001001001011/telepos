library;

import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';

import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/domain/print/print_queue.dart';
import 'package:telepos/domain/services/receipt_print_service.dart';
import 'package:telepos/presentation/controllers/shift/shift_controller.dart';

import '../support/harness.dart';

class _ZReportCapture {
  int? saleCount;
  Decimal? saleTotal;
  int? refundCount;
  Decimal? refundTotal;
  Decimal? cashStart;
  Decimal? cashEnd;
  Decimal? cashIncome;
  Decimal? cashExpense;
  int calls = 0;
}

class _FakeReceiptPrintService implements ReceiptPrintService {
  _FakeReceiptPrintService(this.capture);

  final _ZReportCapture capture;
  bool zReportResult = true;

  @override
  Future<PrintSubmitOutcome> printZReport({
    required String storeName,
    required String posName,
    required String cashierName,
    required DateTime shiftStart,
    required DateTime shiftEnd,
    required int saleCount,
    required Decimal saleTotal,
    required int refundCount,
    required Decimal refundTotal,
    required Decimal cashStart,
    required Decimal cashEnd,
    required Decimal cashIncome,
    required Decimal cashExpense,
  }) async {
    capture
      ..calls += 1
      ..saleCount = saleCount
      ..saleTotal = saleTotal
      ..refundCount = refundCount
      ..refundTotal = refundTotal
      ..cashStart = cashStart
      ..cashEnd = cashEnd
      ..cashIncome = cashIncome
      ..cashExpense = cashExpense;
    // Очередь отвечает «принято»/«отказ», а не «напечатано» — см.
    // `ReceiptPrintService`. Отказ здесь — это то, что контроллер смены
    // считает неудачей Z-отчёта.
    return zReportResult
        ? PrintSubmitOutcome.accepted('z-report')
        : PrintSubmitOutcome.rejected('z-report', 'принтер недоступен');
  }

  @override
  Future<bool> isPrinterAvailable() async => false;
  @override
  Future<bool> openCashDrawer() async => true;
  @override
  dynamic noSuchMethod(Invocation invocation) => Future<bool>.value(true);
}

void main() {
  final h = E2eHarness();

  setUp(() async {
    await h.setUp();
    GetIt.I.registerSingleton<AppDatabase>(h.db);
  });
  tearDown(() => h.tearDown());

  Future<void> goTo(WidgetTester tester, String route) async {
    final ctx = tester.element(find.byType(Navigator).first);
    GoRouter.of(ctx).go(route);
    await tester.pumpAndSettle(const Duration(seconds: 2));
  }

  ProviderContainer container(WidgetTester tester) {
    final ctx = tester.element(find.byType(MaterialApp).first);
    return ProviderScope.containerOf(ctx);
  }

  Future<void> seedCompletedSale(
    AppDatabase db, {
    required int userId,
    required int posAccountId,
    required Decimal amount,
    int receiptNo = 5001,
    int posId = 1,
  }) async {
    final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    await db
        .into(db.sales)
        .insert(
          SalesCompanion.insert(
            receiptNo: receiptNo,
            posId: posId,
            userId: userId,
            amount: amount,
            time: nowSec,
            state: const Value(4),
          ),
        );
    await db
        .into(db.payments)
        .insert(
          PaymentsCompanion.insert(
            userId: userId,
            payeeAccountId: posAccountId,
            amount: amount,
            time: nowSec,
            receiptNo: const Value(5001),
            posId: const Value(1),
            state: const Value(4),
          ),
        );
  }

  Future<Shift?> openedShift(AppDatabase db) => db.shiftDao.findOpenedShift();

  testWidgets(
    'open shift -> sale -> Z-report shows real values -> close shift',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1400, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final db = GetIt.I<AppDatabase>();

      final users = await db.userDao.findAll();
      expect(users, isNotEmpty, reason: 'seed creates a cashier');
      final cashierId = users
          .firstWhere((u) => u.name == E2eHarness.cashierName)
          .id;
      final thisPos = await db.thisPosDao.get();
      final posAccountId = thisPos!.accountId!;

      final capture = _ZReportCapture();
      final fakePrinter = _FakeReceiptPrintService(capture);
      GetIt.I.registerSingleton<ReceiptPrintService>(fakePrinter);

      await h.pumpApp(tester);
      final loggedIn = await h.loginAsCashier(tester);
      expect(loggedIn, isTrue, reason: 'must reach a post-login surface');

      await goTo(tester, '/shift');
      expect(find.byType(Scaffold), findsWidgets);

      expect(
        await openedShift(db),
        isNull,
        reason: 'no shift should be open before we open one',
      );
      expect(
        find.text('Открыть смену'),
        findsWidgets,
        reason: 'closed shift offers the Open action',
      );
      expect(
        find.text('Печать Z-отчёта'),
        findsNothing,
        reason: 'Z-report action is hidden while the shift is closed',
      );

      await tester.tap(find.text('Открыть смену').first);
      await tester.pumpAndSettle();
      final amountField = find.byType(TextField);
      expect(
        amountField,
        findsOneWidget,
        reason: 'open-shift dialog has an initial-amount field',
      );
      await tester.enterText(amountField, '5000');
      await tester.pumpAndSettle();
      final confirmOpen = find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(ElevatedButton),
      );
      expect(confirmOpen, findsOneWidget, reason: 'open-shift confirm present');
      await tester.tap(confirmOpen);
      await tester.pumpAndSettle(const Duration(seconds: 2));

      final shift = await openedShift(db);
      expect(shift, isNotNull, reason: 'opening the shift persists a row');
      expect(shift!.isOpened, isTrue);
      expect(
        shift.userId,
        cashierId,
        reason: 'shift owned by the logged-in cashier',
      );

      expect(
        find.text('Печать Z-отчёта'),
        findsOneWidget,
        reason: 'open shift exposes the Z-report action',
      );
      expect(
        find.text('Закрыть смену'),
        findsWidgets,
        reason: 'open shift exposes the Close action',
      );

      const saleAmount = '1320';
      await seedCompletedSale(
        db,
        userId: cashierId,
        posAccountId: posAccountId,
        amount: d(saleAmount),
      );
      await container(tester).read(shiftControllerProvider.notifier).refresh();
      await tester.pumpAndSettle(const Duration(seconds: 2));

      final stateAfterSale = container(tester).read(shiftControllerProvider);
      expect(stateAfterSale.isOpen, isTrue);
      expect(
        stateAfterSale.salesCount,
        greaterThan(0),
        reason: 'shift must count the completed sale',
      );
      expect(
        stateAfterSale.salesTotal,
        d(saleAmount),
        reason: 'shift sale total is exact (Decimal), no drift',
      );

      final zBtn = find.text('Печать Z-отчёта');
      expect(zBtn, findsOneWidget);
      await tester.tap(zBtn);
      await tester.pumpAndSettle(const Duration(seconds: 2));

      expect(capture.calls, 1, reason: 'Z-report print was triggered once');
      expect(
        capture.saleCount,
        greaterThan(0),
        reason: 'guard #19: Z-report sale count must be REAL, not zero',
      );
      expect(capture.saleTotal, isNotNull);
      expect(
        capture.saleTotal! > Decimal.zero,
        isTrue,
        reason: 'guard #19: Z-report sale total must be > 0',
      );
      expect(
        capture.saleTotal,
        d(saleAmount),
        reason: 'Z-report sale total equals the seeded sale, exact Decimal',
      );
      expect(capture.cashEnd, isNotNull, reason: 'cashEnd passed to Z-report');
      expect(
        capture.cashIncome,
        isNotNull,
        reason: 'cashIncome (cash payments) passed to Z-report',
      );
      expect(
        capture.cashIncome! >= d(saleAmount),
        isTrue,
        reason: 'cash income includes the cash sale payment',
      );
      expect(capture.refundCount, 0, reason: 'no refunds this shift');
      expect(capture.refundTotal, Decimal.zero);

      // «Принято» — не «напечатано». Снекбар обязан сказать, что бумаги ещё
      // нет: задание ждёт принтера тридцать минут, а смена закрывается, не
      // дожидаясь его (И30).
      expect(
        find.textContaining('принят в очередь печати'),
        findsOneWidget,
        reason:
            'SnackBar after the Z-report was accepted by the print queue — it '
            'must not claim paper came out',
      );
      await tester.pumpAndSettle(const Duration(seconds: 5));

      fakePrinter.zReportResult = false;
      await tester.tap(find.text('Печать Z-отчёта'));
      await tester.pumpAndSettle(const Duration(seconds: 2));
      expect(capture.calls, 2, reason: 'second Z-report print attempted');
      expect(
        find.text('Не удалось сдать Z-отчёт в печать'),
        findsOneWidget,
        reason: 'failure SnackBar when the queue refuses the job',
      );
      await tester.pumpAndSettle(const Duration(seconds: 5));

      final closeBtn = find.text('Закрыть смену');
      expect(closeBtn, findsWidgets);
      await tester.tap(closeBtn.first);
      await tester.pumpAndSettle();
      final confirmClose = find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(ElevatedButton),
      );
      expect(
        confirmClose,
        findsOneWidget,
        reason: 'close-shift confirm present',
      );
      await tester.tap(confirmClose);
      await tester.pumpAndSettle(const Duration(seconds: 2));

      expect(
        await openedShift(db),
        isNull,
        reason: 'closing the shift flips it to closed in the DB',
      );

      expect(
        find.text('Открыть смену'),
        findsWidgets,
        reason: 'closed shift offers the Open action again',
      );
    },
  );
}

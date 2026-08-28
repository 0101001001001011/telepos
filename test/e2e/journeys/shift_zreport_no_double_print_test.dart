library;

import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';

import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/domain/entities/shift/shift_receipt.dart';
import 'package:telepos/domain/services/receipt_print_service.dart';
import 'package:telepos/domain/usecases/shift/assemble_shift_receipt_use_case.dart';
import 'package:telepos/domain/print/print_queue.dart';
import 'package:telepos/presentation/controllers/shift/shift_controller.dart';

import '../support/harness.dart';

class _GatedPrintService implements ReceiptPrintService {
  int zCalls = 0;
  final Completer<void> gate = Completer<void>();

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
    zCalls++;
    await gate.future;
    return PrintSubmitOutcome.accepted('z-report');
  }

  @override
  Future<bool> isPrinterAvailable() async => true;
  @override
  Future<bool> openCashDrawer() async => true;
  @override
  dynamic noSuchMethod(Invocation invocation) => Future<bool>.value(true);
}

class _FakeAssemble implements AssembleShiftReceiptUseCase {
  @override
  Future<ShiftReceipt?> assemble(int shiftId, Decimal cashInPos) async {
    return ShiftReceipt(
      shiftId: shiftId,
      shiftUserName: 'Кассир',
      shiftOpenTime: 1_700_000_000,
      shiftCloseTime: 1_700_040_000,
      saleAmount: Decimal.parse('1000.00'),
      debtAmount: Decimal.zero,
      cashInPos: cashInPos,
      cashPaymentsSum: Decimal.parse('1000.00'),
      paymentSums: const [],
      companyName: 'ТОО Тест',
      posName: 'Касса №1',
    );
  }
}

void main() {
  final h = E2eHarness();
  late _GatedPrintService printer;
  late ProviderContainer container;

  setUp(() async {
    await h.setUp();
    GetIt.I.registerSingleton<AppDatabase>(h.db);
    printer = _GatedPrintService();
    GetIt.I.registerSingleton<ReceiptPrintService>(printer);
    GetIt.I.registerSingleton<AssembleShiftReceiptUseCase>(_FakeAssemble());

    final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    await h.db
        .into(h.db.shifts)
        .insert(
          ShiftsCompanion.insert(
            userId: 1,
            openTime: nowSec,
            isOpened: true,
            isSynced: false,
            openingCash: Value(Decimal.parse('5000.00')),
          ),
        );

    container = ProviderContainer();
    addTearDown(container.dispose);
  });
  tearDown(() => h.tearDown());

  Future<ShiftNotifier> settledNotifier() async {
    final n = container.read(shiftControllerProvider.notifier);
    for (var i = 0; i < 50; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
      if (!container.read(shiftControllerProvider).isLoading) break;
    }
    return n;
  }

  test(
    'two concurrent printZReport calls print only ONCE (re-entrancy guard)',
    () async {
      final notifier = await settledNotifier();
      expect(
        container.read(shiftControllerProvider).currentShift,
        isNotNull,
        reason: 'an open shift must be loaded for the Z-report path',
      );

      final first = notifier.printZReport();
      final second = notifier.printZReport();

      expect(
        await second,
        ZReportOutcome.alreadyQueued,
        reason:
            'second concurrent Z-report is a no-op success, not an error — and '
            'not "queued" either: nothing new was submitted by it',
      );

      printer.gate.complete();
      expect(
        await first,
        ZReportOutcome.queued,
        reason:
            'the in-flight Z-report is accepted by the queue; "queued" is what '
            'the cashier must be told, because there is no paper yet',
      );

      expect(printer.zCalls, 1, reason: 'Z-report printed exactly once');

      expect(
        container.read(shiftControllerProvider).zReportFailed,
        isFalse,
        reason: 'no false error surfaced after a successful print',
      );
    },
  );
}

library;

import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';

import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/presentation/controllers/reports/kz_reports_controller.dart';

import '../support/harness.dart';

void main() {
  final h = E2eHarness();
  late ProviderContainer container;

  final now = DateTime.now();
  final range = DateTimeRange(
    start: now.subtract(const Duration(days: 7)),
    end: now.add(const Duration(days: 1)),
  );
  final nowTs = now.millisecondsSinceEpoch ~/ 1000;

  late int cashAccId;
  late int cardAccId;

  setUpAll(() async {
    await h.setUp();
    GetIt.I.registerSingleton<AppDatabase>(h.db);
  });
  tearDownAll(() => h.tearDown());

  setUp(() async {
    final db = h.db;
    await db.delete(db.payments).go();
    await db.delete(db.saleProducts).go();
    await db.delete(db.sales).go();
    await db.delete(db.refunds).go();
    await db.delete(db.cashOperations).go();
    await db.delete(db.productPrices).go();
    await db.delete(db.productInfos).go();
    await db.delete(db.accounts).go();

    cashAccId = await db.accountDao.createPosAccount(name: 'Касса');
    cardAccId = await db.accountDao.createAcquiringAccount(
      name: 'Kaspi Bank',
      acquirerId: 1,
    );

    container = ProviderContainer();
    addTearDown(container.dispose);
  });

  Future<void> seedProductWithVat(int ucode, int vatRate) async {
    final db = h.db;
    await db
        .into(db.productInfos)
        .insert(
          ProductInfosCompanion(
            ucode: drift.Value(ucode),
            barcode: drift.Value(ucode),
            name: drift.Value('VAT-$ucode'),
            type: const drift.Value(0),
            measure: const drift.Value(0),
            vatRate: drift.Value(vatRate),
            isDeleted: const drift.Value(false),
          ),
        );
    await db
        .into(db.productPrices)
        .insert(
          ProductPricesCompanion(
            ucode: drift.Value(ucode),
            barcode: drift.Value(ucode),
            sellingPrice: const drift.Value(null),
            wholesalePrice: const drift.Value(null),
          ),
        );
  }

  Future<void> seedSale({
    required int receiptNo,
    required Decimal amount,
    required int payeeAccountId,
    int? ts,
    List<({int ucode, String qty, String price})> lines = const [],
  }) async {
    final db = h.db;
    final t = ts ?? nowTs;
    await db
        .into(db.sales)
        .insert(
          SalesCompanion.insert(
            receiptNo: receiptNo,
            posId: 1,
            userId: 1,
            amount: amount,
            time: t,
            state: const drift.Value(1),
          ),
        );
    for (final l in lines) {
      await db
          .into(db.saleProducts)
          .insert(
            SaleProductsCompanion.insert(
              ucode: l.ucode,
              quantity: d(l.qty),
              price: d(l.price),
              priceBefore: d(l.price),
              receiptNo: drift.Value(receiptNo),
              posId: const drift.Value(1),
            ),
          );
    }
    await db
        .into(db.payments)
        .insert(
          PaymentsCompanion.insert(
            userId: 1,
            payeeAccountId: payeeAccountId,
            amount: amount,
            time: t,
            receiptNo: drift.Value(receiptNo),
            posId: const drift.Value(1),
          ),
        );
  }

  Future<void> seedCashOp(int type, String amount, {int? ts}) async {
    final db = h.db;
    await db
        .into(db.cashOperations)
        .insert(
          CashOperationsCompanion(
            amount: drift.Value(d(amount)),
            accountId: drift.Value(cashAccId),
            type: drift.Value(type),
            userId: const drift.Value(1),
            docTime: drift.Value(ts ?? nowTs),
            state: const drift.Value(1),
          ),
        );
  }

  Future<void> seedRefund(String amount) async {
    final db = h.db;
    await db
        .into(db.refunds)
        .insert(
          RefundsCompanion.insert(
            userId: 1,
            amount: drift.Value(d(amount)),
            time: nowTs,
          ),
        );
  }

  test(
    'ф.910 income summary nets refunds and computes 3% tax, Decimal-exact',
    () async {
      await seedProductWithVat(5001, 0);
      await seedSale(
        receiptNo: 7001,
        amount: d('1200'),
        payeeAccountId: cashAccId,
        lines: [(ucode: 5001, qty: '1', price: '1200')],
      );
      await seedSale(
        receiptNo: 7002,
        amount: d('800.500'),
        payeeAccountId: cardAccId,
        lines: [(ucode: 5001, qty: '1', price: '800.500')],
      );
      await seedSale(
        receiptNo: 7003,
        amount: d('1999.500'),
        payeeAccountId: cashAccId,
        lines: [(ucode: 5001, qty: '1', price: '1999.500')],
      );
      await seedRefund('500');

      final report = await container.read(
        f910IncomeReportProvider(range).future,
      );

      expect(report.saleCount, 3);
      expect(
        report.salesIncome,
        d('4000'),
        reason: '1200 + 800.500 + 1999.500 = 4000, Decimal-exact',
      );
      expect(report.refundCount, 1);
      expect(report.refundTotal, d('500'));
      expect(
        report.taxableIncome,
        d('3500'),
        reason: 'облагаемый доход = 4000 − 500 = 3500',
      );
      expect(report.taxRatePercent, 3);
      expect(
        report.estimatedTax,
        d('105'),
        reason: 'налог 3% от 3500 = 105, Decimal-exact',
      );
    },
  );

  test(
    'ф.910 taxable income never goes negative when refunds exceed sales',
    () async {
      await seedProductWithVat(5010, 0);
      await seedSale(
        receiptNo: 7100,
        amount: d('1000'),
        payeeAccountId: cashAccId,
        lines: [(ucode: 5010, qty: '1', price: '1000')],
      );
      await seedRefund('1500');

      final report = await container.read(
        f910IncomeReportProvider(range).future,
      );

      expect(
        report.taxableIncome,
        Decimal.zero,
        reason: 'taxable base is floored at zero',
      );
      expect(report.estimatedTax, Decimal.zero);
    },
  );

  test(
    'ф.300 VAT summary derives output VAT per rate + turnover split',
    () async {
      await seedProductWithVat(5101, 12);
      await seedProductWithVat(5102, 0);

      await seedSale(
        receiptNo: 7201,
        amount: d('1120'),
        payeeAccountId: cashAccId,
        lines: [(ucode: 5101, qty: '1', price: '1120')],
      );
      await seedSale(
        receiptNo: 7202,
        amount: d('3000'),
        payeeAccountId: cardAccId,
        lines: [(ucode: 5102, qty: '3', price: '1000')],
      );

      final report = await container.read(f300VatReportProvider(range).future);

      expect(
        report.outputVat,
        d('120'),
        reason: 'начисленный НДС = 120, Decimal-exact',
      );
      expect(
        report.taxableTurnover,
        d('1000'),
        reason: 'облагаемый оборот без НДС = 1000',
      );
      expect(
        report.zeroRatedTurnover,
        d('3000'),
        reason: 'нулевой оборот = 3000',
      );
      expect(
        report.totalTurnoverGross,
        d('4120'),
        reason: 'всего оборот по реализации (с НДС) = 1120 + 3000',
      );

      final line12 = report.taxableBuckets.firstWhere(
        (b) => b.ratePercent == 12,
      );
      expect(line12.vat, d('120'));
      expect(line12.net, d('1000'));
    },
  );

  test(
    'cash book records only CASH movements with an exact running balance',
    () async {
      await seedProductWithVat(5201, 0);

      await seedCashOp(0, '2000', ts: nowTs);
      await seedSale(
        receiptNo: 7301,
        amount: d('1500'),
        payeeAccountId: cashAccId,
        ts: nowTs + 1,
        lines: [(ucode: 5201, qty: '1', price: '1500')],
      );
      await seedSale(
        receiptNo: 7302,
        amount: d('9999'),
        payeeAccountId: cardAccId,
        ts: nowTs + 2,
        lines: [(ucode: 5201, qty: '1', price: '9999')],
      );
      await seedCashOp(1, '300', ts: nowTs + 3);
      await seedCashOp(2, '1000', ts: nowTs + 4);

      final report = await container.read(cashBookReportProvider(range).future);

      expect(report.count, 4, reason: 'card payment is not a cash movement');
      expect(
        report.entries.any((e) => e.income == d('9999')),
        isFalse,
        reason: 'the 9999 card sale must never appear in the cash book',
      );

      expect(report.totalIncome, d('3500'));
      expect(report.totalExpense, d('1300'));
      expect(
        report.closingBalance,
        d('2200'),
        reason: 'opening 0 + 3500 − 1300 = 2200, Decimal-exact',
      );

      expect(report.entries[0].kind, 1, reason: 'first = внесение');
      expect(report.entries[0].balanceAfter, d('2000'));
      expect(report.entries[1].kind, 0, reason: 'then the cash продажа');
      expect(
        report.entries[1].balanceAfter,
        d('3500'),
        reason: '2000 + 1500 = 3500',
      );
      expect(report.entries[2].kind, 2, reason: 'then расход');
      expect(
        report.entries[2].balanceAfter,
        d('3200'),
        reason: '3500 − 300 = 3200',
      );
      expect(report.entries[3].kind, 3, reason: 'then изъятие');
      expect(
        report.entries[3].balanceAfter,
        d('2200'),
        reason: '3200 − 1000 = 2200',
      );
    },
  );

  test(
    'cash book is empty when there are no cash movements in the period',
    () async {
      await seedProductWithVat(5301, 0);
      await seedSale(
        receiptNo: 7400,
        amount: d('5000'),
        payeeAccountId: cardAccId,
        lines: [(ucode: 5301, qty: '1', price: '5000')],
      );

      final report = await container.read(cashBookReportProvider(range).future);

      expect(report.count, 0);
      expect(report.totalIncome, Decimal.zero);
      expect(report.totalExpense, Decimal.zero);
      expect(report.closingBalance, Decimal.zero);
    },
  );
}

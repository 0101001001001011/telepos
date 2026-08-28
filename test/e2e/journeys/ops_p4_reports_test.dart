library;

import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';

import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/database/daos/account_dao.dart';
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
    await db.delete(db.writeoffProducts).go();
    await db.delete(db.writeoffs).go();
    await db.delete(db.cashOperations).go();
    await db.delete(db.productPrices).go();
    await db.delete(db.productInfos).go();
    await db.delete(db.agents).go();
    container = ProviderContainer();
    addTearDown(container.dispose);
  });

  Future<void> seedSale({
    required int receiptNo,
    required Decimal amount,
    required List<({int ucode, String qty, String price})> lines,
  }) async {
    final db = h.db;
    await db
        .into(db.sales)
        .insert(
          SalesCompanion.insert(
            receiptNo: receiptNo,
            posId: 1,
            userId: 1,
            amount: amount,
            time: nowTs,
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
  }

  Future<void> seedProductWithVat(int ucode, int vatRate, String cost) async {
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
            sellingPrice: drift.Value(d(cost)),
            wholesalePrice: drift.Value(d(cost)),
          ),
        );
  }

  test(
    'НДС report extracts Decimal-exact VAT per rate from gross sale lines',
    () async {
      await seedProductWithVat(3001, 12, '0');
      await seedProductWithVat(3002, 0, '0');

      await seedSale(
        receiptNo: 9001,
        amount: d('1120'),
        lines: [(ucode: 3001, qty: '1', price: '1120')],
      );
      await seedSale(
        receiptNo: 9002,
        amount: d('1000'),
        lines: [(ucode: 3002, qty: '2', price: '500')],
      );

      final report = await container.read(vatReportProvider(range).future);

      final vat12 = report.buckets.firstWhere((b) => b.ratePercent == 12);
      expect(vat12.gross, d('1120'));
      expect(
        vat12.vat,
        d('120'),
        reason: 'VAT extracted from gross = 1120*12/112 = 120, Decimal-exact',
      );
      expect(vat12.net, d('1000'));

      final vat0 = report.buckets.firstWhere((b) => b.ratePercent == 0);
      expect(vat0.gross, d('1000'));
      expect(vat0.vat, Decimal.zero, reason: '0% rate extracts no VAT');

      expect(report.totalVat, d('120'), reason: 'period VAT total is exact');
      expect(report.totalGross, d('2120'));
      expect(report.totalNet, d('2000'));
    },
  );

  test(
    'AR/AP report splits counterparty balances into дебиторка / кредиторка',
    () async {
      final db = h.db;

      Future<int> agentWithBalance(String name, int type, String bal) async {
        final accId = await db.accountDao.insertAccount(
          AccountsCompanion(
            id: drift.Value(await db.accountDao.getNextId()),
            type: const drift.Value(AccountType.agentMain),
            name: drift.Value('Счёт $name'),
            value: drift.Value(d(bal)),
            updateTime: drift.Value(nowTs),
          ),
        );
        return db
            .into(db.agents)
            .insert(
              AgentsCompanion(
                type: drift.Value(type),
                name: drift.Value(name),
                mainAccountId: drift.Value(accId),
                isDeleted: const drift.Value(false),
                editTime: drift.Value(nowTs),
              ),
            );
      }

      await agentWithBalance('Клиент Долг', 1, '1500');
      await agentWithBalance('Поставщик Кредит', 0, '-2300');
      await agentWithBalance('Нулевой', 1, '0');

      final report = await container.read(arApReportProvider.future);

      expect(report.receivables.length, 1);
      expect(report.payables.length, 1);
      expect(
        report.balances.any((b) => b.name == 'Нулевой'),
        isFalse,
        reason: 'zero-balance agents are excluded',
      );

      expect(
        report.totalReceivable,
        d('1500'),
        reason: 'дебиторка = sum of positive balances',
      );
      expect(
        report.totalPayable,
        d('2300'),
        reason: 'кредиторка = abs sum of negative balances',
      );
      expect(
        report.netSaldo,
        d('-800'),
        reason: 'net сальдо = 1500 - 2300 = -800, Decimal-exact',
      );
    },
  );

  test(
    'инкассация report lists cash-collection ops and totals them exactly',
    () async {
      final db = h.db;
      for (final amt in ['10000', '5500.500']) {
        await db
            .into(db.cashOperations)
            .insert(
              CashOperationsCompanion(
                amount: drift.Value(d(amt)),
                type: const drift.Value(2),
                userId: const drift.Value(1),
                note: const drift.Value('Инкассация'),
                docTime: drift.Value(nowTs),
                state: const drift.Value(1),
              ),
            );
      }
      await db
          .into(db.cashOperations)
          .insert(
            CashOperationsCompanion(
              amount: drift.Value(d('99999')),
              type: const drift.Value(0),
              userId: const drift.Value(1),
              docTime: drift.Value(nowTs),
            ),
          );

      final report = await container.read(
        cashCollectionReportProvider(range).future,
      );

      expect(report.count, 2, reason: 'only type=2 collection ops are listed');
      expect(
        report.total,
        d('15500.500'),
        reason: '10000 + 5500.500 = 15500.500, Decimal-exact (no double drift)',
      );
    },
  );

  test(
    'profit report uses real COGS (wholesale) for Decimal-exact margin',
    () async {
      await seedProductWithVat(3100, 0, '600');
      await seedSale(
        receiptNo: 9100,
        amount: d('3000'),
        lines: [(ucode: 3100, qty: '3', price: '1000')],
      );

      final report = await container.read(
        profitCogsReportProvider(range).future,
      );

      final item = report.items.firstWhere((i) => i.ucode == 3100);
      expect(item.revenue, d('3000'));
      expect(item.cogs, d('1800'), reason: 'COGS = 3 * 600 = 1800');
      expect(item.profit, d('1200'), reason: 'profit = 3000 - 1800 = 1200');
      expect(item.marginPct, d('40'), reason: 'margin = 1200/3000*100 = 40%');

      expect(report.totalProfit, d('1200'));
      expect(report.totalMarginPct, d('40'));
      expect(
        report.usesRealCogs,
        isFalse,
        reason: 'no CalculateCogsUseCase wired → wholesale fallback is flagged',
      );
    },
  );

  test('write-off report aggregates Decimal totals by reason', () async {
    final db = h.db;
    await db.writeoffDao.insertWriteoff(
      WriteoffsCompanion(
        reason: const drift.Value(0),
        amount: drift.Value(d('320.250')),
        docTime: drift.Value(nowTs),
        state: const drift.Value(1),
      ),
    );
    await db.writeoffDao.insertWriteoff(
      WriteoffsCompanion(
        reason: const drift.Value(0),
        amount: drift.Value(d('179.750')),
        docTime: drift.Value(nowTs),
        state: const drift.Value(1),
      ),
    );
    await db.writeoffDao.insertWriteoff(
      WriteoffsCompanion(
        reason: const drift.Value(1),
        amount: drift.Value(d('1000')),
        docTime: drift.Value(nowTs),
        state: const drift.Value(1),
      ),
    );

    final report = await container.read(writeoffReportProvider(range).future);

    final boy = report.buckets.firstWhere((b) => b.reason == 0);
    expect(boy.docCount, 2);
    expect(
      boy.total,
      d('500'),
      reason: '320.250 + 179.750 = 500, Decimal-exact',
    );
    expect(boy.reasonLabel, 'Бой');

    final prosrochka = report.buckets.firstWhere((b) => b.reason == 1);
    expect(prosrochka.total, d('1000'));

    expect(report.docCount, 3);
    expect(report.total, d('1500'), reason: 'grand total 500 + 1000 = 1500');
  });
}

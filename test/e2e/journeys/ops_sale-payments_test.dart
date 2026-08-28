library;

import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart' as drift;
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';

import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/domain/usecases/sale/sale_initiation_use_case.dart';
import 'package:telepos/domain/usecases/sale/sale_use_case.dart';

import '../support/harness.dart';

void main() {
  final h = E2eHarness();
  late SaleInitiationUseCase initiation;
  late SaleUseCase saleUseCase;
  late int posAccId;
  late int bankAccId;

  setUpAll(() async {
    await h.setUp();
    GetIt.I.registerSingleton<AppDatabase>(h.db);
    initiation = GetIt.I<SaleInitiationUseCase>();
    saleUseCase = GetIt.I<SaleUseCase>();
    final pos = await (h.db.select(
      h.db.accounts,
    )..where((a) => a.type.equals(0))).get();
    final bank = await (h.db.select(
      h.db.accounts,
    )..where((a) => a.type.equals(1))).get();
    posAccId = pos.first.id;
    bankAccId = bank.first.id;
  });
  tearDownAll(() => h.tearDown());

  Future<({int receiptNo, int posId})> sell({
    required int ucode,
    required Decimal qty,
    required Decimal price,
    required List<PaymentEntry> Function(Decimal total) payments,
    Decimal? change,
  }) async {
    final sale = await initiation.initiate(userId: 1) as Sale?;
    expect(sale, isNotNull, reason: 'initiate() must create a sale');
    final receiptNo = sale!.receiptNo;
    final posId = sale.posId;
    await h.db
        .into(h.db.saleProducts)
        .insert(
          SaleProductsCompanion.insert(
            receiptNo: drift.Value(receiptNo),
            posId: drift.Value(posId),
            ucode: ucode,
            quantity: qty,
            price: price,
            priceBefore: price,
          ),
        );
    final total = price * qty;
    await saleUseCase.perform(
      receiptNo: receiptNo,
      posId: posId,
      amount: total,
      payments: payments(total),
      change: change ?? Decimal.zero,
      selectiveOfd: false,
    );
    return (receiptNo: receiptNo, posId: posId);
  }

  Future<List<Payment>> paymentsOf(int receiptNo, int posId) => (h.db.select(
    h.db.payments,
  )..where((p) => p.receiptNo.equals(receiptNo) & p.posId.equals(posId))).get();

  test('cash sale finalizes and records a POS-account payment', () async {
    final r = await sell(
      ucode: 1001,
      qty: d('2'),
      price: d('450'),
      payments: (total) => [
        PaymentEntry(payeeAccountId: posAccId, amount: total),
      ],
    );
    final pays = await paymentsOf(r.receiptNo, r.posId);
    expect(pays, hasLength(1));
    expect(pays.single.payeeAccountId, posAccId);
    expect(pays.single.amount, d('900'));
  });

  test('card sale finalizes and records a bank-account payment', () async {
    final r = await sell(
      ucode: 1002,
      qty: d('3'),
      price: d('150'),
      payments: (total) => [
        PaymentEntry(payeeAccountId: bankAccId, amount: total),
      ],
    );
    final pays = await paymentsOf(r.receiptNo, r.posId);
    expect(pays, hasLength(1));
    expect(pays.single.payeeAccountId, bankAccId);
    expect(pays.single.amount, d('450'));
  });

  test('mixed cash+card sale records both payments summing to total', () async {
    final r = await sell(
      ucode: 1004,
      qty: d('1'),
      price: d('890'),
      payments: (total) => [
        PaymentEntry(payeeAccountId: posAccId, amount: d('400')),
        PaymentEntry(payeeAccountId: bankAccId, amount: total - d('400')),
      ],
    );
    final pays = await paymentsOf(r.receiptNo, r.posId);
    expect(pays, hasLength(2));
    final sum = pays.fold<Decimal>(Decimal.zero, (s, p) => s + p.amount);
    expect(sum, d('890'));
  });

  test(
    'reference (isDeleted, zero-stock) product still sells with oversell off',
    () async {
      const refUcode = 900001;
      await h.db
          .into(h.db.productInfos)
          .insert(
            ProductInfosCompanion(
              ucode: const drift.Value(refUcode),
              barcode: const drift.Value(4690999001),
              name: const drift.Value('Справочный товар'),
              type: const drift.Value(0),
              measure: const drift.Value(0),
              quantity: drift.Value(d('0')),
              isDeleted: const drift.Value(true),
            ),
          );
      await h.db
          .into(h.db.productPrices)
          .insert(
            ProductPricesCompanion(
              ucode: const drift.Value(refUcode),
              barcode: const drift.Value(4690999001),
              sellingPrice: drift.Value(d('1000')),
              wholesalePrice: drift.Value(d('600')),
            ),
          );
      final r = await sell(
        ucode: refUcode,
        qty: d('1'),
        price: d('1000'),
        payments: (total) => [
          PaymentEntry(payeeAccountId: posAccId, amount: total),
        ],
      );
      final pays = await paymentsOf(r.receiptNo, r.posId);
      expect(pays, hasLength(1));
      final info = await h.db.productInfoDao.findByUcode(refUcode);
      expect(info!.quantity, d('-1'));
    },
  );
}

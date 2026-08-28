library;

import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart' as drift;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';

import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/database/daos/account_dao.dart';
import 'package:telepos/domain/usecases/sale/sale_use_case.dart';
import 'package:telepos/presentation/controllers/sale/sale_controller.dart';

import '../support/harness.dart';

void main() {
  final h = E2eHarness();
  late ProviderContainer container;

  setUpAll(() async {
    await h.setUp();
    GetIt.I.registerSingleton<AppDatabase>(h.db);
  });
  tearDownAll(() => h.tearDown());

  setUp(() async {
    await h.db.delete(h.db.saleProductMarks).go();
    await h.db.delete(h.db.payments).go();
    await h.db.delete(h.db.saleProducts).go();
    await h.db.delete(h.db.sales).go();
    await h.db.delete(h.db.shifts).go();
    container = ProviderContainer();
    addTearDown(container.dispose);
  });

  Future<void> waitForSaleInit(SaleNotifier sale) async {
    for (var i = 0; i < 50; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
      if (container.read(saleControllerProvider).receiptNo != null) return;
    }
  }

  Future<int> seedMarkableProduct({
    required int ucode,
    required int barcode,
    required String name,
    required String price,
  }) async {
    final db = GetIt.I<AppDatabase>();
    await db
        .into(db.productInfos)
        .insert(
          ProductInfosCompanion(
            ucode: drift.Value(ucode),
            barcode: drift.Value(barcode),
            name: drift.Value(name),
            type: const drift.Value(0),
            measure: const drift.Value(0),
            quantity: drift.Value(d('100')),
            categoryId: const drift.Value(1),
            isDeleted: const drift.Value(false),
            isMarkable: const drift.Value(true),
          ),
        );
    await db
        .into(db.productPrices)
        .insert(
          ProductPricesCompanion(
            ucode: drift.Value(ucode),
            barcode: drift.Value(barcode),
            sellingPrice: drift.Value(d(price)),
            wholesalePrice: drift.Value(d(price)),
          ),
        );
    return ucode;
  }

  test(
    'scanned DataMatrix mark is persisted to sale_product and retrievable via '
    'findMarksBySaleProduct (reaches the ОФД receipt)',
    () async {
      final db = GetIt.I<AppDatabase>();

      const ucode = 5001;
      const dataMatrix = '0104607001234567215abcd910093dGVz';
      await seedMarkableProduct(
        ucode: ucode,
        barcode: 4609101,
        name: 'Сигареты Marlboro',
        price: '1200',
      );

      final probe = await db.productInfoDao.findByUcode(ucode);
      expect(
        probe?.isMarkable,
        isTrue,
        reason: 'seed must persist isMarkable=true (gate depends on it)',
      );

      final posAccId = (await db.accountDao.findByType(
        AccountType.pos,
      )).first.id;

      final sale = container.read(saleControllerProvider.notifier);
      await waitForSaleInit(sale);
      expect(
        container.read(saleControllerProvider).receiptNo,
        isNotNull,
        reason: 'sale must initialize before payment',
      );

      sale.addProduct(
        ProductSearchResult(
          id: ucode,
          name: 'Сигареты Marlboro',
          price: d('1200'),
        ),
      );

      sale.setMark(dataMatrix);
      final scannedItem = container
          .read(saleControllerProvider)
          .items
          .firstWhere((i) => i.productId == ucode);
      expect(
        scannedItem.mark,
        dataMatrix,
        reason: 'setMark records the code on the selected line (UI state)',
      );

      final total = container.read(saleControllerProvider).total;
      expect(total, d('1200'), reason: 'sale total must be exactly 1200');

      final ok = await sale.completeSale(
        payments: [PaymentEntry(payeeAccountId: posAccId, amount: total)],
        change: Decimal.zero,
      );
      expect(
        ok,
        isTrue,
        reason: 'a markable product WITH a scanned mark must complete',
      );
      expect(container.read(saleControllerProvider).error, isNull);

      final saleState = container.read(saleControllerProvider);
      final lines = await db.saleProductDao.findBySale(
        saleState.receiptNo!,
        saleState.posId!,
      );
      expect(lines.length, 1, reason: 'exactly one sale line persisted');
      final saleProductId = lines.first.id;

      final marks = await db.saleProductDao.findMarksBySaleProduct(
        saleProductId,
      );
      expect(
        marks.length,
        1,
        reason: 'the scanned DataMatrix must be persisted to sale_product',
      );
      expect(
        marks.first.mark,
        dataMatrix,
        reason: 'the persisted mark equals the scanned DataMatrix verbatim',
      );
      expect(
        marks.first.saleProductId,
        saleProductId,
        reason: 'mark is linked to the sale line the fiscal service reads',
      );
    },
  );

  test(
    'a markable product WITHOUT a scanned mark cannot be paid (honest error, '
    'no half-committed sale)',
    () async {
      final db = GetIt.I<AppDatabase>();

      const ucode = 5002;
      await seedMarkableProduct(
        ucode: ucode,
        barcode: 4609102,
        name: 'Парфюм Chanel',
        price: '9000',
      );

      final posAccId = (await db.accountDao.findByType(
        AccountType.pos,
      )).first.id;

      final sale = container.read(saleControllerProvider.notifier);
      await waitForSaleInit(sale);
      final receiptNo = container.read(saleControllerProvider).receiptNo;
      final posId = container.read(saleControllerProvider).posId;
      expect(receiptNo, isNotNull);

      sale.addProduct(
        ProductSearchResult(id: ucode, name: 'Парфюм Chanel', price: d('9000')),
      );

      final total = container.read(saleControllerProvider).total;
      expect(total, d('9000'));

      final ok = await sale.completeSale(
        payments: [PaymentEntry(payeeAccountId: posAccId, amount: total)],
        change: Decimal.zero,
      );
      expect(
        ok,
        isFalse,
        reason: 'a markable product without a mark must NOT be payable',
      );

      final err = container.read(saleControllerProvider).error;
      expect(err, isNotNull, reason: 'an honest error must be surfaced');
      expect(
        err,
        contains('error.mark_required'),
        reason: 'the error names the missing-mark gate',
      );
      expect(
        err,
        contains('Парфюм Chanel'),
        reason: 'the error names the offending product',
      );

      final lines = await db.saleProductDao.findBySale(receiptNo!, posId!);
      expect(
        lines,
        isEmpty,
        reason: 'the gate runs BEFORE any DB write — no sale lines persisted',
      );
      final allMarks = await db.select(db.saleProductMarks).get();
      expect(
        allMarks,
        isEmpty,
        reason: 'no mark rows written for a blocked sale',
      );
    },
  );
}

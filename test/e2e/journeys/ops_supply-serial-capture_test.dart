library;

import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart' as drift;
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';

import 'package:telepos/domain/payment/payment_kind.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/mappers/supply_mapper.dart';
import 'package:telepos/domain/usecases/sale/sale_use_case.dart';
import 'package:telepos/domain/usecases/supply/save_supply_use_case.dart';
import 'package:telepos/domain/usecases/wms/wms_config_use_case.dart';

import '../support/harness.dart';

void main() {
  final h = E2eHarness();

  setUpAll(() async {
    await h.setUp();
    GetIt.I.registerSingleton<AppDatabase>(h.db);
  });
  tearDownAll(() => h.tearDown());

  Decimal d(String v) => Decimal.parse(v);

  Future<int> seedSupplier(AppDatabase db) async {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    return db
        .into(db.agents)
        .insert(
          AgentsCompanion(
            type: const drift.Value(0),
            name: const drift.Value('Серийный поставщик'),
            isDeleted: const drift.Value(false),
            editTime: drift.Value(now),
          ),
        );
  }

  Future<void> seedProduct(
    AppDatabase db, {
    required int ucode,
    required int barcode,
    required String price,
  }) async {
    await db
        .into(db.productInfos)
        .insert(
          ProductInfosCompanion(
            ucode: drift.Value(ucode),
            barcode: drift.Value(barcode),
            name: drift.Value('Серийный товар $ucode'),
            type: const drift.Value(0),
            measure: const drift.Value(0),
            quantity: drift.Value(d('0')),
            categoryId: const drift.Value(1),
            isDeleted: const drift.Value(false),
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
  }

  Future<int> receiveLineWithSerials(
    AppDatabase db, {
    required int supplierId,
    required int ucode,
    required Decimal qty,
    required Decimal price,
    List<String>? serials,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final supplyId = await db.supplyDao.insertSupply(
      SuppliesCompanion(
        supplierId: drift.Value(supplierId),
        paymentType: const drift.Value(1),
        editTime: drift.Value(now),
        state: const drift.Value(1),
      ),
    );
    await db.supplyProductDao.insertProduct(
      SupplyProductsCompanion(
        supplyId: drift.Value(supplyId),
        ucode: drift.Value(ucode),
        quantity: drift.Value(qty),
        price: drift.Value(price),
        amount: drift.Value(qty * price),
        serialNumbers: drift.Value(
          SupplyProductMapper.encodeSerialNumbers(serials),
        ),
      ),
    );

    final res = await GetIt.I<SaveSupplyUseCase>().execute(supplyId);
    expect(res.success, isTrue, reason: res.errorMessage);
    return supplyId;
  }

  Future<int> sell(
    AppDatabase db, {
    required int ucode,
    required Decimal qty,
    required String unitPrice,
    required int receiptNo,
  }) async {
    final posId = (await db.thisPosDao.get())!.id!;
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final amount = qty * d(unitPrice);
    await db
        .into(db.sales)
        .insert(
          SalesCompanion.insert(
            receiptNo: receiptNo,
            posId: posId,
            userId: 0,
            amount: amount,
            time: now,
          ),
        );
    await db
        .into(db.saleProducts)
        .insert(
          SaleProductsCompanion.insert(
            receiptNo: drift.Value(receiptNo),
            posId: drift.Value(posId),
            ucode: ucode,
            quantity: qty,
            price: d(unitPrice),
            priceBefore: d(unitPrice),
          ),
        );
    final posAcc = (await db.accountDao.findByType(0)).first;
    await GetIt.I<SaleUseCase>().perform(
      receiptNo: receiptNo,
      posId: posId,
      amount: amount,
      // Строки чека этот журнал кладёт в базу сам, с уже готовыми ценами:
      // переписывать `perform` нечего. Пустой список — не заглушка, а
      // утверждение «формат уже верен» (задача 9).
      lines: const [],
      payments: [PaymentEntry(kindId: SystemPaymentKindIds.cash, payeeAccountId: posAcc.id, amount: amount)],
      change: Decimal.zero,
      selectiveOfd: false,
    );
    return receiptNo;
  }

  test(
    'serialTracking ON: receive qty 3 with 3 serials -> 3 Serials in_stock; '
    'sell 2 -> exactly 2 sold, 1 remains (closes receipt->sale loop)',
    () async {
      final db = GetIt.I<AppDatabase>();

      final cfgUc = GetIt.I<WmsConfigUseCase>();
      await cfgUc.saveConfig(
        (await cfgUc.getConfig()).copyWith(enableSerials: true),
      );
      expect(await cfgUc.isModuleEnabled('serialTracking'), isTrue);

      const ucode = 5501;
      final supplierId = await seedSupplier(db);
      await seedProduct(db, ucode: ucode, barcode: 4690501, price: '1000');

      await receiveLineWithSerials(
        db,
        supplierId: supplierId,
        ucode: ucode,
        qty: d('3'),
        price: d('600'),
        serials: const ['SN-A', 'SN-B', 'SN-C'],
      );

      final inStock0 = (await db.serialDao.findByStatus(
        0,
      )).where((s) => s.ucode == ucode).toList();
      expect(
        inStock0.length,
        3,
        reason: 'receipt must register one Serial per captured number',
      );
      expect(
        inStock0.map((s) => s.serialNumber).toSet(),
        {'SN-A', 'SN-B', 'SN-C'},
        reason: 'the exact captured serial strings must be registered',
      );

      const receiptNo = 880001;
      await sell(
        db,
        ucode: ucode,
        qty: d('2'),
        unitPrice: '1000',
        receiptNo: receiptNo,
      );

      final sold = (await db.serialDao.findByStatus(
        1,
      )).where((s) => s.ucode == ucode).toList();
      expect(sold.length, 2, reason: 'exactly 2 serials must be marked sold');
      expect(
        sold.every((s) => s.saleId == receiptNo),
        isTrue,
        reason: 'sold serials must carry the saleId (receiptNo)',
      );

      final remaining = (await db.serialDao.findByStatus(
        0,
      )).where((s) => s.ucode == ucode).toList();
      expect(remaining.length, 1, reason: '1 serial must remain in stock');
    },
  );

  test('serialTracking OFF: a plain receipt registers NO serials (non-serial '
      'path unchanged)', () async {
    final db = GetIt.I<AppDatabase>();

    final cfgUc = GetIt.I<WmsConfigUseCase>();
    await cfgUc.saveConfig(
      (await cfgUc.getConfig()).copyWith(enableSerials: false),
    );
    expect(await cfgUc.isModuleEnabled('serialTracking'), isFalse);

    const ucode = 5502;
    final supplierId = await seedSupplier(db);
    await seedProduct(db, ucode: ucode, barcode: 4690502, price: '500');

    final before = (await db.serialDao.findByStatus(
      0,
    )).where((s) => s.ucode == ucode).length;

    await receiveLineWithSerials(
      db,
      supplierId: supplierId,
      ucode: ucode,
      qty: d('4'),
      price: d('300'),
      serials: null,
    );

    final after = (await db.serialDao.findByStatus(
      0,
    )).where((s) => s.ucode == ucode).length;
    expect(
      after,
      before,
      reason: 'serialTracking OFF must not create any Serials',
    );

    final info = await db.productInfoDao.findByUcode(ucode);
    expect(
      info!.quantity,
      d('4'),
      reason: 'non-serial receipt still updates global stock',
    );
  });
}

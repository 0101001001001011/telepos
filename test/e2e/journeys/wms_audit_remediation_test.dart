library;

import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart' as drift;
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';

import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/domain/usecases/sale/sale_use_case.dart';
import 'package:telepos/domain/usecases/wms/manage_warehouse_use_case.dart';
import 'package:telepos/domain/usecases/wms/serial_tracking_use_case.dart';
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

  group('reserveStock', () {
    test('accumulates instead of clobbering, and clamps at quantity '
        '(available = quantity - reservedQty)', () async {
      final db = GetIt.I<AppDatabase>();

      final id = await db.cellStockDao.upsertStock(
        CellStocksCompanion(
          cellId: const drift.Value(9001),
          ucode: const drift.Value(3101),
          quantity: drift.Value(d('10')),
          reservedQty: drift.Value(Decimal.zero),
          updatedAt: const drift.Value(0),
        ),
      );

      await db.cellStockDao.reserveStock(id, d('2'));
      await db.cellStockDao.reserveStock(id, d('3'));

      var row = await (db.select(
        db.cellStocks,
      )..where((s) => s.id.equals(id))).getSingle();
      expect(
        row.reservedQty,
        d('5'),
        reason: 'reserveStock must accumulate (2 + 3 = 5), not overwrite',
      );

      await db.cellStockDao.reserveStock(id, d('100'));
      row = await (db.select(
        db.cellStocks,
      )..where((s) => s.id.equals(id))).getSingle();
      expect(
        row.reservedQty,
        d('10'),
        reason: 'reservedQty must clamp at quantity so available >= 0',
      );
    });
  });

  group('cascade delete', () {
    test('deleteWarehouse removes its zones, cells and cell stocks '
        '(no orphan CellStocks)', () async {
      final db = GetIt.I<AppDatabase>();
      final whUc = GetIt.I<ManageWarehouseUseCase>();

      final whId = await db.warehouseDao.insertWarehouse(
        WarehousesCompanion.insert(code: 'CASC1', name: 'Каскад склад'),
      );
      final zoneId = await db.warehouseZoneDao.insertZone(
        WarehouseZonesCompanion.insert(
          warehouseId: whId,
          code: 'Z1',
          name: 'Зона 1',
          type: 0,
        ),
      );
      final cellId = await db.warehouseCellDao.insertCell(
        WarehouseCellsCompanion.insert(zoneId: zoneId, address: 'CASC1-Z1-C1'),
      );
      await db.cellStockDao.upsertStock(
        CellStocksCompanion(
          cellId: drift.Value(cellId),
          ucode: const drift.Value(3201),
          quantity: drift.Value(Decimal.zero),
          reservedQty: drift.Value(Decimal.zero),
          updatedAt: const drift.Value(0),
        ),
      );

      final res = await whUc.deleteWarehouse(whId);
      expect(res.success, isTrue, reason: 'warehouse delete must succeed');

      expect(await db.warehouseDao.findById(whId), isNull);
      expect(
        await db.warehouseZoneDao.findById(zoneId),
        isNull,
        reason: 'child zone must be cascaded',
      );
      expect(
        await db.warehouseCellDao.findById(cellId),
        isNull,
        reason: 'child cell must be cascaded',
      );
      final orphanStocks = await db.cellStockDao.findByCellId(cellId);
      expect(
        orphanStocks,
        isEmpty,
        reason: 'cell stocks must be cascaded (no phantom stock)',
      );
    });

    test('deleting a cell with non-zero stock is rejected', () async {
      final db = GetIt.I<AppDatabase>();

      final whId = await db.warehouseDao.insertWarehouse(
        WarehousesCompanion.insert(code: 'CASC2', name: 'Каскад 2'),
      );
      final zoneId = await db.warehouseZoneDao.insertZone(
        WarehouseZonesCompanion.insert(
          warehouseId: whId,
          code: 'Z2',
          name: 'Зона 2',
          type: 0,
        ),
      );
      final cellId = await db.warehouseCellDao.insertCell(
        WarehouseCellsCompanion.insert(zoneId: zoneId, address: 'CASC2-Z2-C2'),
      );
      await db.cellStockDao.upsertStock(
        CellStocksCompanion(
          cellId: drift.Value(cellId),
          ucode: const drift.Value(3202),
          quantity: drift.Value(d('7')),
          reservedQty: drift.Value(Decimal.zero),
          updatedAt: const drift.Value(0),
        ),
      );

      final res = await GetIt.I<ManageWarehouseUseCase>().deleteWarehouse(whId);
      expect(
        res.success,
        isFalse,
        reason: 'warehouse holding non-zero stock must not be deleted',
      );
      expect(await db.warehouseCellDao.findById(cellId), isNotNull);
      expect(await db.cellStockDao.findByCellId(cellId), isNotEmpty);
    });
  });

  group('serials consumed on sale', () {
    test('selling 3 of a serialized ucode flips exactly 3 serials to sold; '
        'selling with 0 registered serials does not block the sale', () async {
      final db = GetIt.I<AppDatabase>();

      final cfgUc = GetIt.I<WmsConfigUseCase>();
      final cfg = await cfgUc.getConfig();
      await cfgUc.saveConfig(cfg.copyWith(enableSerials: true));

      final serialUc = GetIt.I<SerialTrackingUseCase>();

      const ucode = 3301;
      await db
          .into(db.productInfos)
          .insert(
            ProductInfosCompanion(
              ucode: const drift.Value(ucode),
              barcode: const drift.Value(4607301),
              name: const drift.Value('Серийный товар'),
              type: const drift.Value(0),
              measure: const drift.Value(0),
              quantity: drift.Value(d('100')),
              categoryId: const drift.Value(1),
              isDeleted: const drift.Value(false),
            ),
          );
      await db
          .into(db.productPrices)
          .insert(
            ProductPricesCompanion(
              ucode: const drift.Value(ucode),
              barcode: const drift.Value(4607301),
              sellingPrice: drift.Value(d('1000')),
              wholesalePrice: drift.Value(d('1000')),
            ),
          );

      for (var i = 1; i <= 5; i++) {
        final r = await serialUc.registerSerial(
          ucode: ucode,
          serialNumber: 'SN-3301-$i',
        );
        expect(r.success, isTrue);
      }
      var inStock = await db.serialDao.findByStatus(0);
      expect(inStock.where((s) => s.ucode == ucode).length, 5);

      const receiptNo = 700001;
      final int posId = (await db.thisPosDao.get())!.id!;
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

      await db
          .into(db.sales)
          .insert(
            SalesCompanion.insert(
              receiptNo: receiptNo,
              posId: posId,
              userId: 0,
              amount: d('3000'),
              time: now,
            ),
          );
      await db
          .into(db.saleProducts)
          .insert(
            SaleProductsCompanion.insert(
              receiptNo: const drift.Value(receiptNo),
              posId: drift.Value(posId),
              ucode: ucode,
              quantity: d('3'),
              price: d('1000'),
              priceBefore: d('1000'),
            ),
          );

      final posAcc = (await db.accountDao.findByType(0)).first;
      final saleUc = GetIt.I<SaleUseCase>();
      await saleUc.perform(
        receiptNo: receiptNo,
        posId: posId,
        amount: d('3000'),
        payments: [PaymentEntry(payeeAccountId: posAcc.id, amount: d('3000'))],
        change: Decimal.zero,
        selectiveOfd: false,
      );

      final sold = await db.serialDao.findByStatus(1);
      final soldForUcode = sold.where((s) => s.ucode == ucode).toList();
      expect(
        soldForUcode.length,
        3,
        reason: 'exactly 3 serials must be marked sold',
      );
      expect(
        soldForUcode.every((s) => s.saleId == receiptNo),
        isTrue,
        reason: 'sold serials must carry the saleId (receiptNo)',
      );
      inStock = await db.serialDao.findByStatus(0);
      expect(
        inStock.where((s) => s.ucode == ucode).length,
        2,
        reason: '2 serials must remain in stock',
      );

      const ucode2 = 3302;
      await db
          .into(db.productInfos)
          .insert(
            ProductInfosCompanion(
              ucode: const drift.Value(ucode2),
              barcode: const drift.Value(4607302),
              name: const drift.Value('Серийный без серий'),
              type: const drift.Value(0),
              measure: const drift.Value(0),
              quantity: drift.Value(d('100')),
              categoryId: const drift.Value(1),
              isDeleted: const drift.Value(false),
            ),
          );
      const receiptNo2 = 700002;
      await db
          .into(db.sales)
          .insert(
            SalesCompanion.insert(
              receiptNo: receiptNo2,
              posId: posId,
              userId: 0,
              amount: d('500'),
              time: now,
            ),
          );
      await db
          .into(db.saleProducts)
          .insert(
            SaleProductsCompanion.insert(
              receiptNo: const drift.Value(receiptNo2),
              posId: drift.Value(posId),
              ucode: ucode2,
              quantity: d('1'),
              price: d('500'),
              priceBefore: d('500'),
            ),
          );

      await saleUc.perform(
        receiptNo: receiptNo2,
        posId: posId,
        amount: d('500'),
        payments: [PaymentEntry(payeeAccountId: posAcc.id, amount: d('500'))],
        change: Decimal.zero,
        selectiveOfd: false,
      );
      final saleRow = await db.saleDao.findByKey(receiptNo2, posId);
      expect(saleRow, isNotNull);
    });
  });
}

library;

import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart' as drift;
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';

import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/database/daos/account_dao.dart';
import 'package:telepos/domain/usecases/sale/sale_use_case.dart';

import '../support/harness.dart';

void main() {
  final h = E2eHarness();

  setUp(() => h.setUp());
  tearDown(() => h.tearDown());

  Future<Decimal> stockOf(AppDatabase db, int ucode) async {
    final p = await db.productInfoDao.findByUcode(ucode);
    return p?.quantity ?? Decimal.zero;
  }

  Future<void> enableWms(AppDatabase db) async {
    await db.wmsConfigDao.saveConfig(
      WmsConfigsCompanion(
        id: const drift.Value(1),
        batchTrackingEnabled: const drift.Value(true),
        cellStorageEnabled: const drift.Value(true),
        expiryControlEnabled: const drift.Value(true),
        defaultPickingStrategy: const drift.Value('FEFO'),
      ),
    );
  }

  Future<void> enableCellOnlyWms(AppDatabase db) async {
    await db.wmsConfigDao.saveConfig(
      WmsConfigsCompanion(
        id: const drift.Value(1),
        batchTrackingEnabled: const drift.Value(false),
        cellStorageEnabled: const drift.Value(true),
        expiryControlEnabled: const drift.Value(false),
        defaultPickingStrategy: const drift.Value('FEFO'),
      ),
    );
  }

  Future<int> seedCell(
    AppDatabase db, {
    String address = 'A-01-01-01-01',
  }) async {
    final whId = await db
        .into(db.warehouses)
        .insert(
          WarehousesCompanion(
            code: drift.Value('WH-$address'),
            name: const drift.Value('Основной склад'),
            isDefault: const drift.Value(true),
          ),
        );
    final zoneId = await db
        .into(db.warehouseZones)
        .insert(
          WarehouseZonesCompanion(
            warehouseId: drift.Value(whId),
            code: const drift.Value('A'),
            name: const drift.Value('Зона A'),
            type: const drift.Value(1),
          ),
        );
    return db
        .into(db.warehouseCells)
        .insert(
          WarehouseCellsCompanion(
            zoneId: drift.Value(zoneId),
            address: drift.Value(address),
          ),
        );
  }

  Future<int> seedBatch(
    AppDatabase db, {
    required int ucode,
    required String number,
    required int expiryDate,
    required Decimal qty,
    required int cellId,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final batchId = await db.batchDao.insertBatch(
      BatchesCompanion(
        ucode: drift.Value(ucode),
        batchNumber: drift.Value(number),
        expiryDate: drift.Value(expiryDate),
        initialQuantity: drift.Value(qty),
        currentQuantity: drift.Value(qty),
        reservedQuantity: drift.Value(Decimal.zero),
        receivedDate: drift.Value(now),
        isActive: const drift.Value(true),
        isQuarantined: const drift.Value(false),
        createdAt: drift.Value(now),
        updatedAt: drift.Value(now),
      ),
    );
    await db.cellStockDao.upsertStock(
      CellStocksCompanion(
        cellId: drift.Value(cellId),
        ucode: drift.Value(ucode),
        batchId: drift.Value(batchId),
        quantity: drift.Value(qty),
        reservedQty: drift.Value(Decimal.zero),
        updatedAt: drift.Value(now),
      ),
    );
    return batchId;
  }

  Future<void> seedInProgressSale(
    AppDatabase db, {
    required int receiptNo,
    required int ucode,
    required Decimal qty,
    required Decimal price,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final amount = qty * price;
    await db
        .into(db.sales)
        .insert(
          SalesCompanion(
            receiptNo: drift.Value(receiptNo),
            posId: const drift.Value(1),
            userId: const drift.Value(1),
            amount: drift.Value(amount),
            time: drift.Value(now),
            state: const drift.Value(0),
          ),
        );
    await db
        .into(db.saleProducts)
        .insert(
          SaleProductsCompanion(
            receiptNo: drift.Value(receiptNo),
            posId: const drift.Value(1),
            ucode: drift.Value(ucode),
            quantity: drift.Value(qty),
            price: drift.Value(price),
            priceBefore: drift.Value(price),
          ),
        );
  }

  Future<void> perform(
    SaleUseCase saleUseCase, {
    required int receiptNo,
    required Decimal amount,
    required int posAccId,
  }) async {
    await saleUseCase.perform(
      receiptNo: receiptNo,
      posId: 1,
      amount: amount,
      payments: [PaymentEntry(payeeAccountId: posAccId, amount: amount)],
      change: Decimal.zero,
      selectiveOfd: false,
    );
  }

  test(
    'BUG1: sale retry decrements stock exactly once (no double-subtract)',
    () async {
      final db = h.db;
      GetIt.I.registerSingleton<AppDatabase>(db);
      final saleUseCase = GetIt.I<SaleUseCase>();
      final posAccId = (await db.accountDao.findByType(
        AccountType.pos,
      )).first.id;

      const ucode = 1001;
      const receiptNo = 7001;
      final before = await stockOf(db, ucode);

      await seedInProgressSale(
        db,
        receiptNo: receiptNo,
        ucode: ucode,
        qty: d('10'),
        price: d('450'),
      );
      await perform(
        saleUseCase,
        receiptNo: receiptNo,
        amount: d('4500'),
        posAccId: posAccId,
      );
      expect(
        await stockOf(db, ucode),
        before - d('10'),
        reason: 'first attempt decrements once',
      );

      await saleUseCase.reverseSaleStock(receiptNo: receiptNo, posId: 1);

      await db.saleProductDao.deleteBySale(receiptNo, 1);
      await db.paymentDao.deleteBySale(receiptNo, 1);

      await db
          .into(db.saleProducts)
          .insert(
            SaleProductsCompanion(
              receiptNo: const drift.Value(receiptNo),
              posId: const drift.Value(1),
              ucode: const drift.Value(ucode),
              quantity: drift.Value(d('10')),
              price: drift.Value(d('450')),
              priceBefore: drift.Value(d('450')),
            ),
          );

      await perform(
        saleUseCase,
        receiptNo: receiptNo,
        amount: d('4500'),
        posAccId: posAccId,
      );

      expect(
        await stockOf(db, ucode),
        before - d('10'),
        reason: 'retry must net to a single decrement, not two',
      );
    },
  );

  test(
    'BUG2: FEFO sale spreads across batches, never drives a batch negative',
    () async {
      final db = h.db;
      GetIt.I.registerSingleton<AppDatabase>(db);
      await enableWms(db);
      final cellId = await seedCell(db);
      final saleUseCase = GetIt.I<SaleUseCase>();
      final posAccId = (await db.accountDao.findByType(
        AccountType.pos,
      )).first.id;

      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      const ucode = 1002;
      final oldBatchId = await seedBatch(
        db,
        ucode: ucode,
        number: 'OLD',
        expiryDate: now + 10 * 86400,
        qty: d('3'),
        cellId: cellId,
      );
      final newBatchId = await seedBatch(
        db,
        ucode: ucode,
        number: 'NEW',
        expiryDate: now + 90 * 86400,
        qty: d('30'),
        cellId: cellId,
      );

      final beforeGlobal = await stockOf(db, ucode);

      await seedInProgressSale(
        db,
        receiptNo: 7002,
        ucode: ucode,
        qty: d('10'),
        price: d('150'),
      );
      await perform(
        saleUseCase,
        receiptNo: 7002,
        amount: d('1500'),
        posAccId: posAccId,
      );

      final oldBatch = await db.batchDao.findById(oldBatchId);
      final newBatch = await db.batchDao.findById(newBatchId);

      expect(
        oldBatch!.currentQuantity >= Decimal.zero,
        isTrue,
        reason: 'OLD batch must never be negative',
      );
      expect(
        newBatch!.currentQuantity >= Decimal.zero,
        isTrue,
        reason: 'NEW batch must never be negative',
      );

      expect(
        oldBatch.currentQuantity,
        Decimal.zero,
        reason: 'OLD (earliest expiry, qty 3) fully consumed',
      );
      expect(
        oldBatch.isActive,
        isFalse,
        reason: 'a depleted batch is deactivated',
      );
      expect(
        newBatch.currentQuantity,
        d('23'),
        reason: 'NEW takes the remaining 7: 30 - 7 = 23',
      );

      final totalBatch = oldBatch.currentQuantity + newBatch.currentQuantity;
      expect(totalBatch, d('23'));

      expect(
        await stockOf(db, ucode),
        beforeGlobal - d('10'),
        reason: 'global stock decremented exactly once',
      );
    },
  );

  test(
    'BUG3: cell depletion runs without batches and spreads across cells',
    () async {
      final db = h.db;
      GetIt.I.registerSingleton<AppDatabase>(db);
      await enableCellOnlyWms(db);
      final cellA = await seedCell(db, address: 'A-01');
      final cellB = await seedCell(db, address: 'B-01');
      final saleUseCase = GetIt.I<SaleUseCase>();
      final posAccId = (await db.accountDao.findByType(
        AccountType.pos,
      )).first.id;

      const ucode = 1003;
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      await db.cellStockDao.upsertStock(
        CellStocksCompanion(
          cellId: drift.Value(cellA),
          ucode: const drift.Value(ucode),
          quantity: drift.Value(d('4')),
          reservedQty: drift.Value(Decimal.zero),
          updatedAt: drift.Value(now),
        ),
      );
      await db.cellStockDao.upsertStock(
        CellStocksCompanion(
          cellId: drift.Value(cellB),
          ucode: const drift.Value(ucode),
          quantity: drift.Value(d('30')),
          reservedQty: drift.Value(Decimal.zero),
          updatedAt: drift.Value(now),
        ),
      );

      final beforeGlobal = await stockOf(db, ucode);

      await seedInProgressSale(
        db,
        receiptNo: 7003,
        ucode: ucode,
        qty: d('10'),
        price: d('280'),
      );
      await perform(
        saleUseCase,
        receiptNo: 7003,
        amount: d('2800'),
        posAccId: posAccId,
      );

      final cells = await db.cellStockDao.findByUcode(ucode);
      var cellSum = Decimal.zero;
      for (final c in cells) {
        cellSum += c.quantity;
        expect(
          c.quantity >= Decimal.zero,
          isTrue,
          reason: 'no cell may go negative',
        );
      }

      expect(await stockOf(db, ucode), beforeGlobal - d('10'));

      expect(
        cellSum,
        d('24'),
        reason: 'sum(cells) tracks the sale (depletion ran without batches)',
      );
    },
  );
}

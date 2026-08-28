library;

import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart' as drift;
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';

import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/database/daos/account_dao.dart';
import 'package:telepos/domain/usecases/sale/sale_use_case.dart';
import 'package:telepos/domain/usecases/supply/create_supply_use_case.dart';
import 'package:telepos/domain/usecases/supply/save_supply_use_case.dart';

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

  Future<int> seedCell(AppDatabase db) async {
    final whId = await db
        .into(db.warehouses)
        .insert(
          WarehousesCompanion(
            code: const drift.Value('WH-001'),
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
            name: const drift.Value('Зона хранения A'),
            type: const drift.Value(1),
          ),
        );
    return db
        .into(db.warehouseCells)
        .insert(
          WarehouseCellsCompanion(
            zoneId: drift.Value(zoneId),
            address: const drift.Value('A-01-01-01-01'),
          ),
        );
  }

  Future<int> seedSupplier(AppDatabase db) async {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    return db
        .into(db.agents)
        .insert(
          AgentsCompanion(
            type: const drift.Value(0),
            name: const drift.Value('ОптТорг'),
            isDeleted: const drift.Value(false),
            editTime: drift.Value(now),
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

  Future<void> sell(
    AppDatabase db,
    SaleUseCase saleUseCase, {
    required int receiptNo,
    required int ucode,
    required Decimal qty,
    required Decimal price,
    required int posAccId,
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
    await saleUseCase.perform(
      receiptNo: receiptNo,
      posId: 1,
      amount: amount,
      payments: [PaymentEntry(payeeAccountId: posAccId, amount: amount)],
      change: Decimal.zero,
      selectiveOfd: false,
    );
  }

  test('stock model: receipt creates batch+cell; sale FEFO-depletes oldest '
      'batch+cell; dish sale depletes ingredient stock', () async {
    final db = h.db;
    GetIt.I.registerSingleton<AppDatabase>(db);

    await enableWms(db);
    final cellId = await seedCell(db);
    final posAccId = (await db.accountDao.findByType(AccountType.pos)).first.id;

    final create = GetIt.I<CreateSupplyUseCase>();
    final save = GetIt.I<SaveSupplyUseCase>();
    final saleUseCase = GetIt.I<SaleUseCase>();

    final supplierId = await seedSupplier(db);
    final stock1001Before = await stockOf(db, 1001);

    final created = await create.execute(
      userId: 1,
      supplierId: supplierId,
      paymentType: SupplyPaymentType.consignment,
    );
    expect(created.success, isTrue);

    await db.supplyProductDao.insertProduct(
      SupplyProductsCompanion(
        supplyId: drift.Value(created.supplyId),
        ucode: const drift.Value(1001),
        quantity: drift.Value(d('40')),
        price: drift.Value(d('300')),
        amount: drift.Value(d('12000')),
      ),
    );

    final saved = await save.execute(created.supplyId);
    expect(saved.success, isTrue, reason: saved.errorMessage ?? '');

    expect(await stockOf(db, 1001), stock1001Before + d('40'));

    final batches1001 = await db.batchDao.findActiveByUcode(1001);
    expect(
      batches1001,
      hasLength(1),
      reason: 'receipt must create exactly one batch for the line',
    );
    expect(
      batches1001.first.currentQuantity,
      d('40'),
      reason: 'batch carries the received quantity (Decimal-exact)',
    );
    expect(batches1001.first.batchNumber, 'SUP-${created.supplyId}-1001');

    final cellStock1001 = await db.cellStockDao.findByBatchId(
      batches1001.first.id,
    );
    expect(
      cellStock1001,
      hasLength(1),
      reason: 'receipt must place stock into a cell',
    );
    expect(cellStock1001.first.cellId, cellId);
    expect(cellStock1001.first.quantity, d('40'));

    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final oldBatchId = await seedBatch(
      db,
      ucode: 1002,
      number: 'OLD',
      expiryDate: now + 10 * 86400,
      qty: d('30'),
      cellId: cellId,
    );
    final newBatchId = await seedBatch(
      db,
      ucode: 1002,
      number: 'NEW',
      expiryDate: now + 90 * 86400,
      qty: d('30'),
      cellId: cellId,
    );

    final stock1002Before = await stockOf(db, 1002);

    await sell(
      db,
      saleUseCase,
      receiptNo: 5001,
      ucode: 1002,
      qty: d('12'),
      price: d('150'),
      posAccId: posAccId,
    );

    expect(await stockOf(db, 1002), stock1002Before - d('12'));

    final oldBatch = await db.batchDao.findById(oldBatchId);
    final newBatch = await db.batchDao.findById(newBatchId);
    expect(
      oldBatch!.currentQuantity,
      d('18'),
      reason: 'FEFO depletes the earliest-expiry batch: 30 - 12 = 18',
    );
    expect(
      newBatch!.currentQuantity,
      d('30'),
      reason: 'the later-expiry batch is untouched',
    );

    final oldCell = await db.cellStockDao.findByBatchId(oldBatchId);
    expect(
      oldCell.first.quantity,
      d('18'),
      reason: 'cell stock for the picked batch decreases by sold qty',
    );
    final newCell = await db.cellStockDao.findByBatchId(newBatchId);
    expect(
      newCell.first.quantity,
      d('30'),
      reason: 'cell stock for the untouched batch is unchanged',
    );

    await (db.update(db.productInfos)..where((p) => p.ucode.equals(1005)))
        .write(const ProductInfosCompanion(type: drift.Value(6)));
    await db.dishIngredientDao.insertIngredient(
      DishIngredientsCompanion(
        dishUcode: const drift.Value(1005),
        ingredientUcode: const drift.Value(1003),
        grossQuantity: drift.Value(d('0.05')),
        netQuantity: drift.Value(d('0.05')),
        sortOrder: const drift.Value(0),
      ),
    );

    final ingredientBefore = await stockOf(db, 1003);
    final plainBefore = await stockOf(db, 1004);
    final dishStockBefore = await stockOf(db, 1005);

    await sell(
      db,
      saleUseCase,
      receiptNo: 5002,
      ucode: 1005,
      qty: d('4'),
      price: d('700'),
      posAccId: posAccId,
    );

    expect(await stockOf(db, 1005), dishStockBefore - d('4'));

    expect(
      await stockOf(db, 1003),
      ingredientBefore - d('0.2'),
      reason: 'dish sale depletes its recipe ingredient (real food cost)',
    );

    expect(
      await stockOf(db, 1004),
      plainBefore,
      reason: 'non-dish / non-batch products behave exactly as before',
    );
  });
}

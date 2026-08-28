library;

import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart' as drift;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';

import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/usecases/cogs/calculate_cogs_use_case_impl.dart';
import 'package:telepos/data/usecases/supplier_return/apply_supplier_return_cogs_use_case.dart';
import 'package:telepos/data/usecases/writeoff/create_writeoff_use_case_impl.dart';
import 'package:telepos/domain/usecases/cogs/calculate_cogs_use_case.dart';
import 'package:telepos/domain/usecases/writeoff/create_writeoff_use_case.dart';
import 'package:telepos/presentation/controllers/supplier_return/supplier_return_controller.dart';

import '../support/harness.dart';

void main() {
  final h = E2eHarness();

  setUpAll(() async {
    await h.setUp();
    GetIt.I.registerSingleton<AppDatabase>(h.db);
    GetIt.I.registerSingleton<CalculateCogsUseCase>(
      CalculateCogsUseCaseImpl(db: h.db),
    );
  });
  tearDownAll(() => h.tearDown());

  const flatUcode = 7200;
  const flatBarcode = 4690200;

  setUp(() async {
    await h.db.delete(h.db.batches).go();
    await h.db.delete(h.db.writeoffProducts).go();
    await h.db.delete(h.db.writeoffs).go();
    await h.db.delete(h.db.supplierReturnProducts).go();
    await h.db.delete(h.db.supplierReturns).go();
    await h.db.delete(h.db.supplyProducts).go();
    await h.db.delete(h.db.supplies).go();
    await (h.db.delete(
      h.db.productInfos,
    )..where((p) => p.ucode.equals(flatUcode))).go();
    await (h.db.delete(
      h.db.productPrices,
    )..where((p) => p.ucode.equals(flatUcode))).go();

    await h.db
        .into(h.db.productInfos)
        .insert(
          ProductInfosCompanion(
            ucode: const drift.Value(flatUcode),
            barcode: const drift.Value(flatBarcode),
            name: const drift.Value('Вода 0.5л'),
            type: const drift.Value(0),
            measure: const drift.Value(0),
            quantity: drift.Value(d('50')),
            categoryId: const drift.Value(1),
            isDeleted: const drift.Value(false),
          ),
        );
  });

  Future<void> seedWholesalePrice(String wholesale) async {
    await h.db
        .into(h.db.productPrices)
        .insert(
          ProductPricesCompanion(
            ucode: const drift.Value(flatUcode),
            barcode: const drift.Value(flatBarcode),
            sellingPrice: drift.Value(d('200')),
            wholesalePrice: drift.Value(d(wholesale)),
          ),
        );
  }

  test('no batches: COGS falls back to product wholesale cost (Decimal-exact), '
      'not 0 and not the line price', () async {
    await seedWholesalePrice('72.5');

    final cogs = CalculateCogsUseCaseImpl(db: h.db);
    final result = await cogs.calculate(ucode: flatUcode, quantity: d('10'));

    expect(
      result.shortfall,
      isFalse,
      reason: 'fallback covers the full quantity from wholesale cost',
    );
    expect(result.resolvedQuantity, d('10'));
    expect(
      result.totalCost,
      d('725'),
      reason: 'wholesale cost 72.5 * 10 = 725, Decimal-exact',
    );
    expect(result.unitCost, d('72.5'));
    expect(
      result.consumptions.single.batchId,
      0,
      reason: 'flat purchase-price consumption (no batch)',
    );
  });

  test(
    'no batches: a real CreateWriteoffUseCase records the fallback wholesale '
    'COGS, not 0',
    () async {
      await seedWholesalePrice('72.5');

      final impl = CreateWriteoffUseCaseImpl(
        cogsUseCase: CalculateCogsUseCaseImpl(db: h.db),
      );
      final res = await impl.create(
        reason: WriteoffReason.spoilage,
        products: [
          WriteoffProductEntry(
            ucode: flatUcode,
            quantity: d('10'),
            price: d('200'),
          ),
        ],
        comment: 'spoiled water',
        userId: 1,
      );

      expect(res.success, isTrue, reason: res.errorMessage);
      expect(res.totalAmount, d('2000'), reason: 'doc value = 10 * 200');
      expect(
        impl.lastCogs,
        d('725'),
        reason: 'writeoff records fallback wholesale COGS (72.5 * 10)',
      );

      final wo = (await h.db.writeoffDao.findAll()).first;
      expect(wo.comment, contains('COGS[FIFO]=725'));
    },
  );

  test(
    'no batches AND no wholesale price: COGS falls back to the latest supply '
    'arrival cost',
    () async {
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final oldSupply = await h.db
          .into(h.db.supplies)
          .insert(SuppliesCompanion(editTime: drift.Value(now - 86400 * 10)));
      final newSupply = await h.db
          .into(h.db.supplies)
          .insert(SuppliesCompanion(editTime: drift.Value(now - 86400 * 1)));
      await h.db
          .into(h.db.supplyProducts)
          .insert(
            SupplyProductsCompanion.insert(
              supplyId: oldSupply,
              ucode: flatUcode,
              quantity: d('20'),
              price: d('60'),
              amount: d('1200'),
            ),
          );
      await h.db
          .into(h.db.supplyProducts)
          .insert(
            SupplyProductsCompanion.insert(
              supplyId: newSupply,
              ucode: flatUcode,
              quantity: d('30'),
              price: d('80'),
              amount: d('2400'),
            ),
          );

      final cogs = CalculateCogsUseCaseImpl(db: h.db);
      final result = await cogs.calculate(ucode: flatUcode, quantity: d('5'));

      expect(result.shortfall, isFalse);
      expect(
        result.totalCost,
        d('400'),
        reason: 'newest supply arrival cost 80 * 5 = 400',
      );
      expect(result.unitCost, d('80'));
    },
  );

  test('with batches: FIFO cost is used (fallback does NOT kick in)', () async {
    await seedWholesalePrice('72.5');
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    await h.db.batchDao.insertBatch(
      BatchesCompanion(
        ucode: const drift.Value(flatUcode),
        batchNumber: const drift.Value('A-OLD'),
        receivedDate: drift.Value(now - 86400 * 7),
        initialQuantity: drift.Value(d('10')),
        currentQuantity: drift.Value(d('10')),
        unitCost: drift.Value(d('100')),
        isActive: const drift.Value(true),
        createdAt: drift.Value(now - 86400 * 7),
      ),
    );
    await h.db.batchDao.insertBatch(
      BatchesCompanion(
        ucode: const drift.Value(flatUcode),
        batchNumber: const drift.Value('B-NEW'),
        receivedDate: drift.Value(now - 86400 * 1),
        initialQuantity: drift.Value(d('10')),
        currentQuantity: drift.Value(d('10')),
        unitCost: drift.Value(d('150')),
        isActive: const drift.Value(true),
        createdAt: drift.Value(now - 86400 * 1),
      ),
    );

    final cogs = CalculateCogsUseCaseImpl(db: h.db);
    final result = await cogs.calculate(ucode: flatUcode, quantity: d('12'));

    expect(
      result.totalCost,
      d('1300'),
      reason: 'real FIFO batches win over the wholesale fallback',
    );
    expect(result.consumptions.length, 2);
    expect(
      result.consumptions.first.batchId,
      isNot(0),
      reason: 'real batch consumption, not a flat fallback',
    );
  });

  test('SupplierReturnNotifier.save() records real FIFO COGS and drains the '
      'oldest batch (wiring of ApplySupplierReturnCogsUseCase)', () async {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    await h.db.batchDao.insertBatch(
      BatchesCompanion(
        ucode: const drift.Value(flatUcode),
        batchNumber: const drift.Value('SR-OLD'),
        receivedDate: drift.Value(now - 86400 * 7),
        initialQuantity: drift.Value(d('10')),
        currentQuantity: drift.Value(d('10')),
        unitCost: drift.Value(d('100')),
        isActive: const drift.Value(true),
        createdAt: drift.Value(now - 86400 * 7),
      ),
    );
    await h.db.batchDao.insertBatch(
      BatchesCompanion(
        ucode: const drift.Value(flatUcode),
        batchNumber: const drift.Value('SR-NEW'),
        receivedDate: drift.Value(now - 86400 * 1),
        initialQuantity: drift.Value(d('10')),
        currentQuantity: drift.Value(d('10')),
        unitCost: drift.Value(d('150')),
        isActive: const drift.Value(true),
        createdAt: drift.Value(now - 86400 * 1),
      ),
    );

    final supplierId = await h.db
        .into(h.db.agents)
        .insert(
          AgentsCompanion(
            name: const drift.Value('ТОО Поставщик'),
            type: const drift.Value(0),
          ),
        );

    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(supplierReturnControllerProvider.notifier);

    await notifier.selectSupplier(supplierId);
    await notifier.addProduct(
      ucode: flatUcode,
      quantity: d('12'),
      price: d('200'),
    );

    final result = await notifier.save();

    expect(result.success, isTrue, reason: result.errorMessage);
    expect(
      result.cogs,
      d('1300'),
      reason: 'supplier return records real FIFO COGS via the wired use case',
    );

    final saved = await h.db.supplierReturnDao.findById(result.returnId!);
    expect(
      saved!.comment,
      contains('COGS[FIFO]=1300'),
      reason:
          'COGS ledger-note written to the return comment (no schema change)',
    );

    final batches = await h.db.batchDao.findByUcode(flatUcode);
    final oldBatch = batches.firstWhere((b) => b.batchNumber == 'SR-OLD');
    final newBatch = batches.firstWhere((b) => b.batchNumber == 'SR-NEW');
    expect(
      oldBatch.currentQuantity,
      d('0'),
      reason: 'oldest batch consumed first (FIFO) on the return issue',
    );
    expect(newBatch.currentQuantity, d('8'));
  });

  test('SupplierReturnNotifier.save() records fallback wholesale COGS when the '
      'returned product has NO batches', () async {
    await seedWholesalePrice('72.5');

    final supplierId = await h.db
        .into(h.db.agents)
        .insert(
          AgentsCompanion(
            name: const drift.Value('ТОО Поставщик'),
            type: const drift.Value(0),
          ),
        );

    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(supplierReturnControllerProvider.notifier);

    await notifier.selectSupplier(supplierId);
    await notifier.addProduct(
      ucode: flatUcode,
      quantity: d('10'),
      price: d('200'),
    );

    final result = await notifier.save();

    expect(result.success, isTrue, reason: result.errorMessage);
    expect(
      result.cogs,
      d('725'),
      reason: 'no batches → fallback wholesale COGS on supplier return',
    );
    final saved = await h.db.supplierReturnDao.findById(result.returnId!);
    expect(saved!.comment, contains('COGS[FIFO]=725'));
  });

  test(
    'CalculateCogsUseCaseImpl is stateless: concurrent calculate() calls each '
    'return their own exact cost (no shared lastCogs race)',
    () async {
      await seedWholesalePrice('72.5');
      final cogs = CalculateCogsUseCaseImpl(db: h.db);

      final futures = [
        for (var q = 1; q <= 12; q++)
          cogs.calculate(ucode: flatUcode, quantity: d('$q')),
      ];
      final results = await Future.wait(futures);

      for (var i = 0; i < results.length; i++) {
        final q = i + 1;
        final expected = d('72.5') * d('$q');
        expect(
          results[i].totalCost,
          expected,
          reason: 'each concurrent calc keeps its own cost ($q * 72.5)',
        );
      }
    },
  );
}

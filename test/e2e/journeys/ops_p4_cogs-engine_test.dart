library;

import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart' as drift;
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';

import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/usecases/cogs/calculate_cogs_use_case_impl.dart';
import 'package:telepos/data/usecases/writeoff/create_writeoff_use_case_impl.dart';
import 'package:telepos/data/usecases/supplier_return/apply_supplier_return_cogs_use_case.dart';
import 'package:telepos/domain/usecases/cogs/calculate_cogs_use_case.dart';
import 'package:telepos/domain/usecases/writeoff/create_writeoff_use_case.dart';

import '../support/harness.dart';

void main() {
  final h = E2eHarness();

  setUpAll(() async {
    await h.setUp();
    GetIt.I.registerSingleton<AppDatabase>(h.db);
  });
  tearDownAll(() => h.tearDown());

  const cogsUcode = 7100;

  setUp(() async {
    await h.db.delete(h.db.batches).go();
    await h.db.delete(h.db.writeoffProducts).go();
    await h.db.delete(h.db.writeoffs).go();
    await (h.db.delete(
      h.db.productInfos,
    )..where((p) => p.ucode.equals(cogsUcode))).go();

    await h.db
        .into(h.db.productInfos)
        .insert(
          ProductInfosCompanion(
            ucode: const drift.Value(cogsUcode),
            barcode: const drift.Value(4690100),
            name: const drift.Value('Кофе зерновой'),
            type: const drift.Value(0),
            measure: const drift.Value(0),
            quantity: drift.Value(d('20')),
            categoryId: const drift.Value(1),
            isDeleted: const drift.Value(false),
          ),
        );
  });

  Future<void> seedTwoBatches() async {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    await h.db.batchDao.insertBatch(
      BatchesCompanion(
        ucode: const drift.Value(cogsUcode),
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
        ucode: const drift.Value(cogsUcode),
        batchNumber: const drift.Value('B-NEW'),
        receivedDate: drift.Value(now - 86400 * 1),
        initialQuantity: drift.Value(d('10')),
        currentQuantity: drift.Value(d('10')),
        unitCost: drift.Value(d('150')),
        isActive: const drift.Value(true),
        createdAt: drift.Value(now - 86400 * 1),
      ),
    );
  }

  test('FIFO COGS consumes the oldest batch first: issuing 12 = 10*100 + 2*150 '
      '= 1300 (exact Decimal), not the line price', () async {
    await seedTwoBatches();
    final cogs = CalculateCogsUseCaseImpl(db: h.db);

    final result = await cogs.calculate(ucode: cogsUcode, quantity: d('12'));

    expect(result.method, CogsMethod.fifo);
    expect(result.shortfall, isFalse, reason: '20 on hand covers 12');
    expect(result.resolvedQuantity, d('12'));
    expect(
      result.totalCost,
      d('1300'),
      reason: 'FIFO drains the 100-cost batch first, then the 150 one',
    );

    expect(result.consumptions.length, 2);
    expect(result.consumptions[0].quantity, d('10'));
    expect(result.consumptions[0].unitCost, d('100'));
    expect(result.consumptions[0].cost, d('1000'));
    expect(result.consumptions[1].quantity, d('2'));
    expect(result.consumptions[1].unitCost, d('150'));
    expect(result.consumptions[1].cost, d('300'));

    final batchesAfterCalc = await h.db.batchDao.findByUcode(cogsUcode);
    final stillFull = batchesAfterCalc.fold<Decimal>(
      Decimal.zero,
      (s, b) => s + b.currentQuantity,
    );
    expect(
      stillFull,
      d('20'),
      reason: 'CalculateCogsUseCase must not mutate stock',
    );
  });

  test('CreateWriteoffUseCase records the REAL FIFO COGS (1300) and drains the '
      'oldest batch first', () async {
    await seedTwoBatches();

    final impl = CreateWriteoffUseCaseImpl(
      cogsUseCase: CalculateCogsUseCaseImpl(db: h.db),
    );

    final res = await impl.create(
      reason: WriteoffReason.spoilage,
      products: [
        WriteoffProductEntry(
          ucode: cogsUcode,
          quantity: d('12'),
          price: d('200'),
        ),
      ],
      comment: 'spoiled',
      userId: 1,
    );

    expect(res.success, isTrue, reason: res.errorMessage);
    expect(res.totalAmount, d('2400'));
    expect(
      impl.lastCogs,
      d('1300'),
      reason: 'writeoff must record real FIFO COGS from batch unitCost',
    );

    final wo = (await h.db.writeoffDao.findAll()).first;
    expect(
      wo.comment,
      contains('COGS[FIFO]=1300'),
      reason: 'COGS recorded as ledger note (no schema change)',
    );

    final batches = await h.db.batchDao.findByUcode(cogsUcode);
    final oldBatch = batches.firstWhere((b) => b.batchNumber == 'A-OLD');
    final newBatch = batches.firstWhere((b) => b.batchNumber == 'B-NEW');
    expect(
      oldBatch.currentQuantity,
      d('0'),
      reason: 'oldest batch consumed first (FIFO)',
    );
    expect(
      newBatch.currentQuantity,
      d('8'),
      reason: 'only the remainder taken from the newer batch',
    );
  });

  test('weighted-average COGS cross-check: avg = (1000+1500)/20 = 125, '
      '12*125 = 1500 (exact Decimal)', () async {
    await seedTwoBatches();
    final cogs = CalculateCogsUseCaseImpl(db: h.db);

    final result = await cogs.calculate(
      ucode: cogsUcode,
      quantity: d('12'),
      method: CogsMethod.weightedAverage,
    );

    expect(result.method, CogsMethod.weightedAverage);
    expect(result.unitCost, d('125'), reason: '(10*100 + 10*150)/20 = 125');
    expect(result.totalCost, d('1500'), reason: '12 * 125 = 1500');
    expect(result.shortfall, isFalse);
  });

  test(
    'FIFO COGS flags a shortfall and costs only what batches can cover',
    () async {
      await seedTwoBatches();

      final cogs = CalculateCogsUseCaseImpl(db: h.db);
      final result = await cogs.calculate(ucode: cogsUcode, quantity: d('25'));

      expect(result.shortfall, isTrue, reason: '25 requested, 20 available');
      expect(result.resolvedQuantity, d('20'));
      expect(result.totalCost, d('2500'));
    },
  );

  test('supplier return applies the same FIFO COGS engine on issue '
      '(ApplySupplierReturnCogsUseCase)', () async {
    await seedTwoBatches();

    final apply = ApplySupplierReturnCogsUseCase(
      cogsUseCase: CalculateCogsUseCaseImpl(db: h.db),
      db: h.db,
    );

    final res = await apply.apply(
      lines: [SupplierReturnCogsLine(ucode: cogsUcode, quantity: d('12'))],
    );

    expect(
      res.totalCogs,
      d('1300'),
      reason: 'supplier return issue records real FIFO COGS',
    );
    expect(res.ledgerNote, 'COGS[FIFO]=1300');

    final batches = await h.db.batchDao.findByUcode(cogsUcode);
    final oldBatch = batches.firstWhere((b) => b.batchNumber == 'A-OLD');
    expect(oldBatch.currentQuantity, d('0'));
  });
}

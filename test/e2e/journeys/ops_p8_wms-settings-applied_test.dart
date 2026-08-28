library;

import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart' as drift;
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';

import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/usecases/cogs/calculate_cogs_use_case_impl.dart';
import 'package:telepos/data/usecases/writeoff/create_writeoff_use_case_impl.dart';
import 'package:telepos/domain/usecases/writeoff/create_writeoff_use_case.dart';
import 'package:telepos/domain/usecases/wms/wms_config_use_case.dart';

import '../support/harness.dart';

void main() {
  final h = E2eHarness();

  setUpAll(() async {
    await h.setUp();
    GetIt.I.registerSingleton<AppDatabase>(h.db);
  });
  tearDownAll(() => h.tearDown());

  const ucode = 7200;

  setUp(() async {
    await h.db.delete(h.db.batches).go();
    await h.db.delete(h.db.writeoffProducts).go();
    await h.db.delete(h.db.writeoffs).go();
    await (h.db.delete(
      h.db.productInfos,
    )..where((p) => p.ucode.equals(ucode))).go();
    await h.db
        .into(h.db.productInfos)
        .insert(
          ProductInfosCompanion(
            ucode: const drift.Value(ucode),
            barcode: const drift.Value(4690200),
            name: const drift.Value('Товар для COGS-метода'),
            type: const drift.Value(0),
            measure: const drift.Value(0),
            quantity: drift.Value(d('20')),
            categoryId: const drift.Value(1),
            isDeleted: const drift.Value(false),
          ),
        );

    final cfgUc = GetIt.I<WmsConfigUseCase>();
    final cfg = await cfgUc.getConfig();
    await cfgUc.saveConfig(cfg.copyWith(costMethod: 'FIFO'));
  });

  Future<void> seedTwoBatches() async {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    await h.db.batchDao.insertBatch(
      BatchesCompanion(
        ucode: const drift.Value(ucode),
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
        ucode: const drift.Value(ucode),
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

  test(
    'cost method AVG (persisted) drives writeoff COGS: weighted-average 1500, '
    'NOT FIFO 1300 — the dropdown is no longer dead',
    () async {
      await seedTwoBatches();

      final cfgUc = GetIt.I<WmsConfigUseCase>();
      await cfgUc.saveConfig(
        (await cfgUc.getConfig()).copyWith(costMethod: 'AVG'),
      );
      expect(await cfgUc.costMethod(), 'AVG');

      final impl = CreateWriteoffUseCaseImpl(
        cogsUseCase: CalculateCogsUseCaseImpl(db: h.db),
      );
      final res = await impl.create(
        reason: WriteoffReason.spoilage,
        products: [
          WriteoffProductEntry(
            ucode: ucode,
            quantity: d('12'),
            price: d('200'),
          ),
        ],
        userId: 1,
      );

      expect(res.success, isTrue, reason: res.errorMessage);
      expect(
        impl.lastCogs,
        d('1500'),
        reason: 'AVG setting must drive weighted-average COGS at runtime',
      );
      final wo = (await h.db.writeoffDao.findAll()).first;
      expect(wo.comment, contains('COGS[WAVG]=1500'));
    },
  );

  test('default cost method FIFO still yields the FIFO COGS (1300) — backward '
      'compatible when the setting is left at its default', () async {
    await seedTwoBatches();

    final cfgUc = GetIt.I<WmsConfigUseCase>();
    expect(await cfgUc.costMethod(), 'FIFO');

    final impl = CreateWriteoffUseCaseImpl(
      cogsUseCase: CalculateCogsUseCaseImpl(db: h.db),
    );
    final res = await impl.create(
      reason: WriteoffReason.spoilage,
      products: [
        WriteoffProductEntry(ucode: ucode, quantity: d('12'), price: d('200')),
      ],
      userId: 1,
    );

    expect(res.success, isTrue, reason: res.errorMessage);
    expect(
      impl.lastCogs,
      d('1300'),
      reason: 'FIFO default preserves the historical 10*100 + 2*150 result',
    );
  });

  test(
    'pickingStrategy() resolves the persisted FEFO/FIFO/LIFO token',
    () async {
      final cfgUc = GetIt.I<WmsConfigUseCase>();

      await cfgUc.saveConfig(
        (await cfgUc.getConfig()).copyWith(pickingStrategy: 'LIFO'),
      );
      expect(await cfgUc.pickingStrategy(), 'LIFO');

      await cfgUc.saveConfig(
        (await cfgUc.getConfig()).copyWith(pickingStrategy: 'FIFO'),
      );
      expect(await cfgUc.pickingStrategy(), 'FIFO');

      await cfgUc.saveConfig(
        (await cfgUc.getConfig()).copyWith(pickingStrategy: 'FEFO'),
      );
      expect(await cfgUc.pickingStrategy(), 'FEFO');
    },
  );
}

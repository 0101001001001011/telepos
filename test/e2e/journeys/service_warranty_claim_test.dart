library;

import 'package:drift/drift.dart' as drift;
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';

import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/domain/repositories/warranty_repository.dart';
import 'package:telepos/domain/usecases/service/service_order_transition_use_case.dart';
import 'package:telepos/domain/usecases/wms/claim_use_case.dart';

import '../support/harness.dart';
import '../support/seed_sequence.dart';

void main() {
  final h = E2eHarness();

  setUpAll(() async {
    await h.setUp();
    GetIt.I.registerSingleton<AppDatabase>(h.db);
  });
  tearDownAll(() => h.tearDown());

  Future<int> seedOrder(
    AppDatabase db, {
    int status = 2,
    int? warrantyDays,
    int? clientAgentId,
    String cost = '1000',
  }) async {
    final id = await db.serviceOrderDao.insert(
      ServiceOrdersCompanion.insert(
        orderNumber: 'SO-W-${nextSeed()}',
        status: drift.Value(status),
        userId: 1,
        intakeTime: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        warrantyDays: drift.Value(warrantyDays),
        clientAgentId: drift.Value(clientAgentId),
      ),
    );
    await db.serviceMarkDao.insert(
      ServiceMarksCompanion(
        serviceOrderId: drift.Value(id),
        description: const drift.Value('Ремонт'),
        markType: const drift.Value(4),
        userId: const drift.Value(1),
        cost: drift.Value(d(cost)),
        createdAt: drift.Value(DateTime.now().millisecondsSinceEpoch ~/ 1000),
      ),
    );
    return id;
  }

  Future<void> seedProduct(
    AppDatabase db, {
    required int ucode,
    required String qty,
  }) async {
    await db
        .into(db.productInfos)
        .insert(
          ProductInfosCompanion(
            ucode: drift.Value(ucode),
            barcode: drift.Value(ucode),
            name: drift.Value('Товар $ucode'),
            type: const drift.Value(0),
            measure: const drift.Value(0),
            quantity: drift.Value(d(qty)),
            categoryId: const drift.Value(1),
            isDeleted: const drift.Value(false),
          ),
        );
  }

  group('B2 — warranty created on service order close', () {
    test(
      'warrantyDays=90 -> a WarrantyRecord exists with start/end set',
      () async {
        final db = GetIt.I<AppDatabase>();
        final repo = GetIt.I<WarrantyRepository>();
        final orderId = await seedOrder(
          db,
          warrantyDays: 90,
          clientAgentId: 77,
        );

        final before = (await repo.findByUcode(0)).length;
        final tClose = DateTime.now().millisecondsSinceEpoch ~/ 1000;

        await GetIt.I<ServiceOrderTransitionUseCase>().progress(orderId);

        final all = await repo.findByUcode(0);
        expect(
          all.length,
          before + 1,
          reason: 'closing with warrantyDays>0 must create one WarrantyRecord',
        );

        final w = all.last;
        expect(w.warrantyStart, isNotNull);
        expect(w.warrantyEnd, isNotNull);
        expect(
          w.warrantyStart! >= tClose && w.warrantyStart! <= tClose + 5,
          isTrue,
          reason: 'warranty start must be the close time',
        );
        expect(
          w.warrantyEnd! - w.warrantyStart!,
          90 * 86400,
          reason: 'warranty end must be start + 90 days',
        );
        expect(
          w.customerId,
          77,
          reason: 'warranty must carry the client agent id',
        );
        expect(w.remainingDays, inInclusiveRange(89, 90));
      },
    );

    test('warrantyDays=null -> NO warranty record', () async {
      final db = GetIt.I<AppDatabase>();
      final repo = GetIt.I<WarrantyRepository>();
      final before = (await repo.findByUcode(0)).length;

      final orderId = await seedOrder(db, warrantyDays: null);
      await GetIt.I<ServiceOrderTransitionUseCase>().progress(orderId);

      expect(
        (await repo.findByUcode(0)).length,
        before,
        reason: 'no warrantyDays => no warranty record',
      );
    });

    test('warrantyDays=0 -> NO warranty record', () async {
      final db = GetIt.I<AppDatabase>();
      final repo = GetIt.I<WarrantyRepository>();
      final before = (await repo.findByUcode(0)).length;

      final orderId = await seedOrder(db, warrantyDays: 0);
      await GetIt.I<ServiceOrderTransitionUseCase>().progress(orderId);

      expect(
        (await repo.findByUcode(0)).length,
        before,
        reason: 'warrantyDays=0 => no warranty record',
      );
    });
  });

  group('CLAIM — resolution moves stock (idempotent)', () {
    test('write_off for qty 3 decrements stock by 3 exactly once', () async {
      final db = GetIt.I<AppDatabase>();
      const ucode = 8001;
      await seedProduct(db, ucode: ucode, qty: '10');

      final claims = GetIt.I<ClaimUseCase>();
      final created = await claims.createClaim(
        claimType: 'quality',
        ucode: ucode,
        quantity: d('3'),
        operatorId: 1,
        problemDescription: 'Брак',
      );
      expect(created.success, isTrue);
      final claimId = created.id!;

      expect((await db.productInfoDao.findByUcode(ucode))!.quantity, d('10'));

      final res = await claims.resolveClaim(
        claimId,
        resolutionType: 'write_off',
        resolvedBy: 1,
      );
      expect(res.success, isTrue);

      expect(
        (await db.productInfoDao.findByUcode(ucode))!.quantity,
        d('7'),
        reason: 'write_off must decrement stock by claim qty (3)',
      );

      await claims.resolveClaim(
        claimId,
        resolutionType: 'write_off',
        resolvedBy: 1,
      );
      expect(
        (await db.productInfoDao.findByUcode(ucode))!.quantity,
        d('7'),
        reason: 'resolving again must not move stock a second time',
      );
    });

    test(
      'return_to_supplier for qty 2.5 decrements exactly (Decimal-exact)',
      () async {
        final db = GetIt.I<AppDatabase>();
        const ucode = 8002;
        await seedProduct(db, ucode: ucode, qty: '5.5');

        final claims = GetIt.I<ClaimUseCase>();
        final created = await claims.createClaim(
          claimType: 'supplier',
          ucode: ucode,
          quantity: d('2.5'),
          operatorId: 1,
          problemDescription: 'Брак поставщика',
        );
        final claimId = created.id!;

        await claims.resolveClaim(
          claimId,
          resolutionType: 'return_to_supplier',
          resolvedBy: 1,
        );

        expect(
          (await db.productInfoDao.findByUcode(ucode))!.quantity,
          d('3'),
          reason: '5.5 - 2.5 = 3 exactly',
        );
      },
    );

    test('repair resolution does NOT move stock', () async {
      final db = GetIt.I<AppDatabase>();
      const ucode = 8003;
      await seedProduct(db, ucode: ucode, qty: '4');

      final claims = GetIt.I<ClaimUseCase>();
      final created = await claims.createClaim(
        claimType: 'warranty',
        ucode: ucode,
        quantity: d('1'),
        operatorId: 1,
        problemDescription: 'Гарантийный ремонт',
      );
      await claims.resolveClaim(
        created.id!,
        resolutionType: 'repair',
        resolvedBy: 1,
      );

      expect(
        (await db.productInfoDao.findByUcode(ucode))!.quantity,
        d('4'),
        reason: 'repair keeps the item — stock must not change',
      );
    });
  });
}

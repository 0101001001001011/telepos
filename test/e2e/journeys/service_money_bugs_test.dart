library;

import 'package:drift/drift.dart' as drift;
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';

import 'package:telepos/core/constants/enums/service_order_status.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/domain/usecases/service/add_service_mark_use_case.dart';
import 'package:telepos/domain/usecases/service/approve_service_mark_use_case.dart';
import 'package:telepos/domain/usecases/service/service_order_transition_use_case.dart';

import '../support/harness.dart';

void main() {
  final h = E2eHarness();

  setUpAll(() async {
    await h.setUp();
    GetIt.I.registerSingleton<AppDatabase>(h.db);
  });
  tearDownAll(() => h.tearDown());

  Future<int> seedOrder(AppDatabase db, {int status = 0}) async {
    return db.serviceOrderDao.insert(
      ServiceOrdersCompanion.insert(
        orderNumber: 'SO-TEST-${DateTime.now().microsecondsSinceEpoch}',
        status: drift.Value(status),
        userId: 1,
        intakeTime: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      ),
    );
  }

  Future<void> seedMark(
    AppDatabase db, {
    required int orderId,
    required String cost,
    int? approvalStatus,
    String desc = 'work',
  }) async {
    await db.serviceMarkDao.insert(
      ServiceMarksCompanion(
        serviceOrderId: drift.Value(orderId),
        description: drift.Value(desc),
        markType: const drift.Value(4),
        userId: const drift.Value(1),
        cost: drift.Value(d(cost)),
        createdAt: drift.Value(DateTime.now().millisecondsSinceEpoch ~/ 1000),
        approvalStatus: drift.Value(approvalStatus),
      ),
    );
  }

  Future<void> seedConsumable(
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
            name: drift.Value('Расходник $ucode'),
            type: const drift.Value(5),
            measure: const drift.Value(0),
            quantity: drift.Value(d(qty)),
            categoryId: const drift.Value(1),
            isDeleted: const drift.Value(false),
          ),
        );
    await db
        .into(db.productPrices)
        .insert(
          ProductPricesCompanion(
            ucode: drift.Value(ucode),
            barcode: drift.Value(ucode),
            sellingPrice: drift.Value(d('100')),
            wholesalePrice: drift.Value(d('100')),
          ),
        );
  }

  group('B3 — approval filter on closing total', () {
    test('sumCostByOrder counts ONLY approved/implicit marks '
        '(excludes rejected AND pending)', () async {
      final db = GetIt.I<AppDatabase>();
      final orderId = await seedOrder(db);

      await seedMark(db, orderId: orderId, cost: '1000');
      await seedMark(db, orderId: orderId, cost: '2000', approvalStatus: 1);
      await seedMark(db, orderId: orderId, cost: '5000', approvalStatus: 2);
      await seedMark(db, orderId: orderId, cost: '4000', approvalStatus: 0);

      final total = await db.serviceMarkDao.sumCostByOrder(orderId);

      expect(
        total,
        d('3000'),
        reason:
            'closing total must exclude rejected (5000) AND pending '
            '(4000); only approved/implicit (1000+2000) is chargeable',
      );
    });

    test(
      'completed->closed is BLOCKED while a mark is pending approval',
      () async {
        final db = GetIt.I<AppDatabase>();
        final orderId = await seedOrder(db, status: 2);
        await seedMark(db, orderId: orderId, cost: '1000', approvalStatus: 1);
        await seedMark(db, orderId: orderId, cost: '4000', approvalStatus: 0);

        final transition = GetIt.I<ServiceOrderTransitionUseCase>();

        await expectLater(
          transition.progress(orderId),
          throwsA(isA<StateError>()),
          reason: 'must not close an order with pending approvals',
        );

        final row = await db.serviceOrderDao.findById(orderId);
        expect(
          row!.status,
          ServiceOrderStatus.completed.index,
          reason: 'blocked transition must leave status at completed',
        );
      },
    );
  });

  group('B4 — Decimal-exact closing total', () {
    test(
      'sumCostByOrder round-trips a non-double-exact value losslessly',
      () async {
        final db = GetIt.I<AppDatabase>();
        final orderId = await seedOrder(db);

        await seedMark(db, orderId: orderId, cost: '0.1');
        await seedMark(db, orderId: orderId, cost: '0.2');

        final total = await db.serviceMarkDao.sumCostByOrder(orderId);
        expect(
          total,
          d('0.3'),
          reason: 'Decimal sum must be exact 0.3, not a double-rounded value',
        );

        final orderId2 = await seedOrder(db);
        await seedMark(db, orderId: orderId2, cost: '10.005');
        await seedMark(db, orderId: orderId2, cost: '10.005');
        await seedMark(db, orderId: orderId2, cost: '10.005');
        final total2 = await db.serviceMarkDao.sumCostByOrder(orderId2);
        expect(total2, d('30.015'), reason: 'P18,S3 sum must be exact 30.015');
      },
    );
  });

  group('B1/B5 — consumable stock deduct/restore is balanced', () {
    test(
      'adding a consumable deducts the REAL quantity (not hardcoded 1)',
      () async {
        final db = GetIt.I<AppDatabase>();
        const ucode = 9001;
        await seedConsumable(db, ucode: ucode, qty: '100');
        final orderId = await seedOrder(db);

        final addUseCase = GetIt.I<AddServiceMarkUseCase>();
        await addUseCase.add(
          serviceOrderId: orderId,
          description: 'Расходник x5',
          markType: 5,
          userId: 1,
          cost: d('500'),
          productUcode: ucode,
          quantity: d('5'),
        );

        final after = await db.productInfoDao.findByUcode(ucode);
        expect(
          after!.quantity,
          d('95'),
          reason: 'stock must drop by the REAL quantity 5, not by 1',
        );
      },
    );

    test('the deducted quantity is STORED on the mark (reversible)', () async {
      final db = GetIt.I<AppDatabase>();
      const ucode = 9002;
      await seedConsumable(db, ucode: ucode, qty: '100');
      final orderId = await seedOrder(db);

      final addUseCase = GetIt.I<AddServiceMarkUseCase>();
      final mark = await addUseCase.add(
        serviceOrderId: orderId,
        description: 'Расходник x7',
        markType: 5,
        userId: 1,
        cost: d('700'),
        productUcode: ucode,
        quantity: d('7'),
      );

      final row = await db.serviceMarkDao.findById(mark.id!);
      expect(
        row!.quantity,
        d('7'),
        reason: 'the mark must persist its deducted quantity for reversal',
      );
    });

    test(
      'add 5 then REJECT restores stock — net unchanged (balanced)',
      () async {
        final db = GetIt.I<AppDatabase>();
        const ucode = 9003;
        await seedConsumable(db, ucode: ucode, qty: '100');
        final orderId = await seedOrder(db);

        final addUseCase = GetIt.I<AddServiceMarkUseCase>();
        final mark = await addUseCase.add(
          serviceOrderId: orderId,
          description: 'Расходник x5',
          markType: 5,
          userId: 1,
          cost: d('500'),
          productUcode: ucode,
          quantity: d('5'),
          approvalStatus: 0,
        );

        expect((await db.productInfoDao.findByUcode(ucode))!.quantity, d('95'));

        final approveUseCase = GetIt.I<ApproveServiceMarkUseCase>();
        await approveUseCase.reject(markId: mark.id!, approverUserId: 1);

        final after = await db.productInfoDao.findByUcode(ucode);
        expect(
          after!.quantity,
          d('100'),
          reason:
              'rejecting a consumable mark must restore the 5 units '
              '(net stock unchanged)',
        );
      },
    );

    test('add 5 then DELETE restores stock — net unchanged', () async {
      final db = GetIt.I<AppDatabase>();
      const ucode = 9004;
      await seedConsumable(db, ucode: ucode, qty: '100');
      final orderId = await seedOrder(db);

      final addUseCase = GetIt.I<AddServiceMarkUseCase>();
      final mark = await addUseCase.add(
        serviceOrderId: orderId,
        description: 'Расходник x5',
        markType: 5,
        userId: 1,
        cost: d('500'),
        productUcode: ucode,
        quantity: d('5'),
      );
      expect((await db.productInfoDao.findByUcode(ucode))!.quantity, d('95'));

      await db.serviceMarkDao.deleteByIdRestoringStock(mark.id!);

      final after = await db.productInfoDao.findByUcode(ucode);
      expect(
        after!.quantity,
        d('100'),
        reason: 'deleting a consumable mark must restore stock',
      );
    });

    test('CANCELLING the order restores all consumed stock', () async {
      final db = GetIt.I<AppDatabase>();
      const ucode = 9005;
      await seedConsumable(db, ucode: ucode, qty: '50');
      final orderId = await seedOrder(db);

      final addUseCase = GetIt.I<AddServiceMarkUseCase>();
      await addUseCase.add(
        serviceOrderId: orderId,
        description: 'Расходник x8',
        markType: 5,
        userId: 1,
        cost: d('800'),
        productUcode: ucode,
        quantity: d('8'),
      );
      expect((await db.productInfoDao.findByUcode(ucode))!.quantity, d('42'));

      final transition = GetIt.I<ServiceOrderTransitionUseCase>();
      await transition.cancel(orderId);

      final after = await db.productInfoDao.findByUcode(ucode);
      expect(
        after!.quantity,
        d('50'),
        reason: 'cancelling the order must return all consumed stock',
      );
    });
  });
}

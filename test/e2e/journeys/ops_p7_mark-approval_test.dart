library;

import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';

import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/domain/usecases/service/add_service_mark_use_case.dart';
import 'package:telepos/domain/usecases/service/approve_service_mark_use_case.dart';
import 'package:telepos/domain/usecases/service/create_service_order_use_case.dart';

import '../support/harness.dart';

void main() {
  final h = E2eHarness();

  setUpAll(() async {
    await h.setUp();
    GetIt.I.registerSingleton<AppDatabase>(h.db);
  });
  tearDownAll(() => h.tearDown());

  setUp(() async {
    await h.db.delete(h.db.serviceMarks).go();
    await h.db.delete(h.db.serviceOrders).go();
  });

  test(
    'approving a pending mark flips status to approved and persists',
    () async {
      final db = GetIt.I<AppDatabase>();
      final addMark = GetIt.I<AddServiceMarkUseCase>();
      final approve = GetIt.I<ApproveServiceMarkUseCase>();
      final createOrder = GetIt.I<CreateServiceOrderUseCase>();

      final order = await createOrder.create(
        userId: 1,
        clientName: 'Клиент А',
        complaint: 'Доп. работа на согласование',
      );

      final mark = await addMark.add(
        serviceOrderId: order.id,
        description: 'Замена аккумулятора (предложено мастером)',
        markType: 1,
        userId: 1,
        cost: d('8000'),
        approvalStatus: 0,
      );
      expect(mark.id, isNotNull);
      expect(
        mark.isPendingApproval,
        isTrue,
        reason: 'mark must start pending approval',
      );

      final approved = await approve.approve(
        markId: mark.id!,
        approverUserId: 2,
      );
      expect(
        approved.approvalStatus,
        1,
        reason: 'returned entity must be approved (1)',
      );
      expect(approved.isApproved, isTrue);
      expect(
        approved.cost,
        d('8000'),
        reason: 'cost stays Decimal-exact through approval',
      );

      final row = await (db.select(
        db.serviceMarks,
      )..where((m) => m.id.equals(mark.id!))).getSingle();
      expect(
        row.approvalStatus,
        1,
        reason: 'approved status must be persisted to the DB',
      );

      final pending = await db.serviceMarkDao.getOrderIdsWithPendingApprovals();
      expect(
        pending.contains(order.id),
        isFalse,
        reason: 'order no longer has pending approvals after approve',
      );
    },
  );

  test(
    'rejecting a pending mark flips status to rejected and persists',
    () async {
      final db = GetIt.I<AppDatabase>();
      final addMark = GetIt.I<AddServiceMarkUseCase>();
      final approve = GetIt.I<ApproveServiceMarkUseCase>();
      final createOrder = GetIt.I<CreateServiceOrderUseCase>();

      final order = await createOrder.create(
        userId: 1,
        clientName: 'Клиент Б',
        complaint: 'Доп. работа на согласование',
      );

      final mark = await addMark.add(
        serviceOrderId: order.id,
        description: 'Полировка корпуса (предложено мастером)',
        markType: 2,
        userId: 1,
        cost: d('3000'),
        approvalStatus: 0,
      );
      expect(mark.isPendingApproval, isTrue);

      final rejected = await approve.reject(
        markId: mark.id!,
        approverUserId: 2,
      );
      expect(
        rejected.approvalStatus,
        2,
        reason: 'returned entity must be rejected (2)',
      );
      expect(rejected.isRejected, isTrue);

      final row = await (db.select(
        db.serviceMarks,
      )..where((m) => m.id.equals(mark.id!))).getSingle();
      expect(
        row.approvalStatus,
        2,
        reason: 'rejected status must be persisted to the DB',
      );

      final pending = await db.serviceMarkDao.getOrderIdsWithPendingApprovals();
      expect(
        pending.contains(order.id),
        isFalse,
        reason: 'a rejected mark is no longer pending',
      );
    },
  );
}

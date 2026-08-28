import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/database/tables/service_order_tables.dart';

part 'service_mark_dao.g.dart';

@DriftAccessor(tables: [ServiceMarks])
class ServiceMarkDao extends DatabaseAccessor<AppDatabase>
    with _$ServiceMarkDaoMixin {
  ServiceMarkDao(super.db);

  Future<List<ServiceMark>> getByOrder(int serviceOrderId) =>
      (select(serviceMarks)
            ..where((m) => m.serviceOrderId.equals(serviceOrderId))
            ..orderBy([(m) => OrderingTerm.asc(m.createdAt)]))
          .get();

  Future<Decimal> sumCostByOrder(int serviceOrderId) async {
    final marks = await getByOrder(serviceOrderId);
    return marks
        .where(_isChargeable)
        .fold<Decimal>(
          Decimal.zero,
          (sum, m) => sum + (m.cost ?? Decimal.zero),
        );
  }

  bool _isChargeable(ServiceMark m) =>
      m.approvalStatus == null || m.approvalStatus == 1;

  Future<int> insert(ServiceMarksCompanion entry) =>
      into(serviceMarks).insert(entry);

  Future<ServiceMark?> findById(int id) =>
      (select(serviceMarks)..where((m) => m.id.equals(id))).getSingleOrNull();

  Future<int> deleteById(int id) =>
      (delete(serviceMarks)..where((m) => m.id.equals(id))).go();

  Future<int> deleteByIdRestoringStock(int id) async {
    final mark = await findById(id);
    if (mark == null) return 0;
    await restoreStockFor(mark);
    return deleteById(id);
  }

  Future<void> restoreStockFor(ServiceMark mark) async {
    final ucode = mark.productUcode;
    final isConsumable = mark.markType == 5 || mark.markType == 1;
    if (ucode == null || !isConsumable) return;
    final qty = mark.quantity;
    if (qty <= Decimal.zero) return;
    await db.productInfoDao.adjustQuantity(ucode, qty);
  }

  Future<int> updateApprovalStatus(int id, int? status) =>
      (update(serviceMarks)..where((m) => m.id.equals(id))).write(
        ServiceMarksCompanion(approvalStatus: Value(status)),
      );

  Future<Set<int>> getOrderIdsWithPendingApprovals() async {
    final rows = await customSelect(
      'SELECT DISTINCT service_order_id FROM service_marks WHERE approval_status = 0',
      readsFrom: {serviceMarks},
    ).get();
    return rows.map((r) => r.read<int>('service_order_id')).toSet();
  }

  Future<bool> hasPendingApprovals(int serviceOrderId) async {
    final rows = await customSelect(
      'SELECT 1 FROM service_marks '
      'WHERE service_order_id = ? AND approval_status = 0 LIMIT 1',
      variables: [Variable.withInt(serviceOrderId)],
      readsFrom: {serviceMarks},
    ).get();
    return rows.isNotEmpty;
  }
}

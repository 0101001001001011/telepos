import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/database/tables/refund_tables.dart';

part 'refund_dao.g.dart';

@DriftAccessor(tables: [Refunds, RefundProducts, RefundProductMarks])
class RefundDao extends DatabaseAccessor<AppDatabase> with _$RefundDaoMixin {
  RefundDao(super.db);

  Future<Refund?> findById(int localId) => (select(
    refunds,
  )..where((r) => r.localId.equals(localId))).getSingleOrNull();

  Future<Refund?> findWithState(int state) =>
      (select(refunds)..where((r) => r.state.equals(state))).getSingleOrNull();

  Future<List<Refund>> findByState(int state) =>
      (select(refunds)..where((r) => r.state.equals(state))).get();

  Future<List<QueryRow>> findToUpload(int state) => customSelect(
    'SELECT DISTINCT r.* FROM refunds r '
    'LEFT JOIN refund_products rp ON r.local_id = rp.refund_local_id '
    'LEFT JOIN product_info_editions pe ON rp.ucode = pe.ucode '
    'LEFT JOIN product_price_editions ppe ON ppe.ucode = rp.ucode '
    'WHERE r.state = ? '
    'AND (r.customer_local_id IS NULL OR r.customer_server_id IS NOT NULL) '
    'GROUP BY r.local_id '
    'HAVING COUNT(pe.ucode) = 0 AND COUNT(ppe.ucode) = 0',
    variables: [Variable.withInt(state)],
    readsFrom: {refunds},
  ).get();

  Future<Refund?> findBySale(int receiptNo, int posId) =>
      (select(refunds)..where(
            (r) =>
                r.saleReceiptNo.equals(receiptNo) & r.salePosId.equals(posId),
          ))
          .getSingleOrNull();

  Future<double?> sumAmountByCustomerLocalId(int customerLocalId) {
    final expr = refunds.amount.sum();
    return (selectOnly(refunds)
          ..addColumns([expr])
          ..where(refunds.customerLocalId.equals(customerLocalId)))
        .map((row) => row.read(expr))
        .getSingleOrNull();
  }

  Future<List<Refund>> findWithNoCustomerLocId(List<int> serverIds) =>
      (select(refunds)..where(
            (r) =>
                r.customerServerId.isIn(serverIds) & r.customerLocalId.isNull(),
          ))
          .get();

  Future<int?> findLocalIdByServerId(int serverId) {
    final expr = refunds.localId;
    return (selectOnly(refunds)
          ..addColumns([expr])
          ..where(refunds.serverId.equals(serverId)))
        .map((row) => row.read(expr))
        .getSingleOrNull();
  }

  Future<Refund?> findLast() =>
      (select(refunds)
            ..where((r) => r.state.equals(4))
            ..orderBy([(r) => OrderingTerm.desc(r.time)])
            ..limit(1))
          .getSingleOrNull();

  Future<int> setAgentServerIdByLocalId(int localId, int serverId) =>
      (update(refunds)..where((r) => r.customerLocalId.equals(localId))).write(
        RefundsCompanion(customerServerId: Value(serverId)),
      );

  Future<int> setState(int state, List<int> refundIds) =>
      (update(refunds)..where((r) => r.localId.isIn(refundIds))).write(
        RefundsCompanion(state: Value(state)),
      );

  Future<int> countWithState(int state) {
    final expr = refunds.localId.count();
    return (selectOnly(refunds)
          ..addColumns([expr])
          ..where(refunds.state.equals(state)))
        .map((row) => row.read(expr)!)
        .getSingle();
  }

  Future<int?> findMaxSyncedRefundId() {
    final expr = refunds.serverId.max();
    return (selectOnly(refunds)
          ..addColumns([expr])
          ..where(refunds.state.equals(4)))
        .map((row) => row.read(expr))
        .getSingleOrNull();
  }

  Future<int> setSaleId(int saleReceiptNo, int salePosId, int saleId) =>
      (update(refunds)..where(
            (r) =>
                r.saleReceiptNo.equals(saleReceiptNo) &
                r.salePosId.equals(salePosId),
          ))
          .write(RefundsCompanion(saleId: Value(saleId)));

  Future<int> setServerId(int localId, int serverId) =>
      (update(refunds)..where((r) => r.localId.equals(localId))).write(
        RefundsCompanion(serverId: Value(serverId)),
      );

  Future<List<RefundProduct>> findProductsByRefund(int refundLocalId) =>
      (select(
        refundProducts,
      )..where((rp) => rp.refundLocalId.equals(refundLocalId))).get();

  Future<int> setProductQuantity(int id, double quantity) =>
      (update(refundProducts)..where((rp) => rp.id.equals(id))).write(
        RefundProductsCompanion(
          quantity: Value(Decimal.parse(quantity.toString())),
        ),
      );

  Future<List<RefundProductMark>> findMarksByMark(String mark) =>
      (select(refundProductMarks)..where((rpm) => rpm.mark.equals(mark))).get();

  Future<List<RefundProductMark>> findMarksByRefundProduct(
    int refundProductId,
  ) => (select(
    refundProductMarks,
  )..where((rpm) => rpm.refundProductId.equals(refundProductId))).get();
}

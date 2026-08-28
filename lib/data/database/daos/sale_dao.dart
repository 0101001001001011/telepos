import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/database/tables/sale_tables.dart';

part 'sale_dao.g.dart';

@DriftAccessor(tables: [Sales, SaleWithdrawals])
class SaleDao extends DatabaseAccessor<AppDatabase> with _$SaleDaoMixin {
  SaleDao(super.db);

  Future<Sale?> findByKey(int receiptNo, int posId) =>
      (select(sales)..where(
            (s) => s.receiptNo.equals(receiptNo) & s.posId.equals(posId),
          ))
          .getSingleOrNull();

  Future<Sale?> findBySaleId(int saleId) =>
      (select(sales)..where((s) => s.saleId.equals(saleId))).getSingleOrNull();

  Future<int?> findLastReceiptNo() {
    final expr = sales.receiptNo.max();
    return (selectOnly(
      sales,
    )..addColumns([expr])).map((row) => row.read(expr)).getSingleOrNull();
  }

  Future<Sale?> findInProgress() async {
    final results =
        await (select(sales)
              ..where((s) => s.state.equals(0))
              ..limit(1))
            .get();
    return results.isEmpty ? null : results.first;
  }

  Future<int> updateState(int receiptNo, int posId, int state) =>
      (update(sales)..where(
            (s) => s.receiptNo.equals(receiptNo) & s.posId.equals(posId),
          ))
          .write(SalesCompanion(state: Value(state)));

  Future<List<Sale>> findByState(int state) =>
      (select(sales)..where((s) => s.state.equals(state))).get();

  Future<List<Sale>> findRecentCompleted({int limit = 30}) =>
      (select(sales)
            ..where(
              (s) => s.state.isNotIn([0, 3]) & s.time.isBiggerThanValue(0),
            )
            ..orderBy([(s) => OrderingTerm.desc(s.time)])
            ..limit(limit))
          .get();

  Future<List<QueryRow>> findToUpload(
    int state, {
    int limit = 100,
  }) => customSelect(
    'SELECT DISTINCT s.* FROM sales s '
    'LEFT JOIN sale_products sp ON s.pos_id = sp.pos_id AND s.receipt_no = sp.receipt_no '
    'LEFT JOIN product_info_editions pe ON sp.ucode = pe.ucode '
    'LEFT JOIN product_price_editions ppe ON ppe.ucode = sp.ucode '
    'WHERE s.state = ? '
    'AND (s.customer_local_id IS NULL OR s.customer_server_id IS NOT NULL) '
    'GROUP BY s.receipt_no, s.pos_id '
    'HAVING COUNT(pe.ucode) = 0 AND COUNT(ppe.ucode) = 0 '
    'LIMIT ?',
    variables: [Variable.withInt(state), Variable.withInt(limit)],
    readsFrom: {sales},
  ).get();

  Future<int> countWithState(int state) {
    final expr = sales.receiptNo.count();
    return (selectOnly(sales)
          ..addColumns([expr])
          ..where(sales.state.equals(state)))
        .map((row) => row.read(expr)!)
        .getSingle();
  }

  Future<int> countBetweenDate(int startDate, int endDate) {
    final expr = sales.receiptNo.count();
    return (selectOnly(sales)
          ..addColumns([expr])
          ..where(
            sales.time.isBiggerThanValue(startDate) &
                sales.time.isSmallerThanValue(endDate) &
                sales.state.equals(3).not(),
          ))
        .map((row) => row.read(expr)!)
        .getSingle();
  }

  Future<Sale?> findFirstSaleAfter(int timestamp) =>
      (select(sales)
            ..where(
              (s) =>
                  s.time.isBiggerThanValue(timestamp) & s.state.equals(3).not(),
            )
            ..orderBy([(s) => OrderingTerm.asc(s.time)])
            ..limit(1))
          .getSingleOrNull();

  Future<List<Sale>> findSalesToDelete(int threeMonthEarly) =>
      (select(sales)..where(
            (s) =>
                s.time.isSmallerThanValue(threeMonthEarly) &
                s.state.equals(4) &
                s.customerLocalId.isNull() &
                s.customerServerId.isNull(),
          ))
          .get();

  Future<double?> sumAmountByCustomerLocalId(int customerLocalId) {
    final expr = sales.amount.sum();
    return (selectOnly(sales)
          ..addColumns([expr])
          ..where(sales.customerLocalId.equals(customerLocalId)))
        .map((row) => row.read(expr))
        .getSingleOrNull();
  }

  Future<int?> findMaxSyncedSaleId() {
    final expr = sales.saleId.max();
    return (selectOnly(sales)
          ..addColumns([expr])
          ..where(sales.state.equals(4)))
        .map((row) => row.read(expr))
        .getSingleOrNull();
  }

  Future<List<Sale>> findWithNoCustomerLocId(List<int> serverIds) =>
      (select(sales)..where(
            (s) =>
                s.customerServerId.isIn(serverIds) & s.customerLocalId.isNull(),
          ))
          .get();

  Future<List<QueryRow>> findLastForeign() => customSelect(
    'SELECT * FROM sales WHERE pos_id NOT IN (SELECT id FROM this_pos_entries) ORDER BY time DESC LIMIT 1',
    readsFrom: {sales},
  ).get();

  Future<int> markSyncedByKey(
    int receiptNo,
    int posId, {
    int syncedState = 4,
  }) =>
      (update(sales)..where(
            (s) => s.receiptNo.equals(receiptNo) & s.posId.equals(posId),
          ))
          .write(SalesCompanion(state: Value(syncedState)));

  Future<int> setState(int state, int posId, List<int> receiptNos) =>
      (update(
            sales,
          )..where((s) => s.receiptNo.isIn(receiptNos) & s.posId.equals(posId)))
          .write(SalesCompanion(state: Value(state)));

  Future<int> setAgentServerIdByLocalId(int localId, int serverId) =>
      (update(sales)..where((s) => s.customerLocalId.equals(localId))).write(
        SalesCompanion(customerServerId: Value(serverId)),
      );

  Future<double?> amountOfShift(int userId, int fromTime, int toTime) {
    final expr = sales.amount.sum();
    return (selectOnly(sales)
          ..addColumns([expr])
          ..where(
            sales.userId.equals(userId) &
                sales.time.isBetweenValues(fromTime, toTime),
          ))
        .map((row) => row.read(expr))
        .getSingleOrNull();
  }

  Future<List<Sale>> findByPosIdAndBetweenDate(
    int posId,
    int startDate,
    int endDate, {
    int limit = 100,
  }) =>
      (select(sales)
            ..where(
              (s) =>
                  s.posId.equals(posId) &
                  s.time.isBiggerThanValue(startDate) &
                  s.time.isSmallerThanValue(endDate) &
                  s.state.equals(3).not(),
            )
            ..orderBy([(s) => OrderingTerm.desc(s.time)])
            ..limit(limit))
          .get();

  Future<int> setSaleId(int receiptNo, int posId, int saleId) =>
      (update(sales)..where(
            (s) => s.receiptNo.equals(receiptNo) & s.posId.equals(posId),
          ))
          .write(SalesCompanion(saleId: Value(saleId)));

  Future<int> setIsWholesale(int receiptNo, int posId, bool isWholesale) =>
      (update(sales)..where(
            (s) => s.receiptNo.equals(receiptNo) & s.posId.equals(posId),
          ))
          .write(SalesCompanion(isWholesale: Value(isWholesale)));

  Future<int> setAmount(int receiptNo, int posId, Decimal amount) =>
      (update(sales)..where(
            (s) => s.receiptNo.equals(receiptNo) & s.posId.equals(posId),
          ))
          .write(SalesCompanion(amount: Value(amount)));

  Future<SaleWithdrawal?> findWithdrawalByReceiptNo(int receiptNo) => (select(
    saleWithdrawals,
  )..where((sw) => sw.receiptNo.equals(receiptNo))).getSingleOrNull();

  Future<SaleWithdrawal?> findWithdrawalBySale(int receiptNo, int posId) =>
      (select(saleWithdrawals)..where(
            (sw) => sw.receiptNo.equals(receiptNo) & sw.posId.equals(posId),
          ))
          .getSingleOrNull();

  Future<List<Sale>> findOldSyncedSales(int cutoffTimestamp) =>
      (select(sales)..where(
            (s) =>
                s.time.isSmallerThanValue(cutoffTimestamp) & s.state.equals(4),
          ))
          .get();

  Future<int> deleteSale(int receiptNo, int posId) => (delete(
    sales,
  )..where((s) => s.receiptNo.equals(receiptNo) & s.posId.equals(posId))).go();

  Future<int> deleteSales(List<({int receiptNo, int posId})> keys) async {
    int deleted = 0;
    for (final key in keys) {
      deleted += await deleteSale(key.receiptNo, key.posId);
    }
    return deleted;
  }
}

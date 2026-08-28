import 'package:drift/drift.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/database/tables/payment_tables.dart';

part 'payment_dao.g.dart';

@DriftAccessor(tables: [Payments])
class PaymentDao extends DatabaseAccessor<AppDatabase> with _$PaymentDaoMixin {
  PaymentDao(super.db);

  Future<List<Payment>> findBySale(int receiptNo, int posId) => (select(
    payments,
  )..where((p) => p.receiptNo.equals(receiptNo) & p.posId.equals(posId))).get();

  Future<List<Payment>> findByRefund(int refundLocalId) => (select(
    payments,
  )..where((p) => p.refundLocalId.equals(refundLocalId))).get();

  Future<double?> sumByUserAndPayeeAccountIdBetween(
    int userId,
    int payeeAccountId,
    int startDate,
    int endDate,
  ) {
    final expr = payments.amount.sum();
    return (selectOnly(payments)
          ..addColumns([expr])
          ..where(
            payments.userId.equals(userId) &
                payments.payeeAccountId.equals(payeeAccountId) &
                payments.time.isBetweenValues(startDate, endDate) &
                payments.receiptNo.isNotNull() &
                payments.posId.isNotNull(),
          ))
        .map((row) => row.read(expr))
        .getSingleOrNull();
  }

  Future<List<QueryRow>> findDebtPaymentsWithState(int state) => customSelect(
    'SELECT p.id, p.user_id, ac.id AS agent_account_id, p.payee_account_id, p.amount, p.time '
    'FROM payments p '
    'JOIN agents ag ON ag.local_id = p.customer_local_id '
    'JOIN accounts ac ON ac.agent_id = ag.server_id AND ac.type = 3 '
    'WHERE ac.id IS NOT NULL AND p.state = ?',
    variables: [Variable.withInt(state)],
    readsFrom: {payments},
  ).get();

  Future<List<QueryRow>> findUnSyncedDebtPayments() => customSelect(
    'SELECT p.id, p.user_id, ac.id AS agent_account_id, p.payee_account_id, p.amount, p.time '
    'FROM payments p '
    'JOIN agents ag ON ag.local_id = p.customer_local_id '
    'JOIN accounts ac ON ac.agent_id = ag.server_id AND ac.type = 3 '
    'WHERE ac.id IS NOT NULL AND p.state <> 4',
    readsFrom: {payments},
  ).get();

  Future<int> countUnsynced() {
    final expr = payments.id.count();
    return (selectOnly(payments)
          ..addColumns([expr])
          ..where(
            payments.state.equals(1) &
                payments.receiptNo.isNull() &
                payments.refundLocalId.isNull(),
          ))
        .map((row) => row.read(expr)!)
        .getSingle();
  }

  Future<double?> sumAmountByCustomerLocalId(int customerLocalId) {
    final expr = payments.amount.sum();
    return (selectOnly(payments)
          ..addColumns([expr])
          ..where(payments.customerLocalId.equals(customerLocalId)))
        .map((row) => row.read(expr))
        .getSingleOrNull();
  }

  Future<int> setState(List<int> ids, int state) =>
      (update(payments)..where((p) => p.id.isIn(ids))).write(
        PaymentsCompanion(state: Value(state)),
      );

  Future<int?> findIdByRefund(int refundLocalId, int payeeAccountId) {
    final expr = payments.id;
    return (selectOnly(payments)
          ..addColumns([expr])
          ..where(
            payments.payeeAccountId.equals(payeeAccountId) &
                payments.refundLocalId.equals(refundLocalId),
          ))
        .map((row) => row.read(expr))
        .getSingleOrNull();
  }

  Future<int> countBySale(int receiptNo, int posId) {
    final expr = payments.id.count();
    return (selectOnly(payments)
          ..addColumns([expr])
          ..where(
            payments.receiptNo.equals(receiptNo) & payments.posId.equals(posId),
          ))
        .map((row) => row.read(expr)!)
        .getSingle();
  }

  Future<int> deleteBySale(int receiptNo, int posId) => (delete(
    payments,
  )..where((p) => p.receiptNo.equals(receiptNo) & p.posId.equals(posId))).go();
}

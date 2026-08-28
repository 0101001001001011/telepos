import 'package:drift/drift.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/database/tables/cash_operation_tables.dart';

part 'cash_operation_dao.g.dart';

@DriftAccessor(tables: [CashOperations, CashOperationCustomFields])
class CashOperationDao extends DatabaseAccessor<AppDatabase>
    with _$CashOperationDaoMixin {
  CashOperationDao(super.db);

  Future<int> insert(CashOperationsCompanion operation) =>
      into(cashOperations).insert(operation);

  Future<CashOperation?> findById(int id) => (select(
    cashOperations,
  )..where((co) => co.id.equals(id))).getSingleOrNull();

  Future<List<CashOperation>> findByState(int state) =>
      (select(cashOperations)..where((co) => co.state.equals(state))).get();

  Future<List<CashOperation>> findByTimeRange(int fromTime, {int? toTime}) {
    final endTime = toTime ?? (DateTime.now().millisecondsSinceEpoch ~/ 1000);
    return (select(cashOperations)
          ..where(
            (co) =>
                co.docTime.isBiggerOrEqualValue(fromTime) &
                co.docTime.isSmallerOrEqualValue(endTime),
          )
          ..orderBy([(co) => OrderingTerm.desc(co.docTime)]))
        .get();
  }

  Future<List<CashOperationCustomField>> findCustomFieldsByOperation(
    int cashOperationId,
  ) => (select(
    cashOperationCustomFields,
  )..where((cf) => cf.cashOperationId.equals(cashOperationId))).get();
}

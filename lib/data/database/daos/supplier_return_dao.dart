import 'package:drift/drift.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/database/tables/supplier_return_tables.dart';

part 'supplier_return_dao.g.dart';

@DriftAccessor(tables: [SupplierReturns])
class SupplierReturnDao extends DatabaseAccessor<AppDatabase>
    with _$SupplierReturnDaoMixin {
  SupplierReturnDao(super.db);

  Future<List<SupplierReturn>> findAll({int limit = 50, int offset = 0}) =>
      (select(supplierReturns)
            ..orderBy([(sr) => OrderingTerm.desc(sr.editTime)])
            ..limit(limit, offset: offset))
          .get();

  Future<SupplierReturn?> findById(int id) => (select(
    supplierReturns,
  )..where((sr) => sr.id.equals(id))).getSingleOrNull();

  Future<int> insertReturn(SupplierReturnsCompanion supplierReturn) =>
      into(supplierReturns).insert(supplierReturn);

  Future<int> updateReturn(int id, SupplierReturnsCompanion supplierReturn) =>
      (update(
        supplierReturns,
      )..where((sr) => sr.id.equals(id))).write(supplierReturn);

  Future<int> deleteReturn(int id) =>
      (delete(supplierReturns)..where((sr) => sr.id.equals(id))).go();

  Future<int> countAll() {
    final expr = supplierReturns.id.count();
    return (selectOnly(
      supplierReturns,
    )..addColumns([expr])).map((row) => row.read(expr)!).getSingle();
  }

  Future<List<SupplierReturn>> findNonSynced() =>
      (select(supplierReturns)..where((sr) => sr.state.equals(3).not())).get();

  Future<int> countUnsynced() {
    final expr = supplierReturns.id.count();
    return (selectOnly(supplierReturns)
          ..addColumns([expr])
          ..where(supplierReturns.state.equals(3).not()))
        .map((row) => row.read(expr)!)
        .getSingle();
  }

  Future<int> setResponse(int id, String? msg, int state) =>
      (update(supplierReturns)..where((sr) => sr.id.equals(id))).write(
        SupplierReturnsCompanion(state: Value(state), msg: Value(msg)),
      );

  Future<List<SupplierReturn>> findBySupplierId(int supplierId) =>
      (select(supplierReturns)
            ..where((sr) => sr.supplierId.equals(supplierId))
            ..orderBy([(sr) => OrderingTerm.desc(sr.editTime)]))
          .get();

  Future<List<SupplierReturn>> findFiltered({
    int? dateFrom,
    int? dateTo,
    int? supplierId,
    String? searchQuery,
    int limit = 50,
    int offset = 0,
  }) {
    final query = select(supplierReturns);

    if (dateFrom != null) {
      query.where((sr) => sr.editTime.isBiggerOrEqualValue(dateFrom));
    }
    if (dateTo != null) {
      query.where((sr) => sr.editTime.isSmallerOrEqualValue(dateTo));
    }
    if (supplierId != null) {
      query.where((sr) => sr.supplierId.equals(supplierId));
    }
    if (searchQuery != null && searchQuery.isNotEmpty) {
      query.where((sr) => sr.comment.like('%$searchQuery%'));
    }

    query
      ..orderBy([(sr) => OrderingTerm.desc(sr.editTime)])
      ..limit(limit, offset: offset);

    return query.get();
  }
}

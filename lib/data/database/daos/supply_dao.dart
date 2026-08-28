import 'package:drift/drift.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/database/tables/supply_tables.dart';

part 'supply_dao.g.dart';

@DriftAccessor(tables: [Supplies])
class SupplyDao extends DatabaseAccessor<AppDatabase> with _$SupplyDaoMixin {
  SupplyDao(super.db);

  Future<List<Supply>> findNonSynced() =>
      (select(supplies)..where((s) => s.state.equals(3).not())).get();

  Future<int> countUnsynced() {
    final expr = supplies.id.count();
    return (selectOnly(supplies)
          ..addColumns([expr])
          ..where(supplies.state.equals(3).not()))
        .map((row) => row.read(expr)!)
        .getSingle();
  }

  Future<int> setResponse(int id, String? msg, int state) =>
      (update(supplies)..where((s) => s.id.equals(id))).write(
        SuppliesCompanion(state: Value(state), msg: Value(msg)),
      );

  Future<Supply?> findById(int id) =>
      (select(supplies)..where((s) => s.id.equals(id))).getSingleOrNull();

  Future<Supply?> findDraft() =>
      (select(supplies)..where((s) => s.state.equals(0))).getSingleOrNull();

  Future<int> insertSupply(SuppliesCompanion supply) =>
      into(supplies).insert(supply);

  Future<int> updateSupply(int id, SuppliesCompanion supply) =>
      (update(supplies)..where((s) => s.id.equals(id))).write(supply);

  Future<int> deleteSupply(int id) =>
      (delete(supplies)..where((s) => s.id.equals(id))).go();

  Future<List<Supply>> findAll({int limit = 50, int offset = 0}) =>
      (select(supplies)
            ..orderBy([(s) => OrderingTerm.desc(s.editTime)])
            ..limit(limit, offset: offset))
          .get();

  Future<List<Supply>> findBySupplierId(int supplierId) =>
      (select(supplies)
            ..where((s) => s.supplierId.equals(supplierId))
            ..orderBy([(s) => OrderingTerm.desc(s.editTime)]))
          .get();
}

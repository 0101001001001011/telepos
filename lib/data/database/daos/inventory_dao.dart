import 'package:drift/drift.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/database/tables/inventory_tables.dart';

part 'inventory_dao.g.dart';

@DriftAccessor(tables: [Inventories])
class InventoryDao extends DatabaseAccessor<AppDatabase>
    with _$InventoryDaoMixin {
  InventoryDao(super.db);

  Future<int> insertInventory(InventoriesCompanion inventory) =>
      into(inventories).insert(inventory);

  Future<Inventory?> findById(int id) =>
      (select(inventories)..where((i) => i.id.equals(id))).getSingleOrNull();

  Future<Inventory?> findActive() =>
      (select(inventories)..where((i) => i.status.equals(0))).getSingleOrNull();

  Future<List<Inventory>> findAll({int limit = 50, int offset = 0}) =>
      (select(inventories)
            ..orderBy([(i) => OrderingTerm.desc(i.startTime)])
            ..limit(limit, offset: offset))
          .get();

  Future<int> complete(int id, int discrepancyCount) {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    return (update(inventories)..where((i) => i.id.equals(id))).write(
      InventoriesCompanion(
        status: const Value(1),
        endTime: Value(now),
        discrepancyCount: Value(discrepancyCount),
        state: const Value(1),
      ),
    );
  }

  Future<int> cancel(int id) {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    return (update(inventories)..where((i) => i.id.equals(id))).write(
      InventoriesCompanion(status: const Value(2), endTime: Value(now)),
    );
  }

  Future<List<Inventory>> findNonSynced() =>
      (select(inventories)..where((i) => i.state.equals(3).not())).get();

  Future<int> countUnsynced() {
    final expr = inventories.id.count();
    return (selectOnly(inventories)
          ..addColumns([expr])
          ..where(inventories.state.equals(3).not()))
        .map((row) => row.read(expr)!)
        .getSingle();
  }

  Future<int> setResponse(int id, String? msg, int state) =>
      (update(inventories)..where((i) => i.id.equals(id))).write(
        InventoriesCompanion(state: Value(state), msg: Value(msg)),
      );
}

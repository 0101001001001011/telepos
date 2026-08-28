import 'package:drift/drift.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/database/tables/wms_tables.dart';

part 'warehouse_dao.g.dart';

@DriftAccessor(tables: [Warehouses])
class WarehouseDao extends DatabaseAccessor<AppDatabase>
    with _$WarehouseDaoMixin {
  WarehouseDao(super.db);

  Future<List<Warehouse>> findAll() => select(warehouses).get();

  Future<Warehouse?> findById(int id) =>
      (select(warehouses)..where((w) => w.id.equals(id))).getSingleOrNull();

  Future<Warehouse?> findDefault() => (select(
    warehouses,
  )..where((w) => w.isDefault.equals(true))).getSingleOrNull();

  Future<List<Warehouse>> findActive() =>
      (select(warehouses)..where((w) => w.isActive.equals(true))).get();

  Future<int> insertWarehouse(WarehousesCompanion warehouse) =>
      into(warehouses).insert(warehouse);

  Future<int> updateWarehouse(int id, WarehousesCompanion warehouse) =>
      (update(warehouses)..where((w) => w.id.equals(id))).write(warehouse);

  Future<int> deleteWarehouse(int id) =>
      (delete(warehouses)..where((w) => w.id.equals(id))).go();

  Future<void> setDefault(int id) async {
    await transaction(() async {
      await update(
        warehouses,
      ).write(const WarehousesCompanion(isDefault: Value(false)));
      await (update(warehouses)..where((w) => w.id.equals(id))).write(
        const WarehousesCompanion(isDefault: Value(true)),
      );
    });
  }
}

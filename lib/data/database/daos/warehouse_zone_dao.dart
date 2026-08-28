import 'package:drift/drift.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/database/tables/wms_tables.dart';

part 'warehouse_zone_dao.g.dart';

@DriftAccessor(tables: [WarehouseZones])
class WarehouseZoneDao extends DatabaseAccessor<AppDatabase>
    with _$WarehouseZoneDaoMixin {
  WarehouseZoneDao(super.db);

  Future<List<WarehouseZone>> findByWarehouseId(int warehouseId) => (select(
    warehouseZones,
  )..where((z) => z.warehouseId.equals(warehouseId))).get();

  Future<WarehouseZone?> findById(int id) =>
      (select(warehouseZones)..where((z) => z.id.equals(id))).getSingleOrNull();

  Future<List<WarehouseZone>> findActive(int warehouseId) =>
      (select(warehouseZones)..where(
            (z) => z.warehouseId.equals(warehouseId) & z.isActive.equals(true),
          ))
          .get();

  Future<List<WarehouseZone>> findByType(int type) =>
      (select(warehouseZones)..where((z) => z.type.equals(type))).get();

  Future<int> insertZone(WarehouseZonesCompanion zone) =>
      into(warehouseZones).insert(zone);

  Future<int> updateZone(int id, WarehouseZonesCompanion zone) =>
      (update(warehouseZones)..where((z) => z.id.equals(id))).write(zone);

  Future<int> deleteZone(int id) =>
      (delete(warehouseZones)..where((z) => z.id.equals(id))).go();
}

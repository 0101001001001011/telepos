import 'package:drift/drift.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/database/tables/wms_tables.dart';

part 'warehouse_cell_dao.g.dart';

@DriftAccessor(tables: [WarehouseCells])
class WarehouseCellDao extends DatabaseAccessor<AppDatabase>
    with _$WarehouseCellDaoMixin {
  WarehouseCellDao(super.db);

  Future<List<WarehouseCell>> findByZoneId(int zoneId) =>
      (select(warehouseCells)..where((c) => c.zoneId.equals(zoneId))).get();

  Future<WarehouseCell?> findById(int id) =>
      (select(warehouseCells)..where((c) => c.id.equals(id))).getSingleOrNull();

  Future<WarehouseCell?> findByBarcode(String barcode) => (select(
    warehouseCells,
  )..where((c) => c.barcode.equals(barcode))).getSingleOrNull();

  Future<WarehouseCell?> findByAddress(String address) => (select(
    warehouseCells,
  )..where((c) => c.address.equals(address))).getSingleOrNull();

  Future<List<WarehouseCell>> findActive(int zoneId) => (select(
    warehouseCells,
  )..where((c) => c.zoneId.equals(zoneId) & c.isActive.equals(true))).get();

  Future<List<WarehouseCell>> findBlocked() =>
      (select(warehouseCells)..where((c) => c.isBlocked.equals(true))).get();

  Future<int> insertCell(WarehouseCellsCompanion cell) =>
      into(warehouseCells).insert(cell);

  Future<int> updateCell(int id, WarehouseCellsCompanion cell) =>
      (update(warehouseCells)..where((c) => c.id.equals(id))).write(cell);

  Future<int> deleteCell(int id) =>
      (delete(warehouseCells)..where((c) => c.id.equals(id))).go();

  Future<int> setBlocked(int id, bool blocked) =>
      (update(warehouseCells)..where((c) => c.id.equals(id))).write(
        WarehouseCellsCompanion(isBlocked: Value(blocked)),
      );

  Future<int> countByZoneId(int zoneId) {
    final expr = warehouseCells.id.count();
    return (selectOnly(warehouseCells)
          ..addColumns([expr])
          ..where(warehouseCells.zoneId.equals(zoneId)))
        .map((row) => row.read(expr)!)
        .getSingle();
  }
}

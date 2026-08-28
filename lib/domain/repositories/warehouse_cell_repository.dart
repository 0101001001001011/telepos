import 'package:telepos/domain/entities/wms/warehouse_cell_entity.dart';

abstract class WarehouseCellRepository {
  Future<List<WarehouseCellEntity>> findByZoneId(int zoneId);

  Future<WarehouseCellEntity?> findById(int id);

  Future<WarehouseCellEntity?> findByBarcode(String barcode);

  Future<WarehouseCellEntity?> findByAddress(String address);

  Future<List<WarehouseCellEntity>> findActive(int zoneId);

  Future<int> create(WarehouseCellEntity entity);

  Future<int> update(WarehouseCellEntity entity);

  Future<int> delete(int id);

  Future<int> setBlocked(int id, bool blocked);

  Future<int> countByZoneId(int zoneId);
}

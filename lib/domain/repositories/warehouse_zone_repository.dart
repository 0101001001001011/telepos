import 'package:telepos/domain/entities/wms/warehouse_zone_entity.dart';

abstract class WarehouseZoneRepository {
  Future<List<WarehouseZoneEntity>> findByWarehouseId(int warehouseId);

  Future<WarehouseZoneEntity?> findById(int id);

  Future<List<WarehouseZoneEntity>> findActive(int warehouseId);

  Future<List<WarehouseZoneEntity>> findByType(int type);

  Future<int> create(WarehouseZoneEntity entity);

  Future<int> update(WarehouseZoneEntity entity);

  Future<int> delete(int id);
}

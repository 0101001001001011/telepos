import 'package:telepos/domain/entities/wms/warehouse_entity.dart';

abstract class WarehouseRepository {
  Future<List<WarehouseEntity>> findAll();

  Future<WarehouseEntity?> findById(int id);

  Future<WarehouseEntity?> findDefault();

  Future<List<WarehouseEntity>> findActive();

  Future<int> create(WarehouseEntity entity);

  Future<int> update(WarehouseEntity entity);

  Future<int> delete(int id);

  Future<void> setDefault(int id);
}

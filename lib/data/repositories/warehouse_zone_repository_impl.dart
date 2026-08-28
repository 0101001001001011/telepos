import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/mappers/wms_mappers.dart';
import 'package:telepos/domain/entities/wms/warehouse_zone_entity.dart';
import 'package:telepos/domain/repositories/warehouse_zone_repository.dart';

class WarehouseZoneRepositoryImpl implements WarehouseZoneRepository {
  WarehouseZoneRepositoryImpl(this._db);

  final AppDatabase _db;

  @override
  Future<List<WarehouseZoneEntity>> findByWarehouseId(int warehouseId) async {
    final rows = await _db.warehouseZoneDao.findByWarehouseId(warehouseId);
    return WarehouseZoneMapper.fromDriftList(rows);
  }

  @override
  Future<WarehouseZoneEntity?> findById(int id) async {
    final row = await _db.warehouseZoneDao.findById(id);
    return row != null ? WarehouseZoneMapper.fromDrift(row) : null;
  }

  @override
  Future<List<WarehouseZoneEntity>> findActive(int warehouseId) async {
    final rows = await _db.warehouseZoneDao.findActive(warehouseId);
    return WarehouseZoneMapper.fromDriftList(rows);
  }

  @override
  Future<List<WarehouseZoneEntity>> findByType(int type) async {
    final rows = await _db.warehouseZoneDao.findByType(type);
    return WarehouseZoneMapper.fromDriftList(rows);
  }

  @override
  Future<int> create(WarehouseZoneEntity entity) {
    final companion = WarehouseZoneMapper.toDrift(entity);
    return _db.warehouseZoneDao.insertZone(companion);
  }

  @override
  Future<int> update(WarehouseZoneEntity entity) {
    final companion = WarehouseZoneMapper.toDrift(entity);
    return _db.warehouseZoneDao.updateZone(entity.id!, companion);
  }

  @override
  Future<int> delete(int id) {
    return _db.warehouseZoneDao.deleteZone(id);
  }
}

import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/mappers/wms_mappers.dart';
import 'package:telepos/domain/entities/wms/warehouse_cell_entity.dart';
import 'package:telepos/domain/repositories/warehouse_cell_repository.dart';

class WarehouseCellRepositoryImpl implements WarehouseCellRepository {
  WarehouseCellRepositoryImpl(this._db);

  final AppDatabase _db;

  @override
  Future<List<WarehouseCellEntity>> findByZoneId(int zoneId) async {
    final rows = await _db.warehouseCellDao.findByZoneId(zoneId);
    return WarehouseCellMapper.fromDriftList(rows);
  }

  @override
  Future<WarehouseCellEntity?> findById(int id) async {
    final row = await _db.warehouseCellDao.findById(id);
    return row != null ? WarehouseCellMapper.fromDrift(row) : null;
  }

  @override
  Future<WarehouseCellEntity?> findByBarcode(String barcode) async {
    final row = await _db.warehouseCellDao.findByBarcode(barcode);
    return row != null ? WarehouseCellMapper.fromDrift(row) : null;
  }

  @override
  Future<WarehouseCellEntity?> findByAddress(String address) async {
    final row = await _db.warehouseCellDao.findByAddress(address);
    return row != null ? WarehouseCellMapper.fromDrift(row) : null;
  }

  @override
  Future<List<WarehouseCellEntity>> findActive(int zoneId) async {
    final rows = await _db.warehouseCellDao.findActive(zoneId);
    return WarehouseCellMapper.fromDriftList(rows);
  }

  @override
  Future<int> create(WarehouseCellEntity entity) {
    final companion = WarehouseCellMapper.toDrift(entity);
    return _db.warehouseCellDao.insertCell(companion);
  }

  @override
  Future<int> update(WarehouseCellEntity entity) {
    final companion = WarehouseCellMapper.toDrift(entity);
    return _db.warehouseCellDao.updateCell(entity.id!, companion);
  }

  @override
  Future<int> delete(int id) {
    return _db.warehouseCellDao.deleteCell(id);
  }

  @override
  Future<int> setBlocked(int id, bool blocked) {
    return _db.warehouseCellDao.setBlocked(id, blocked);
  }

  @override
  Future<int> countByZoneId(int zoneId) {
    return _db.warehouseCellDao.countByZoneId(zoneId);
  }
}

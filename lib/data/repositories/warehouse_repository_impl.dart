import 'package:decimal/decimal.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/mappers/wms_mappers.dart';
import 'package:telepos/domain/entities/wms/warehouse_entity.dart';
import 'package:telepos/domain/repositories/warehouse_repository.dart';

class WarehouseRepositoryImpl implements WarehouseRepository {
  WarehouseRepositoryImpl(this._db);

  final AppDatabase _db;

  @override
  Future<List<WarehouseEntity>> findAll() async {
    final rows = await _db.warehouseDao.findAll();
    return WarehouseMapper.fromDriftList(rows);
  }

  @override
  Future<WarehouseEntity?> findById(int id) async {
    final row = await _db.warehouseDao.findById(id);
    return row != null ? WarehouseMapper.fromDrift(row) : null;
  }

  @override
  Future<WarehouseEntity?> findDefault() async {
    final row = await _db.warehouseDao.findDefault();
    return row != null ? WarehouseMapper.fromDrift(row) : null;
  }

  @override
  Future<List<WarehouseEntity>> findActive() async {
    final rows = await _db.warehouseDao.findActive();
    return WarehouseMapper.fromDriftList(rows);
  }

  @override
  Future<int> create(WarehouseEntity entity) {
    final companion = WarehouseMapper.toDrift(entity);
    return _db.warehouseDao.insertWarehouse(companion);
  }

  @override
  Future<int> update(WarehouseEntity entity) {
    final companion = WarehouseMapper.toDrift(entity);
    return _db.warehouseDao.updateWarehouse(entity.id!, companion);
  }

  @override
  Future<int> delete(int id) async {
    return _db.transaction(() async {
      final zones = await _db.warehouseZoneDao.findByWarehouseId(id);
      for (final z in zones) {
        final cells = await _db.warehouseCellDao.findByZoneId(z.id);
        for (final c in cells) {
          await _assertCellEmpty(c.id);
        }
      }

      for (final z in zones) {
        final cells = await _db.warehouseCellDao.findByZoneId(z.id);
        for (final c in cells) {
          await _db.cellStockDao.deleteByCell(c.id);
          await _db.warehouseCellDao.deleteCell(c.id);
        }
        await _db.warehouseZoneDao.deleteZone(z.id);
      }

      return _db.warehouseDao.deleteWarehouse(id);
    });
  }

  Future<void> _assertCellEmpty(int cellId) async {
    final stocks = await _db.cellStockDao.findByCellId(cellId);
    final hasStock = stocks.any((s) => s.quantity > Decimal.zero);
    if (hasStock) {
      throw StateError(
        'Ячейка $cellId содержит остаток — сначала переместите товар',
      );
    }
  }

  @override
  Future<void> setDefault(int id) {
    return _db.warehouseDao.setDefault(id);
  }
}

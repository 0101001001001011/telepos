import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/mappers/wms_mappers.dart';
import 'package:telepos/domain/entities/wms/cell_stock_entity.dart';
import 'package:telepos/domain/repositories/cell_stock_repository.dart';

class CellStockRepositoryImpl implements CellStockRepository {
  CellStockRepositoryImpl(this._db);

  final AppDatabase _db;

  @override
  Future<List<CellStockEntity>> findByCellId(int cellId) async {
    final rows = await _db.cellStockDao.findByCellId(cellId);
    return CellStockMapper.fromDriftList(rows);
  }

  @override
  Future<List<CellStockEntity>> findByUcode(int ucode) async {
    final rows = await _db.cellStockDao.findByUcode(ucode);
    return CellStockMapper.fromDriftList(rows);
  }

  @override
  Future<List<CellStockEntity>> findInCell(
    int cellId,
    int ucode,
    int? batchId,
  ) async {
    final rows = await _db.cellStockDao.findByCellUcodeBatch(
      cellId,
      ucode,
      batchId,
    );
    return CellStockMapper.fromDriftList(rows);
  }

  @override
  Future<int> upsertStock(CellStockEntity entity) {
    final companion = CellStockMapper.toDrift(entity);
    return _db.cellStockDao.upsertStock(companion);
  }

  @override
  Future<T> runInTransaction<T>(Future<T> Function() action) =>
      _db.transaction(action);
}

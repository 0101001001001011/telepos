import 'package:telepos/domain/entities/wms/cell_stock_entity.dart';

abstract class CellStockRepository {
  Future<List<CellStockEntity>> findByCellId(int cellId);

  Future<List<CellStockEntity>> findByUcode(int ucode);

  Future<List<CellStockEntity>> findInCell(int cellId, int ucode, int? batchId);

  Future<int> upsertStock(CellStockEntity entity);

  Future<T> runInTransaction<T>(Future<T> Function() action);
}

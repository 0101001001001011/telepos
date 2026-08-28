import 'package:decimal/decimal.dart';
import 'package:telepos/domain/entities/wms/cell_stock_entity.dart';
import 'package:telepos/domain/usecases/wms/wms_result.dart';

abstract class CellStockUseCase {
  Future<WmsResult> placeStock({
    required int cellId,
    required int ucode,
    required Decimal quantity,
    int? batchId,
  });

  Future<WmsResult> pickStock({
    required int cellId,
    required int ucode,
    required Decimal quantity,
    int? batchId,
  });

  Future<WmsResult> transferStock({
    required int fromCellId,
    required int toCellId,
    required int ucode,
    required Decimal quantity,
    int? batchId,
  });

  Future<List<CellStockEntity>> getStockByCell(int cellId);

  Future<List<CellStockEntity>> getStockByProduct(int ucode);
}

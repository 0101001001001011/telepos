import 'package:decimal/decimal.dart';
import 'package:telepos/domain/entities/wms/cell_stock_entity.dart';
import 'package:telepos/domain/repositories/cell_stock_repository.dart';
import 'package:telepos/domain/repositories/warehouse_cell_repository.dart';
import 'package:telepos/domain/usecases/wms/cell_stock_use_case.dart';
import 'package:telepos/domain/usecases/wms/wms_result.dart';

class CellStockUseCaseImpl implements CellStockUseCase {
  CellStockUseCaseImpl(this._cellStockRepo, this._cellRepo);

  final CellStockRepository _cellStockRepo;
  final WarehouseCellRepository _cellRepo;

  @override
  Future<WmsResult> placeStock({
    required int cellId,
    required int ucode,
    required Decimal quantity,
    int? batchId,
  }) async {
    try {
      return await _placeStock(
        cellId: cellId,
        ucode: ucode,
        quantity: quantity,
        batchId: batchId,
      );
    } catch (e) {
      return WmsResult.failed('Ошибка размещения товара: $e');
    }
  }

  Future<WmsResult> _placeStock({
    required int cellId,
    required int ucode,
    required Decimal quantity,
    int? batchId,
  }) async {
    final cell = await _cellRepo.findById(cellId);
    if (cell == null) {
      return WmsResult.failed('Ячейка с ID $cellId не найдена');
    }
    if (cell.isBlocked ?? false) {
      return WmsResult.failed('Ячейка заблокирована');
    }

    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    final existing = await _cellStockRepo.findInCell(cellId, ucode, batchId);

    if (existing.isNotEmpty) {
      existing.sort((a, b) => (a.id ?? 0).compareTo(b.id ?? 0));
      final primary = existing.first;

      var mergedQty = primary.quantity ?? Decimal.zero;
      for (final extra in existing.skip(1)) {
        mergedQty += extra.quantity ?? Decimal.zero;
        await _cellStockRepo.upsertStock(
          extra.copyWith(quantity: Decimal.zero, updatedAt: now),
        );
      }

      final id = await _cellStockRepo.upsertStock(
        primary.copyWith(quantity: mergedQty + quantity, updatedAt: now),
      );
      return WmsResult.ok(primary.id ?? id);
    }

    final id = await _cellStockRepo.upsertStock(
      CellStockEntity(
        cellId: cellId,
        ucode: ucode,
        batchId: batchId,
        quantity: quantity,
        reservedQty: Decimal.zero,
        updatedAt: now,
      ),
    );
    return WmsResult.ok(id);
  }

  @override
  Future<WmsResult> pickStock({
    required int cellId,
    required int ucode,
    required Decimal quantity,
    int? batchId,
  }) async {
    try {
      return await _pickStock(
        cellId: cellId,
        ucode: ucode,
        quantity: quantity,
        batchId: batchId,
      );
    } catch (e) {
      return WmsResult.failed('Ошибка отбора товара: $e');
    }
  }

  Future<WmsResult> _pickStock({
    required int cellId,
    required int ucode,
    required Decimal quantity,
    int? batchId,
  }) async {
    final stocks = await _cellStockRepo.findInCell(cellId, ucode, batchId)
      ..sort((a, b) => (a.id ?? 0).compareTo(b.id ?? 0));

    if (stocks.isEmpty) {
      return WmsResult.failed('Товар не найден в ячейке $cellId');
    }

    var totalAvailable = Decimal.zero;
    for (final s in stocks) {
      totalAvailable +=
          (s.quantity ?? Decimal.zero) - (s.reservedQty ?? Decimal.zero);
    }
    if (totalAvailable < quantity) {
      return WmsResult.failed(
        'Недостаточно товара в ячейке. Доступно: $totalAvailable, запрошено: $quantity',
      );
    }

    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    var remaining = quantity;
    int? firstTouchedId;

    for (final s in stocks) {
      if (remaining <= Decimal.zero) break;

      final rowAvailable =
          (s.quantity ?? Decimal.zero) - (s.reservedQty ?? Decimal.zero);
      if (rowAvailable <= Decimal.zero) continue;

      final take = rowAvailable < remaining ? rowAvailable : remaining;
      final newQty = (s.quantity ?? Decimal.zero) - take;

      await _cellStockRepo.upsertStock(
        s.copyWith(quantity: newQty, updatedAt: now),
      );

      firstTouchedId ??= s.id;
      remaining -= take;
    }

    return WmsResult.ok(firstTouchedId);
  }

  @override
  Future<WmsResult> transferStock({
    required int fromCellId,
    required int toCellId,
    required int ucode,
    required Decimal quantity,
    int? batchId,
  }) async {
    try {
      return await _cellStockRepo.runInTransaction<WmsResult>(() async {
        final pickResult = await _pickStock(
          cellId: fromCellId,
          ucode: ucode,
          quantity: quantity,
          batchId: batchId,
        );
        if (!pickResult.success) {
          throw _TransferAbort(
            'Ошибка отбора из ячейки-источника: ${pickResult.errorMessage}',
          );
        }

        final placeResult = await _placeStock(
          cellId: toCellId,
          ucode: ucode,
          quantity: quantity,
          batchId: batchId,
        );
        if (!placeResult.success) {
          throw _TransferAbort(
            'Ошибка размещения в ячейке-назначения: ${placeResult.errorMessage}',
          );
        }

        return WmsResult.ok();
      });
    } on _TransferAbort catch (e) {
      return WmsResult.failed(e.message);
    } catch (e) {
      return WmsResult.failed('Ошибка перемещения товара: $e');
    }
  }

  @override
  Future<List<CellStockEntity>> getStockByCell(int cellId) async {
    return _cellStockRepo.findByCellId(cellId);
  }

  @override
  Future<List<CellStockEntity>> getStockByProduct(int ucode) async {
    return _cellStockRepo.findByUcode(ucode);
  }
}

class _TransferAbort implements Exception {
  _TransferAbort(this.message);

  final String message;

  @override
  String toString() => 'TransferAbort: $message';
}

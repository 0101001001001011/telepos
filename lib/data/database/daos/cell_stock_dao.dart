import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/database/tables/wms_tables.dart';

part 'cell_stock_dao.g.dart';

@DriftAccessor(tables: [CellStocks])
class CellStockDao extends DatabaseAccessor<AppDatabase>
    with _$CellStockDaoMixin {
  CellStockDao(super.db);

  Future<List<CellStock>> findByCellId(int cellId) =>
      (select(cellStocks)..where((s) => s.cellId.equals(cellId))).get();

  Future<List<CellStock>> findByUcode(int ucode) =>
      (select(cellStocks)..where((s) => s.ucode.equals(ucode))).get();

  Future<List<CellStock>> findByBatchId(int batchId) =>
      (select(cellStocks)..where((s) => s.batchId.equals(batchId))).get();

  Future<List<CellStock>> findByCellUcodeBatch(
    int cellId,
    int ucode,
    int? batchId,
  ) {
    final query = select(cellStocks)
      ..where((s) => s.cellId.equals(cellId) & s.ucode.equals(ucode));
    if (batchId == null) {
      query.where((s) => s.batchId.isNull());
    } else {
      query.where((s) => s.batchId.equals(batchId));
    }
    return query.get();
  }

  Future<int> upsertStock(CellStocksCompanion stock) =>
      into(cellStocks).insertOnConflictUpdate(stock);

  Future<int> reserveStock(int id, Decimal qty) async {
    final existing = await (select(
      cellStocks,
    )..where((s) => s.id.equals(id))).getSingleOrNull();
    if (existing == null) return 0;

    final requested = existing.reservedQty + qty;
    final newReserved = requested > existing.quantity
        ? existing.quantity
        : requested;

    return (update(cellStocks)..where((s) => s.id.equals(id))).write(
      CellStocksCompanion(
        reservedQty: Value(newReserved),
        updatedAt: Value(DateTime.now().millisecondsSinceEpoch ~/ 1000),
      ),
    );
  }

  Future<int> releaseReservation(int id, Decimal qty) async {
    final existing = await (select(
      cellStocks,
    )..where((s) => s.id.equals(id))).getSingleOrNull();
    if (existing == null) return 0;

    final currentReserved = existing.reservedQty;
    final diff = currentReserved - qty;
    final newReserved = diff < Decimal.zero ? Decimal.zero : diff;

    return (update(cellStocks)..where((s) => s.id.equals(id))).write(
      CellStocksCompanion(
        reservedQty: Value(newReserved),
        updatedAt: Value(DateTime.now().millisecondsSinceEpoch ~/ 1000),
      ),
    );
  }

  Future<int> deleteByCell(int cellId) =>
      (delete(cellStocks)..where((s) => s.cellId.equals(cellId))).go();
}

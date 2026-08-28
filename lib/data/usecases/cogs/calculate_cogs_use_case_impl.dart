import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart';
import 'package:get_it/get_it.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/domain/usecases/cogs/calculate_cogs_use_case.dart';

class CalculateCogsUseCaseImpl implements CalculateCogsUseCase {
  CalculateCogsUseCaseImpl({AppDatabase? db}) : _db = db;

  final AppDatabase? _db;

  AppDatabase get _database => _db ?? GetIt.I<AppDatabase>();

  @override
  Future<CogsResult> calculate({
    required int ucode,
    required Decimal quantity,
    CogsMethod method = CogsMethod.fifo,
  }) async {
    final batches = await _database.batchDao.findFifoConsumable(ucode);

    if (quantity <= Decimal.zero) {
      return CogsResult(
        method: method,
        requestedQuantity: quantity,
        resolvedQuantity: Decimal.zero,
        totalCost: Decimal.zero,
        consumptions: const [],
      );
    }

    final hasBatchStock = batches.any((b) => b.currentQuantity > Decimal.zero);
    if (!hasBatchStock) {
      final unitCost = await _fallbackUnitCost(ucode);
      if (unitCost != null) {
        return _fromFlatUnitCost(method, quantity, unitCost);
      }
    }

    return switch (method) {
      CogsMethod.fifo => _fifo(ucode, quantity, batches),
      CogsMethod.weightedAverage => _weightedAverage(ucode, quantity, batches),
    };
  }

  Future<Decimal?> _fallbackUnitCost(int ucode) async {
    final price = await _database.productPriceDao.findByUcode(ucode);
    final wholesale = price?.wholesalePrice;
    if (wholesale != null && wholesale > Decimal.zero) {
      return wholesale;
    }
    return _latestArrivalCost(ucode);
  }

  Future<Decimal?> _latestArrivalCost(int ucode) async {
    final db = _database;
    final query =
        db.select(db.supplyProducts).join([
            innerJoin(
              db.supplies,
              db.supplies.id.equalsExp(db.supplyProducts.supplyId),
            ),
          ])
          ..where(db.supplyProducts.ucode.equals(ucode))
          ..orderBy([
            OrderingTerm.desc(db.supplies.editTime),
            OrderingTerm.desc(db.supplies.id),
          ])
          ..limit(1);
    final row = await query.getSingleOrNull();
    final sp = row?.readTable(db.supplyProducts);
    final cost = sp?.price;
    if (cost != null && cost > Decimal.zero) return cost;
    return null;
  }

  CogsResult _fromFlatUnitCost(
    CogsMethod method,
    Decimal quantity,
    Decimal unitCost,
  ) {
    final totalCost = quantity * unitCost;
    return CogsResult(
      method: method,
      requestedQuantity: quantity,
      resolvedQuantity: quantity,
      totalCost: totalCost,
      consumptions: [
        CogsBatchConsumption(
          batchId: 0,
          quantity: quantity,
          unitCost: unitCost,
        ),
      ],
    );
  }

  CogsResult _fifo(int ucode, Decimal quantity, List<Batche> batches) {
    var remaining = quantity;
    var totalCost = Decimal.zero;
    final consumptions = <CogsBatchConsumption>[];

    for (final batch in batches) {
      if (remaining <= Decimal.zero) break;

      final available = batch.currentQuantity;
      if (available <= Decimal.zero) continue;

      final take = available < remaining ? available : remaining;
      final unitCost = batch.unitCost ?? Decimal.zero;

      consumptions.add(
        CogsBatchConsumption(
          batchId: batch.id,
          quantity: take,
          unitCost: unitCost,
        ),
      );
      totalCost += take * unitCost;
      remaining -= take;
    }

    final resolved = quantity - remaining;
    return CogsResult(
      method: CogsMethod.fifo,
      requestedQuantity: quantity,
      resolvedQuantity: resolved,
      totalCost: totalCost,
      consumptions: consumptions,
      shortfall: remaining > Decimal.zero,
      fromBatches: resolved > Decimal.zero,
    );
  }

  CogsResult _weightedAverage(
    int ucode,
    Decimal quantity,
    List<Batche> batches,
  ) {
    var totalQty = Decimal.zero;
    var totalValue = Decimal.zero;

    for (final batch in batches) {
      final qty = batch.currentQuantity;
      if (qty <= Decimal.zero) continue;
      totalQty += qty;
      totalValue += qty * (batch.unitCost ?? Decimal.zero);
    }

    if (totalQty <= Decimal.zero) {
      return CogsResult(
        method: CogsMethod.weightedAverage,
        requestedQuantity: quantity,
        resolvedQuantity: Decimal.zero,
        totalCost: Decimal.zero,
        consumptions: const [],
        shortfall: true,
      );
    }

    final avgUnitCost = (totalValue / totalQty).toDecimal(
      scaleOnInfinitePrecision: 18,
    );

    final resolved = quantity <= totalQty ? quantity : totalQty;
    final totalCost = resolved * avgUnitCost;

    return CogsResult(
      method: CogsMethod.weightedAverage,
      requestedQuantity: quantity,
      resolvedQuantity: resolved,
      totalCost: totalCost,
      consumptions: [
        CogsBatchConsumption(
          batchId: 0,
          quantity: resolved,
          unitCost: avgUnitCost,
        ),
      ],
      shortfall: quantity > totalQty,
      fromBatches: true,
    );
  }
}

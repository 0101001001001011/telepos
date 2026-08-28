import 'package:decimal/decimal.dart';

enum CogsMethod { fifo, weightedAverage }

class CogsBatchConsumption {
  const CogsBatchConsumption({
    required this.batchId,
    required this.quantity,
    required this.unitCost,
  });

  final int batchId;

  final Decimal quantity;

  final Decimal unitCost;

  Decimal get cost => quantity * unitCost;
}

class CogsResult {
  const CogsResult({
    required this.method,
    required this.requestedQuantity,
    required this.resolvedQuantity,
    required this.totalCost,
    required this.consumptions,
    this.shortfall = false,
    this.fromBatches = false,
  });

  final CogsMethod method;

  final Decimal requestedQuantity;

  final Decimal resolvedQuantity;

  final Decimal totalCost;

  final List<CogsBatchConsumption> consumptions;

  final bool shortfall;

  final bool fromBatches;

  Decimal get unitCost => resolvedQuantity > Decimal.zero
      ? (totalCost / resolvedQuantity).toDecimal(scaleOnInfinitePrecision: 18)
      : Decimal.zero;
}

abstract class CalculateCogsUseCase {
  Future<CogsResult> calculate({
    required int ucode,
    required Decimal quantity,
    CogsMethod method = CogsMethod.fifo,
  });
}

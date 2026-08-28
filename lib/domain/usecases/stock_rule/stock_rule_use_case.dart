import 'package:decimal/decimal.dart';

import 'package:telepos/domain/entities/wms/stock_rule_entity.dart';

class ReorderSignal {
  const ReorderSignal({
    required this.ucode,
    required this.currentQty,
    required this.reorderPoint,
    this.warehouseId,
    this.suggestedOrderQty,
  });

  final int ucode;

  final Decimal currentQty;

  final Decimal reorderPoint;

  final int? warehouseId;

  final Decimal? suggestedOrderQty;
}

abstract class StockRuleUseCase {
  Future<List<StockRuleEntity>> listRules();

  Future<List<StockRuleEntity>> listRulesForUcode(int ucode);

  Future<int> upsertRule({
    required int ucode,
    int? warehouseId,
    Decimal? minStock,
    Decimal? maxStock,
    Decimal? reorderQty,
    bool? autoReorder,
  });

  Future<List<ReorderSignal>> evaluateReorders();

  Future<List<int>> ucodesBelowReorderPoint();
}

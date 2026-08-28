import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart';

import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/database/daos/product_info_dao.dart';
import 'package:telepos/data/database/daos/stock_rule_dao.dart';
import 'package:telepos/data/mappers/wms_mappers.dart';
import 'package:telepos/domain/entities/wms/stock_rule_entity.dart';
import 'package:telepos/domain/usecases/stock_rule/stock_rule_use_case.dart';

class StockRuleUseCaseImpl implements StockRuleUseCase {
  StockRuleUseCaseImpl(this._stockRuleDao, this._productInfoDao);

  final StockRuleDao _stockRuleDao;
  final ProductInfoDao _productInfoDao;

  @override
  Future<List<StockRuleEntity>> listRules() async {
    final rows = await _stockRuleDao.select(_stockRuleDao.stockRules).get();
    return StockRuleMapper.fromDriftList(rows);
  }

  @override
  Future<List<StockRuleEntity>> listRulesForUcode(int ucode) async {
    final rows = await _stockRuleDao.findByUcode(ucode);
    return StockRuleMapper.fromDriftList(rows);
  }

  @override
  Future<int> upsertRule({
    required int ucode,
    int? warehouseId,
    Decimal? minStock,
    Decimal? maxStock,
    Decimal? reorderQty,
    bool? autoReorder,
  }) {
    final companion = StockRulesCompanion(
      ucode: Value(ucode),
      warehouseId: Value(warehouseId),
      minStock: Value(minStock),
      maxStock: Value(maxStock),
      reorderQty: Value(reorderQty),
      autoReorder: Value(autoReorder ?? false),
      updatedAt: Value(DateTime.now().millisecondsSinceEpoch ~/ 1000),
    );
    return _stockRuleDao.upsertRule(companion);
  }

  @override
  Future<List<ReorderSignal>> evaluateReorders() async {
    final rules = await _stockRuleDao.select(_stockRuleDao.stockRules).get();

    final signals = <ReorderSignal>[];
    for (final rule in rules) {
      final reorderPoint = rule.minStock;
      if (reorderPoint == null) continue;

      final product = await _productInfoDao.findByUcode(rule.ucode);
      if (product == null) continue;

      final currentQty = product.quantity ?? Decimal.zero;

      if (currentQty <= reorderPoint) {
        signals.add(
          ReorderSignal(
            ucode: rule.ucode,
            currentQty: currentQty,
            reorderPoint: reorderPoint,
            warehouseId: rule.warehouseId,
            suggestedOrderQty: rule.reorderQty,
          ),
        );
      }
    }
    return signals;
  }

  @override
  Future<List<int>> ucodesBelowReorderPoint() async {
    final signals = await evaluateReorders();
    return signals.map((s) => s.ucode).toList();
  }
}

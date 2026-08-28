import 'package:drift/drift.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/database/tables/wms_tables.dart';

part 'stock_rule_dao.g.dart';

@DriftAccessor(tables: [StockRules])
class StockRuleDao extends DatabaseAccessor<AppDatabase>
    with _$StockRuleDaoMixin {
  StockRuleDao(super.db);

  Future<List<StockRule>> findByUcode(int ucode) =>
      (select(stockRules)..where((r) => r.ucode.equals(ucode))).get();

  Future<List<StockRule>> findByWarehouseId(int warehouseId) => (select(
    stockRules,
  )..where((r) => r.warehouseId.equals(warehouseId))).get();

  Future<List<StockRule>> findAutoReorder() =>
      (select(stockRules)..where((r) => r.autoReorder.equals(true))).get();

  Future<List<StockRule>> findByAbcClass(String abcClass) =>
      (select(stockRules)..where((r) => r.abcClass.equals(abcClass))).get();

  Future<int> insertRule(StockRulesCompanion rule) =>
      into(stockRules).insert(rule);

  Future<int> updateRule(int id, StockRulesCompanion rule) =>
      (update(stockRules)..where((r) => r.id.equals(id))).write(rule);

  Future<int> upsertRule(StockRulesCompanion rule) =>
      into(stockRules).insertOnConflictUpdate(rule);
}

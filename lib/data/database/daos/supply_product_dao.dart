import 'package:drift/drift.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/database/tables/supply_tables.dart';

part 'supply_product_dao.g.dart';

@DriftAccessor(tables: [SupplyProducts])
class SupplyProductDao extends DatabaseAccessor<AppDatabase>
    with _$SupplyProductDaoMixin {
  SupplyProductDao(super.db);

  Future<List<SupplyProduct>> findBySupplyId(int supplyId) => (select(
    supplyProducts,
  )..where((sp) => sp.supplyId.equals(supplyId))).get();

  Future<SupplyProduct?> findBySupplyIdAndUcode(int supplyId, int ucode) =>
      (select(supplyProducts)..where(
            (sp) => sp.supplyId.equals(supplyId) & sp.ucode.equals(ucode),
          ))
          .getSingleOrNull();

  Future<int> insertProduct(SupplyProductsCompanion product) =>
      into(supplyProducts).insert(product);

  Future<int> updateProduct(int id, SupplyProductsCompanion product) =>
      (update(supplyProducts)..where((sp) => sp.id.equals(id))).write(product);

  Future<int> deleteProduct(int id) =>
      (delete(supplyProducts)..where((sp) => sp.id.equals(id))).go();

  Future<int> deleteBySupplyId(int supplyId) => (delete(
    supplyProducts,
  )..where((sp) => sp.supplyId.equals(supplyId))).go();

  Future<int> countBySupplyId(int supplyId) {
    final expr = supplyProducts.id.count();
    return (selectOnly(supplyProducts)
          ..addColumns([expr])
          ..where(supplyProducts.supplyId.equals(supplyId)))
        .map((row) => row.read(expr)!)
        .getSingle();
  }
}

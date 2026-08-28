import 'package:drift/drift.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/database/tables/inventory_tables.dart';

part 'inventory_product_dao.g.dart';

@DriftAccessor(tables: [InventoryProducts])
class InventoryProductDao extends DatabaseAccessor<AppDatabase>
    with _$InventoryProductDaoMixin {
  InventoryProductDao(super.db);

  Future<int> insertProduct(InventoryProductsCompanion product) =>
      into(inventoryProducts).insert(product);

  Future<void> upsert({
    required int inventoryId,
    required int ucode,
    required InventoryProductsCompanion product,
  }) async {
    final existing =
        await (select(inventoryProducts)..where(
              (p) => p.inventoryId.equals(inventoryId) & p.ucode.equals(ucode),
            ))
            .getSingleOrNull();

    if (existing != null) {
      await (update(
        inventoryProducts,
      )..where((p) => p.id.equals(existing.id))).write(product);
    } else {
      await into(inventoryProducts).insert(product);
    }
  }

  Future<List<InventoryProduct>> findByInventoryId(int inventoryId) => (select(
    inventoryProducts,
  )..where((p) => p.inventoryId.equals(inventoryId))).get();

  Future<List<InventoryProduct>> findWithDiscrepancy(int inventoryId) =>
      (select(inventoryProducts)..where(
            (p) =>
                p.inventoryId.equals(inventoryId) &
                (p.difference.isBiggerThanValue(0.001) |
                    p.difference.isSmallerThanValue(-0.001)),
          ))
          .get();

  Future<int> deleteProduct(int id) =>
      (delete(inventoryProducts)..where((p) => p.id.equals(id))).go();

  Future<int> deleteByInventoryId(int inventoryId) => (delete(
    inventoryProducts,
  )..where((p) => p.inventoryId.equals(inventoryId))).go();

  Future<int> countByInventoryId(int inventoryId) {
    final expr = inventoryProducts.id.count();
    return (selectOnly(inventoryProducts)
          ..addColumns([expr])
          ..where(inventoryProducts.inventoryId.equals(inventoryId)))
        .map((row) => row.read(expr)!)
        .getSingle();
  }

  Future<int> countDiscrepancies(int inventoryId) {
    final expr = inventoryProducts.id.count();
    return (selectOnly(inventoryProducts)
          ..addColumns([expr])
          ..where(
            inventoryProducts.inventoryId.equals(inventoryId) &
                    inventoryProducts.difference.isBiggerThanValue(0.001) |
                inventoryProducts.difference.isSmallerThanValue(-0.001),
          ))
        .map((row) => row.read(expr)!)
        .getSingle();
  }
}

import 'package:drift/drift.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/database/tables/movement_tables.dart';

part 'movement_product_dao.g.dart';

@DriftAccessor(tables: [MovementProducts])
class MovementProductDao extends DatabaseAccessor<AppDatabase>
    with _$MovementProductDaoMixin {
  MovementProductDao(super.db);

  Future<List<MovementProduct>> findByMovementId(int movementId) => (select(
    movementProducts,
  )..where((mp) => mp.movementId.equals(movementId))).get();

  Future<MovementProduct?> findByMovementIdAndUcode(
    int movementId,
    int ucode,
  ) =>
      (select(movementProducts)..where(
            (mp) => mp.movementId.equals(movementId) & mp.ucode.equals(ucode),
          ))
          .getSingleOrNull();

  Future<int> insertProduct(MovementProductsCompanion product) =>
      into(movementProducts).insert(product);

  Future<int> updateProduct(int id, MovementProductsCompanion product) =>
      (update(
        movementProducts,
      )..where((mp) => mp.id.equals(id))).write(product);

  Future<int> deleteProduct(int id) =>
      (delete(movementProducts)..where((mp) => mp.id.equals(id))).go();

  Future<int> deleteByMovementId(int movementId) => (delete(
    movementProducts,
  )..where((mp) => mp.movementId.equals(movementId))).go();

  Future<int> countByMovementId(int movementId) {
    final expr = movementProducts.id.count();
    return (selectOnly(movementProducts)
          ..addColumns([expr])
          ..where(movementProducts.movementId.equals(movementId)))
        .map((row) => row.read(expr)!)
        .getSingle();
  }
}

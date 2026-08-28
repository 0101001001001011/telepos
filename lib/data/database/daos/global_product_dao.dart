import 'package:drift/drift.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/database/tables/nomenclature_tables.dart';

part 'global_product_dao.g.dart';

@DriftAccessor(tables: [GlobalProducts])
class GlobalProductDao extends DatabaseAccessor<AppDatabase>
    with _$GlobalProductDaoMixin {
  GlobalProductDao(super.db);

  Future<GlobalProduct?> findByCode(int code) => (select(
    globalProducts,
  )..where((g) => g.code.equals(code))).getSingleOrNull();

  Future<GlobalProduct?> findByBarcode(String barcode) {
    final code = int.tryParse(barcode);
    if (code == null) return Future.value(null);
    return findByCode(code);
  }

  Future<DateTime?> findMaxEditTime() {
    final expr = globalProducts.editTime.max();
    return (selectOnly(
      globalProducts,
    )..addColumns([expr])).map((row) => row.read(expr)).getSingleOrNull();
  }

  Future<GlobalProduct?> findLast() =>
      (select(globalProducts)
            ..orderBy([
              (g) => OrderingTerm.desc(g.editTime),
              (g) => OrderingTerm.desc(g.code),
            ])
            ..limit(1))
          .getSingleOrNull();

  Future<int> count() async {
    final countExpr = globalProducts.code.count();
    final query = selectOnly(globalProducts)..addColumns([countExpr]);
    final result = await query.getSingle();
    return result.read(countExpr) ?? 0;
  }

  Future<bool> isEmpty() async => (await count()) == 0;

  Future<void> insertBulk(List<GlobalProductsCompanion> products) async {
    await batch((batch) {
      batch.insertAllOnConflictUpdate(globalProducts, products);
    });
  }

  Future<int> deleteAll() => delete(globalProducts).go();

  Future<List<GlobalProduct>> searchByName(String query, {int limit = 20}) =>
      (select(globalProducts)
            ..where((g) => g.name.like('%$query%'))
            ..limit(limit))
          .get();
}

import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/database/tables/nomenclature_tables.dart';

part 'product_price_dao.g.dart';

@DriftAccessor(tables: [ProductPrices, ProductPriceEditions])
class ProductPriceDao extends DatabaseAccessor<AppDatabase>
    with _$ProductPriceDaoMixin {
  ProductPriceDao(super.db);

  Future<ProductPrice?> findByUcode(int ucode) => (select(
    productPrices,
  )..where((pp) => pp.ucode.equals(ucode))).getSingleOrNull();

  Future<ProductPrice?> findLastByBarcode() =>
      (select(productPrices)
            ..where((pp) => pp.serverEditTime.isNotNull())
            ..orderBy([
              (pp) => OrderingTerm.desc(pp.serverEditTime),
              (pp) => OrderingTerm.desc(pp.barcode),
            ])
            ..limit(1))
          .getSingleOrNull();

  Future<ProductPrice?> findLastByUcode() =>
      (select(productPrices)
            ..where((pp) => pp.editTime.isNotNull())
            ..orderBy([
              (pp) => OrderingTerm.desc(pp.editTime),
              (pp) => OrderingTerm.desc(pp.ucode),
            ])
            ..limit(1))
          .getSingleOrNull();

  Future<int> updatePrices(
    int ucode,
    Decimal sellingPrice,
    Decimal wholesalePrice,
  ) => (update(productPrices)..where((pp) => pp.ucode.equals(ucode))).write(
    ProductPricesCompanion(
      sellingPrice: Value(sellingPrice),
      wholesalePrice: Value(wholesalePrice),
    ),
  );

  Future<int> deleteAll() => delete(productPrices).go();

  Future<void> insertBulk(List<ProductPricesCompanion> items) async {
    await batch((b) {
      b.insertAllOnConflictUpdate(productPrices, items);
    });
  }

  Future<List<ProductPriceEdition>> findUploadable({
    int limit = 100,
  }) => customSelect(
    'SELECT ppe.* FROM product_price_editions ppe '
    'WHERE ppe.ucode NOT IN (SELECT pe.ucode FROM product_info_editions pe) '
    'LIMIT ?',
    variables: [Variable.withInt(limit)],
    readsFrom: {productPriceEditions},
  ).get().then((_) => (select(productPriceEditions)..limit(limit)).get());

  Future<int> deleteEditions(List<int> ucodes) => (delete(
    productPriceEditions,
  )..where((ppe) => ppe.ucode.isIn(ucodes))).go();

  Future<int> count() {
    final expr = productPrices.ucode.count();
    return (selectOnly(
      productPrices,
    )..addColumns([expr])).map((row) => row.read(expr)!).getSingle();
  }

  Future<bool> hasAny() async {
    final c = await count();
    return c > 0;
  }
}

import 'package:drift/drift.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/database/tables/nomenclature_tables.dart';

part 'product_alias_dao.g.dart';

@DriftAccessor(tables: [ProductAliases])
class ProductAliasDao extends DatabaseAccessor<AppDatabase>
    with _$ProductAliasDaoMixin {
  ProductAliasDao(super.db);

  Future<List<int>> findActiveProductIdsByAliasPart(String codePart) {
    final expr = productAliases.productUcode;
    return (selectOnly(productAliases)
          ..addColumns([expr])
          ..where(
            productAliases.code.like(codePart) &
                productAliases.isDeleted.equals(false),
          ))
        .map((row) => row.read(expr)!)
        .get();
  }

  Future<ProductAliase?> findProductByAlias(String code) =>
      (select(productAliases)
            ..where((a) => a.code.like(code) & a.isDeleted.equals(false)))
          .getSingleOrNull();

  Future<DateTime?> findMaxTime() {
    final expr = productAliases.time.max();
    return (selectOnly(
      productAliases,
    )..addColumns([expr])).map((row) => row.read(expr)).getSingleOrNull();
  }

  Future<ProductAliase?> findLast() =>
      (select(productAliases)
            ..orderBy([
              (a) => OrderingTerm.desc(a.time),
              (a) => OrderingTerm.desc(a.code),
            ])
            ..limit(1))
          .getSingleOrNull();
}

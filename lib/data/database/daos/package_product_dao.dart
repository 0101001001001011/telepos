import 'package:drift/drift.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/database/tables/nomenclature_tables.dart';

part 'package_product_dao.g.dart';

@DriftAccessor(tables: [PackageProducts])
class PackageProductDao extends DatabaseAccessor<AppDatabase>
    with _$PackageProductDaoMixin {
  PackageProductDao(super.db);

  Future<List<PackageProduct>> findByUcodeAndNotDeleted(int ucode) => (select(
    packageProducts,
  )..where((pp) => pp.ucode.equals(ucode) & pp.isDeleted.equals(false))).get();

  Future<int> countByUcodeAndNotDeleted(int ucode) {
    final expr = packageProducts.ucode.count();
    return (selectOnly(packageProducts)
          ..addColumns([expr])
          ..where(
            packageProducts.ucode.equals(ucode) &
                packageProducts.isDeleted.equals(false),
          ))
        .map((row) => row.read(expr)!)
        .getSingle();
  }

  Future<PackageProduct?> findLast() =>
      (select(packageProducts)
            ..orderBy([(pp) => OrderingTerm.desc(pp.createTime)])
            ..limit(1))
          .getSingleOrNull();
}

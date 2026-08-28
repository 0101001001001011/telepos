import 'package:drift/drift.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/database/tables/nomenclature_tables.dart';

part 'cancelled_product_dao.g.dart';

@DriftAccessor(tables: [CancelledProducts])
class CancelledProductDao extends DatabaseAccessor<AppDatabase>
    with _$CancelledProductDaoMixin {
  CancelledProductDao(super.db);

  Future<List<CancelledProduct>> findAllNonSync() => (select(
    cancelledProducts,
  )..where((c) => c.syncStatus.equals(3).not())).get();

  Future<List<CancelledProduct>> findPendingSync({int limit = 100}) =>
      (select(cancelledProducts)
            ..where((c) => c.syncStatus.equals(1))
            ..limit(limit))
          .get();

  Future<int> countUnsynced() {
    final expr = cancelledProducts.id.count();
    return (selectOnly(cancelledProducts)
          ..addColumns([expr])
          ..where(cancelledProducts.syncStatus.equals(1)))
        .map((row) => row.read(expr)!)
        .getSingle();
  }

  Future<List<CancelledProduct>> findByUcodeAndDateAfter(
    int ucode,
    DateTime afterDate,
  ) =>
      (select(cancelledProducts)
            ..where(
              (c) =>
                  c.ucode.equals(ucode) & c.date.isBiggerThanValue(afterDate),
            )
            ..orderBy([(c) => OrderingTerm.desc(c.date)]))
          .get();

  Future<int> setSyncStatus(List<int> productIds, int syncStatus) =>
      (update(cancelledProducts)..where((c) => c.id.isIn(productIds))).write(
        CancelledProductsCompanion(syncStatus: Value(syncStatus)),
      );
}

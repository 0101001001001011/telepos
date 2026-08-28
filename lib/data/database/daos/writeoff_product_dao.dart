import 'package:drift/drift.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/database/tables/writeoff_tables.dart';

part 'writeoff_product_dao.g.dart';

@DriftAccessor(tables: [WriteoffProducts])
class WriteoffProductDao extends DatabaseAccessor<AppDatabase>
    with _$WriteoffProductDaoMixin {
  WriteoffProductDao(super.db);

  Future<int> insertProduct(WriteoffProductsCompanion product) =>
      into(writeoffProducts).insert(product);

  Future<List<WriteoffProduct>> findByWriteoffId(int writeoffId) => (select(
    writeoffProducts,
  )..where((p) => p.writeoffId.equals(writeoffId))).get();

  Future<int> deleteProduct(int id) =>
      (delete(writeoffProducts)..where((p) => p.id.equals(id))).go();

  Future<int> deleteByWriteoffId(int writeoffId) => (delete(
    writeoffProducts,
  )..where((p) => p.writeoffId.equals(writeoffId))).go();

  Future<int> countByWriteoffId(int writeoffId) {
    final expr = writeoffProducts.id.count();
    return (selectOnly(writeoffProducts)
          ..addColumns([expr])
          ..where(writeoffProducts.writeoffId.equals(writeoffId)))
        .map((row) => row.read(expr)!)
        .getSingle();
  }
}

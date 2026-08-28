import 'package:drift/drift.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/database/tables/supplier_return_tables.dart';

part 'supplier_return_product_dao.g.dart';

@DriftAccessor(tables: [SupplierReturnProducts])
class SupplierReturnProductDao extends DatabaseAccessor<AppDatabase>
    with _$SupplierReturnProductDaoMixin {
  SupplierReturnProductDao(super.db);

  Future<List<SupplierReturnProduct>> findByReturnId(int supplierReturnId) =>
      (select(
        supplierReturnProducts,
      )..where((srp) => srp.supplierReturnId.equals(supplierReturnId))).get();

  Future<SupplierReturnProduct?> findByReturnIdAndUcode(
    int supplierReturnId,
    int ucode,
  ) =>
      (select(supplierReturnProducts)..where(
            (srp) =>
                srp.supplierReturnId.equals(supplierReturnId) &
                srp.ucode.equals(ucode),
          ))
          .getSingleOrNull();

  Future<int> insertProduct(SupplierReturnProductsCompanion product) =>
      into(supplierReturnProducts).insert(product);

  Future<int> updateProduct(int id, SupplierReturnProductsCompanion product) =>
      (update(
        supplierReturnProducts,
      )..where((srp) => srp.id.equals(id))).write(product);

  Future<int> deleteProduct(int id) =>
      (delete(supplierReturnProducts)..where((srp) => srp.id.equals(id))).go();

  Future<int> deleteByReturnId(int supplierReturnId) => (delete(
    supplierReturnProducts,
  )..where((srp) => srp.supplierReturnId.equals(supplierReturnId))).go();

  Future<int> countByReturnId(int supplierReturnId) {
    final expr = supplierReturnProducts.id.count();
    return (selectOnly(supplierReturnProducts)
          ..addColumns([expr])
          ..where(
            supplierReturnProducts.supplierReturnId.equals(supplierReturnId),
          ))
        .map((row) => row.read(expr)!)
        .getSingle();
  }
}

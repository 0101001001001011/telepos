import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/database/tables/sale_tables.dart';

part 'sale_product_dao.g.dart';

@DriftAccessor(
  tables: [SaleProducts, SaleProductMarks, SaleCustomFields, UniversalProducts],
)
class SaleProductDao extends DatabaseAccessor<AppDatabase>
    with _$SaleProductDaoMixin {
  SaleProductDao(super.db);

  Future<List<SaleProduct>> findBySale(int receiptNo, int posId) =>
      (select(saleProducts)
            ..where(
              (sp) => sp.receiptNo.equals(receiptNo) & sp.posId.equals(posId),
            )
            ..orderBy([(sp) => OrderingTerm.asc(sp.id)]))
          .get();

  Future<int> setQuantity(int id, Decimal quantity) =>
      (update(saleProducts)..where((sp) => sp.id.equals(id))).write(
        SaleProductsCompanion(quantity: Value(quantity)),
      );

  Future<int> setPriceBefore(int id, Decimal priceBefore) =>
      (update(saleProducts)..where((sp) => sp.id.equals(id))).write(
        SaleProductsCompanion(priceBefore: Value(priceBefore)),
      );

  Future<int> setPrice(int id, Decimal price) =>
      (update(saleProducts)..where((sp) => sp.id.equals(id))).write(
        SaleProductsCompanion(price: Value(price)),
      );

  Future<List<SaleProductMark>> findMarksByMark(String mark) =>
      (select(saleProductMarks)..where((spm) => spm.mark.equals(mark))).get();

  Future<List<SaleProductMark>> findMarksBySaleProduct(int saleProductId) =>
      (select(
        saleProductMarks,
      )..where((spm) => spm.saleProductId.equals(saleProductId))).get();

  /// Снимает все марки со строки продажи.
  ///
  /// Заведён задачей 7: маркировка строки корзины теперь правится
  /// командой (`CartService.setMark`), а не собирается один раз при
  /// завершении продажи. Без снятия прежней марки повторная простановка
  /// оставляла бы у одной строки две марки, и `findMarksBySaleProduct`
  /// возвращал бы обе — на фискальный чек уехала бы произвольная.
  Future<int> deleteMarksBySaleProduct(int saleProductId) => (delete(
    saleProductMarks,
  )..where((m) => m.saleProductId.equals(saleProductId))).go();

  Future<int> insertMark(int saleProductId, String mark) =>
      into(saleProductMarks).insert(
        SaleProductMarksCompanion.insert(
          mark: Value(mark),
          saleProductId: Value(saleProductId),
        ),
      );

  Future<List<SaleCustomField>> findCustomFieldsByReceiptNo(int receiptNo) =>
      (select(
        saleCustomFields,
      )..where((scf) => scf.receiptNo.equals(receiptNo))).get();

  Future<List<UniversalProduct>> findUniversalBySale(
    int receiptNo,
    int posId,
  ) =>
      (select(universalProducts)..where(
            (up) => up.receiptNo.equals(receiptNo) & up.posId.equals(posId),
          ))
          .get();

  Future<UniversalProduct?> findOneUniversal(
    int receiptNo,
    int posId,
    Decimal priceBefore,
  ) =>
      (select(universalProducts)..where(
            (up) =>
                up.receiptNo.equals(receiptNo) &
                up.posId.equals(posId) &
                up.priceBefore.equalsValue(priceBefore),
          ))
          .getSingleOrNull();

  Future<List<UniversalProduct>> findUniversalByRefund(int refundLocalId) =>
      (select(
        universalProducts,
      )..where((up) => up.refundLocalId.equals(refundLocalId))).get();

  Future<int> setUniversalQuantity(int id, Decimal quantity) =>
      (update(universalProducts)..where((up) => up.id.equals(id))).write(
        UniversalProductsCompanion(quantity: Value(quantity)),
      );

  Future<int> setUniversalPriceBefore(int id, Decimal priceBefore) =>
      (update(universalProducts)..where((up) => up.id.equals(id))).write(
        UniversalProductsCompanion(priceBefore: Value(priceBefore)),
      );

  Future<int> setUniversalPrice(int id, Decimal price) =>
      (update(universalProducts)..where((up) => up.id.equals(id))).write(
        UniversalProductsCompanion(price: Value(price)),
      );

  Future<int> countBySale(int receiptNo, int posId) {
    final expr = saleProducts.id.count();
    return (selectOnly(saleProducts)
          ..addColumns([expr])
          ..where(
            saleProducts.receiptNo.equals(receiptNo) &
                saleProducts.posId.equals(posId),
          ))
        .map((row) => row.read(expr)!)
        .getSingle();
  }

  Future<int> deleteBySale(int receiptNo, int posId) async {
    final products = await findBySale(receiptNo, posId);
    final productIds = products.map((p) => p.id).toList();

    if (productIds.isNotEmpty) {
      await (delete(
        saleProductMarks,
      )..where((m) => m.saleProductId.isIn(productIds))).go();
    }

    await (delete(universalProducts)..where(
          (up) => up.receiptNo.equals(receiptNo) & up.posId.equals(posId),
        ))
        .go();

    await (delete(
      saleCustomFields,
    )..where((scf) => scf.receiptNo.equals(receiptNo))).go();

    return (delete(saleProducts)..where(
          (sp) => sp.receiptNo.equals(receiptNo) & sp.posId.equals(posId),
        ))
        .go();
  }
}

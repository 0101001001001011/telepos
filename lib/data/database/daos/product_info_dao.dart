import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/database/tables/nomenclature_tables.dart';

part 'product_info_dao.g.dart';

@DriftAccessor(tables: [ProductInfos, ProductInfoEditions])
class ProductInfoDao extends DatabaseAccessor<AppDatabase>
    with _$ProductInfoDaoMixin {
  ProductInfoDao(super.db);

  Future<List<ProductInfo>> findByNamePart(
    String namePart, {
    bool includeDeleted = false,
  }) =>
      (select(productInfos)
            ..where(
              (pi) => includeDeleted
                  ? pi.name.like(namePart)
                  : pi.name.like(namePart) & pi.isDeleted.equals(false),
            )
            ..orderBy([
              (pi) => OrderingTerm.asc(pi.isDeleted),
              (pi) => OrderingTerm.desc(pi.type),
            ]))
          .get();

  Future<List<QueryRow>> findWithNoAliasByUcodeLike(
    String codePartWildCard,
  ) => customSelect(
    'SELECT pi.* FROM product_infos pi '
    'WHERE CAST(pi.ucode AS TEXT) LIKE ? '
    'AND NOT EXISTS(SELECT 1 FROM product_aliases pa WHERE CAST(pi.ucode AS TEXT) = pa.code)',
    variables: [Variable.withString(codePartWildCard)],
    readsFrom: {productInfos},
  ).get();

  Future<ProductInfo?> findLastByBarcode() =>
      (select(productInfos)
            ..where((pi) => pi.serverEditTime.isNotNull())
            ..orderBy([
              (pi) => OrderingTerm.desc(pi.serverEditTime),
              (pi) => OrderingTerm.desc(pi.barcode),
            ])
            ..limit(1))
          .getSingleOrNull();

  Future<ProductInfo?> findLastByUcode() =>
      (select(productInfos)
            ..where((pi) => pi.serverEditTime.isNotNull())
            ..orderBy([
              (pi) => OrderingTerm.desc(pi.serverEditTime),
              (pi) => OrderingTerm.desc(pi.ucode),
            ])
            ..limit(1))
          .getSingleOrNull();

  Future<ProductInfo?> findWithMaxUcode() =>
      (select(productInfos)
            ..orderBy([(pi) => OrderingTerm.desc(pi.ucode)])
            ..limit(1))
          .getSingleOrNull();

  Future<ProductInfo?> findWithMaxBarcode() =>
      (select(productInfos)
            ..orderBy([(pi) => OrderingTerm.desc(pi.barcode)])
            ..limit(1))
          .getSingleOrNull();

  Future<int> updateName(int ucode, String name) =>
      (update(productInfos)..where((pi) => pi.ucode.equals(ucode))).write(
        ProductInfosCompanion(name: Value(name)),
      );

  Future<int> updateDescriptionAndImage(
    int ucode, {
    String? description,
    String? imagePath,
  }) => (update(productInfos)..where((pi) => pi.ucode.equals(ucode))).write(
    ProductInfosCompanion(
      description: Value(description),
      imagePath: Value(imagePath),
    ),
  );

  Future<int> updateFiscalAttributes(
    int ucode, {
    int? vatRate,
    bool vatRateSet = false,
    String? ntin,
    bool? isMarkable,
  }) => (update(productInfos)..where((pi) => pi.ucode.equals(ucode))).write(
    ProductInfosCompanion(
      vatRate: vatRateSet ? Value(vatRate) : const Value.absent(),
      ntin: ntin != null ? Value(ntin) : const Value.absent(),
      isMarkable: isMarkable != null ? Value(isMarkable) : const Value.absent(),
      localEditTime: Value(DateTime.now()),
    ),
  );

  Future<int> restoreProduct(int ucode) =>
      (update(productInfos)..where((pi) => pi.ucode.equals(ucode))).write(
        const ProductInfosCompanion(isDeleted: Value(false)),
      );

  Future<ProductInfo?> findByIdAndNotDeleted(int ucode) =>
      (select(productInfos)
            ..where((pi) => pi.ucode.equals(ucode) & pi.isDeleted.equals(false))
            ..limit(1))
          .getSingleOrNull();

  Future<ProductInfo?> findByUcode(int ucode) =>
      (select(productInfos)
            ..where((pi) => pi.ucode.equals(ucode))
            ..limit(1))
          .getSingleOrNull();

  Future<List<ProductInfo>> findByCategoryId(
    int categoryId, {
    int limit = 100,
    int offset = 0,
  }) async {
    final rows = await customSelect(
      'SELECT pi.* FROM product_infos pi '
      'INNER JOIN quick_products qp ON qp.ucode = pi.ucode '
      'WHERE qp.parent_id = ? AND pi.is_deleted = 0 '
      'ORDER BY pi.name ASC '
      'LIMIT ? OFFSET ?',
      variables: [
        Variable.withInt(categoryId),
        Variable.withInt(limit),
        Variable.withInt(offset),
      ],
      readsFrom: {productInfos},
    ).get();
    return [for (final row in rows) await productInfos.mapFromRow(row)];
  }

  Future<ProductInfo?> findByBarcode(String barcode) async {
    final barcodeInt = int.tryParse(barcode);
    if (barcodeInt == null) return null;
    return (select(productInfos)
          ..where(
            (pi) => pi.barcode.equals(barcodeInt) & pi.isDeleted.equals(false),
          )
          ..limit(1))
        .getSingleOrNull();
  }

  Future<int> updateQuantity(int ucode, Decimal quantity) =>
      (update(productInfos)..where((pi) => pi.ucode.equals(ucode))).write(
        ProductInfosCompanion(quantity: Value(quantity)),
      );

  Future<void> adjustQuantity(int ucode, Decimal delta) async {
    final product = await findByUcode(ucode);
    if (product == null) return;
    final currentQty = product.quantity ?? Decimal.zero;
    final newQty = currentQty + delta;
    await updateQuantity(ucode, newQty);
  }

  Future<int> deleteAll() => delete(productInfos).go();

  Future<void> insertBulk(List<ProductInfosCompanion> items) async {
    await batch((b) {
      b.insertAllOnConflictUpdate(productInfos, items);
    });
  }

  Future<int> deleteEditions(List<int> ucodes) =>
      (delete(productInfoEditions)..where((pe) => pe.ucode.isIn(ucodes))).go();

  Future<List<ProductInfo>> findAll({
    int? type,
    int? categoryId,
    bool includeDeleted = false,
    int limit = 50,
    int offset = 0,
  }) {
    final q = select(productInfos);
    q.where((pi) {
      Expression<bool> condition = const Constant(true);
      if (!includeDeleted) {
        condition = condition & pi.isDeleted.equals(false);
      }
      if (type != null) {
        condition = condition & pi.type.equals(type);
      }
      if (categoryId != null) {
        condition = condition & pi.categoryId.equals(categoryId);
      }
      return condition;
    });
    q.orderBy([(pi) => OrderingTerm.asc(pi.name)]);
    q.limit(limit, offset: offset);
    return q.get();
  }

  Future<int> countFiltered({
    int? type,
    int? categoryId,
    bool includeDeleted = false,
  }) {
    final expr = productInfos.ucode.count();
    final q = selectOnly(productInfos)..addColumns([expr]);
    Expression<bool> condition = const Constant(true);
    if (!includeDeleted) {
      condition = condition & productInfos.isDeleted.equals(false);
    }
    if (type != null) {
      condition = condition & productInfos.type.equals(type);
    }
    if (categoryId != null) {
      condition = condition & productInfos.categoryId.equals(categoryId);
    }
    q.where(condition);
    return q.map((row) => row.read(expr)!).getSingle();
  }

  Future<int> softDelete(int ucode) =>
      (update(productInfos)..where((pi) => pi.ucode.equals(ucode))).write(
        const ProductInfosCompanion(isDeleted: Value(true)),
      );

  Future<int> count() {
    final expr = productInfos.ucode.count();
    return (selectOnly(productInfos)
          ..addColumns([expr])
          ..where(productInfos.isDeleted.equals(false)))
        .map((row) => row.read(expr)!)
        .getSingle();
  }

  Future<int> countAll() {
    final expr = productInfos.ucode.count();
    return (selectOnly(
      productInfos,
    )..addColumns([expr])).map((row) => row.read(expr)!).getSingle();
  }

  Future<int> countByType(int type) {
    final expr = productInfos.ucode.count();
    return (selectOnly(productInfos)
          ..addColumns([expr])
          ..where(
            productInfos.type.equals(type) &
                productInfos.isDeleted.equals(false),
          ))
        .map((row) => row.read(expr)!)
        .getSingle();
  }

  Future<int> countRegular() => countByType(0);

  Future<int> countWeighted() => countByType(1);

  Future<int> countServices() => countByType(2);

  Future<bool> hasAny() async {
    final c = await count();
    return c > 0;
  }

  Future<ProductStats> getStats() async {
    final total = await count();
    final totalAll = await countAll();
    final regular = await countRegular();
    final weighted = await countWeighted();
    final services = await countServices();

    return ProductStats(
      total: total,
      deleted: totalAll - total,
      regular: regular,
      weighted: weighted,
      services: services,
    );
  }
}

class ProductStats {
  final int total;
  final int deleted;
  final int regular;
  final int weighted;
  final int services;

  const ProductStats({
    required this.total,
    required this.deleted,
    required this.regular,
    required this.weighted,
    required this.services,
  });

  @override
  String toString() =>
      'total=$total (deleted=$deleted, regular=$regular, '
      'weighted=$weighted, services=$services)';
}

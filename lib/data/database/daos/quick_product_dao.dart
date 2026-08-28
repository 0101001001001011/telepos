import 'package:drift/drift.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/database/tables/nomenclature_tables.dart';

part 'quick_product_dao.g.dart';

@DriftAccessor(tables: [QuickProducts])
class QuickProductDao extends DatabaseAccessor<AppDatabase>
    with _$QuickProductDaoMixin {
  QuickProductDao(super.db);

  Future<int?> findLastEditTime() {
    final expr = quickProducts.editTime.max();
    return (selectOnly(
      quickProducts,
    )..addColumns([expr])).map((row) => row.read(expr)).getSingleOrNull();
  }

  Future<List<QuickProduct>> findAllByParents({
    int limit = 100,
    int offset = 0,
  }) =>
      (select(quickProducts)
            ..where((qp) => qp.parentId.isNull() & qp.isActive.equals(true))
            ..orderBy([
              (qp) => OrderingTerm.asc(qp.orderName),
              (qp) => OrderingTerm.desc(qp.id),
            ])
            ..limit(limit, offset: offset))
          .get();

  Future<List<QuickProduct>> findAllByParentId(
    int parentId, {
    int limit = 100,
    int offset = 0,
  }) =>
      (select(quickProducts)
            ..where(
              (qp) =>
                  qp.parentId.equals(parentId) &
                  qp.isActive.equals(true) &
                  qp.ucode.isNotNull(),
            )
            ..orderBy([
              (qp) => OrderingTerm.asc(qp.orderName),
              (qp) => OrderingTerm.desc(qp.id),
            ])
            ..limit(limit, offset: offset))
          .get();

  Future<int> countRootActive() {
    final expr = quickProducts.id.count();
    return (selectOnly(quickProducts)
          ..addColumns([expr])
          ..where(
            quickProducts.productId.isNull() &
                quickProducts.isActive.equals(true),
          ))
        .map((row) => row.read(expr)!)
        .getSingle();
  }

  Future<int> countByParentActive(int parentId) {
    final expr = quickProducts.id.count();
    return (selectOnly(quickProducts)
          ..addColumns([expr])
          ..where(
            quickProducts.parentId.equals(parentId) &
                quickProducts.isActive.equals(true),
          ))
        .map((row) => row.read(expr)!)
        .getSingle();
  }

  Future<QuickProduct?> findLast() =>
      (select(quickProducts)
            ..orderBy([
              (qp) => OrderingTerm.desc(qp.editTime),
              (qp) => OrderingTerm.desc(qp.id),
            ])
            ..limit(1))
          .getSingleOrNull();

  Future<int> count() {
    final expr = quickProducts.id.count();
    return (selectOnly(
      quickProducts,
    )..addColumns([expr])).map((row) => row.read(expr)!).getSingle();
  }

  Future<int> countActive() {
    final expr = quickProducts.id.count();
    return (selectOnly(quickProducts)
          ..addColumns([expr])
          ..where(quickProducts.isActive.equals(true)))
        .map((row) => row.read(expr)!)
        .getSingle();
  }

  Future<int> addQuickProduct({
    required int ucode,
    int? parentId,
    required String orderName,
  }) async {
    final lastId = await _nextId();
    await into(quickProducts).insert(
      QuickProductsCompanion.insert(
        id: Value(lastId),
        ucode: Value(ucode),
        parentId: Value(parentId),
        name: Value(orderName),
        orderName: Value(lastId),
        isActive: Value(true),
        editTime: Value(DateTime.now().millisecondsSinceEpoch ~/ 1000),
      ),
    );
    return lastId;
  }

  Future<int> removeQuickProduct(int id) =>
      (update(quickProducts)..where((qp) => qp.id.equals(id))).write(
        const QuickProductsCompanion(isActive: Value(false)),
      );

  Future<int> reorder(int id, int newOrder) =>
      (update(quickProducts)..where((qp) => qp.id.equals(id))).write(
        QuickProductsCompanion(orderName: Value(newOrder)),
      );

  Future<int> createCategory({required String name, int? parentId}) async {
    final lastId = await _nextId();
    await into(quickProducts).insert(
      QuickProductsCompanion.insert(
        id: Value(lastId),
        name: Value(name),
        parentId: Value(parentId),
        isActive: Value(true),
        editTime: Value(DateTime.now().millisecondsSinceEpoch ~/ 1000),
      ),
    );
    return lastId;
  }

  Future<int> updateCategoryName(int id, String name) =>
      (update(quickProducts)..where((qp) => qp.id.equals(id))).write(
        QuickProductsCompanion(
          name: Value(name),
          editTime: Value(DateTime.now().millisecondsSinceEpoch ~/ 1000),
        ),
      );

  Future<QuickProduct?> findByUcode(int ucode) =>
      (select(quickProducts)
            ..where((qp) => qp.ucode.equals(ucode) & qp.isActive.equals(true))
            ..limit(1))
          .getSingleOrNull();

  Future<int> _nextId() async {
    final expr = quickProducts.id.max();
    final maxId = await (selectOnly(
      quickProducts,
    )..addColumns([expr])).map((row) => row.read(expr)).getSingleOrNull();
    return (maxId ?? 0) + 1;
  }
}

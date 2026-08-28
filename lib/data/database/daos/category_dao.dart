import 'package:drift/drift.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/database/tables/nomenclature_tables.dart';

part 'category_dao.g.dart';

@DriftAccessor(tables: [Categories])
class CategoryDao extends DatabaseAccessor<AppDatabase>
    with _$CategoryDaoMixin {
  CategoryDao(super.db);

  Future<Category?> findByGlobalCategory(int globalCategoryId) => (select(
    categories,
  )..where((c) => c.globalCategory.equals(globalCategoryId))).getSingleOrNull();

  Future<Category?> findLast() =>
      (select(categories)
            ..orderBy([
              (c) => OrderingTerm.desc(c.editTime),
              (c) => OrderingTerm.desc(c.id),
            ])
            ..limit(1))
          .getSingleOrNull();

  Future<List<Category>> findAll({int limit = 100, int offset = 0}) =>
      (select(categories)
            ..orderBy([(c) => OrderingTerm.asc(c.id)])
            ..limit(limit, offset: offset))
          .get();

  Future<Category?> findById(int id) =>
      (select(categories)..where((c) => c.id.equals(id))).getSingleOrNull();

  Future<List<Category>> findChildren(int parentId) =>
      (select(categories)
            ..where((c) => c.parentId.equals(parentId))
            ..orderBy([(c) => OrderingTerm.asc(c.id)]))
          .get();

  Future<List<Category>> findRoots() =>
      (select(categories)
            ..where((c) => c.parentId.isNull())
            ..orderBy([(c) => OrderingTerm.asc(c.id)]))
          .get();

  Future<void> upsertCategory({
    required int id,
    int? parentId,
    String? name,
    int? globalCategory,
    required DateTime createTime,
    DateTime? editTime,
  }) => into(categories).insertOnConflictUpdate(
    CategoriesCompanion.insert(
      id: Value(id),
      parentId: Value(parentId),
      name: Value(name),
      globalCategory: Value(globalCategory),
      createTime: createTime,
      editTime: Value(editTime),
    ),
  );

  Future<void> deleteCategory(int id) =>
      (delete(categories)..where((c) => c.id.equals(id))).go();

  Future<int> count() {
    final expr = categories.id.count();
    return (selectOnly(
      categories,
    )..addColumns([expr])).map((row) => row.read(expr)!).getSingle();
  }
}

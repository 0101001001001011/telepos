import 'package:drift/drift.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/database/tables/nomenclature_tables.dart';

part 'category_restriction_dao.g.dart';

@DriftAccessor(tables: [CategoryRestrictions])
class CategoryRestrictionDao extends DatabaseAccessor<AppDatabase>
    with _$CategoryRestrictionDaoMixin {
  CategoryRestrictionDao(super.db);

  Future<List<CategoryRestriction>> findActiveForCategory(int categoryId) =>
      customSelect(
        'SELECT cr.* FROM category_restrictions cr '
        'WHERE cr.is_active = 1 AND cr.is_deleted = 0 '
        'AND (cr.category_id = ? OR cr.category_id = '
        '(SELECT c.parent_id FROM categories c WHERE c.id = ?))',
        variables: [Variable.withInt(categoryId), Variable.withInt(categoryId)],
        readsFrom: {categoryRestrictions},
      ).get().then(
        (_) =>
            (select(categoryRestrictions)..where(
                  (cr) =>
                      cr.isActive.equals(true) &
                      cr.isDeleted.equals(false) &
                      cr.categoryId.equals(categoryId),
                ))
                .get(),
      );

  Future<CategoryRestriction?> findLast() =>
      (select(categoryRestrictions)
            ..orderBy([
              (cr) => OrderingTerm.desc(cr.editTime),
              (cr) => OrderingTerm.desc(cr.id),
            ])
            ..limit(1))
          .getSingleOrNull();
}

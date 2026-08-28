import 'package:drift/drift.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/database/tables/dish_tables.dart';

part 'dish_recipe_version_dao.g.dart';

@DriftAccessor(tables: [DishRecipeVersions])
class DishRecipeVersionDao extends DatabaseAccessor<AppDatabase>
    with _$DishRecipeVersionDaoMixin {
  DishRecipeVersionDao(super.db);

  Future<List<DishRecipeVersion>> findByDish(int dishUcode) =>
      (select(dishRecipeVersions)
            ..where((v) => v.dishUcode.equals(dishUcode))
            ..orderBy([(v) => OrderingTerm.desc(v.versionNumber)]))
          .get();

  Future<DishRecipeVersion?> findLatest(int dishUcode) =>
      (select(dishRecipeVersions)
            ..where((v) => v.dishUcode.equals(dishUcode))
            ..orderBy([(v) => OrderingTerm.desc(v.versionNumber)])
            ..limit(1))
          .getSingleOrNull();

  Future<int> insertVersion(DishRecipeVersionsCompanion entry) =>
      into(dishRecipeVersions).insert(entry);
}

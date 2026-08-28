import 'package:drift/drift.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/database/tables/dish_tables.dart';

part 'dish_ingredient_dao.g.dart';

@DriftAccessor(tables: [DishIngredients])
class DishIngredientDao extends DatabaseAccessor<AppDatabase>
    with _$DishIngredientDaoMixin {
  DishIngredientDao(super.db);

  Future<List<DishIngredient>> findByDish(int dishUcode) =>
      (select(dishIngredients)
            ..where((d) => d.dishUcode.equals(dishUcode))
            ..orderBy([(d) => OrderingTerm.asc(d.sortOrder)]))
          .get();

  Future<int> countByDish(int dishUcode) async {
    final expr = dishIngredients.id.count();
    return (selectOnly(dishIngredients)
          ..addColumns([expr])
          ..where(dishIngredients.dishUcode.equals(dishUcode)))
        .map((row) => row.read(expr)!)
        .getSingle();
  }

  Future<int> insertIngredient(DishIngredientsCompanion entry) =>
      into(dishIngredients).insert(entry);

  Future<int> updateIngredient(int id, DishIngredientsCompanion entry) =>
      (update(dishIngredients)..where((d) => d.id.equals(id))).write(entry);

  Future<int> deleteById(int id) =>
      (delete(dishIngredients)..where((d) => d.id.equals(id))).go();

  Future<int> deleteByDish(int dishUcode) => (delete(
    dishIngredients,
  )..where((d) => d.dishUcode.equals(dishUcode))).go();

  Future<List<QueryRow>> findIngredientsWithPrices(int dishUcode) =>
      customSelect(
        'SELECT di.*, pi.name AS ingredient_name, '
        'pp.wholesale_price AS purchase_price, '
        'pi.measure AS ingredient_measure '
        'FROM dish_ingredients di '
        'INNER JOIN product_infos pi ON pi.ucode = di.ingredient_ucode '
        'LEFT JOIN product_prices pp ON pp.ucode = di.ingredient_ucode '
        'WHERE di.dish_ucode = ? '
        'ORDER BY di.sort_order ASC',
        variables: [Variable.withInt(dishUcode)],
        readsFrom: {},
      ).get();
}

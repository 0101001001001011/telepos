import 'package:drift/drift.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/database/tables/restaurant_tables.dart';

part 'restaurant_table_dao.g.dart';

@DriftAccessor(tables: [RestaurantTables])
class RestaurantTableDao extends DatabaseAccessor<AppDatabase>
    with _$RestaurantTableDaoMixin {
  RestaurantTableDao(super.db);

  Future<List<RestaurantTable>> getActive() =>
      (select(restaurantTables)
            ..where((t) => t.isActive.equals(true))
            ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
          .get();

  Future<RestaurantTable?> findById(int id) => (select(
    restaurantTables,
  )..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<int> updateStatus(int id, int status) =>
      (update(restaurantTables)..where((t) => t.id.equals(id))).write(
        RestaurantTablesCompanion(status: Value(status)),
      );

  Future<List<RestaurantTable>> getByZone(String zone) =>
      (select(restaurantTables)
            ..where((t) => t.zone.equals(zone) & t.isActive.equals(true))
            ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
          .get();

  Future<int> countByStatus(int status) {
    final expr = restaurantTables.id.count();
    return (selectOnly(restaurantTables)
          ..addColumns([expr])
          ..where(
            restaurantTables.status.equals(status) &
                restaurantTables.isActive.equals(true),
          ))
        .map((row) => row.read(expr)!)
        .getSingle();
  }

  Future<int> insert(RestaurantTablesCompanion entry) =>
      into(restaurantTables).insert(entry);

  Future<bool> updateTable(RestaurantTable entry) =>
      update(restaurantTables).replace(entry);

  Future<int> deactivate(int id) =>
      (update(restaurantTables)..where((t) => t.id.equals(id))).write(
        const RestaurantTablesCompanion(isActive: Value(false)),
      );

  Future<List<String>> getZones() async {
    final rows = await customSelect(
      'SELECT DISTINCT zone FROM restaurant_tables WHERE zone IS NOT NULL AND is_active = 1 ORDER BY zone',
      readsFrom: {restaurantTables},
    ).get();
    return rows.map((r) => r.read<String>('zone')).toList();
  }
}

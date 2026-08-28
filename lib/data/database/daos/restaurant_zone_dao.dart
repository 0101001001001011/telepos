import 'package:drift/drift.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/database/tables/restaurant_tables.dart';

part 'restaurant_zone_dao.g.dart';

@DriftAccessor(tables: [RestaurantZones])
class RestaurantZoneDao extends DatabaseAccessor<AppDatabase>
    with _$RestaurantZoneDaoMixin {
  RestaurantZoneDao(super.db);

  Future<List<RestaurantZone>> getAll() =>
      (select(restaurantZones)..orderBy([
            (z) => OrderingTerm.asc(z.sortOrder),
            (z) => OrderingTerm.asc(z.name),
          ]))
          .get();

  Future<List<String>> getNames() async {
    final rows = await getAll();
    return rows.map((z) => z.name).toList();
  }

  Future<void> upsert(String name, {int sortOrder = 0}) =>
      into(restaurantZones).insertOnConflictUpdate(
        RestaurantZonesCompanion(
          name: Value(name),
          sortOrder: Value(sortOrder),
        ),
      );

  Future<void> replaceAll(List<String> names) async {
    await transaction(() async {
      await delete(restaurantZones).go();
      for (var i = 0; i < names.length; i++) {
        await into(restaurantZones).insertOnConflictUpdate(
          RestaurantZonesCompanion(name: Value(names[i]), sortOrder: Value(i)),
        );
      }
    });
  }
}

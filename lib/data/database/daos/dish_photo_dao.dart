import 'package:drift/drift.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/database/tables/dish_tables.dart';

part 'dish_photo_dao.g.dart';

@DriftAccessor(tables: [DishPhotos])
class DishPhotoDao extends DatabaseAccessor<AppDatabase>
    with _$DishPhotoDaoMixin {
  DishPhotoDao(super.db);

  Future<List<DishPhoto>> findByDish(int dishUcode) =>
      (select(dishPhotos)
            ..where((p) => p.dishUcode.equals(dishUcode))
            ..orderBy([(p) => OrderingTerm.asc(p.createdAt)]))
          .get();

  Future<int> insertPhoto(DishPhotosCompanion entry) =>
      into(dishPhotos).insert(entry);

  Future<int> deleteById(int id) =>
      (delete(dishPhotos)..where((p) => p.id.equals(id))).go();
}

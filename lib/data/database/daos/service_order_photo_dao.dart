import 'package:drift/drift.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/database/tables/service_order_tables.dart';

part 'service_order_photo_dao.g.dart';

@DriftAccessor(tables: [ServiceOrderPhotos])
class ServiceOrderPhotoDao extends DatabaseAccessor<AppDatabase>
    with _$ServiceOrderPhotoDaoMixin {
  ServiceOrderPhotoDao(super.db);

  Future<List<ServiceOrderPhoto>> getByOrder(int serviceOrderId) =>
      (select(serviceOrderPhotos)
            ..where((p) => p.serviceOrderId.equals(serviceOrderId))
            ..orderBy([(p) => OrderingTerm.asc(p.createdAt)]))
          .get();

  Future<List<ServiceOrderPhoto>> getByOrderAndType(
    int serviceOrderId,
    int photoType,
  ) =>
      (select(serviceOrderPhotos)
            ..where(
              (p) =>
                  p.serviceOrderId.equals(serviceOrderId) &
                  p.photoType.equals(photoType),
            )
            ..orderBy([(p) => OrderingTerm.asc(p.createdAt)]))
          .get();

  Future<int> insert(ServiceOrderPhotosCompanion entry) =>
      into(serviceOrderPhotos).insert(entry);

  Future<int> deleteById(int id) =>
      (delete(serviceOrderPhotos)..where((p) => p.id.equals(id))).go();
}

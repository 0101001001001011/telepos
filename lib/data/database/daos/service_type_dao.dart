import 'package:drift/drift.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/database/tables/service_order_tables.dart';

part 'service_type_dao.g.dart';

@DriftAccessor(tables: [ServiceTypes])
class ServiceTypeDao extends DatabaseAccessor<AppDatabase>
    with _$ServiceTypeDaoMixin {
  ServiceTypeDao(super.db);

  Future<List<ServiceType>> getActive() =>
      (select(serviceTypes)..where((t) => t.isActive.equals(true))).get();

  Future<ServiceType?> findByProductUcode(int productUcode) => (select(
    serviceTypes,
  )..where((t) => t.productUcode.equals(productUcode))).getSingleOrNull();

  Future<ServiceType?> findById(int id) =>
      (select(serviceTypes)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<int> insert(ServiceTypesCompanion entry) =>
      into(serviceTypes).insert(entry);

  Future<bool> updateType(ServiceType entry) =>
      update(serviceTypes).replace(entry);

  Future<int> deactivate(int id) =>
      (update(serviceTypes)..where((t) => t.id.equals(id))).write(
        const ServiceTypesCompanion(isActive: Value(false)),
      );
}

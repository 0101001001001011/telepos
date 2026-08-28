import 'package:drift/drift.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/database/tables/service_order_tables.dart';

part 'service_consumable_dao.g.dart';

@DriftAccessor(tables: [ServiceConsumables])
class ServiceConsumableDao extends DatabaseAccessor<AppDatabase>
    with _$ServiceConsumableDaoMixin {
  ServiceConsumableDao(super.db);

  Future<List<ServiceConsumable>> findByService(int serviceProductUcode) =>
      (select(
        serviceConsumables,
      )..where((c) => c.serviceProductUcode.equals(serviceProductUcode))).get();

  Future<int> insert(ServiceConsumablesCompanion entry) =>
      into(serviceConsumables).insert(entry);

  Future<int> deleteById(int id) =>
      (delete(serviceConsumables)..where((c) => c.id.equals(id))).go();

  Future<int> deleteByService(int serviceProductUcode) => (delete(
    serviceConsumables,
  )..where((c) => c.serviceProductUcode.equals(serviceProductUcode))).go();
}

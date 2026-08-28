import 'package:drift/drift.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/database/tables/service_order_tables.dart';

part 'service_order_dao.g.dart';

@DriftAccessor(tables: [ServiceOrders])
class ServiceOrderDao extends DatabaseAccessor<AppDatabase>
    with _$ServiceOrderDaoMixin {
  ServiceOrderDao(super.db);

  Future<List<ServiceOrder>> getByStatus(int status) =>
      (select(serviceOrders)
            ..where((o) => o.status.equals(status))
            ..orderBy([(o) => OrderingTerm.desc(o.intakeTime)]))
          .get();

  Future<List<ServiceOrder>> getActive() =>
      (select(serviceOrders)
            ..where((o) => o.status.isSmallerThanValue(3))
            ..orderBy([(o) => OrderingTerm.desc(o.intakeTime)]))
          .get();

  Future<List<ServiceOrder>> findAll({int limit = 500}) =>
      (select(serviceOrders)
            ..orderBy([(o) => OrderingTerm.desc(o.intakeTime)])
            ..limit(limit))
          .get();

  Future<ServiceOrder?> findById(int id) =>
      (select(serviceOrders)..where((o) => o.id.equals(id))).getSingleOrNull();

  Future<ServiceOrder?> findByOrderNumber(String orderNumber) => (select(
    serviceOrders,
  )..where((o) => o.orderNumber.equals(orderNumber))).getSingleOrNull();

  Future<List<ServiceOrder>> findByClient(int clientAgentId) =>
      (select(serviceOrders)
            ..where((o) => o.clientAgentId.equals(clientAgentId))
            ..orderBy([(o) => OrderingTerm.desc(o.intakeTime)]))
          .get();

  Future<List<ServiceOrder>> searchByClientNameOrPhone(String query) {
    final escaped = query
        .replaceAll(r'\', r'\\')
        .replaceAll('%', r'\%')
        .replaceAll('_', r'\_');
    return (select(serviceOrders)
          ..where(
            (o) =>
                o.clientName.like('%$escaped%') |
                o.clientPhone.like('%$escaped%'),
          )
          ..orderBy([(o) => OrderingTerm.desc(o.intakeTime)]))
        .get();
  }

  Future<int> linkToSale(int id, int receiptNo, int posId) =>
      (update(serviceOrders)..where((o) => o.id.equals(id))).write(
        ServiceOrdersCompanion(
          receiptNo: Value(receiptNo),
          posId: Value(posId),
        ),
      );

  Future<int> updateStatus(int id, int status) =>
      (update(serviceOrders)..where((o) => o.id.equals(id))).write(
        ServiceOrdersCompanion(status: Value(status)),
      );

  Future<String> generateOrderNumber() async {
    return transaction(() async {
      final now = DateTime.now();
      final datePrefix =
          'SO-${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';

      final rows = await customSelect(
        'SELECT COUNT(*) AS cnt FROM service_orders WHERE order_number LIKE ?',
        variables: [Variable.withString('$datePrefix%')],
        readsFrom: {serviceOrders},
      ).get();
      final count = rows.first.read<int>('cnt');
      final seq = (count + 1).toString().padLeft(3, '0');

      return '$datePrefix-$seq';
    });
  }

  Future<int> insert(ServiceOrdersCompanion entry) =>
      into(serviceOrders).insert(entry);

  Future<bool> updateOrder(ServiceOrder entry) =>
      update(serviceOrders).replace(entry);
}

import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/database/tables/restaurant_tables.dart';

part 'restaurant_order_dao.g.dart';

@DriftAccessor(tables: [RestaurantOrders])
class RestaurantOrderDao extends DatabaseAccessor<AppDatabase>
    with _$RestaurantOrderDaoMixin {
  RestaurantOrderDao(super.db);

  Future<List<RestaurantOrder>> getOpenOrders() =>
      (select(restaurantOrders)
            ..where((o) => o.closeTime.isNull())
            ..orderBy([(o) => OrderingTerm.asc(o.openTime)]))
          .get();

  Future<RestaurantOrder?> findOpenByTable(int tableId) =>
      (select(restaurantOrders)
            ..where((o) => o.tableId.equals(tableId) & o.closeTime.isNull()))
          .getSingleOrNull();

  Future<RestaurantOrder?> findById(int id) => (select(
    restaurantOrders,
  )..where((o) => o.id.equals(id))).getSingleOrNull();

  Future<RestaurantOrder?> findBySale(int receiptNo, int posId) =>
      (select(restaurantOrders)..where(
            (o) => o.receiptNo.equals(receiptNo) & o.posId.equals(posId),
          ))
          .getSingleOrNull();

  Future<int> closeOrder(int id, int closeTime) =>
      (update(restaurantOrders)..where((o) => o.id.equals(id))).write(
        RestaurantOrdersCompanion(closeTime: Value(closeTime)),
      );

  Future<int> updateTips(int id, Decimal? tips) =>
      (update(restaurantOrders)..where((o) => o.id.equals(id))).write(
        RestaurantOrdersCompanion(tips: Value(tips)),
      );

  Future<int> transferTable(int orderId, int newTableId) =>
      (update(restaurantOrders)..where((o) => o.id.equals(orderId))).write(
        RestaurantOrdersCompanion(tableId: Value(newTableId)),
      );

  Future<int> insert(RestaurantOrdersCompanion entry) =>
      into(restaurantOrders).insert(entry);

  Future<bool> updateOrder(RestaurantOrder entry) =>
      update(restaurantOrders).replace(entry);

  Future<List<RestaurantOrder>> getOpenByType(int orderType) =>
      (select(restaurantOrders)
            ..where((o) => o.orderType.equals(orderType) & o.closeTime.isNull())
            ..orderBy([(o) => OrderingTerm.asc(o.openTime)]))
          .get();
}

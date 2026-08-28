import 'package:talker/talker.dart';
import 'package:telepos/core/constants/enums/order_type.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/domain/entities/restaurant/restaurant_order_entity.dart';
import 'package:telepos/domain/usecases/restaurant/get_open_orders_use_case.dart';

class GetOpenOrdersUseCaseImpl implements GetOpenOrdersUseCase {
  GetOpenOrdersUseCaseImpl({required AppDatabase db, required Talker logger})
    : _db = db,
      _logger = logger;

  final AppDatabase _db;
  final Talker _logger;

  @override
  Future<List<RestaurantOrderEntity>> getAll() async {
    try {
      final rows = await _db.restaurantOrderDao.getOpenOrders();

      _logger.info('GetOpenOrders: loaded ${rows.length} open orders');

      return rows.map(_mapToEntity).toList();
    } catch (e) {
      _logger.error('GetOpenOrders: failed to get all open orders: $e');
      rethrow;
    }
  }

  @override
  Future<RestaurantOrderEntity?> getByTable(int tableId) async {
    try {
      final row = await _db.restaurantOrderDao.findOpenByTable(tableId);

      if (row == null) {
        _logger.info('GetOpenOrders: no open order for table $tableId');
        return null;
      }

      _logger.info(
        'GetOpenOrders: found open order ${row.id} '
        'for table $tableId',
      );

      return _mapToEntity(row);
    } catch (e) {
      _logger.error(
        'GetOpenOrders: failed to get order for table $tableId: $e',
      );
      rethrow;
    }
  }

  RestaurantOrderEntity _mapToEntity(RestaurantOrder row) {
    return RestaurantOrderEntity(
      id: row.id,
      tableId: row.tableId,
      receiptNo: row.receiptNo,
      posId: row.posId,
      partySize: row.partySize,
      orderType: OrderType.values[row.orderType],
      openTime: row.openTime,
      closeTime: row.closeTime,
      waiterId: row.waiterId,
      tips: row.tips,
      deliveryAddress: row.deliveryAddress,
      deliveryPhone: row.deliveryPhone,
      note: row.note,
    );
  }
}

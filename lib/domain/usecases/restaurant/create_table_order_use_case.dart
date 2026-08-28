import 'package:telepos/core/constants/enums/order_type.dart';
import 'package:telepos/domain/entities/restaurant/restaurant_order_entity.dart';

abstract class CreateTableOrderUseCase {
  Future<RestaurantOrderEntity> create({
    int? tableId,
    int partySize,
    OrderType orderType,
    int? waiterId,
    String? note,
  });
}

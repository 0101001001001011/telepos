import 'package:telepos/domain/entities/restaurant/restaurant_order_entity.dart';

abstract class GetOpenOrdersUseCase {
  Future<List<RestaurantOrderEntity>> getAll();

  Future<RestaurantOrderEntity?> getByTable(int tableId);
}

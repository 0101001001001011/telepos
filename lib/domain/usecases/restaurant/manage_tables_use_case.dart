import 'package:telepos/domain/entities/restaurant/restaurant_table_entity.dart';

abstract class ManageTablesUseCase {
  Future<List<RestaurantTableEntity>> getActiveTables();

  Future<RestaurantTableEntity> createTable({
    required String name,
    int capacity,
    String? zone,
  });

  Future<void> updateTable(RestaurantTableEntity table);

  Future<void> deactivateTable(int tableId);
}

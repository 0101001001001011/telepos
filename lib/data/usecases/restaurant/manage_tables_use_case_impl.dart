import 'package:drift/drift.dart';
import 'package:talker/talker.dart';
import 'package:telepos/core/constants/enums/table_status.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/domain/entities/restaurant/restaurant_table_entity.dart';
import 'package:telepos/domain/usecases/restaurant/manage_tables_use_case.dart';

class ManageTablesUseCaseImpl implements ManageTablesUseCase {
  ManageTablesUseCaseImpl({required AppDatabase db, required Talker logger})
    : _db = db,
      _logger = logger;

  final AppDatabase _db;
  final Talker _logger;

  @override
  Future<List<RestaurantTableEntity>> getActiveTables() async {
    try {
      final rows = await _db.restaurantTableDao.getActive();
      _logger.info('ManageTables: loaded ${rows.length} active tables');
      return rows.map(_mapToEntity).toList();
    } catch (e) {
      _logger.error('ManageTables: failed to get active tables: $e');
      rethrow;
    }
  }

  @override
  Future<RestaurantTableEntity> createTable({
    required String name,
    int capacity = 4,
    String? zone,
  }) async {
    try {
      final id = await _db.restaurantTableDao.insert(
        RestaurantTablesCompanion.insert(
          name: name,
          capacity: Value(capacity),
          zone: Value(zone),
        ),
      );

      _logger.info('ManageTables: created table id=$id, name=$name');

      final row = await _db.restaurantTableDao.findById(id);
      return _mapToEntity(row!);
    } catch (e) {
      _logger.error('ManageTables: failed to create table $name: $e');
      rethrow;
    }
  }

  @override
  Future<void> updateTable(RestaurantTableEntity table) async {
    try {
      final row = RestaurantTable(
        id: table.id,
        name: table.name,
        capacity: table.capacity,
        status: table.status.index,
        zone: table.zone,
        positionX: table.positionX,
        positionY: table.positionY,
        isActive: table.isActive,
        sortOrder: table.sortOrder,
      );

      await _db.restaurantTableDao.updateTable(row);
      _logger.info('ManageTables: updated table id=${table.id}');
    } catch (e) {
      _logger.error('ManageTables: failed to update table ${table.id}: $e');
      rethrow;
    }
  }

  @override
  Future<void> deactivateTable(int tableId) async {
    try {
      await _db.restaurantTableDao.deactivate(tableId);
      _logger.info('ManageTables: deactivated table id=$tableId');
    } catch (e) {
      _logger.error('ManageTables: failed to deactivate table $tableId: $e');
      rethrow;
    }
  }

  RestaurantTableEntity _mapToEntity(RestaurantTable row) {
    return RestaurantTableEntity(
      id: row.id,
      name: row.name,
      capacity: row.capacity,
      status: TableStatus.values[row.status],
      zone: row.zone,
      positionX: row.positionX,
      positionY: row.positionY,
      isActive: row.isActive,
      sortOrder: row.sortOrder,
    );
  }
}

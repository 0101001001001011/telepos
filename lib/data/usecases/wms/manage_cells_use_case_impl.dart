import 'package:telepos/domain/entities/wms/warehouse_cell_entity.dart';
import 'package:telepos/domain/entities/wms/warehouse_zone_entity.dart';
import 'package:telepos/domain/repositories/warehouse_cell_repository.dart';
import 'package:telepos/domain/repositories/warehouse_zone_repository.dart';
import 'package:telepos/domain/usecases/wms/manage_cells_use_case.dart';
import 'package:telepos/domain/usecases/wms/wms_result.dart';

class ManageCellsUseCaseImpl implements ManageCellsUseCase {
  ManageCellsUseCaseImpl(this._zoneRepo, this._cellRepo);

  final WarehouseZoneRepository _zoneRepo;
  final WarehouseCellRepository _cellRepo;

  @override
  Future<WmsResult> createZone({
    required int warehouseId,
    required String code,
    required String name,
    required int type,
    int storageType = 0,
  }) async {
    try {
      final id = await _zoneRepo.create(
        WarehouseZoneEntity(
          warehouseId: warehouseId,
          code: code,
          name: name,
          type: type,
          storageType: storageType,
          isActive: true,
        ),
      );

      return WmsResult.ok(id);
    } catch (e) {
      return WmsResult.failed('Ошибка создания зоны: $e');
    }
  }

  @override
  Future<WmsResult> createCell({
    required int zoneId,
    required String address,
    String? barcode,
  }) async {
    try {
      final zone = await _zoneRepo.findById(zoneId);
      if (zone == null) {
        return WmsResult.failed('Зона с ID $zoneId не найдена');
      }

      final cellBarcode = barcode ?? 'CELL-$address';

      final id = await _cellRepo.create(
        WarehouseCellEntity(
          zoneId: zoneId,
          address: address,
          barcode: cellBarcode,
          isActive: true,
          isBlocked: false,
        ),
      );

      return WmsResult.ok(id);
    } catch (e) {
      return WmsResult.failed('Ошибка создания ячейки: $e');
    }
  }

  @override
  Future<WmsResult> generateCells({
    required int zoneId,
    required CellGenerationParams params,
  }) async {
    try {
      final zone = await _zoneRepo.findById(zoneId);
      if (zone == null) {
        return WmsResult.failed('Зона с ID $zoneId не найдена');
      }

      final prefix = params.prefix ?? '';
      int created = 0;

      for (int row = 1; row <= params.rows; row++) {
        for (int rack = 1; rack <= params.racks; rack++) {
          for (int level = 1; level <= params.levels; level++) {
            for (int bin = 1; bin <= params.bins; bin++) {
              final rowStr = row.toString().padLeft(2, '0');
              final rackStr = rack.toString().padLeft(2, '0');
              final levelStr = level.toString().padLeft(2, '0');
              final binStr = bin.toString().padLeft(2, '0');
              final address = '$prefix$rowStr-$rackStr-$levelStr-$binStr';

              await _cellRepo.create(
                WarehouseCellEntity(
                  zoneId: zoneId,
                  address: address,
                  rowCode: rowStr,
                  rackCode: rackStr,
                  levelCode: levelStr,
                  binCode: binStr,
                  barcode: 'CELL-$address',
                  isActive: true,
                  isBlocked: false,
                ),
              );
              created++;
            }
          }
        }
      }

      return WmsResult.ok(created);
    } catch (e) {
      return WmsResult.failed('Ошибка генерации ячеек: $e');
    }
  }

  @override
  Future<WmsResult> blockCell(int cellId, {required bool blocked}) async {
    try {
      final cell = await _cellRepo.findById(cellId);
      if (cell == null) {
        return WmsResult.failed('Ячейка с ID $cellId не найдена');
      }

      await _cellRepo.setBlocked(cellId, blocked);

      return WmsResult.ok(cellId);
    } catch (e) {
      return WmsResult.failed('Ошибка блокировки ячейки: $e');
    }
  }
}

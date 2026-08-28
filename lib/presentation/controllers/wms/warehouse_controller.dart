import 'package:decimal/decimal.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';
import 'package:telepos/core/errors/safe_error_text.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/domain/entities/wms/warehouse_entity.dart';
import 'package:telepos/domain/entities/wms/warehouse_zone_entity.dart';
import 'package:telepos/domain/entities/wms/warehouse_cell_entity.dart';
import 'package:telepos/domain/repositories/warehouse_repository.dart';
import 'package:telepos/domain/repositories/warehouse_zone_repository.dart';
import 'package:telepos/domain/repositories/warehouse_cell_repository.dart';
import 'package:telepos/domain/usecases/wms/manage_warehouse_use_case.dart';
import 'package:telepos/domain/usecases/wms/manage_cells_use_case.dart';
import 'package:telepos/domain/usecases/wms/wms_result.dart';

@immutable
class WarehouseState {
  const WarehouseState({
    this.warehouses = const [],
    this.zones = const [],
    this.cells = const [],
    this.selectedWarehouseId,
    this.selectedZoneId,
    this.isLoading = false,
    this.error,
  });

  final List<WarehouseEntity> warehouses;

  final List<WarehouseZoneEntity> zones;

  final List<WarehouseCellEntity> cells;

  final int? selectedWarehouseId;

  final int? selectedZoneId;

  final bool isLoading;

  final String? error;

  int get warehouseCount => warehouses.length;

  int get zoneCount => zones.length;

  int get cellCount => cells.length;

  WarehouseEntity? get selectedWarehouse {
    if (selectedWarehouseId == null) return null;
    final idx = warehouses.indexWhere((w) => w.id == selectedWarehouseId);
    return idx >= 0 ? warehouses[idx] : null;
  }

  WarehouseZoneEntity? get selectedZone {
    if (selectedZoneId == null) return null;
    final idx = zones.indexWhere((z) => z.id == selectedZoneId);
    return idx >= 0 ? zones[idx] : null;
  }

  WarehouseState copyWith({
    List<WarehouseEntity>? warehouses,
    List<WarehouseZoneEntity>? zones,
    List<WarehouseCellEntity>? cells,
    int? selectedWarehouseId,
    int? selectedZoneId,
    bool? isLoading,
    String? error,
    bool clearError = false,
    bool clearSelectedWarehouse = false,
    bool clearSelectedZone = false,
  }) => WarehouseState(
    warehouses: warehouses ?? this.warehouses,
    zones: zones ?? this.zones,
    cells: cells ?? this.cells,
    selectedWarehouseId: clearSelectedWarehouse
        ? null
        : (selectedWarehouseId ?? this.selectedWarehouseId),
    selectedZoneId: clearSelectedZone
        ? null
        : (selectedZoneId ?? this.selectedZoneId),
    isLoading: isLoading ?? this.isLoading,
    error: clearError ? null : (error ?? this.error),
  );
}

class WarehouseNotifier extends Notifier<WarehouseState> {
  @override
  WarehouseState build() => const WarehouseState();

  WarehouseRepository get _warehouseRepo => GetIt.I<WarehouseRepository>();
  WarehouseZoneRepository get _zoneRepo => GetIt.I<WarehouseZoneRepository>();
  WarehouseCellRepository get _cellRepo => GetIt.I<WarehouseCellRepository>();

  Future<void> loadWarehouses() async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final warehouses = await _warehouseRepo.findAll();

      state = state.copyWith(warehouses: warehouses, isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'error.load_failed:${safeErrorText(e)}',
      );
    }
  }

  Future<void> selectWarehouse(int id) async {
    state = state.copyWith(
      selectedWarehouseId: id,
      clearSelectedZone: true,
      zones: const [],
      cells: const [],
    );
    await loadZones(id);
  }

  Future<void> loadZones(int warehouseId) async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final zones = await _zoneRepo.findByWarehouseId(warehouseId);

      state = state.copyWith(zones: zones, isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'error.load_failed:${safeErrorText(e)}',
      );
    }
  }

  Future<void> selectZone(int id) async {
    state = state.copyWith(selectedZoneId: id, cells: const []);
    await loadCells(id);
  }

  Future<void> loadCells(int zoneId) async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final cells = await _cellRepo.findByZoneId(zoneId);

      state = state.copyWith(cells: cells, isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'error.load_failed:${safeErrorText(e)}',
      );
    }
  }

  Future<WmsResult> createWarehouse({
    required String code,
    required String name,
    String? address,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final useCase = GetIt.I<ManageWarehouseUseCase>();
      final result = await useCase.createWarehouse(
        code: code,
        name: name,
        address: address,
      );

      state = state.copyWith(isLoading: false);

      if (result.success) {
        await loadWarehouses();
      } else {
        state = state.copyWith(error: result.errorMessage);
      }

      return result;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'error.save_failed:${safeErrorText(e)}',
      );
      return WmsResult.failed('error.unknown:${safeErrorText(e)}');
    }
  }

  Future<WmsResult> createZone({
    required int warehouseId,
    required String code,
    required String name,
    required int type,
    int storageType = 0,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final useCase = GetIt.I<ManageCellsUseCase>();
      final result = await useCase.createZone(
        warehouseId: warehouseId,
        code: code,
        name: name,
        type: type,
        storageType: storageType,
      );

      state = state.copyWith(isLoading: false);

      if (result.success) {
        await loadZones(warehouseId);
      } else {
        state = state.copyWith(error: result.errorMessage);
      }

      return result;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'error.save_failed:${safeErrorText(e)}',
      );
      return WmsResult.failed('error.unknown:${safeErrorText(e)}');
    }
  }

  Future<WmsResult> generateCells(
    int zoneId,
    CellGenerationParams params,
  ) async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final useCase = GetIt.I<ManageCellsUseCase>();
      final result = await useCase.generateCells(
        zoneId: zoneId,
        params: params,
      );

      state = state.copyWith(isLoading: false);

      if (result.success) {
        await loadCells(zoneId);
      } else {
        state = state.copyWith(error: result.errorMessage);
      }

      return result;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'error.save_failed:${safeErrorText(e)}',
      );
      return WmsResult.failed('error.unknown:${safeErrorText(e)}');
    }
  }

  Future<WmsResult> deleteWarehouse(int id) async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final useCase = GetIt.I<ManageWarehouseUseCase>();
      final result = await useCase.deleteWarehouse(id);

      state = state.copyWith(isLoading: false);

      if (result.success) {
        await loadWarehouses();
        if (state.selectedWarehouseId == id) {
          state = state.copyWith(
            clearSelectedWarehouse: true,
            zones: const [],
            cells: const [],
          );
        }
      } else {
        state = state.copyWith(error: result.errorMessage);
      }

      return result;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'error.delete_failed:${safeErrorText(e)}',
      );
      return WmsResult.failed('error.unknown:${safeErrorText(e)}');
    }
  }

  Future<WmsResult> deleteZone(int id) async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final db = GetIt.I<AppDatabase>();
      await db.transaction(() async {
        final cells = await db.warehouseCellDao.findByZoneId(id);
        for (final c in cells) {
          await _assertCellEmpty(db, c.id);
        }
        for (final c in cells) {
          await db.cellStockDao.deleteByCell(c.id);
          await db.warehouseCellDao.deleteCell(c.id);
        }
        await db.warehouseZoneDao.deleteZone(id);
      });

      state = state.copyWith(isLoading: false);

      if (state.selectedWarehouseId != null) {
        await loadZones(state.selectedWarehouseId!);
      }
      if (state.selectedZoneId == id) {
        state = state.copyWith(clearSelectedZone: true, cells: const []);
      }

      return WmsResult.ok();
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'error.delete_failed:${safeErrorText(e)}',
      );
      return WmsResult.failed('error.unknown:${safeErrorText(e)}');
    }
  }

  Future<WmsResult> deleteCell(int id) async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final db = GetIt.I<AppDatabase>();
      await db.transaction(() async {
        await _assertCellEmpty(db, id);
        await db.cellStockDao.deleteByCell(id);
        await db.warehouseCellDao.deleteCell(id);
      });

      state = state.copyWith(isLoading: false);

      if (state.selectedZoneId != null) {
        await loadCells(state.selectedZoneId!);
      }

      return WmsResult.ok();
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'error.delete_failed:${safeErrorText(e)}',
      );
      return WmsResult.failed('error.unknown:${safeErrorText(e)}');
    }
  }

  Future<void> _assertCellEmpty(AppDatabase db, int cellId) async {
    final stocks = await db.cellStockDao.findByCellId(cellId);
    final hasStock = stocks.any((s) => s.quantity > Decimal.zero);
    if (hasStock) {
      throw StateError('error.cell_has_stock:$cellId');
    }
  }
}

final warehouseControllerProvider =
    NotifierProvider<WarehouseNotifier, WarehouseState>(WarehouseNotifier.new);

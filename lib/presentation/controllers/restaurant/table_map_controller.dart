import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';
import 'package:telepos/core/constants/enums/table_status.dart';
import 'package:telepos/core/errors/safe_error_text.dart';
import 'package:telepos/domain/entities/restaurant/restaurant_table_entity.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/domain/usecases/restaurant/manage_tables_use_case.dart';
import 'package:telepos/domain/usecases/restaurant/table_status_use_case.dart';

@immutable
class TableMapState {
  const TableMapState({
    this.tables = const [],
    this.isLoading = false,
    this.selectedTableId,
    this.filterZone,
    this.error,
    this.zoneNames = const [],
  });

  final List<RestaurantTableEntity> tables;
  final bool isLoading;
  final int? selectedTableId;
  final String? filterZone;
  final String? error;

  final List<String> zoneNames;

  int countByStatus(TableStatus status) =>
      tables.where((t) => t.status == status).length;

  List<String> get zones {
    final set = <String>{};
    for (final t in tables) {
      if (t.zone != null) set.add(t.zone!);
    }
    set.addAll(zoneNames);
    return set.toList()..sort();
  }

  List<RestaurantTableEntity> get filteredTables {
    if (filterZone == null) return tables;
    return tables.where((t) => t.zone == filterZone).toList();
  }

  TableMapState copyWith({
    List<RestaurantTableEntity>? tables,
    bool? isLoading,
    int? selectedTableId,
    bool clearSelectedTableId = false,
    String? filterZone,
    bool clearFilterZone = false,
    String? error,
    bool clearError = false,
    List<String>? zoneNames,
  }) {
    return TableMapState(
      tables: tables ?? this.tables,
      isLoading: isLoading ?? this.isLoading,
      selectedTableId: clearSelectedTableId
          ? null
          : (selectedTableId ?? this.selectedTableId),
      filterZone: clearFilterZone ? null : (filterZone ?? this.filterZone),
      error: clearError ? null : (error ?? this.error),
      zoneNames: zoneNames ?? this.zoneNames,
    );
  }
}

class TableMapNotifier extends Notifier<TableMapState> {
  @override
  TableMapState build() {
    Future.microtask(loadTables);
    return const TableMapState();
  }

  Future<void> loadTables() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final tables = await GetIt.I<ManageTablesUseCase>().getActiveTables();
      List<String> zoneNames = const [];
      try {
        zoneNames = await GetIt.I<AppDatabase>().restaurantZoneDao.getNames();
      } catch (_) {}
      state = state.copyWith(
        tables: tables,
        zoneNames: zoneNames,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        error: 'error.load_failed:${safeErrorText(e)}',
        isLoading: false,
      );
    }
  }

  Future<void> refreshTables() => loadTables();

  Future<void> setTableStatus(int id, TableStatus status) async {
    try {
      final useCase = GetIt.I<TableStatusUseCase>();
      switch (status) {
        case TableStatus.free:
          await useCase.setFree(id);
        case TableStatus.occupied:
          await useCase.setOccupied(id);
        case TableStatus.reserved:
          await useCase.setReserved(id);
        case TableStatus.dirty:
          await useCase.setDirty(id);
      }
      await loadTables();
    } catch (e) {
      state = state.copyWith(error: 'error.save_failed:${safeErrorText(e)}');
    }
  }

  void selectTable(int? tableId) {
    state = state.copyWith(
      selectedTableId: tableId,
      clearSelectedTableId: tableId == null,
    );
  }

  void setFilterZone(String? zone) {
    state = state.copyWith(filterZone: zone, clearFilterZone: zone == null);
  }
}

final tableMapProvider = NotifierProvider<TableMapNotifier, TableMapState>(
  TableMapNotifier.new,
);

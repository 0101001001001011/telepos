import 'package:decimal/decimal.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';
import 'package:telepos/core/errors/safe_error_text.dart';
import 'package:telepos/domain/entities/wms/cell_stock_entity.dart';
import 'package:telepos/domain/usecases/wms/cell_stock_use_case.dart';
import 'package:telepos/domain/usecases/wms/wms_result.dart';

@immutable
class CellStockState {
  const CellStockState({
    this.stockItems = const [],
    this.isLoading = false,
    this.error,
  });

  final List<CellStockEntity> stockItems;

  final bool isLoading;

  final String? error;

  int get itemCount => stockItems.length;

  Decimal get totalQuantity => stockItems.fold(
    Decimal.zero,
    (sum, item) => sum + (item.quantity ?? Decimal.zero),
  );

  Decimal get totalAvailable =>
      stockItems.fold(Decimal.zero, (sum, item) => sum + item.availableQty);

  CellStockState copyWith({
    List<CellStockEntity>? stockItems,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) => CellStockState(
    stockItems: stockItems ?? this.stockItems,
    isLoading: isLoading ?? this.isLoading,
    error: clearError ? null : (error ?? this.error),
  );
}

class CellStockNotifier extends Notifier<CellStockState> {
  @override
  CellStockState build() => const CellStockState();

  Future<void> loadStockByCell(int cellId) async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final useCase = GetIt.I<CellStockUseCase>();
      final stockItems = await useCase.getStockByCell(cellId);

      state = state.copyWith(stockItems: stockItems, isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'error.load_failed:${safeErrorText(e)}',
      );
    }
  }

  Future<void> loadStockByProduct(int ucode) async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final useCase = GetIt.I<CellStockUseCase>();
      final stockItems = await useCase.getStockByProduct(ucode);

      state = state.copyWith(stockItems: stockItems, isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'error.load_failed:${safeErrorText(e)}',
      );
    }
  }

  Future<WmsResult> placeStock({
    required int cellId,
    required int ucode,
    required Decimal quantity,
    int? batchId,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final useCase = GetIt.I<CellStockUseCase>();
      final result = await useCase.placeStock(
        cellId: cellId,
        ucode: ucode,
        quantity: quantity,
        batchId: batchId,
      );

      state = state.copyWith(isLoading: false);

      if (result.success) {
        await loadStockByCell(cellId);
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

  Future<WmsResult> pickStock({
    required int cellId,
    required int ucode,
    required Decimal quantity,
    int? batchId,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final useCase = GetIt.I<CellStockUseCase>();
      final result = await useCase.pickStock(
        cellId: cellId,
        ucode: ucode,
        quantity: quantity,
        batchId: batchId,
      );

      state = state.copyWith(isLoading: false);

      if (result.success) {
        await loadStockByCell(cellId);
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

  Future<WmsResult> transferStock({
    required int fromCellId,
    required int toCellId,
    required int ucode,
    required Decimal quantity,
    int? batchId,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final useCase = GetIt.I<CellStockUseCase>();
      final result = await useCase.transferStock(
        fromCellId: fromCellId,
        toCellId: toCellId,
        ucode: ucode,
        quantity: quantity,
        batchId: batchId,
      );

      state = state.copyWith(isLoading: false);

      if (result.success) {
        await loadStockByCell(fromCellId);
        await loadStockByCell(toCellId);
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
}

final cellStockControllerProvider =
    NotifierProvider<CellStockNotifier, CellStockState>(CellStockNotifier.new);

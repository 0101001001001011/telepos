import 'package:decimal/decimal.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';
import 'package:telepos/core/errors/safe_error_text.dart';
import 'package:telepos/domain/entities/wms/batch_entity.dart';
import 'package:telepos/domain/repositories/batch_repository.dart';
import 'package:telepos/domain/usecases/wms/batch_tracking_use_case.dart';
import 'package:telepos/domain/usecases/wms/wms_result.dart';

@immutable
class BatchState {
  const BatchState({
    this.batches = const [],
    this.expiringBatches = const [],
    this.expiredBatches = const [],
    this.isLoading = false,
    this.error,
  });

  final List<BatchEntity> batches;

  final List<BatchEntity> expiringBatches;

  final List<BatchEntity> expiredBatches;

  final bool isLoading;

  final String? error;

  int get batchCount => batches.length;

  int get expiringCount => expiringBatches.length;

  int get expiredCount => expiredBatches.length;

  bool get hasWarnings => expiringCount > 0 || expiredCount > 0;

  BatchState copyWith({
    List<BatchEntity>? batches,
    List<BatchEntity>? expiringBatches,
    List<BatchEntity>? expiredBatches,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) => BatchState(
    batches: batches ?? this.batches,
    expiringBatches: expiringBatches ?? this.expiringBatches,
    expiredBatches: expiredBatches ?? this.expiredBatches,
    isLoading: isLoading ?? this.isLoading,
    error: clearError ? null : (error ?? this.error),
  );
}

class BatchNotifier extends Notifier<BatchState> {
  @override
  BatchState build() => const BatchState();

  BatchRepository get _batchRepo => GetIt.I<BatchRepository>();

  Future<void> loadBatchesByProduct(int ucode) async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final batches = await _batchRepo.findByUcode(ucode);

      state = state.copyWith(batches: batches, isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'error.load_failed:${safeErrorText(e)}',
      );
    }
  }

  Future<void> loadExpiringBatches(int daysAhead) async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final useCase = GetIt.I<BatchTrackingUseCase>();
      final expiringBatches = await useCase.getExpiringBatches(daysAhead);

      state = state.copyWith(
        expiringBatches: expiringBatches,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'error.load_failed:${safeErrorText(e)}',
      );
    }
  }

  Future<void> loadExpiredBatches() async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final useCase = GetIt.I<BatchTrackingUseCase>();
      final expiredBatches = await useCase.getExpiredBatches();

      state = state.copyWith(expiredBatches: expiredBatches, isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'error.load_failed:${safeErrorText(e)}',
      );
    }
  }

  Future<void> _reloadCurrentBatches(int affectedBatchId) async {
    final ucode = state.batches
        .where((b) => b.id == affectedBatchId)
        .map((b) => b.ucode)
        .firstOrNull;
    if (ucode != null) {
      await loadBatchesByProduct(ucode);
    }
  }

  Future<WmsResult> createBatch({
    required int ucode,
    required String batchNumber,
    int? expiryDate,
    int? productionDate,
    int? supplierId,
    required Decimal quantity,
    Decimal? unitCost,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final useCase = GetIt.I<BatchTrackingUseCase>();
      final result = await useCase.createBatch(
        ucode: ucode,
        batchNumber: batchNumber,
        expiryDate: expiryDate,
        productionDate: productionDate,
        supplierId: supplierId,
        quantity: quantity,
        unitCost: unitCost,
      );

      state = state.copyWith(isLoading: false);

      if (result.success) {
        await loadBatchesByProduct(ucode);
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

  Future<WmsResult> quarantineBatch(int id) async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final useCase = GetIt.I<BatchTrackingUseCase>();
      final result = await useCase.quarantineBatch(id);

      state = state.copyWith(isLoading: false);

      if (result.success) {
        await _reloadCurrentBatches(id);
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

  Future<WmsResult> approveBatch(int id) async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final useCase = GetIt.I<BatchTrackingUseCase>();
      final result = await useCase.approveBatch(id);

      state = state.copyWith(isLoading: false);

      if (result.success) {
        await _reloadCurrentBatches(id);
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

final batchControllerProvider = NotifierProvider<BatchNotifier, BatchState>(
  BatchNotifier.new,
);

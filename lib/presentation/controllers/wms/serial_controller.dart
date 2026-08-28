import 'package:decimal/decimal.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';
import 'package:telepos/core/errors/safe_error_text.dart';
import 'package:telepos/domain/entities/wms/serial_entity.dart';
import 'package:telepos/domain/entities/wms/serial_movement_entity.dart';
import 'package:telepos/domain/repositories/serial_repository.dart';
import 'package:telepos/domain/usecases/wms/serial_tracking_use_case.dart';
import 'package:telepos/domain/usecases/wms/wms_result.dart';

@immutable
class SerialState {
  const SerialState({
    this.serials = const [],
    this.movements = const [],
    this.isLoading = false,
    this.error,
  });

  final List<SerialEntity> serials;

  final List<SerialMovementEntity> movements;

  final bool isLoading;

  final String? error;

  int get serialCount => serials.length;

  int get availableCount => serials.where((s) => s.isAvailable).length;

  SerialState copyWith({
    List<SerialEntity>? serials,
    List<SerialMovementEntity>? movements,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) => SerialState(
    serials: serials ?? this.serials,
    movements: movements ?? this.movements,
    isLoading: isLoading ?? this.isLoading,
    error: clearError ? null : (error ?? this.error),
  );
}

class SerialNotifier extends Notifier<SerialState> {
  @override
  SerialState build() => const SerialState();

  SerialRepository get _serialRepo => GetIt.I<SerialRepository>();

  Future<void> loadSerialsByProduct(int ucode) async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final serials = await _serialRepo.findByUcode(ucode);

      state = state.copyWith(serials: serials, isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'error.load_failed:${safeErrorText(e)}',
      );
    }
  }

  Future<void> searchBySerialNumber(String sn) async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final serial = await _serialRepo.findBySerialNumber(sn);
      if (serial == null) {
        state = state.copyWith(
          serials: const [],
          isLoading: false,
          error: 'error.serial_not_found:$sn',
        );
        return;
      }

      state = state.copyWith(serials: [serial], isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'error.load_failed:${safeErrorText(e)}',
      );
    }
  }

  Future<WmsResult> registerSerial({
    required int ucode,
    required String serialNumber,
    int? type,
    int? batchId,
    int? supplierId,
    Decimal? purchasePrice,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final useCase = GetIt.I<SerialTrackingUseCase>();
      final result = await useCase.registerSerial(
        ucode: ucode,
        serialNumber: serialNumber,
        type: type,
        batchId: batchId,
        supplierId: supplierId,
        purchasePrice: purchasePrice,
      );

      state = state.copyWith(isLoading: false);

      if (result.success) {
        await loadSerialsByProduct(ucode);
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

  Future<void> _reloadCurrentSerials(int affectedSerialId) async {
    final ucode = state.serials
        .where((s) => s.id == affectedSerialId)
        .map((s) => s.ucode)
        .firstOrNull;
    if (ucode != null) {
      await loadSerialsByProduct(ucode);
    }
  }

  Future<WmsResult> markAsSold(
    int serialId, {
    required int saleId,
    required int userId,
    Decimal? salePrice,
    int? customerId,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final useCase = GetIt.I<SerialTrackingUseCase>();
      final result = await useCase.markAsSold(
        serialId,
        saleId: saleId,
        userId: userId,
        salePrice: salePrice,
        customerId: customerId,
      );

      state = state.copyWith(isLoading: false);

      if (result.success) {
        await _reloadCurrentSerials(serialId);
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

  Future<WmsResult> markAsReturned(int serialId) async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final useCase = GetIt.I<SerialTrackingUseCase>();
      final result = await useCase.markAsReturned(serialId);

      state = state.copyWith(isLoading: false);

      if (result.success) {
        await _reloadCurrentSerials(serialId);
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

  Future<void> loadMovements(int serialId) async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final movements = await _serialRepo.getMovements(serialId);

      state = state.copyWith(movements: movements, isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'error.load_failed:${safeErrorText(e)}',
      );
    }
  }
}

final serialControllerProvider = NotifierProvider<SerialNotifier, SerialState>(
  SerialNotifier.new,
);

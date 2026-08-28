import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';
import 'package:telepos/core/errors/safe_error_text.dart';
import 'package:telepos/domain/entities/wms/wms_config_entity.dart';
import 'package:telepos/domain/usecases/wms/wms_config_use_case.dart';
import 'package:telepos/domain/usecases/wms/wms_result.dart';

@immutable
class WmsConfigState {
  const WmsConfigState({
    this.config,
    this.isLoading = false,
    this.isSaving = false,
    this.error,
  });

  final WmsConfigEntity? config;

  final bool isLoading;

  final bool isSaving;

  final String? error;

  bool get hasAnyFeatureEnabled => config?.hasAnyFeatureEnabled ?? false;

  WmsConfigState copyWith({
    WmsConfigEntity? config,
    bool? isLoading,
    bool? isSaving,
    String? error,
    bool clearError = false,
  }) => WmsConfigState(
    config: config ?? this.config,
    isLoading: isLoading ?? this.isLoading,
    isSaving: isSaving ?? this.isSaving,
    error: clearError ? null : (error ?? this.error),
  );
}

class WmsConfigNotifier extends Notifier<WmsConfigState> {
  @override
  WmsConfigState build() => const WmsConfigState();

  Future<void> loadConfig() async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final useCase = GetIt.I<WmsConfigUseCase>();
      final config = await useCase.getConfig();

      state = state.copyWith(config: config, isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'error.load_failed:${safeErrorText(e)}',
      );
    }
  }

  Future<WmsResult> saveConfig(WmsConfigEntity config) async {
    state = state.copyWith(isSaving: true, clearError: true);

    try {
      final useCase = GetIt.I<WmsConfigUseCase>();
      final result = await useCase.saveConfig(config);

      if (result.success) {
        state = state.copyWith(config: config, isSaving: false);
      } else {
        state = state.copyWith(isSaving: false, error: result.errorMessage);
      }

      return result;
    } catch (e) {
      state = state.copyWith(
        isSaving: false,
        error: 'error.save_failed:${safeErrorText(e)}',
      );
      return WmsResult.failed('error.unknown:${safeErrorText(e)}');
    }
  }

  Future<void> toggleModule(String moduleName, bool enabled) async {
    final current = state.config;
    if (current == null) return;

    WmsConfigEntity updated;
    switch (moduleName) {
      case 'batches':
        updated = current.copyWith(enableBatches: enabled);
        break;
      case 'serials':
        updated = current.copyWith(enableSerials: enabled);
        break;
      case 'cells':
        updated = current.copyWith(enableCells: enabled);
        break;
      case 'markingCodes':
        updated = current.copyWith(enableMarkingCodes: enabled);
        break;
      case 'warranty':
        updated = current.copyWith(enableWarranty: enabled);
        break;
      case 'stockRules':
        updated = current.copyWith(enableStockRules: enabled);
        break;
      case 'fifo':
        updated = current.copyWith(enableFifo: enabled);
        break;
      case 'fefo':
        updated = current.copyWith(enableFefo: enabled);
        break;
      default:
        return;
    }

    await saveConfig(updated);
  }
}

final wmsConfigControllerProvider =
    NotifierProvider<WmsConfigNotifier, WmsConfigState>(WmsConfigNotifier.new);

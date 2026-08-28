import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';

import 'package:telepos/core/locale/locale_provider.dart';
import 'package:telepos/data/fiscal/fiscal_settings_store.dart';
import 'package:telepos/domain/fiscal/fiscal_provider.dart';
import 'package:telepos/domain/fiscal/fiscal_provider_registry.dart';
import 'package:telepos/domain/fiscal/fiscal_settings.dart';

final fiscalSettingsStoreProvider = Provider<FiscalSettingsStore>((ref) {
  return FiscalSettingsStore(ref.watch(sharedPreferencesProvider));
});

final fiscalProviderRegistryProvider = Provider<FiscalProviderRegistry>((ref) {
  return GetIt.I<FiscalProviderRegistry>();
});

class FiscalSettingsState {
  const FiscalSettingsState({
    required this.settings,
    this.loading = false,
    this.saved = false,
    this.validationError,
  });

  final FiscalSettings settings;

  final bool loading;

  final bool saved;

  final String? validationError;

  factory FiscalSettingsState.initial() =>
      FiscalSettingsState(settings: FiscalSettings.disabled(), loading: true);

  FiscalSettingsState copyWith({
    FiscalSettings? settings,
    bool? loading,
    bool? saved,
    String? validationError,
    bool clearValidationError = false,
  }) {
    return FiscalSettingsState(
      settings: settings ?? this.settings,
      loading: loading ?? this.loading,
      saved: saved ?? this.saved,
      validationError: clearValidationError
          ? null
          : (validationError ?? this.validationError),
    );
  }
}

class FiscalSettingsController extends Notifier<FiscalSettingsState> {
  late FiscalSettingsStore _store;

  @override
  FiscalSettingsState build() {
    _store = ref.watch(fiscalSettingsStoreProvider);
    final loaded = _store.load();
    return FiscalSettingsState(settings: loaded);
  }

  void update(FiscalSettings settings) {
    state = state.copyWith(
      settings: settings,
      saved: false,
      clearValidationError: true,
    );
  }

  void selectOperator(FiscalOperatorType operator) {
    final current = state.settings;
    final keepBaseUrl = current.baseUrl != null && current.baseUrl!.isNotEmpty;
    update(
      current.copyWith(
        operatorType: operator,
        baseUrl: keepBaseUrl
            ? current.baseUrl
            : FiscalDefaults.cloudBaseUrl(operator, testMode: current.testMode),
      ),
    );
  }

  Future<bool> save() async {
    final settings = state.settings;
    if (settings.isEnabled) {
      final registry = ref.read(fiscalProviderRegistryProvider);
      final provider = registry.resolve(settings);
      final error = provider.validateConfig(settings);
      if (error != null) {
        state = state.copyWith(validationError: error, saved: false);
        return false;
      }
    }
    final ok = await _store.save(settings);
    state = state.copyWith(saved: ok, clearValidationError: true);
    return ok;
  }

  FiscalProvider resolveProvider() {
    final registry = ref.read(fiscalProviderRegistryProvider);
    return registry.resolve(state.settings);
  }
}

final fiscalSettingsControllerProvider =
    NotifierProvider<FiscalSettingsController, FiscalSettingsState>(
      FiscalSettingsController.new,
    );

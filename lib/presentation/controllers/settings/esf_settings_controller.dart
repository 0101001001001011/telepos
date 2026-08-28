import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';

import 'package:telepos/core/locale/locale_provider.dart';
import 'package:telepos/data/esf/esf_settings_store.dart';
import 'package:telepos/domain/esf/esf_provider.dart';
import 'package:telepos/domain/esf/esf_provider_registry.dart';
import 'package:telepos/domain/esf/esf_settings.dart';

final esfSettingsStoreProvider = Provider<EsfSettingsStore>((ref) {
  return EsfSettingsStore(ref.watch(sharedPreferencesProvider));
});

final esfProviderRegistryProvider = Provider<EsfProviderRegistry>((ref) {
  return GetIt.I<EsfProviderRegistry>();
});

class EsfSettingsState {
  const EsfSettingsState({
    required this.settings,
    this.loading = false,
    this.saved = false,
    this.validationError,
  });

  final EsfSettings settings;
  final bool loading;
  final bool saved;
  final String? validationError;

  factory EsfSettingsState.initial() =>
      EsfSettingsState(settings: EsfSettings.disabled(), loading: true);

  EsfSettingsState copyWith({
    EsfSettings? settings,
    bool? loading,
    bool? saved,
    String? validationError,
    bool clearValidationError = false,
  }) {
    return EsfSettingsState(
      settings: settings ?? this.settings,
      loading: loading ?? this.loading,
      saved: saved ?? this.saved,
      validationError: clearValidationError
          ? null
          : (validationError ?? this.validationError),
    );
  }
}

class EsfSettingsController extends Notifier<EsfSettingsState> {
  late EsfSettingsStore _store;

  @override
  EsfSettingsState build() {
    _store = ref.watch(esfSettingsStoreProvider);
    final loaded = _store.load();
    return EsfSettingsState(settings: loaded);
  }

  void update(EsfSettings settings) {
    state = state.copyWith(
      settings: settings,
      saved: false,
      clearValidationError: true,
    );
  }

  void setEnabled(bool enabled) => update(
    state.settings.copyWith(
      enabled: enabled,
      operatorType: enabled
          ? EsfOperatorType.kgdEsf
          : state.settings.operatorType,
    ),
  );

  void selectOperator(EsfOperatorType operator) =>
      update(state.settings.copyWith(operatorType: operator));

  Future<bool> save() async {
    final settings = state.settings;
    if (settings.isEnabled) {
      final registry = ref.read(esfProviderRegistryProvider);
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

  EsfProvider resolveProvider() {
    final registry = ref.read(esfProviderRegistryProvider);
    return registry.resolve(state.settings);
  }
}

final esfSettingsControllerProvider =
    NotifierProvider<EsfSettingsController, EsfSettingsState>(
      EsfSettingsController.new,
    );

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';
import 'package:telepos/domain/fiscal/fiscal_offset_settings.dart';

/// Сертификат и аванс в фискальном документе — три настройки кассы.
///
/// Сохраняются **сразу**, а не кнопкой «Сохранить» экрана: кнопка пишет
/// настройки подключения к оператору в prefs, а эти лежат строкой `ThisPos`
/// и от проверки подключения не зависят.
class FiscalOffsetSettingsController
    extends AsyncNotifier<FiscalOffsetSettings> {
  FiscalOffsetSettingsStore get _store => GetIt.I<FiscalOffsetSettingsStore>();

  @override
  Future<FiscalOffsetSettings> build() => _store.load();

  /// `false` — не сохранилось; показанное значение возвращается прежним,
  /// чтобы экран не показывал настройку, которой в базе нет.
  Future<bool> change(FiscalOffsetSettings next) async {
    final previous = state.value;
    state = AsyncData(next);
    try {
      await _store.save(next);
      return true;
    } catch (_) {
      if (previous != null) state = AsyncData(previous);
      return false;
    }
  }
}

final fiscalOffsetSettingsControllerProvider =
    AsyncNotifierProvider<FiscalOffsetSettingsController, FiscalOffsetSettings>(
      FiscalOffsetSettingsController.new,
    );

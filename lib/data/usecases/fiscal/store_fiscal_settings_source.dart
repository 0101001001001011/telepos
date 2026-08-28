import 'package:telepos/data/fiscal/fiscal_settings_store.dart';
import 'package:telepos/domain/fiscal/fiscal_settings.dart';
import 'package:telepos/domain/usecases/fiscal/fiscal_service.dart';

class StoreFiscalSettingsSource implements FiscalSettingsSource {
  StoreFiscalSettingsSource({
    required FiscalSettingsStore store,
    required FiscalSettingsSource fallback,
  }) : _store = store,
       _fallback = fallback;

  final FiscalSettingsStore _store;
  final FiscalSettingsSource _fallback;

  @override
  Future<FiscalSettings> load() async {
    final fromUi = _store.load();
    if (fromUi.operatorType != FiscalOperatorType.none) return fromUi;
    return _fallback.load();
  }
}

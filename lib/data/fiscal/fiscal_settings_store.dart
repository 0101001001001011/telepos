import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:telepos/domain/fiscal/fiscal_settings.dart';

class FiscalSettingsStore {
  FiscalSettingsStore(this._prefs);

  final SharedPreferences _prefs;

  static const String prefsKey = 'fiscal_settings_v1';

  FiscalSettings load() {
    final raw = _prefs.getString(prefsKey);
    if (raw == null || raw.isEmpty) {
      return FiscalSettings.disabled();
    }
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return FiscalSettings.fromJson(json);
    } catch (_) {
      return FiscalSettings.disabled();
    }
  }

  Future<bool> save(FiscalSettings settings) {
    return _prefs.setString(prefsKey, jsonEncode(settings.toJson()));
  }

  Future<bool> clear() => _prefs.remove(prefsKey);

  bool get hasSettings => _prefs.containsKey(prefsKey);
}

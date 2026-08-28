import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:telepos/domain/esutd/esutd_settings.dart';

class EsutdSettingsStore {
  EsutdSettingsStore(this._prefs);

  final SharedPreferences _prefs;

  static const String prefsKey = 'esutd_settings_v1';

  EsutdSettings load() {
    final raw = _prefs.getString(prefsKey);
    if (raw == null || raw.isEmpty) {
      return EsutdSettings.disabled();
    }
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return EsutdSettings.fromJson(json);
    } catch (_) {
      return EsutdSettings.disabled();
    }
  }

  Future<bool> save(EsutdSettings settings) =>
      _prefs.setString(prefsKey, jsonEncode(settings.toJson()));

  Future<bool> clear() => _prefs.remove(prefsKey);

  bool get hasSettings => _prefs.containsKey(prefsKey);
}

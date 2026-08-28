import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:telepos/domain/esf/esf_settings.dart';

class EsfSettingsStore {
  EsfSettingsStore(this._prefs);

  final SharedPreferences _prefs;

  static const String prefsKey = 'esf_settings_v1';

  EsfSettings load() {
    final raw = _prefs.getString(prefsKey);
    if (raw == null || raw.isEmpty) {
      return EsfSettings.disabled();
    }
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return EsfSettings.fromJson(json);
    } catch (_) {
      return EsfSettings.disabled();
    }
  }

  Future<bool> save(EsfSettings settings) =>
      _prefs.setString(prefsKey, jsonEncode(settings.toJson()));

  Future<bool> clear() => _prefs.remove(prefsKey);

  bool get hasSettings => _prefs.containsKey(prefsKey);
}

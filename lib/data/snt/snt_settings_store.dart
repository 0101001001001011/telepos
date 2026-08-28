import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:telepos/domain/snt/snt_settings.dart';

class SntSettingsStore {
  SntSettingsStore(this._prefs);

  final SharedPreferences _prefs;

  static const String prefsKey = 'snt_settings_v1';

  SntSettings load() {
    final raw = _prefs.getString(prefsKey);
    if (raw == null || raw.isEmpty) {
      return SntSettings.disabled();
    }
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return SntSettings.fromJson(json);
    } catch (_) {
      return SntSettings.disabled();
    }
  }

  Future<bool> save(SntSettings settings) =>
      _prefs.setString(prefsKey, jsonEncode(settings.toJson()));

  Future<bool> clear() => _prefs.remove(prefsKey);

  bool get hasSettings => _prefs.containsKey(prefsKey);
}

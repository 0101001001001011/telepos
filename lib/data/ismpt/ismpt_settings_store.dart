import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:telepos/domain/ismpt/ismpt_settings.dart';

class IsMptSettingsStore {
  IsMptSettingsStore(this._prefs);

  final SharedPreferences _prefs;

  static const String prefsKey = 'ismpt_settings_v1';

  IsMptSettings load() {
    final raw = _prefs.getString(prefsKey);
    if (raw == null || raw.isEmpty) {
      return IsMptSettings.disabled();
    }
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return IsMptSettings.fromJson(json);
    } catch (_) {
      return IsMptSettings.disabled();
    }
  }

  Future<bool> save(IsMptSettings settings) =>
      _prefs.setString(prefsKey, jsonEncode(settings.toJson()));

  Future<bool> clear() => _prefs.remove(prefsKey);

  bool get hasSettings => _prefs.containsKey(prefsKey);
}

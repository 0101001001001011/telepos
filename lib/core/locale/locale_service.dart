import 'dart:ui';

import 'package:shared_preferences/shared_preferences.dart';

import 'app_locale.dart';

class LocaleService {
  LocaleService(this._prefs);

  final SharedPreferences _prefs;

  static const String _localeKey = 'app_locale';

  AppLocale? getSavedLocale() {
    final code = _prefs.getString(_localeKey);
    if (code == null) return null;
    return AppLocale.fromCode(code);
  }

  Future<bool> saveLocale(AppLocale locale) {
    return _prefs.setString(_localeKey, locale.languageCode);
  }

  Future<bool> clearLocale() {
    return _prefs.remove(_localeKey);
  }

  AppLocale getEffectiveLocale(Locale systemLocale) {
    final saved = getSavedLocale();
    if (saved != null) return saved;

    return AppLocale.fromSystemLocale(systemLocale);
  }
}

import 'package:shared_preferences/shared_preferences.dart';

class LocalProperties {
  LocalProperties._(this._prefs);

  final SharedPreferences _prefs;

  SharedPreferences get prefs => _prefs;

  static Future<LocalProperties> create() async {
    final prefs = await SharedPreferences.getInstance();
    return LocalProperties._(prefs);
  }

  LocalProperties.forTesting(this._prefs);

  static const _keyIsSyncedOnce = 'is_synced_once';
  static const _keyReservedBarcodeRegex = 'reserved_barcode_regex';

  bool get isSyncedOnce => _prefs.getBool(_keyIsSyncedOnce) ?? false;

  set isSyncedOnce(bool value) => _prefs.setBool(_keyIsSyncedOnce, value);

  List<String> get reservedBarcodeRegex {
    final raw = _prefs.getString(_keyReservedBarcodeRegex);
    if (raw == null || raw.isEmpty) return [];
    return raw.split(',');
  }

  set reservedBarcodeRegex(List<String> value) =>
      _prefs.setString(_keyReservedBarcodeRegex, value.join(','));

  static const _keyLastReceiptNo = 'last_receipt_no';
  static const _keyLastReceiptType = 'last_receipt_type';
  static const _keyPrinterEnabled = 'printer_enabled';
  static const _keyQuickProductDisplayType = 'quick_product_display_type';
  static const _keyPathToApp = 'path_to_app';
  static const _keyVersionOfApp = 'version_of_app';
  static const _keyIsLastReceiptNoLoadedOnce = 'is_last_receipt_no_loaded_once';
  static const _keyLanguagePreference = 'language_preference';
  static const _keyPosKey = 'pos_key';
  static const _keyPosToken = 'pos_token';
  static const _keySyncIntervalMinutes = 'sync_interval_minutes';
  static const _keyAutoSyncEnabled = 'auto_sync_enabled';

  String? get posKey => _prefs.getString(_keyPosKey);

  set posKey(String? value) {
    if (value == null) {
      _prefs.remove(_keyPosKey);
    } else {
      _prefs.setString(_keyPosKey, value);
    }
  }

  String? get posToken => _prefs.getString(_keyPosToken);

  set posToken(String? value) {
    if (value == null) {
      _prefs.remove(_keyPosToken);
    } else {
      _prefs.setString(_keyPosToken, value);
    }
  }

  int get lastReceiptNo => _prefs.getInt(_keyLastReceiptNo) ?? -1;

  set lastReceiptNo(int value) => _prefs.setInt(_keyLastReceiptNo, value);

  String get lastReceiptType =>
      _prefs.getString(_keyLastReceiptType) ?? 'unknown';

  set lastReceiptType(String value) =>
      _prefs.setString(_keyLastReceiptType, value);

  bool get printerEnabled => _prefs.getBool(_keyPrinterEnabled) ?? true;

  set printerEnabled(bool value) => _prefs.setBool(_keyPrinterEnabled, value);

  String get quickProductDisplayType =>
      _prefs.getString(_keyQuickProductDisplayType) ?? 'GRID';

  set quickProductDisplayType(String value) =>
      _prefs.setString(_keyQuickProductDisplayType, value);

  String get pathToApp => _prefs.getString(_keyPathToApp) ?? '';

  set pathToApp(String value) => _prefs.setString(_keyPathToApp, value);

  String get versionOfApp => _prefs.getString(_keyVersionOfApp) ?? '';

  set versionOfApp(String value) => _prefs.setString(_keyVersionOfApp, value);

  bool get isLastReceiptNoLoadedOnce =>
      _prefs.getBool(_keyIsLastReceiptNoLoadedOnce) ?? false;

  set isLastReceiptNoLoadedOnce(bool value) =>
      _prefs.setBool(_keyIsLastReceiptNoLoadedOnce, value);

  String get languagePreference =>
      _prefs.getString(_keyLanguagePreference) ?? 'ru';

  set languagePreference(String value) =>
      _prefs.setString(_keyLanguagePreference, value);

  int get syncIntervalMinutes => _prefs.getInt(_keySyncIntervalMinutes) ?? 5;

  set syncIntervalMinutes(int value) =>
      _prefs.setInt(_keySyncIntervalMinutes, value);

  bool get autoSyncEnabled => _prefs.getBool(_keyAutoSyncEnabled) ?? true;

  set autoSyncEnabled(bool value) => _prefs.setBool(_keyAutoSyncEnabled, value);

  static const _keyTelegramEnabled = 'telegram_enabled';

  bool get telegramEnabled => _prefs.getBool(_keyTelegramEnabled) ?? false;

  set telegramEnabled(bool value) => _prefs.setBool(_keyTelegramEnabled, value);

  static const _keyCouchDbUrl = 'couchdb_url';
  static const _keyCouchDbName = 'couchdb_db_name';
  static const _keyCouchDbUser = 'couchdb_user';
  static const _keyCouchDbPass = 'couchdb_pass';

  String? get couchDbUrl => _prefs.getString(_keyCouchDbUrl);
  set couchDbUrl(String? v) => v != null
      ? _prefs.setString(_keyCouchDbUrl, v)
      : _prefs.remove(_keyCouchDbUrl);

  String? get couchDbName => _prefs.getString(_keyCouchDbName);
  set couchDbName(String? v) => v != null
      ? _prefs.setString(_keyCouchDbName, v)
      : _prefs.remove(_keyCouchDbName);

  String? get couchDbUser => _prefs.getString(_keyCouchDbUser);
  set couchDbUser(String? v) => v != null
      ? _prefs.setString(_keyCouchDbUser, v)
      : _prefs.remove(_keyCouchDbUser);

  String? get couchDbPass => _prefs.getString(_keyCouchDbPass);
  set couchDbPass(String? v) => v != null
      ? _prefs.setString(_keyCouchDbPass, v)
      : _prefs.remove(_keyCouchDbPass);

  bool get isCouchDbConfigured =>
      couchDbUrl != null &&
      couchDbName != null &&
      couchDbUser != null &&
      couchDbPass != null;

  Future<bool> clear() => _prefs.clear();

  void resetInitialization() {
    isSyncedOnce = false;
    isLastReceiptNoLoadedOnce = false;
  }

  bool get needsFullInitialization => !isSyncedOnce;
}

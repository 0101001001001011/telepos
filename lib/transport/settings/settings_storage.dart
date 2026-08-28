import 'transport_settings.dart';

abstract class SettingsStorage {
  Future<TransportSettings?> load();

  Future<void> save(TransportSettings settings);

  Future<void> clear();

  Future<bool> hasSettings();

  Future<DateTime?> getLastModified();
}

typedef SettingsChangedCallback =
    void Function(TransportSettings oldSettings, TransportSettings newSettings);

class SettingsManager {
  final SettingsStorage _storage;
  final List<SettingsChangedCallback> _listeners = [];

  TransportSettings? _currentSettings;

  SettingsManager(this._storage);

  TransportSettings get currentSettings =>
      _currentSettings ?? _defaultSettings();

  bool get isLoaded => _currentSettings != null;

  Future<void> initialize() async {
    _currentSettings = await _storage.load() ?? _defaultSettings();
  }

  Future<void> updateSettings(TransportSettings newSettings) async {
    final oldSettings = _currentSettings;
    _currentSettings = newSettings;
    await _storage.save(newSettings);

    if (oldSettings != null) {
      for (final listener in _listeners) {
        listener(oldSettings, newSettings);
      }
    }
  }

  Future<void> resetToDefaults() async {
    final oldSettings = _currentSettings;
    final newSettings = _defaultSettings();
    _currentSettings = newSettings;
    await _storage.save(newSettings);

    if (oldSettings != null) {
      for (final listener in _listeners) {
        listener(oldSettings, newSettings);
      }
    }
  }

  void addListener(SettingsChangedCallback callback) {
    _listeners.add(callback);
  }

  void removeListener(SettingsChangedCallback callback) {
    _listeners.remove(callback);
  }

  void dispose() {
    _listeners.clear();
  }

  TransportSettings _defaultSettings() {
    return TransportSettings.restDefault(
      baseUrl: 'https://api.telepos.example.com',
    );
  }
}

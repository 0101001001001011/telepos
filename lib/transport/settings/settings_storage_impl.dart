import 'dart:convert';
import 'dart:io';

import 'settings_storage.dart';
import 'transport_settings.dart';

class SettingsStorageImpl implements SettingsStorage {
  final String filePath;

  static const int _version = 1;

  SettingsStorageImpl({required this.filePath});

  factory SettingsStorageImpl.defaultPath(String baseDir) {
    return SettingsStorageImpl(filePath: '$baseDir/transport_settings.json');
  }

  @override
  Future<TransportSettings?> load() async {
    final file = File(filePath);

    if (!await file.exists()) {
      return null;
    }

    try {
      final content = await file.readAsString();
      final json = jsonDecode(content) as Map<String, dynamic>;

      final version = json['version'] as int? ?? 0;
      if (version != _version) {
        return _migrate(json, version);
      }

      return TransportSettings.fromJson(
        json['settings'] as Map<String, dynamic>,
      );
    } catch (e) {
      return null;
    }
  }

  @override
  Future<void> save(TransportSettings settings) async {
    final file = File(filePath);
    final dir = file.parent;

    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    final json = {
      'version': _version,
      'savedAt': DateTime.now().toIso8601String(),
      'settings': settings.toJson(),
    };

    await file.writeAsString(const JsonEncoder.withIndent('  ').convert(json));
  }

  @override
  Future<void> clear() async {
    final file = File(filePath);
    if (await file.exists()) {
      await file.delete();
    }
  }

  @override
  Future<bool> hasSettings() async {
    final file = File(filePath);
    return file.exists();
  }

  @override
  Future<DateTime?> getLastModified() async {
    final file = File(filePath);
    if (!await file.exists()) {
      return null;
    }

    try {
      final content = await file.readAsString();
      final json = jsonDecode(content) as Map<String, dynamic>;
      final savedAt = json['savedAt'] as String?;
      return savedAt != null ? DateTime.parse(savedAt) : null;
    } catch (_) {
      return null;
    }
  }

  TransportSettings? _migrate(Map<String, dynamic> json, int fromVersion) {
    if (fromVersion == 0) {
      try {
        return TransportSettings.fromJson(
          json['settings'] as Map<String, dynamic>,
        );
      } catch (_) {
        return null;
      }
    }

    return null;
  }
}

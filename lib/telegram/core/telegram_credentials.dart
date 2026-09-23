import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:telepos/telegram/core/tdlib_logger.dart';
import 'package:telepos/telegram/models/telegram_config.dart';
import 'package:telepos/telegram/core/tdlib_config.dart';

/// Telegram application credentials.
///
/// TelePOS deliberately ships without a credential pair of its own. Every
/// deployment registers its own application at https://my.telegram.org and
/// supplies the pair either at build time
/// (`--dart-define=TELEGRAM_API_ID=... --dart-define=TELEGRAM_API_HASH=...`),
/// through the ambient environment, or by entering it in the Telegram setup
/// screen — see [TelegramCredentials.saveApiCredentials], which takes
/// precedence over both.
class TelegramAppCredentials {
  TelegramAppCredentials._();

  static const String _buildApiId = String.fromEnvironment('TELEGRAM_API_ID');

  static const String _buildApiHash = String.fromEnvironment(
    'TELEGRAM_API_HASH',
  );

  static int? get apiId {
    final raw = _buildApiId.isNotEmpty ? _buildApiId : _env('TELEGRAM_API_ID');
    final parsed = int.tryParse(raw?.trim() ?? '');
    return (parsed != null && parsed > 0) ? parsed : null;
  }

  static String? get apiHash {
    final raw = _buildApiHash.isNotEmpty
        ? _buildApiHash
        : _env('TELEGRAM_API_HASH');
    final trimmed = raw?.trim();
    return (trimmed != null && trimmed.isNotEmpty) ? trimmed : null;
  }

  static bool get isConfigured => apiId != null && apiHash != null;

  static String? _env(String key) {
    try {
      return Platform.environment[key];
    } catch (_) {
      // Platform.environment is unavailable on web.
      return null;
    }
  }

  static const String appTitle = 'TelePOS — Telegram Point of Sale';
  static const String shortName = 'TelePOS';
}

class TelegramCredentials {
  final TdLibLogger _logger;
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  static const String _posIdKey = 'telegram_pos_id';
  static const String _storeNameKey = 'telegram_store_name';
  static const String _isConfiguredKey = 'telegram_is_configured';
  static const String _apiIdKey = 'telegram_api_id';
  static const String _apiHashKey = 'telegram_api_hash';

  TelegramCredentials({required TdLibLogger logger}) : _logger = logger;

  Future<bool> hasCredentials() async {
    final pair = await _resolveApiCredentials();
    return pair != null;
  }

  /// Stores the API pair entered in the Telegram setup screen. These take
  /// precedence over anything supplied at build time.
  Future<void> saveApiCredentials({
    required int apiId,
    required String apiHash,
  }) async {
    await _secureStorage.write(key: _apiIdKey, value: apiId.toString());
    await _secureStorage.write(key: _apiHashKey, value: apiHash.trim());
    _logger.logConnection('Telegram API credentials saved');
  }

  Future<void> clearApiCredentials() async {
    await _secureStorage.delete(key: _apiIdKey);
    await _secureStorage.delete(key: _apiHashKey);
    _logger.logConnection('Telegram API credentials cleared');
  }

  /// Resolves the API pair: operator-entered values first, then the values
  /// baked in at build time or read from the environment. Null when TelePOS has
  /// not been given a Telegram application to talk to.
  Future<({int apiId, String apiHash})?> _resolveApiCredentials() async {
    try {
      final storedId = int.tryParse(
        (await _secureStorage.read(key: _apiIdKey))?.trim() ?? '',
      );
      final storedHash = (await _secureStorage.read(key: _apiHashKey))?.trim();
      if (storedId != null &&
          storedId > 0 &&
          storedHash != null &&
          storedHash.isNotEmpty) {
        return (apiId: storedId, apiHash: storedHash);
      }
    } catch (e) {
      _logger.logError('readApiCredentials', e);
    }

    final id = TelegramAppCredentials.apiId;
    final hash = TelegramAppCredentials.apiHash;
    if (id != null && hash != null) return (apiId: id, apiHash: hash);
    return null;
  }

  Future<CredentialsResult> loadCredentials() async {
    final pair = await _resolveApiCredentials();
    if (pair == null) {
      _logger.logConnection(
        'No Telegram API credentials configured — register an application at '
        'my.telegram.org and supply TELEGRAM_API_ID / TELEGRAM_API_HASH',
      );
      return const CredentialsResult.notFound();
    }

    String? posId;
    String? storeName;
    try {
      posId = await _secureStorage.read(key: _posIdKey);
      storeName = await _secureStorage.read(key: _storeNameKey);
    } catch (e) {
      _logger.logError('loadCredentials', e);
    }

    _logger.logConnection('Telegram credentials loaded');

    return CredentialsResult.found(
      apiId: pair.apiId,
      apiHash: pair.apiHash,
      posId: posId ?? _getEnvPosId(),
      storeName: storeName ?? _getEnvStoreName(),
    );
  }

  Future<void> saveAdditionalData({String? posId, String? storeName}) async {
    try {
      if (posId != null) {
        await _secureStorage.write(key: _posIdKey, value: posId);
      }
      if (storeName != null) {
        await _secureStorage.write(key: _storeNameKey, value: storeName);
      }
      await _secureStorage.write(key: _isConfiguredKey, value: 'true');
      _logger.logConnection('Additional data saved');
    } catch (e) {
      _logger.logError('saveAdditionalData', e);
    }
  }

  Future<void> clearAdditionalData() async {
    try {
      await _secureStorage.delete(key: _posIdKey);
      await _secureStorage.delete(key: _storeNameKey);
      await _secureStorage.delete(key: _isConfiguredKey);
      _logger.logConnection('Additional data cleared');
    } catch (e) {
      _logger.logError('clearAdditionalData', e);
    }
  }

  Future<TelegramConfig> createConfig({
    String? posId,
    String? storeName,
  }) async {
    final pair = await _resolveApiCredentials();
    if (pair == null) {
      throw StateError(
        'Telegram API credentials are not configured. Register an application '
        'at https://my.telegram.org and pass TELEGRAM_API_ID / '
        'TELEGRAM_API_HASH via --dart-define, or enter them in the Telegram '
        'settings screen.',
      );
    }
    return TdLibConfigProvider.createDefault(
      apiId: pair.apiId,
      apiHash: pair.apiHash,
      posId: posId,
      storeName: storeName,
    );
  }

  String? _getEnvPosId() {
    return Platform.environment['TELEGRAM_POS_ID'];
  }

  String? _getEnvStoreName() {
    return Platform.environment['TELEGRAM_STORE_NAME'];
  }
}

class CredentialsResult {
  final bool found;
  final int? apiId;
  final String? apiHash;
  final String? posId;
  final String? storeName;

  const CredentialsResult({
    required this.found,
    this.apiId,
    this.apiHash,
    this.posId,
    this.storeName,
  });

  const CredentialsResult.notFound()
    : found = false,
      apiId = null,
      apiHash = null,
      posId = null,
      storeName = null;

  factory CredentialsResult.found({
    required int apiId,
    required String apiHash,
    String? posId,
    String? storeName,
  }) {
    return CredentialsResult(
      found: true,
      apiId: apiId,
      apiHash: apiHash,
      posId: posId,
      storeName: storeName,
    );
  }

  bool get isValid =>
      found &&
      apiId != null &&
      apiId! > 0 &&
      apiHash != null &&
      apiHash!.isNotEmpty;
}

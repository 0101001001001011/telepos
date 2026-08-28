import 'package:telepos/domain/repositories/config_sync_repository.dart';
import 'package:telepos/telegram/core/tdlib_logger.dart';
import 'package:telepos/telegram/data_exchange/telegram_sync_engine.dart';
import 'package:telepos/domain/entities/telegram/sync_packet.dart';

class ConfigExchange {
  final TelegramSyncEngine _syncEngine;
  final TdLibLogger _logger;
  final ConfigSyncRepository? _repository;

  ConfigExchange({
    required TelegramSyncEngine syncEngine,
    required TdLibLogger logger,
    ConfigSyncRepository? repository,
  }) : _syncEngine = syncEngine,
       _logger = logger,
       _repository = repository;

  Future<void> downloadConfig({
    required String posId,
    required String serverId,
    required String sessionId,
    DateTime? lastSyncDate,
  }) async {
    _logger.logSync('Config download started');

    await _syncEngine.sendPacket(
      sourceId: posId,
      targetId: serverId,
      type: ExchangeType.config,
      sessionId: sessionId,
      data: {
        'action': 'download_config',
        'lastSyncDate': lastSyncDate?.toIso8601String(),
        'posId': posId,
      },
    );
  }

  Future<void> downloadPermissions({
    required String posId,
    required String serverId,
    required String sessionId,
  }) async {
    _logger.logSync('Permissions download started');

    await _syncEngine.sendPacket(
      sourceId: posId,
      targetId: serverId,
      type: ExchangeType.config,
      sessionId: sessionId,
      data: {'action': 'download_permissions', 'posId': posId},
    );
  }

  Future<void> downloadUsers({
    required String posId,
    required String serverId,
    required String sessionId,
  }) async {
    _logger.logSync('Users download started');

    await _syncEngine.sendPacket(
      sourceId: posId,
      targetId: serverId,
      type: ExchangeType.config,
      sessionId: sessionId,
      data: {'action': 'download_users', 'posId': posId},
    );
  }

  Future<void> processReceived(Map<String, dynamic> data) async {
    final action = data['action'] as String?;

    switch (action) {
      case 'config_response':
        final config = data['config'] as Map<String, dynamic>?;
        _logger.logSync('Received POS config from server');

        final repository = _repository;
        if (repository != null && config != null) {
          await repository.saveConfig(config);
        } else if (repository == null) {
          _logger.logWarning('ConfigSyncRepository not configured');
        }
        break;

      case 'permissions_response':
        final items = data['items'] as List? ?? [];
        _logger.logSync('Received ${items.length} permission sets from server');
        break;

      case 'users_response':
        final items = data['items'] as List? ?? [];
        _logger.logSync('Received ${items.length} users from server');
        break;

      case 'download_error':
        final error = data['error'] as String? ?? 'Unknown error';
        _logger.logError('processReceived', 'Config download error: $error');
        break;

      default:
        _logger.logError('processReceived', 'Unknown action: $action');
    }
  }
}

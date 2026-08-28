import 'package:telepos/domain/repositories/agent_sync_repository.dart';
import 'package:telepos/telegram/core/tdlib_logger.dart';
import 'package:telepos/telegram/data_exchange/telegram_sync_engine.dart';
import 'package:telepos/domain/entities/telegram/sync_packet.dart';

class AgentExchange {
  final TelegramSyncEngine _syncEngine;
  final TdLibLogger _logger;
  final AgentSyncRepository? _repository;

  AgentExchange({
    required TelegramSyncEngine syncEngine,
    required TdLibLogger logger,
    AgentSyncRepository? repository,
  }) : _syncEngine = syncEngine,
       _logger = logger,
       _repository = repository;

  Future<void> download({
    required String posId,
    required String serverId,
    required String sessionId,
    DateTime? lastSyncDate,
  }) async {
    _logger.logSync('Agent download started');

    await _syncEngine.sendPacket(
      sourceId: posId,
      targetId: serverId,
      type: ExchangeType.agent,
      sessionId: sessionId,
      data: {
        'action': 'download_request',
        'lastSyncDate': lastSyncDate?.toIso8601String(),
        'posId': posId,
      },
    );
  }

  Future<void> upload({
    required String posId,
    required String serverId,
    required String sessionId,
    required List<Map<String, dynamic>> agents,
  }) async {
    _logger.logSync('Agent upload: ${agents.length} agents');

    await _syncEngine.sendPacket(
      sourceId: posId,
      targetId: serverId,
      type: ExchangeType.agent,
      sessionId: sessionId,
      data: {
        'action': 'upload',
        'posId': posId,
        'items': agents,
        'count': agents.length,
      },
    );
  }

  Future<void> processReceived(Map<String, dynamic> data) async {
    final action = data['action'] as String?;

    switch (action) {
      case 'download_response':
        final items = data['items'] as List? ?? [];
        _logger.logSync('Received ${items.length} agents from server');

        final repository = _repository;
        if (repository != null) {
          await repository.saveAgents(items.cast<Map<String, dynamic>>());
        } else {
          _logger.logWarning('AgentSyncRepository not configured');
        }
        break;

      case 'balance_update':
        final items = data['items'] as List? ?? [];
        _logger.logSync('Received ${items.length} balance updates');

        final repository = _repository;
        if (repository != null) {
          for (final item in items) {
            final agentId = item['agentId'] as int?;
            final balance = item['balance'] as num?;
            if (agentId != null && balance != null) {
              await repository.updateAgentBalance(agentId, balance);
            }
          }
        } else {
          _logger.logWarning('AgentSyncRepository not configured');
        }
        break;

      case 'upload_ack':
        final count = data['count'] as int? ?? 0;
        _logger.logSync('Agent upload acknowledged: $count agents');
        break;

      case 'upload_error':
        final error = data['error'] as String? ?? 'Unknown error';
        _logger.logError('processReceived', 'Agent upload error: $error');
        break;

      default:
        _logger.logError('processReceived', 'Unknown action: $action');
    }
  }
}

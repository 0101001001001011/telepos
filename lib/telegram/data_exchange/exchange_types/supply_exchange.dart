import 'package:telepos/domain/repositories/supply_sync_repository.dart';
import 'package:telepos/telegram/core/tdlib_logger.dart';
import 'package:telepos/telegram/data_exchange/telegram_sync_engine.dart';
import 'package:telepos/domain/entities/telegram/sync_packet.dart';

class SupplyExchange {
  final TelegramSyncEngine _syncEngine;
  final TdLibLogger _logger;
  final SupplySyncRepository? _repository;

  SupplyExchange({
    required TelegramSyncEngine syncEngine,
    required TdLibLogger logger,
    SupplySyncRepository? repository,
  }) : _syncEngine = syncEngine,
       _logger = logger,
       _repository = repository;

  Future<void> upload({
    required String posId,
    required String serverId,
    required String sessionId,
    required List<Map<String, dynamic>> supplies,
  }) async {
    _logger.logSync('Supply upload: ${supplies.length} supplies');

    await _syncEngine.sendPacket(
      sourceId: posId,
      targetId: serverId,
      type: ExchangeType.supply,
      sessionId: sessionId,
      data: {
        'action': 'upload',
        'posId': posId,
        'items': supplies,
        'count': supplies.length,
      },
    );
  }

  Future<void> downloadExpected({
    required String posId,
    required String serverId,
    required String sessionId,
    DateTime? lastSyncDate,
  }) async {
    _logger.logSync('Expected supplies download started');

    await _syncEngine.sendPacket(
      sourceId: posId,
      targetId: serverId,
      type: ExchangeType.supply,
      sessionId: sessionId,
      data: {
        'action': 'download_expected',
        'lastSyncDate': lastSyncDate?.toIso8601String(),
        'posId': posId,
      },
    );
  }

  Future<void> processReceived(Map<String, dynamic> data) async {
    final action = data['action'] as String?;

    switch (action) {
      case 'upload_ack':
        final count = data['count'] as int? ?? 0;
        final supplyIds = data['supplyIds'] as List? ?? [];
        _logger.logSync('Supply upload acknowledged: $count supplies');

        final repository = _repository;
        if (repository != null) {
          await repository.markSuppliesSynced(supplyIds.cast<int>());
        } else {
          _logger.logWarning('SupplySyncRepository not configured');
        }
        break;

      case 'expected_response':
        final items = data['items'] as List? ?? [];
        _logger.logSync(
          'Received ${items.length} expected supplies from server',
        );
        break;

      case 'upload_error':
        final error = data['error'] as String? ?? 'Unknown error';
        _logger.logError('processReceived', 'Supply upload error: $error');
        break;

      default:
        _logger.logError('processReceived', 'Unknown action: $action');
    }
  }
}

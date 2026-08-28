import 'package:telepos/domain/repositories/price_sync_repository.dart';
import 'package:telepos/telegram/core/tdlib_logger.dart';
import 'package:telepos/telegram/data_exchange/telegram_sync_engine.dart';
import 'package:telepos/domain/entities/telegram/sync_packet.dart';

class PriceExchange {
  final TelegramSyncEngine _syncEngine;
  final TdLibLogger _logger;
  final PriceSyncRepository? _repository;

  PriceExchange({
    required TelegramSyncEngine syncEngine,
    required TdLibLogger logger,
    PriceSyncRepository? repository,
  }) : _syncEngine = syncEngine,
       _logger = logger,
       _repository = repository;

  Future<void> download({
    required String posId,
    required String serverId,
    required String sessionId,
    DateTime? lastSyncDate,
  }) async {
    _logger.logSync('Price download started');

    await _syncEngine.sendPacket(
      sourceId: posId,
      targetId: serverId,
      type: ExchangeType.price,
      sessionId: sessionId,
      data: {
        'action': 'download_request',
        'lastSyncDate': lastSyncDate?.toIso8601String(),
        'posId': posId,
      },
    );
  }

  Future<void> downloadMarkups({
    required String posId,
    required String serverId,
    required String sessionId,
  }) async {
    _logger.logSync('Markup download started');

    await _syncEngine.sendPacket(
      sourceId: posId,
      targetId: serverId,
      type: ExchangeType.price,
      sessionId: sessionId,
      data: {'action': 'download_markups', 'posId': posId},
    );
  }

  Future<void> processReceived(Map<String, dynamic> data) async {
    final action = data['action'] as String?;

    switch (action) {
      case 'download_response':
        final items = data['items'] as List? ?? [];
        _logger.logSync('Received ${items.length} price updates from server');

        final repository = _repository;
        if (repository != null) {
          await repository.savePrices(items.cast<Map<String, dynamic>>());
        } else {
          _logger.logWarning('PriceSyncRepository not configured');
        }
        break;

      case 'markup_response':
        final items = data['items'] as List? ?? [];
        _logger.logSync('Received ${items.length} markup rules from server');
        break;

      case 'download_error':
        final error = data['error'] as String? ?? 'Unknown error';
        _logger.logError('processReceived', 'Price download error: $error');
        break;

      default:
        _logger.logError('processReceived', 'Unknown action: $action');
    }
  }
}

import 'package:telepos/domain/repositories/product_sync_repository.dart';
import 'package:telepos/telegram/core/tdlib_logger.dart';
import 'package:telepos/telegram/data_exchange/telegram_sync_engine.dart';
import 'package:telepos/domain/entities/telegram/sync_packet.dart';

class ProductExchange {
  final TelegramSyncEngine _syncEngine;
  final TdLibLogger _logger;
  final ProductSyncRepository? _repository;

  ProductExchange({
    required TelegramSyncEngine syncEngine,
    required TdLibLogger logger,
    ProductSyncRepository? repository,
  }) : _syncEngine = syncEngine,
       _logger = logger,
       _repository = repository;

  Future<void> download({
    required String posId,
    required String serverId,
    required String sessionId,
    DateTime? lastSyncDate,
  }) async {
    _logger.logSync('Product download started');

    await _syncEngine.sendPacket(
      sourceId: posId,
      targetId: serverId,
      type: ExchangeType.product,
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
    required List<Map<String, dynamic>> products,
  }) async {
    _logger.logSync('Product upload: ${products.length} items');

    await _syncEngine.sendPacket(
      sourceId: posId,
      targetId: serverId,
      type: ExchangeType.product,
      sessionId: sessionId,
      data: {
        'action': 'upload',
        'posId': posId,
        'items': products,
        'count': products.length,
      },
    );
  }

  Future<void> processReceived(Map<String, dynamic> data) async {
    final action = data['action'] as String?;

    switch (action) {
      case 'download_response':
        final items = data['items'] as List? ?? [];
        _logger.logSync('Received ${items.length} products from server');

        final repository = _repository;
        if (repository != null) {
          await repository.saveProducts(items.cast<Map<String, dynamic>>());
        } else {
          _logger.logWarning('ProductSyncRepository not configured');
        }
        break;

      case 'upload_ack':
        _logger.logSync('Product upload acknowledged');
        break;

      default:
        _logger.logError('processReceived', 'Unknown action: $action');
    }
  }
}

import 'package:telepos/domain/repositories/sale_sync_repository.dart';
import 'package:telepos/telegram/core/tdlib_logger.dart';
import 'package:telepos/telegram/data_exchange/telegram_sync_engine.dart';
import 'package:telepos/domain/entities/telegram/sync_packet.dart';

class SaleExchange {
  final TelegramSyncEngine _syncEngine;
  final TdLibLogger _logger;
  final SaleSyncRepository? _repository;

  SaleExchange({
    required TelegramSyncEngine syncEngine,
    required TdLibLogger logger,
    SaleSyncRepository? repository,
  }) : _syncEngine = syncEngine,
       _logger = logger,
       _repository = repository;

  Future<void> uploadSales({
    required String posId,
    required String serverId,
    required String sessionId,
    required List<Map<String, dynamic>> sales,
  }) async {
    _logger.logSync('Sale upload: ${sales.length} sales');

    await _syncEngine.sendPacket(
      sourceId: posId,
      targetId: serverId,
      type: ExchangeType.sale,
      sessionId: sessionId,
      data: {
        'action': 'upload_sales',
        'posId': posId,
        'items': sales,
        'count': sales.length,
      },
    );
  }

  Future<void> downloadFiscalResults({
    required String posId,
    required String serverId,
    required String sessionId,
    DateTime? lastSyncDate,
  }) async {
    _logger.logSync('Sale fiscal results download started');

    await _syncEngine.sendPacket(
      sourceId: posId,
      targetId: serverId,
      type: ExchangeType.sale,
      sessionId: sessionId,
      data: {
        'action': 'download_fiscal_results',
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
        final saleIds = data['saleIds'] as List? ?? [];
        _logger.logSync('Sale upload acknowledged: $count sales');

        final repository = _repository;
        if (repository != null) {
          await repository.markSalesSynced(saleIds.cast<int>());
        } else {
          _logger.logWarning('SaleSyncRepository not configured');
        }
        break;

      case 'fiscal_results':
        final items = data['items'] as List? ?? [];
        _logger.logSync('Received ${items.length} fiscal results from server');

        final repository = _repository;
        if (repository != null) {
          await repository.updateFiscalData(items.cast<Map<String, dynamic>>());
        } else {
          _logger.logWarning('SaleSyncRepository not configured');
        }
        break;

      case 'upload_error':
        final error = data['error'] as String? ?? 'Unknown error';
        _logger.logError('processReceived', 'Sale upload error: $error');
        break;

      default:
        _logger.logError('processReceived', 'Unknown action: $action');
    }
  }
}

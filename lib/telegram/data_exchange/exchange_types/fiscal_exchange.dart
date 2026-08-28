import 'package:telepos/domain/repositories/fiscal_sync_repository.dart';
import 'package:telepos/telegram/core/tdlib_logger.dart';
import 'package:telepos/telegram/data_exchange/telegram_sync_engine.dart';
import 'package:telepos/domain/entities/telegram/sync_packet.dart';

class FiscalExchange {
  final TelegramSyncEngine _syncEngine;
  final TdLibLogger _logger;
  final FiscalSyncRepository? _repository;

  FiscalExchange({
    required TelegramSyncEngine syncEngine,
    required TdLibLogger logger,
    FiscalSyncRepository? repository,
  }) : _syncEngine = syncEngine,
       _logger = logger,
       _repository = repository;

  Future<void> uploadReceipts({
    required String posId,
    required String serverId,
    required String sessionId,
    required List<Map<String, dynamic>> receipts,
  }) async {
    _logger.logSync('Fiscal upload: ${receipts.length} receipts');

    await _syncEngine.sendPacket(
      sourceId: posId,
      targetId: serverId,
      type: ExchangeType.fiscal,
      sessionId: sessionId,
      data: {
        'action': 'upload_receipts',
        'posId': posId,
        'items': receipts,
        'count': receipts.length,
      },
    );
  }

  Future<void> downloadStatuses({
    required String posId,
    required String serverId,
    required String sessionId,
    DateTime? lastSyncDate,
  }) async {
    _logger.logSync('Fiscal statuses download started');

    await _syncEngine.sendPacket(
      sourceId: posId,
      targetId: serverId,
      type: ExchangeType.fiscal,
      sessionId: sessionId,
      data: {
        'action': 'download_statuses',
        'lastSyncDate': lastSyncDate?.toIso8601String(),
        'posId': posId,
      },
    );
  }

  Future<void> downloadErrors({
    required String posId,
    required String serverId,
    required String sessionId,
  }) async {
    _logger.logSync('Fiscal errors download started');

    await _syncEngine.sendPacket(
      sourceId: posId,
      targetId: serverId,
      type: ExchangeType.fiscal,
      sessionId: sessionId,
      data: {'action': 'download_errors', 'posId': posId},
    );
  }

  Future<void> processReceived(Map<String, dynamic> data) async {
    final action = data['action'] as String?;

    switch (action) {
      case 'upload_ack':
        final count = data['count'] as int? ?? 0;
        final receiptIds = data['receiptIds'] as List? ?? [];
        _logger.logSync('Fiscal upload acknowledged: $count receipts');

        final repository = _repository;
        if (repository != null) {
          await repository.markFiscalDocsSynced(receiptIds.cast<int>());
        } else {
          _logger.logWarning('FiscalSyncRepository not configured');
        }
        break;

      case 'fiscal_statuses':
        final items = data['items'] as List? ?? [];
        _logger.logSync('Received ${items.length} fiscal statuses from OFD');

        final repository = _repository;
        if (repository != null) {
          for (final item in items) {
            await repository.saveFiscalStatus(item as Map<String, dynamic>);
          }
        } else {
          _logger.logWarning('FiscalSyncRepository not configured');
        }
        break;

      case 'fiscal_errors':
        final items = data['items'] as List? ?? [];
        _logger.logSync('Received ${items.length} fiscal errors from OFD');
        break;

      case 'upload_error':
        final error = data['error'] as String? ?? 'Unknown error';
        _logger.logError('processReceived', 'Fiscal upload error: $error');
        break;

      default:
        _logger.logError('processReceived', 'Unknown action: $action');
    }
  }
}

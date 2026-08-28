import 'package:telepos/domain/repositories/refund_sync_repository.dart';
import 'package:telepos/telegram/core/tdlib_logger.dart';
import 'package:telepos/telegram/data_exchange/telegram_sync_engine.dart';
import 'package:telepos/domain/entities/telegram/sync_packet.dart';

class RefundExchange {
  final TelegramSyncEngine _syncEngine;
  final TdLibLogger _logger;
  final RefundSyncRepository? _repository;

  RefundExchange({
    required TelegramSyncEngine syncEngine,
    required TdLibLogger logger,
    RefundSyncRepository? repository,
  }) : _syncEngine = syncEngine,
       _logger = logger,
       _repository = repository;

  Future<void> upload({
    required String posId,
    required String serverId,
    required String sessionId,
    required List<Map<String, dynamic>> refunds,
  }) async {
    _logger.logSync('Refund upload: ${refunds.length} refunds');

    await _syncEngine.sendPacket(
      sourceId: posId,
      targetId: serverId,
      type: ExchangeType.refund,
      sessionId: sessionId,
      data: {
        'action': 'upload',
        'posId': posId,
        'items': refunds,
        'count': refunds.length,
      },
    );
  }

  Future<void> downloadFiscalResults({
    required String posId,
    required String serverId,
    required String sessionId,
    DateTime? lastSyncDate,
  }) async {
    _logger.logSync('Refund fiscal results download started');

    await _syncEngine.sendPacket(
      sourceId: posId,
      targetId: serverId,
      type: ExchangeType.refund,
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
        final refundIds = data['refundIds'] as List? ?? [];
        _logger.logSync('Refund upload acknowledged: $count refunds');

        final repository = _repository;
        if (repository != null) {
          await repository.markRefundsSynced(refundIds.cast<int>());
        } else {
          _logger.logWarning('RefundSyncRepository not configured');
        }
        break;

      case 'fiscal_results':
        final items = data['items'] as List? ?? [];
        _logger.logSync(
          'Received ${items.length} refund fiscal results from server',
        );
        break;

      case 'upload_error':
        final error = data['error'] as String? ?? 'Unknown error';
        _logger.logError('processReceived', 'Refund upload error: $error');
        break;

      default:
        _logger.logError('processReceived', 'Unknown action: $action');
    }
  }
}

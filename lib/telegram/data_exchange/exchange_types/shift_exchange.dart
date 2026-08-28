import 'package:telepos/domain/repositories/shift_sync_repository.dart';
import 'package:telepos/telegram/core/tdlib_logger.dart';
import 'package:telepos/telegram/data_exchange/telegram_sync_engine.dart';
import 'package:telepos/domain/entities/telegram/sync_packet.dart';

class ShiftExchange {
  final TelegramSyncEngine _syncEngine;
  final TdLibLogger _logger;
  final ShiftSyncRepository? _repository;

  ShiftExchange({
    required TelegramSyncEngine syncEngine,
    required TdLibLogger logger,
    ShiftSyncRepository? repository,
  }) : _syncEngine = syncEngine,
       _logger = logger,
       _repository = repository;

  Future<void> uploadShiftOpen({
    required String posId,
    required String serverId,
    required String sessionId,
    required Map<String, dynamic> shiftData,
  }) async {
    _logger.logSync('Shift open upload');

    await _syncEngine.sendPacket(
      sourceId: posId,
      targetId: serverId,
      type: ExchangeType.shift,
      sessionId: sessionId,
      data: {'action': 'upload_shift_open', 'posId': posId, 'shift': shiftData},
    );
  }

  Future<void> uploadShiftClose({
    required String posId,
    required String serverId,
    required String sessionId,
    required Map<String, dynamic> shiftData,
    required Map<String, dynamic> zReport,
  }) async {
    _logger.logSync('Shift close upload with Z-report');

    await _syncEngine.sendPacket(
      sourceId: posId,
      targetId: serverId,
      type: ExchangeType.shift,
      sessionId: sessionId,
      data: {
        'action': 'upload_shift_close',
        'posId': posId,
        'shift': shiftData,
        'zReport': zReport,
      },
    );
  }

  Future<void> uploadZReport({
    required String posId,
    required String serverId,
    required String sessionId,
    required Map<String, dynamic> zReport,
  }) async {
    _logger.logSync('Z-report upload');

    await _syncEngine.sendPacket(
      sourceId: posId,
      targetId: serverId,
      type: ExchangeType.shift,
      sessionId: sessionId,
      data: {'action': 'upload_z_report', 'posId': posId, 'zReport': zReport},
    );
  }

  Future<void> processReceived(Map<String, dynamic> data) async {
    final action = data['action'] as String?;
    final shiftId = data['shiftId'] as int?;

    switch (action) {
      case 'shift_open_ack':
        _logger.logSync('Shift open acknowledged by server');

        final repository = _repository;
        if (repository != null && shiftId != null) {
          final shifts = await repository.getUnsyncedShifts();
          final matchingShifts = shifts.where((s) => s['id'] == shiftId);
          if (matchingShifts.isNotEmpty) {
            await repository.markShiftsSynced([shiftId]);
          }
        } else if (repository == null) {
          _logger.logWarning('ShiftSyncRepository not configured');
        }
        break;

      case 'shift_close_ack':
        _logger.logSync('Shift close acknowledged by server');

        final repository = _repository;
        if (repository != null && shiftId != null) {
          await repository.markShiftsSynced([shiftId]);
        } else if (repository == null) {
          _logger.logWarning('ShiftSyncRepository not configured');
        }
        break;

      case 'z_report_ack':
        _logger.logSync('Z-report acknowledged by server');
        break;

      case 'upload_error':
        final error = data['error'] as String? ?? 'Unknown error';
        _logger.logError('processReceived', 'Shift upload error: $error');
        break;

      default:
        _logger.logError('processReceived', 'Unknown action: $action');
    }
  }
}

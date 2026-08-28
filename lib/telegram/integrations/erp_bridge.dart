import 'dart:async';

import 'package:telepos/telegram/core/tdlib_logger.dart';
import 'package:telepos/telegram/data_exchange/telegram_sync_engine.dart';
import 'package:telepos/telegram/integrations/integration_protocol.dart';
import 'package:telepos/domain/entities/telegram/sync_packet.dart';

class ErpBridge implements IntegrationBridge {
  final TelegramSyncEngine _syncEngine;
  final TdLibLogger _logger;

  final String _posId;
  final String _erpId;
  final String _erpName;
  final String _sessionId;

  bool _connected = false;
  final _incomingController = StreamController<BridgeMessage>.broadcast();

  ErpBridge({
    required TelegramSyncEngine syncEngine,
    required TdLibLogger logger,
    required String posId,
    required String erpId,
    required String erpName,
    required String sessionId,
  }) : _syncEngine = syncEngine,
       _logger = logger,
       _posId = posId,
       _erpId = erpId,
       _erpName = erpName,
       _sessionId = sessionId;

  @override
  String get bridgeId => 'erp_${_posId}_$_erpId';

  @override
  BridgeType get bridgeType => BridgeType.erp;

  @override
  bool get isConnected => _connected;

  @override
  Stream<BridgeMessage> get incomingData => _incomingController.stream;

  String get erpName => _erpName;

  @override
  Future<void> connect() async {
    _logger.logConnection('ERP bridge ($_erpName) connecting...');
    _connected = true;
    _logger.logConnection('ERP bridge ($_erpName) connected');
  }

  @override
  Future<void> disconnect() async {
    _connected = false;
    await _incomingController.close();
    _logger.logConnection('ERP bridge ($_erpName) disconnected');
  }

  @override
  Future<void> sendData(ExchangeType type, Map<String, dynamic> data) async {
    if (!_connected) throw StateError('ERP bridge not connected');

    await _syncEngine.sendPacket(
      sourceId: _posId,
      targetId: _erpId,
      type: type,
      data: {'target': 'ERP', 'erpName': _erpName, ...data},
      sessionId: _sessionId,
    );
  }

  @override
  Future<Map<String, dynamic>> requestData(
    ExchangeType type, {
    Map<String, dynamic>? params,
  }) async {
    if (!_connected) throw StateError('ERP bridge not connected');

    await sendData(type, {'action': 'request', 'params': params});

    final response = await incomingData
        .where((msg) => msg.type == type)
        .first
        .timeout(const Duration(seconds: 60));

    return response.data;
  }

  @override
  Future<bool> ping() async {
    try {
      await sendData(ExchangeType.heartbeat, {
        'ping': true,
        'timestamp': DateTime.now().toIso8601String(),
      });
      return true;
    } catch (_) {
      return false;
    }
  }
}

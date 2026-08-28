import 'dart:async';

import 'package:telepos/telegram/core/tdlib_logger.dart';
import 'package:telepos/telegram/data_exchange/telegram_sync_engine.dart';
import 'package:telepos/telegram/integrations/integration_protocol.dart';
import 'package:telepos/telegram/messaging/realtime_updates.dart';
import 'package:telepos/domain/entities/telegram/sync_packet.dart';

class ServerBridge implements IntegrationBridge {
  final TelegramSyncEngine _syncEngine;
  final RealtimeUpdates _realtimeUpdates; // ignore: unused_field
  final TdLibLogger _logger;

  final String _posId;
  final String _serverId;
  final String _sessionId;

  bool _connected = false;

  final _incomingController = StreamController<BridgeMessage>.broadcast();

  ServerBridge({
    required TelegramSyncEngine syncEngine,
    required RealtimeUpdates realtimeUpdates,
    required TdLibLogger logger,
    required String posId,
    required String serverId,
    required String sessionId,
  }) : _syncEngine = syncEngine,
       _realtimeUpdates = realtimeUpdates,
       _logger = logger,
       _posId = posId,
       _serverId = serverId,
       _sessionId = sessionId;

  @override
  String get bridgeId => 'server_${_posId}_$_serverId';

  @override
  BridgeType get bridgeType => BridgeType.server;

  @override
  bool get isConnected => _connected;

  @override
  Stream<BridgeMessage> get incomingData => _incomingController.stream;

  @override
  Future<void> connect() async {
    _logger.logConnection('Server bridge connecting...');
    _connected = true;
    _logger.logConnection('Server bridge connected');
  }

  @override
  Future<void> disconnect() async {
    _connected = false;
    await _incomingController.close();
    _logger.logConnection('Server bridge disconnected');
  }

  @override
  Future<void> sendData(ExchangeType type, Map<String, dynamic> data) async {
    if (!_connected) throw StateError('Bridge not connected');

    await _syncEngine.sendPacket(
      sourceId: _posId,
      targetId: _serverId,
      type: type,
      data: data,
      sessionId: _sessionId,
    );
  }

  @override
  Future<Map<String, dynamic>> requestData(
    ExchangeType type, {
    Map<String, dynamic>? params,
  }) async {
    if (!_connected) throw StateError('Bridge not connected');

    await sendData(type, {'action': 'request', 'params': params});

    final response = await incomingData
        .where((msg) => msg.type == type)
        .first
        .timeout(const Duration(seconds: 30));

    return response.data;
  }

  @override
  Future<bool> ping() async {
    try {
      await _syncEngine.sendPacket(
        sourceId: _posId,
        targetId: _serverId,
        type: ExchangeType.heartbeat,
        data: {'ping': true, 'timestamp': DateTime.now().toIso8601String()},
        sessionId: _sessionId,
      );
      return true;
    } catch (_) {
      return false;
    }
  }
}

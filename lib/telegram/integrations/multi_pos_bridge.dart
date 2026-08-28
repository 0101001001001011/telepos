import 'dart:async';

import 'package:telepos/telegram/core/tdlib_logger.dart';
import 'package:telepos/telegram/data_exchange/telegram_sync_engine.dart';
import 'package:telepos/telegram/integrations/integration_protocol.dart';
import 'package:telepos/domain/entities/telegram/sync_packet.dart';

class MultiPosBridge implements IntegrationBridge {
  final TelegramSyncEngine _syncEngine;
  final TdLibLogger _logger;

  final String _posId;
  final String _sessionId;

  bool _connected = false;
  final _incomingController = StreamController<BridgeMessage>.broadcast();

  final Map<String, DateTime> _knownPeers = {};

  MultiPosBridge({
    required TelegramSyncEngine syncEngine,
    required TdLibLogger logger,
    required String posId,
    required String sessionId,
  }) : _syncEngine = syncEngine,
       _logger = logger,
       _posId = posId,
       _sessionId = sessionId;

  @override
  String get bridgeId => 'multi_pos_$_posId';

  @override
  BridgeType get bridgeType => BridgeType.multiPos;

  @override
  bool get isConnected => _connected;

  @override
  Stream<BridgeMessage> get incomingData => _incomingController.stream;

  Map<String, DateTime> get knownPeers => Map.unmodifiable(_knownPeers);

  @override
  Future<void> connect() async {
    _logger.logConnection('Multi-POS bridge connecting...');
    _connected = true;

    await _announcePresence();
    _logger.logConnection('Multi-POS bridge connected');
  }

  @override
  Future<void> disconnect() async {
    _connected = false;
    await _incomingController.close();
    _logger.logConnection('Multi-POS bridge disconnected');
  }

  @override
  Future<void> sendData(ExchangeType type, Map<String, dynamic> data) async {
    if (!_connected) throw StateError('Multi-POS bridge not connected');

    await _syncEngine.sendPacket(
      sourceId: _posId,
      targetId: '*',
      type: type,
      data: {'source_pos': _posId, ...data},
      sessionId: _sessionId,
    );
  }

  Future<void> sendToPeer(
    String targetPosId,
    ExchangeType type,
    Map<String, dynamic> data,
  ) async {
    if (!_connected) throw StateError('Multi-POS bridge not connected');

    await _syncEngine.sendPacket(
      sourceId: _posId,
      targetId: targetPosId,
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
    await sendData(type, {'action': 'request', 'params': params});

    final response = await incomingData
        .where((msg) => msg.type == type)
        .first
        .timeout(const Duration(seconds: 15));

    return response.data;
  }

  @override
  Future<bool> ping() async {
    try {
      await _announcePresence();
      return true;
    } catch (_) {
      return false;
    }
  }

  void registerPeer(String peerId) {
    _knownPeers[peerId] = DateTime.now();
    _logger.logConnection('Peer registered: $peerId');
  }

  bool isPeerOnline(
    String peerId, {
    Duration timeout = const Duration(minutes: 5),
  }) {
    final lastSeen = _knownPeers[peerId];
    if (lastSeen == null) return false;
    return DateTime.now().difference(lastSeen) < timeout;
  }

  int get onlinePeerCount {
    final timeout = const Duration(minutes: 5);
    return _knownPeers.values
        .where((dt) => DateTime.now().difference(dt) < timeout)
        .length;
  }

  Future<void> _announcePresence() async {
    await _syncEngine.sendPacket(
      sourceId: _posId,
      targetId: '*',
      type: ExchangeType.heartbeat,
      data: {
        'action': 'pos_announce',
        'posId': _posId,
        'timestamp': DateTime.now().toIso8601String(),
      },
      sessionId: _sessionId,
    );
  }
}

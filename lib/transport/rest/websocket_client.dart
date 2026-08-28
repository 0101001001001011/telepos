import 'dart:async';
import 'dart:convert';

import '../interface/transport_interface_exports.dart';
import 'websocket_message.dart';

enum WebSocketState { disconnected, connecting, connected, reconnecting, error }

class WebSocketClient {
  final String url;

  final String? authToken;

  final Duration heartbeatInterval;

  final Duration reconnectInterval;

  final int maxReconnectAttempts;

  WebSocketState _state = WebSocketState.disconnected;
  int _reconnectAttempts = 0;
  Timer? _heartbeatTimer;
  Timer? _reconnectTimer;
  DateTime? _lastPongReceived;
  final Set<String> _subscribedChannels = {};

  final _stateController = StreamController<WebSocketState>.broadcast();
  final _messageController = StreamController<WebSocketMessage>.broadcast();
  final _updatesController = StreamController<TransportUpdate>.broadcast();
  final _commandsController = StreamController<RemoteCommand>.broadcast();

  WebSocketClient({
    required this.url,
    this.authToken,
    this.heartbeatInterval = const Duration(seconds: 30),
    this.reconnectInterval = const Duration(seconds: 5),
    this.maxReconnectAttempts = 10,
  });

  WebSocketState get state => _state;

  bool get isConnected => _state == WebSocketState.connected;

  Stream<WebSocketState> get stateStream => _stateController.stream;

  Stream<WebSocketMessage> get messageStream => _messageController.stream;

  Stream<TransportUpdate> get updatesStream => _updatesController.stream;

  Stream<RemoteCommand> get commandsStream => _commandsController.stream;

  Future<void> connect() async {
    if (_state == WebSocketState.connected ||
        _state == WebSocketState.connecting) {
      return;
    }

    _updateState(WebSocketState.error);
  }

  Future<void> disconnect() async {
    _stopHeartbeat();
    _cancelReconnect();

    _updateState(WebSocketState.disconnected);
  }

  Future<void> subscribe(List<String> channels) async {
    _subscribedChannels.addAll(channels);

    if (!isConnected) return;

    final message = WebSocketMessage.subscribe(channels);
    await _send(message);
  }

  Future<void> unsubscribe(List<String> channels) async {
    _subscribedChannels.removeAll(channels);

    if (!isConnected) return;

    final message = WebSocketMessage.unsubscribe(channels);
    await _send(message);
  }

  Future<void> unsubscribeAll() async {
    final channels = _subscribedChannels.toList();
    _subscribedChannels.clear();

    if (!isConnected || channels.isEmpty) return;

    final message = WebSocketMessage.unsubscribe(channels);
    await _send(message);
  }

  Future<void> acknowledgeCommand(
    String commandId, {
    bool success = true,
  }) async {
    if (!isConnected) return;

    final message = WebSocketMessage(
      type: WebSocketMessageType.ack,
      messageId: commandId,
      data: {'success': success},
      timestamp: DateTime.now(),
    );
    await _send(message);
  }

  Future<void> _send(WebSocketMessage message) async {
    if (!isConnected) return;
  }

  void handleMessage(dynamic rawMessage) {
    try {
      final json = jsonDecode(rawMessage as String) as Map<String, dynamic>;
      final message = WebSocketMessage.fromJson(json);

      _messageController.add(message);

      switch (message.type) {
        case WebSocketMessageType.ping:
          _sendPong();
          break;

        case WebSocketMessageType.pong:
          _lastPongReceived = DateTime.now();
          break;

        case WebSocketMessageType.priceUpdate:
        case WebSocketMessageType.stockUpdate:
        case WebSocketMessageType.configUpdate:
          _handleDataUpdate(message);
          break;

        case WebSocketMessageType.remoteCommand:
          _handleRemoteCommand(message);
          break;

        case WebSocketMessageType.syncRequest:
          _handleSyncRequest(message);
          break;

        case WebSocketMessageType.notification:
          _handleNotification(message);
          break;

        case WebSocketMessageType.error:
          _handleServerError(message);
          break;

        default:
          break;
      }
    } catch (e) {}
  }

  void _handleDataUpdate(WebSocketMessage message) {
    final update = TransportUpdate(
      type: _mapUpdateType(message.type),
      data: message.data ?? {},
      timestamp: message.timestamp,
    );
    _updatesController.add(update);
  }

  String _mapUpdateType(WebSocketMessageType type) {
    switch (type) {
      case WebSocketMessageType.priceUpdate:
        return 'price';
      case WebSocketMessageType.stockUpdate:
        return 'stock';
      case WebSocketMessageType.configUpdate:
        return 'config';
      default:
        return 'unknown';
    }
  }

  void _handleRemoteCommand(WebSocketMessage message) {
    if (message.data == null) return;

    final command = RemoteCommand.fromJson(message.data!);
    _commandsController.add(command);
  }

  void _handleSyncRequest(WebSocketMessage message) {
    final command = RemoteCommand(
      type: RemoteCommandType.forceSync,
      params: message.data ?? {},
      commandId: message.messageId ?? '',
    );
    _commandsController.add(command);
  }

  void _handleNotification(WebSocketMessage message) {
    final update = TransportUpdate(
      type: 'notification',
      data: message.data ?? {},
      timestamp: message.timestamp,
    );
    _updatesController.add(update);
  }

  void _handleServerError(WebSocketMessage message) {}

  void _handleError(Object error) {
    _updateState(WebSocketState.error);
    _scheduleReconnect();
  }

  void handleDone() {
    if (_state != WebSocketState.disconnected) {
      _updateState(WebSocketState.disconnected);
      _scheduleReconnect();
    }
  }

  void _sendPong() {
    final message = WebSocketMessage.pong();
    _send(message);
  }

  void _sendPing() {
    final message = WebSocketMessage.ping();
    _send(message);
  }

  void _startHeartbeat() {
    _stopHeartbeat();

    _heartbeatTimer = Timer.periodic(heartbeatInterval, (_) {
      if (isConnected) {
        _sendPing();

        if (_lastPongReceived != null) {
          final silenceTime = DateTime.now().difference(_lastPongReceived!);
          if (silenceTime > heartbeatInterval * 2) {
            _handleError(Exception('Heartbeat timeout'));
          }
        }
      }
    });
  }

  void _stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  void _scheduleReconnect() {
    if (_reconnectAttempts >= maxReconnectAttempts) {
      _updateState(WebSocketState.error);
      return;
    }

    _cancelReconnect();
    _updateState(WebSocketState.reconnecting);

    final delay = reconnectInterval * (1 << _reconnectAttempts);
    _reconnectAttempts++;

    _reconnectTimer = Timer(delay, () {
      connect();
    });
  }

  void _cancelReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
  }

  void _updateState(WebSocketState newState) {
    if (_state != newState) {
      _state = newState;
      _stateController.add(newState);
    }
  }

  Future<void> dispose() async {
    await disconnect();
    await _stateController.close();
    await _messageController.close();
    await _updatesController.close();
    await _commandsController.close();
  }
}

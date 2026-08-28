import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'payment_connector.dart';

class TcpPaymentConnector implements PaymentConnector {
  TcpPaymentConnector({PaymentConnectorConfig? config})
    : _config =
          config ??
          const PaymentConnectorConfig(
            connectionType: PaymentConnectionType.tcp,
          );

  PaymentConnectorConfig _config;
  Socket? _socket;
  final _statusController =
      StreamController<PaymentConnectionStatus>.broadcast();
  PaymentConnectionStatus _status = PaymentConnectionStatus.disconnected;
  int _reconnectAttempts = 0;
  Timer? _reconnectTimer;

  void updateConfig(PaymentConnectorConfig config) {
    _config = config;
  }

  @override
  PaymentConnectionType get connectionType => PaymentConnectionType.tcp;

  @override
  PaymentConnectionStatus get status => _status;

  @override
  Stream<PaymentConnectionStatus> get statusStream => _statusController.stream;

  @override
  bool get isConnected => _status == PaymentConnectionStatus.connected;

  @override
  Future<ConnectionResult> connect({
    required String address,
    Duration timeout = const Duration(seconds: 5),
  }) async {
    if (isConnected) {
      return ConnectionResult.success();
    }

    _updateStatus(PaymentConnectionStatus.connecting);

    try {
      final parts = address.split(':');
      if (parts.length != 2) {
        _updateStatus(PaymentConnectionStatus.error);
        return ConnectionResult.failure(
          'Invalid address format. Expected host:port',
          code: 'INVALID_ADDRESS',
        );
      }

      final host = parts[0];
      final port = int.tryParse(parts[1]);

      if (port == null || port <= 0 || port > 65535) {
        _updateStatus(PaymentConnectionStatus.error);
        return ConnectionResult.failure(
          'Invalid port number',
          code: 'INVALID_PORT',
        );
      }

      _socket = await Socket.connect(host, port, timeout: timeout);

      _setupSocketListeners();
      _reconnectAttempts = 0;
      _updateStatus(PaymentConnectionStatus.connected);

      return ConnectionResult.success();
    } on SocketException catch (e) {
      _updateStatus(PaymentConnectionStatus.error);
      return ConnectionResult.failure(
        'Socket error: ${e.message}',
        code: 'SOCKET_ERROR',
      );
    } on TimeoutException {
      _updateStatus(PaymentConnectionStatus.error);
      return ConnectionResult.failure('Connection timeout', code: 'TIMEOUT');
    } catch (e) {
      _updateStatus(PaymentConnectionStatus.error);
      return ConnectionResult.failure('Connection failed: $e');
    }
  }

  void _setupSocketListeners() {
    _socket?.listen(
      (data) {},
      onError: (error) {
        _handleDisconnect();
      },
      onDone: () {
        _handleDisconnect();
      },
    );
  }

  void _handleDisconnect() {
    _socket = null;

    if (_config.autoReconnect &&
        _reconnectAttempts < _config.maxReconnectAttempts) {
      _updateStatus(PaymentConnectionStatus.reconnecting);
      _scheduleReconnect();
    } else {
      _updateStatus(PaymentConnectionStatus.disconnected);
    }
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(
      Duration(milliseconds: _config.reconnectDelayMs),
      () async {
        _reconnectAttempts++;
        await connect(
          address: _config.fullAddress,
          timeout: Duration(milliseconds: _config.connectionTimeoutMs),
        );
      },
    );
  }

  @override
  Future<void> disconnect() async {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _reconnectAttempts = _config.maxReconnectAttempts;

    await _socket?.close();
    _socket = null;
    _updateStatus(PaymentConnectionStatus.disconnected);
  }

  @override
  Future<TransferResult> send(
    Uint8List data, {
    Duration timeout = const Duration(seconds: 10),
  }) async {
    if (!isConnected || _socket == null) {
      return TransferResult.failure('Not connected');
    }

    try {
      _socket!.add(data);
      await _socket!.flush().timeout(timeout);

      return TransferResult.success(bytesTransferred: data.length);
    } on TimeoutException {
      return TransferResult.timeout();
    } catch (e) {
      return TransferResult.failure('Send failed: $e');
    }
  }

  @override
  Future<TransferResult> receive({
    Duration timeout = const Duration(seconds: 30),
    int expectedLength = 0,
  }) async {
    if (!isConnected || _socket == null) {
      return TransferResult.failure('Not connected');
    }

    try {
      final completer = Completer<Uint8List>();
      final buffer = <int>[];
      StreamSubscription<Uint8List>? subscription;

      subscription = _socket!.listen(
        (data) {
          buffer.addAll(data);

          if (expectedLength > 0 && buffer.length >= expectedLength) {
            subscription?.cancel();
            if (!completer.isCompleted) {
              completer.complete(Uint8List.fromList(buffer));
            }
          } else if (expectedLength == 0) {
            subscription?.cancel();
            if (!completer.isCompleted) {
              completer.complete(Uint8List.fromList(buffer));
            }
          }
        },
        onError: (error) {
          subscription?.cancel();
          if (!completer.isCompleted) {
            completer.completeError(error);
          }
        },
        cancelOnError: true,
      );

      final data = await completer.future.timeout(timeout);
      return TransferResult.success(data: data);
    } on TimeoutException {
      return TransferResult.timeout();
    } catch (e) {
      return TransferResult.failure('Receive failed: $e');
    }
  }

  @override
  Future<TransferResult> sendAndReceive(
    Uint8List data, {
    Duration responseTimeout = const Duration(seconds: 30),
  }) async {
    final sendResult = await send(data);
    if (!sendResult.success) {
      return sendResult;
    }

    return receive(timeout: responseTimeout);
  }

  void _updateStatus(PaymentConnectionStatus newStatus) {
    _status = newStatus;
    _statusController.add(newStatus);
  }

  @override
  void dispose() {
    _reconnectTimer?.cancel();
    _socket?.close();
    _socket = null;
    _statusController.close();
  }
}

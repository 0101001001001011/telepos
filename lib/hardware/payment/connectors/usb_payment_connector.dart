import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_libserialport/flutter_libserialport.dart';

import 'payment_connector.dart';

class UsbPaymentConnector implements PaymentConnector {
  UsbPaymentConnector({PaymentConnectorConfig? config, this.baudRate = 115200})
    : _config =
          config ??
          const PaymentConnectorConfig(
            connectionType: PaymentConnectionType.usb,
          );

  // ignore: unused_field
  final PaymentConnectorConfig _config;
  final int baudRate;

  final _statusController =
      StreamController<PaymentConnectionStatus>.broadcast();
  PaymentConnectionStatus _status = PaymentConnectionStatus.disconnected;

  SerialPort? _port;
  SerialPortReader? _reader;
  StreamSubscription<Uint8List>? _readerSubscription;

  final _responseBuffer = <int>[];
  Completer<Uint8List>? _pendingResponse;

  @override
  PaymentConnectionType get connectionType => PaymentConnectionType.usb;

  @override
  PaymentConnectionStatus get status => _status;

  @override
  Stream<PaymentConnectionStatus> get statusStream => _statusController.stream;

  @override
  bool get isConnected => _status == PaymentConnectionStatus.connected;

  static List<String> availablePorts() {
    try {
      return SerialPort.availablePorts;
    } catch (_) {
      return [];
    }
  }

  @override
  Future<ConnectionResult> connect({
    required String address,
    Duration timeout = const Duration(seconds: 5),
  }) async {
    _updateStatus(PaymentConnectionStatus.connecting);

    try {
      _port = SerialPort(address);

      if (!_port!.openReadWrite()) {
        _updateStatus(PaymentConnectionStatus.error);
        return ConnectionResult.failure(
          'Не удалось открыть порт $address: ${SerialPort.lastError}',
        );
      }

      final portConfig = SerialPortConfig()
        ..baudRate = baudRate
        ..bits = 8
        ..stopBits = 1
        ..parity = SerialPortParity.none;
      _port!.config = portConfig;
      portConfig.dispose();

      _reader = SerialPortReader(_port!);
      _readerSubscription = _reader!.stream.listen(
        _onData,
        onError: (_) => _updateStatus(PaymentConnectionStatus.error),
      );

      _updateStatus(PaymentConnectionStatus.connected);
      return ConnectionResult.success();
    } catch (e) {
      _updateStatus(PaymentConnectionStatus.error);
      _cleanup();
      return ConnectionResult.failure('Ошибка подключения: $e');
    }
  }

  @override
  Future<void> disconnect() async {
    _cleanup();
    _updateStatus(PaymentConnectionStatus.disconnected);
  }

  @override
  Future<TransferResult> send(
    Uint8List data, {
    Duration timeout = const Duration(seconds: 10),
  }) async {
    if (_port == null || !isConnected) {
      return TransferResult.failure('Не подключен');
    }

    try {
      final written = _port!.write(data);
      if (written < 0) {
        return TransferResult.failure('Ошибка записи: ${SerialPort.lastError}');
      }
      return TransferResult.success(bytesTransferred: written);
    } catch (e) {
      return TransferResult.failure('Ошибка отправки: $e');
    }
  }

  @override
  Future<TransferResult> receive({
    Duration timeout = const Duration(seconds: 30),
    int expectedLength = 0,
  }) async {
    if (!isConnected) {
      return TransferResult.failure('Не подключен');
    }

    _responseBuffer.clear();
    _pendingResponse = Completer<Uint8List>();

    try {
      final data = await _pendingResponse!.future.timeout(
        timeout,
        onTimeout: () => throw TimeoutException('Таймаут ответа', timeout),
      );
      return TransferResult.success(data: data);
    } on TimeoutException {
      _pendingResponse = null;
      return TransferResult.timeout();
    } catch (e) {
      _pendingResponse = null;
      return TransferResult.failure('Ошибка приёма: $e');
    }
  }

  @override
  Future<TransferResult> sendAndReceive(
    Uint8List data, {
    Duration responseTimeout = const Duration(seconds: 30),
  }) async {
    final sendResult = await send(data);
    if (!sendResult.success) return sendResult;
    return receive(timeout: responseTimeout);
  }

  void _onData(Uint8List data) {
    _responseBuffer.addAll(data);
    if (_pendingResponse != null && !_pendingResponse!.isCompleted) {
      _pendingResponse!.complete(Uint8List.fromList(_responseBuffer));
      _responseBuffer.clear();
    }
  }

  void _cleanup() {
    _readerSubscription?.cancel();
    _readerSubscription = null;
    _reader = null;
    _pendingResponse?.completeError(Exception('Disconnected'));
    _pendingResponse = null;
    _responseBuffer.clear();

    try {
      if (_port?.isOpen ?? false) _port!.close();
      _port?.dispose();
    } catch (_) {}
    _port = null;
  }

  void _updateStatus(PaymentConnectionStatus newStatus) {
    _status = newStatus;
    if (!_statusController.isClosed) {
      _statusController.add(newStatus);
    }
  }

  @override
  void dispose() {
    _cleanup();
    _statusController.close();
  }
}

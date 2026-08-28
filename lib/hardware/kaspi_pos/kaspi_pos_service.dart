import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'kaspi_pos_config.dart';

class KaspiPosService {
  KaspiPosService({KaspiPosConfig? config})
    : _config = config ?? const KaspiPosConfig();

  KaspiPosConfig _config;

  final _statusController = StreamController<KaspiPosStatus>.broadcast();

  KaspiPosStatus _status = KaspiPosStatus.disconnected;
  Socket? _socket;
  StreamSubscription<Uint8List>? _socketSubscription;

  final _responseBuffer = <int>[];

  Completer<Uint8List>? _pendingResponse;

  KaspiPosConfig get config => _config;

  KaspiPosStatus get status => _status;

  Stream<KaspiPosStatus> get statusStream => _statusController.stream;

  bool get isConnected => _status == KaspiPosStatus.connected;

  void updateConfig(KaspiPosConfig config) {
    _config = config;
  }

  Future<KaspiPosTestResult> testConnection() async {
    if (!_config.isValid) {
      return KaspiPosTestResult.failure('Invalid configuration');
    }

    _updateStatus(KaspiPosStatus.connecting);

    try {
      final stopwatch = Stopwatch()..start();

      final socket = await Socket.connect(
        _config.host,
        _config.port,
        timeout: Duration(milliseconds: _config.timeoutMs),
      );
      await socket.close();

      stopwatch.stop();

      _updateStatus(KaspiPosStatus.connected);
      return KaspiPosTestResult.success(
        latencyMs: stopwatch.elapsedMilliseconds,
        terminalInfo: 'Kaspi POS @ ${_config.address}',
      );
    } on SocketException catch (e) {
      _updateStatus(KaspiPosStatus.error);
      return KaspiPosTestResult.failure(
        'Не удалось подключиться: ${e.message}',
      );
    } on TimeoutException {
      _updateStatus(KaspiPosStatus.error);
      return KaspiPosTestResult.failure(
        'Таймаут подключения (${_config.timeoutMs}ms)',
      );
    } catch (e) {
      _updateStatus(KaspiPosStatus.error);
      return KaspiPosTestResult.failure('Ошибка: $e');
    }
  }

  Future<bool> connect() async {
    if (!_config.enabled || !_config.isValid) {
      return false;
    }

    if (_socket != null && isConnected) return true;

    _updateStatus(KaspiPosStatus.connecting);

    try {
      _socket = await Socket.connect(
        _config.host,
        _config.port,
        timeout: Duration(milliseconds: _config.timeoutMs),
      );

      _socketSubscription = _socket!.listen(
        _onDataReceived,
        onError: _onSocketError,
        onDone: _onSocketDone,
      );

      _updateStatus(KaspiPosStatus.connected);
      return true;
    } on SocketException catch (e) {
      _updateStatus(KaspiPosStatus.error);
      _socket = null;
      throw Exception('Kaspi POS connection failed: ${e.message}');
    } catch (e) {
      _updateStatus(KaspiPosStatus.error);
      _socket = null;
      return false;
    }
  }

  Future<void> disconnect() async {
    await _socketSubscription?.cancel();
    _socketSubscription = null;
    await _socket?.close();
    _socket = null;
    _responseBuffer.clear();
    _pendingResponse?.completeError(const SocketException('Disconnected'));
    _pendingResponse = null;
    _updateStatus(KaspiPosStatus.disconnected);
  }

  Future<Uint8List> _sendAndReceive(
    List<int> data, {
    Duration timeout = const Duration(seconds: 30),
  }) async {
    if (_socket == null || !isConnected) {
      throw const SocketException('Not connected to Kaspi POS');
    }

    _responseBuffer.clear();
    _pendingResponse = Completer<Uint8List>();

    _socket!.add(data);
    await _socket!.flush();

    return _pendingResponse!.future.timeout(
      timeout,
      onTimeout: () {
        _pendingResponse = null;
        throw TimeoutException('No response from terminal', timeout);
      },
    );
  }

  void _onDataReceived(Uint8List data) {
    _responseBuffer.addAll(data);

    if (_pendingResponse != null && !_pendingResponse!.isCompleted) {
      _pendingResponse!.complete(Uint8List.fromList(_responseBuffer));
      _responseBuffer.clear();
    }
  }

  void _onSocketError(Object error) {
    _updateStatus(KaspiPosStatus.error);
    _pendingResponse?.completeError(error);
    _pendingResponse = null;
  }

  void _onSocketDone() {
    _socket = null;
    _socketSubscription = null;
    _updateStatus(KaspiPosStatus.disconnected);
    _pendingResponse?.completeError(
      const SocketException('Connection closed by terminal'),
    );
    _pendingResponse = null;
  }

  Future<KaspiPaymentResult> requestPayment({
    required int amountKopeiki,
    required String receiptNo,
  }) async {
    if (!isConnected) {
      final connected = await connect();
      if (!connected) {
        return KaspiPaymentResult.failure(
          'Не удалось подключиться к терминалу',
        );
      }
    }

    try {
      final command = _buildPurchaseCommand(amountKopeiki, receiptNo);

      final response = await _sendAndReceive(
        command,
        timeout: const Duration(seconds: 60),
      );

      return _parsePurchaseResponse(response);
    } on TimeoutException {
      return KaspiPaymentResult.failure('Таймаут ожидания ответа от терминала');
    } on SocketException catch (e) {
      _updateStatus(KaspiPosStatus.error);
      return KaspiPaymentResult.failure('Ошибка связи: ${e.message}');
    } catch (e) {
      return KaspiPaymentResult.failure('Ошибка: $e');
    }
  }

  Future<bool> cancelTransaction() async {
    if (!isConnected) return false;

    try {
      final command = _buildReversalCommand();
      final response = await _sendAndReceive(
        command,
        timeout: const Duration(seconds: 30),
      );
      return _isSuccessResponse(response);
    } catch (_) {
      return false;
    }
  }

  List<int> _buildPurchaseCommand(int amountKopeiki, String receiptNo) {
    final amountStr = amountKopeiki.toString().padLeft(12, '0');
    final receiptStr = receiptNo.padLeft(6, '0');
    final payload = '1$amountStr$receiptStr';
    return [0x02, ...payload.codeUnits, 0x03];
  }

  List<int> _buildReversalCommand() {
    return [0x02, ...('3').codeUnits, 0x03];
  }

  KaspiPaymentResult _parsePurchaseResponse(Uint8List response) {
    if (response.isEmpty) {
      return KaspiPaymentResult.failure('Пустой ответ от терминала');
    }

    final payload = response.where((b) => b != 0x02 && b != 0x03).toList();
    if (payload.isEmpty) {
      return KaspiPaymentResult.failure('Некорректный ответ');
    }

    final resultCode = payload[0];
    if (resultCode == 0x30) {
      final dataStr = String.fromCharCodes(payload.skip(1));
      final transactionId = dataStr.length >= 12
          ? dataStr.substring(0, 12).trim()
          : '';
      final approvalCode = dataStr.length >= 18
          ? dataStr.substring(12, 18).trim()
          : '';

      return KaspiPaymentResult.success(
        transactionId: transactionId.isNotEmpty
            ? transactionId
            : 'KP${DateTime.now().millisecondsSinceEpoch}',
        approvalCode: approvalCode.isNotEmpty ? approvalCode : '000000',
        cardMask: dataStr.length >= 34
            ? dataStr.substring(18, 34).trim()
            : null,
      );
    } else {
      final errorMsg = String.fromCharCodes(payload.skip(1)).trim();
      return KaspiPaymentResult.failure(
        errorMsg.isNotEmpty ? errorMsg : 'Отказ терминала (код: $resultCode)',
        errorCode: resultCode.toString(),
      );
    }
  }

  bool _isSuccessResponse(Uint8List response) {
    final payload = response.where((b) => b != 0x02 && b != 0x03).toList();
    return payload.isNotEmpty && payload[0] == 0x30;
  }

  void _updateStatus(KaspiPosStatus newStatus) {
    _status = newStatus;
    if (!_statusController.isClosed) {
      _statusController.add(newStatus);
    }
  }

  void dispose() {
    disconnect();
    _statusController.close();
  }
}

class KaspiPaymentResult {
  const KaspiPaymentResult({
    required this.success,
    this.transactionId,
    this.approvalCode,
    this.cardMask,
    this.errorCode,
    this.errorMessage,
  });

  final bool success;
  final String? transactionId;
  final String? approvalCode;
  final String? cardMask;
  final String? errorCode;
  final String? errorMessage;

  factory KaspiPaymentResult.success({
    required String transactionId,
    required String approvalCode,
    String? cardMask,
  }) {
    return KaspiPaymentResult(
      success: true,
      transactionId: transactionId,
      approvalCode: approvalCode,
      cardMask: cardMask,
    );
  }

  factory KaspiPaymentResult.failure(String errorMessage, {String? errorCode}) {
    return KaspiPaymentResult(
      success: false,
      errorCode: errorCode,
      errorMessage: errorMessage,
    );
  }
}

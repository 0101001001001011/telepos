import 'dart:async';
import 'dart:typed_data';

enum PaymentPlatform { desktop, mobile, web }

enum PaymentConnectionType { tcp, bluetooth, nfc, usb, mock }

enum PaymentConnectionStatus {
  disconnected,

  connecting,

  connected,

  error,

  reconnecting,
}

class ConnectionResult {
  const ConnectionResult({
    required this.success,
    this.errorMessage,
    this.errorCode,
  });

  final bool success;

  final String? errorMessage;

  final String? errorCode;

  factory ConnectionResult.success() {
    return const ConnectionResult(success: true);
  }

  factory ConnectionResult.failure(String message, {String? code}) {
    return ConnectionResult(
      success: false,
      errorMessage: message,
      errorCode: code,
    );
  }

  @override
  String toString() {
    if (success) return 'ConnectionResult(success)';
    return 'ConnectionResult(failed: $errorMessage)';
  }
}

class TransferResult {
  const TransferResult({
    required this.success,
    this.data,
    this.bytesTransferred,
    this.errorMessage,
  });

  final bool success;

  final Uint8List? data;

  final int? bytesTransferred;

  final String? errorMessage;

  factory TransferResult.success({Uint8List? data, int? bytesTransferred}) {
    return TransferResult(
      success: true,
      data: data,
      bytesTransferred: bytesTransferred ?? data?.length ?? 0,
    );
  }

  factory TransferResult.failure(String message) {
    return TransferResult(success: false, errorMessage: message);
  }

  factory TransferResult.timeout() {
    return const TransferResult(
      success: false,
      errorMessage: 'Operation timed out',
    );
  }
}

abstract class PaymentConnector {
  PaymentConnectionType get connectionType;

  PaymentConnectionStatus get status;

  Stream<PaymentConnectionStatus> get statusStream;

  bool get isConnected;

  Future<ConnectionResult> connect({
    required String address,
    Duration timeout = const Duration(seconds: 5),
  });

  Future<void> disconnect();

  Future<TransferResult> send(
    Uint8List data, {
    Duration timeout = const Duration(seconds: 10),
  });

  Future<TransferResult> receive({
    Duration timeout = const Duration(seconds: 30),
    int expectedLength = 0,
  });

  Future<TransferResult> sendAndReceive(
    Uint8List data, {
    Duration responseTimeout = const Duration(seconds: 30),
  });

  void dispose();
}

class PaymentConnectorConfig {
  const PaymentConnectorConfig({
    required this.connectionType,
    this.address,
    this.port,
    this.deviceId,
    this.autoReconnect = true,
    this.reconnectDelayMs = 3000,
    this.maxReconnectAttempts = 3,
    this.connectionTimeoutMs = 5000,
    this.readTimeoutMs = 30000,
    this.writeTimeoutMs = 10000,
  });

  final PaymentConnectionType connectionType;

  final String? address;

  final int? port;

  final String? deviceId;

  final bool autoReconnect;

  final int reconnectDelayMs;

  final int maxReconnectAttempts;

  final int connectionTimeoutMs;

  final int readTimeoutMs;

  final int writeTimeoutMs;

  String get fullAddress {
    if (connectionType == PaymentConnectionType.tcp && port != null) {
      return '${address ?? ''}:$port';
    }
    return address ?? deviceId ?? '';
  }

  PaymentConnectorConfig copyWith({
    PaymentConnectionType? connectionType,
    String? address,
    int? port,
    String? deviceId,
    bool? autoReconnect,
    int? reconnectDelayMs,
    int? maxReconnectAttempts,
    int? connectionTimeoutMs,
    int? readTimeoutMs,
    int? writeTimeoutMs,
  }) {
    return PaymentConnectorConfig(
      connectionType: connectionType ?? this.connectionType,
      address: address ?? this.address,
      port: port ?? this.port,
      deviceId: deviceId ?? this.deviceId,
      autoReconnect: autoReconnect ?? this.autoReconnect,
      reconnectDelayMs: reconnectDelayMs ?? this.reconnectDelayMs,
      maxReconnectAttempts: maxReconnectAttempts ?? this.maxReconnectAttempts,
      connectionTimeoutMs: connectionTimeoutMs ?? this.connectionTimeoutMs,
      readTimeoutMs: readTimeoutMs ?? this.readTimeoutMs,
      writeTimeoutMs: writeTimeoutMs ?? this.writeTimeoutMs,
    );
  }
}

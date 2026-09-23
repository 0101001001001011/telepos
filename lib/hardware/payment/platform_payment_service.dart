import 'dart:io';

import 'package:flutter/foundation.dart';

import 'connectors/payment_connector.dart';
import 'connectors/tcp_payment_connector.dart';
import 'connectors/bluetooth_payment_connector.dart';
import 'connectors/nfc_payment_connector.dart';
import 'connectors/usb_payment_connector.dart';

class PlatformPaymentService {
  PlatformPaymentService();

  PaymentConnector? _activeConnector;

  PaymentPlatform get currentPlatform => _detectPlatform();

  List<PaymentConnectionType> get availableConnectionTypes {
    switch (currentPlatform) {
      case PaymentPlatform.desktop:
        return [
          PaymentConnectionType.tcp,
          PaymentConnectionType.usb,
          PaymentConnectionType.mock,
        ];
      case PaymentPlatform.mobile:
        return [
          PaymentConnectionType.bluetooth,
          PaymentConnectionType.nfc,
          PaymentConnectionType.mock,
        ];
      case PaymentPlatform.web:
        return [PaymentConnectionType.mock];
    }
  }

  PaymentConnectionType get defaultConnectionType {
    switch (currentPlatform) {
      case PaymentPlatform.desktop:
        return PaymentConnectionType.tcp;
      case PaymentPlatform.mobile:
        return PaymentConnectionType.bluetooth;
      case PaymentPlatform.web:
        return PaymentConnectionType.mock;
    }
  }

  PaymentConnector? get activeConnector => _activeConnector;

  bool get hasActiveConnector => _activeConnector != null;

  bool get isConnected => _activeConnector?.isConnected ?? false;

  PaymentConnector? createConnector(
    PaymentConnectionType type, {
    PaymentConnectorConfig? config,
  }) {
    if (!availableConnectionTypes.contains(type) &&
        type != PaymentConnectionType.mock) {
      return null;
    }

    switch (type) {
      case PaymentConnectionType.tcp:
        return TcpPaymentConnector(
          config:
              config?.copyWith(connectionType: type) ??
              PaymentConnectorConfig(connectionType: type),
        );
      case PaymentConnectionType.bluetooth:
        return BluetoothPaymentConnector(
          config:
              config?.copyWith(connectionType: type) ??
              PaymentConnectorConfig(connectionType: type),
        );
      case PaymentConnectionType.nfc:
        return NfcPaymentConnector(
          config:
              config?.copyWith(connectionType: type) ??
              PaymentConnectorConfig(connectionType: type),
        );
      case PaymentConnectionType.usb:
        return UsbPaymentConnector(
          config:
              config?.copyWith(connectionType: type) ??
              PaymentConnectorConfig(connectionType: type),
        );
      case PaymentConnectionType.mock:
        return MockPaymentConnector(
          config:
              config?.copyWith(connectionType: type) ??
              PaymentConnectorConfig(connectionType: type),
        );
    }
  }

  PaymentConnector? activateConnector(
    PaymentConnectionType type, {
    PaymentConnectorConfig? config,
  }) {
    _activeConnector?.dispose();
    _activeConnector = createConnector(type, config: config);
    return _activeConnector;
  }

  PaymentConnector? activateDefaultConnector({PaymentConnectorConfig? config}) {
    return activateConnector(defaultConnectionType, config: config);
  }

  void deactivateConnector() {
    _activeConnector?.dispose();
    _activeConnector = null;
  }

  PaymentPlatform _detectPlatform() {
    if (kIsWeb) {
      return PaymentPlatform.web;
    }

    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      return PaymentPlatform.desktop;
    }

    if (Platform.isAndroid || Platform.isIOS) {
      return PaymentPlatform.mobile;
    }

    return PaymentPlatform.desktop;
  }

  bool isConnectionTypeSupported(PaymentConnectionType type) {
    return availableConnectionTypes.contains(type);
  }

  // `platformName` и `connectionTypeName` жили здесь и не звались НИКЕМ.
  // Замер мёртвых ключей словаря 2026-09-23 вывел на них по значению
  // «Тестовый режим», и оказалось, что это не место для перевода, а
  // мёртвый код: две подписи для человека, у которых нет читателя. Тот же
  // узор, что 36 зарегистрированных и не спрошенных договоров.
  //
  // Появится читатель — слово выберет он, на языке интерфейса, а не эти
  // литералы, где «USB» было английским, а «Тестовый режим» русским.


  void dispose() {
    _activeConnector?.dispose();
    _activeConnector = null;
  }
}

class MockPaymentConnector implements PaymentConnector {
  MockPaymentConnector({PaymentConnectorConfig? config})
    : _config =
          config ??
          const PaymentConnectorConfig(
            connectionType: PaymentConnectionType.mock,
          );

  // ignore: unused_field
  final PaymentConnectorConfig _config;
  PaymentConnectionStatus _status = PaymentConnectionStatus.disconnected;

  @override
  PaymentConnectionType get connectionType => PaymentConnectionType.mock;

  @override
  PaymentConnectionStatus get status => _status;

  @override
  Stream<PaymentConnectionStatus> get statusStream =>
      Stream.value(_status).asBroadcastStream();

  @override
  bool get isConnected => _status == PaymentConnectionStatus.connected;

  @override
  Future<ConnectionResult> connect({
    required String address,
    Duration timeout = const Duration(seconds: 5),
  }) async {
    _status = PaymentConnectionStatus.connecting;
    await Future<void>.delayed(const Duration(milliseconds: 500));
    _status = PaymentConnectionStatus.connected;
    return ConnectionResult.success();
  }

  @override
  Future<void> disconnect() async {
    _status = PaymentConnectionStatus.disconnected;
  }

  @override
  Future<TransferResult> send(
    Uint8List data, {
    Duration timeout = const Duration(seconds: 10),
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 100));
    return TransferResult.success(bytesTransferred: data.length);
  }

  @override
  Future<TransferResult> receive({
    Duration timeout = const Duration(seconds: 30),
    int expectedLength = 0,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    return TransferResult.success(data: Uint8List.fromList([0x06]));
  }

  @override
  Future<TransferResult> sendAndReceive(
    Uint8List data, {
    Duration responseTimeout = const Duration(seconds: 30),
  }) async {
    await send(data);
    return receive(timeout: responseTimeout);
  }

  @override
  void dispose() {
    _status = PaymentConnectionStatus.disconnected;
  }
}

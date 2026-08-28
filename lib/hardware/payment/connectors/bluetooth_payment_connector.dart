import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_blue_plus/flutter_blue_plus.dart' as fbp;

import 'payment_connector.dart';

class BluetoothPaymentConnector implements PaymentConnector {
  BluetoothPaymentConnector({PaymentConnectorConfig? config})
    : _config =
          config ??
          const PaymentConnectorConfig(
            connectionType: PaymentConnectionType.bluetooth,
          );

  // ignore: unused_field
  final PaymentConnectorConfig _config;
  final _statusController =
      StreamController<PaymentConnectionStatus>.broadcast();
  PaymentConnectionStatus _status = PaymentConnectionStatus.disconnected;

  fbp.BluetoothDevice? _fbpDevice;

  fbp.BluetoothCharacteristic? _writeCharacteristic;

  fbp.BluetoothCharacteristic? _readCharacteristic;

  StreamSubscription<List<int>>? _notificationSubscription;

  final _receiveBuffer = <int>[];

  Completer<Uint8List>? _receiveCompleter;

  static const int _bleChunkSize = 512;

  @override
  PaymentConnectionType get connectionType => PaymentConnectionType.bluetooth;

  @override
  PaymentConnectionStatus get status => _status;

  @override
  Stream<PaymentConnectionStatus> get statusStream => _statusController.stream;

  @override
  bool get isConnected => _status == PaymentConnectionStatus.connected;

  Future<List<BluetoothPaymentDevice>> scanDevices({
    Duration timeout = const Duration(seconds: 10),
  }) async {
    try {
      final devices = <BluetoothPaymentDevice>[];

      await fbp.FlutterBluePlus.startScan(timeout: timeout);

      final subscription = fbp.FlutterBluePlus.scanResults.listen((results) {
        for (final result in results) {
          final name = result.device.platformName;
          if (name.isNotEmpty) {
            final device = BluetoothPaymentDevice(
              id: result.device.remoteId.str,
              name: name,
              rssi: result.rssi,
            );
            if (!devices.any((d) => d.id == device.id)) {
              devices.add(device);
            }
          }
        }
      });

      await Future<void>.delayed(timeout);
      await subscription.cancel();

      try {
        final bonded = await fbp.FlutterBluePlus.bondedDevices;
        for (final d in bonded) {
          final id = d.remoteId.str;
          if (!devices.any((dev) => dev.id == id)) {
            devices.add(
              BluetoothPaymentDevice(
                id: id,
                name: d.platformName.isNotEmpty ? d.platformName : 'Unknown',
                isPaired: true,
              ),
            );
          }
        }
      } catch (_) {}

      return devices;
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
      _fbpDevice = fbp.BluetoothDevice.fromId(address);
      await _fbpDevice!.connect(license: fbp.License.free, timeout: timeout);

      final services = await _fbpDevice!.discoverServices();

      for (final service in services) {
        for (final characteristic in service.characteristics) {
          if (characteristic.properties.write ||
              characteristic.properties.writeWithoutResponse) {
            _writeCharacteristic ??= characteristic;
          }
          if (characteristic.properties.notify ||
              characteristic.properties.indicate) {
            _readCharacteristic ??= characteristic;
          }
        }
      }

      if (_writeCharacteristic == null) {
        await _fbpDevice!.disconnect();
        _fbpDevice = null;
        _updateStatus(PaymentConnectionStatus.error);
        return ConnectionResult.failure(
          'No writable characteristic found on device',
          code: 'NO_WRITE_CHAR',
        );
      }

      if (_readCharacteristic != null) {
        await _readCharacteristic!.setNotifyValue(true);
        _notificationSubscription = _readCharacteristic!.onValueReceived.listen(
          (data) {
            _receiveBuffer.addAll(data);
            if (_receiveCompleter != null && !_receiveCompleter!.isCompleted) {
              _receiveCompleter!.complete(Uint8List.fromList(_receiveBuffer));
              _receiveBuffer.clear();
            }
          },
        );
      }

      _updateStatus(PaymentConnectionStatus.connected);
      return ConnectionResult.success();
    } catch (e) {
      _updateStatus(PaymentConnectionStatus.error);
      _fbpDevice = null;
      _writeCharacteristic = null;
      _readCharacteristic = null;
      return ConnectionResult.failure(
        'Bluetooth connection failed: $e',
        code: 'BT_CONNECT_FAILED',
      );
    }
  }

  @override
  Future<void> disconnect() async {
    try {
      await _notificationSubscription?.cancel();
      _notificationSubscription = null;
      await _fbpDevice?.disconnect();
    } catch (_) {}
    _fbpDevice = null;
    _writeCharacteristic = null;
    _readCharacteristic = null;
    _receiveBuffer.clear();
    _receiveCompleter = null;
    _updateStatus(PaymentConnectionStatus.disconnected);
  }

  @override
  Future<TransferResult> send(
    Uint8List data, {
    Duration timeout = const Duration(seconds: 10),
  }) async {
    if (!isConnected || _writeCharacteristic == null) {
      return TransferResult.failure('Not connected to Bluetooth device');
    }

    try {
      int offset = 0;
      while (offset < data.length) {
        final end = (offset + _bleChunkSize < data.length)
            ? offset + _bleChunkSize
            : data.length;
        final chunk = data.sublist(offset, end);
        await _writeCharacteristic!.write(chunk, withoutResponse: false);
        offset = end;
      }

      return TransferResult.success(bytesTransferred: data.length);
    } catch (e) {
      return TransferResult.failure('Bluetooth send failed: $e');
    }
  }

  @override
  Future<TransferResult> receive({
    Duration timeout = const Duration(seconds: 30),
    int expectedLength = 0,
  }) async {
    if (!isConnected || _readCharacteristic == null) {
      return TransferResult.failure('Not connected or no read characteristic');
    }

    try {
      _receiveBuffer.clear();
      _receiveCompleter = Completer<Uint8List>();

      final data = await _receiveCompleter!.future.timeout(
        timeout,
        onTimeout: () => Uint8List(0),
      );

      if (data.isEmpty) {
        return TransferResult.timeout();
      }

      return TransferResult.success(data: data);
    } catch (e) {
      return TransferResult.failure('Bluetooth receive failed: $e');
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

    return await receive(timeout: responseTimeout);
  }

  void _updateStatus(PaymentConnectionStatus newStatus) {
    _status = newStatus;
    _statusController.add(newStatus);
  }

  @override
  void dispose() {
    _notificationSubscription?.cancel();
    _statusController.close();
  }
}

class BluetoothPaymentDevice {
  const BluetoothPaymentDevice({
    required this.id,
    required this.name,
    this.rssi,
    this.isPaired = false,
  });

  final String id;

  final String name;

  final int? rssi;

  final bool isPaired;

  @override
  String toString() => 'BluetoothPaymentDevice($name, $id)';
}

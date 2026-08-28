import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_blue_plus/flutter_blue_plus.dart' as fbp;
import 'package:telepos/hardware/printer/printer_manager.dart';

class BluetoothPrinterManager extends BufferedPrinterManager {
  BluetoothPrinterManager({this.deviceAddress, this.deviceName});

  final String? deviceAddress;

  final String? deviceName;

  bool _isConnected = false;
  PrinterInfo? _printerInfo;
  BluetoothDevice? _device;

  fbp.BluetoothDevice? _fbpDevice;

  fbp.BluetoothCharacteristic? _writeCharacteristic;

  static const int _bleChunkSize = 512;

  @override
  bool get isConnected => _isConnected;

  @override
  Future<PrinterConnectionResult> connect() async {
    try {
      if (deviceAddress == null && deviceName == null) {
        return PrinterConnectionResult.error(
          'Укажите адрес или имя Bluetooth устройства',
        );
      }

      final isBluetoothEnabled = await _checkBluetoothEnabled();
      if (!isBluetoothEnabled) {
        return PrinterConnectionResult.error(
          'Включите Bluetooth на устройстве',
        );
      }

      if (deviceAddress != null) {
        _fbpDevice = fbp.BluetoothDevice.fromId(deviceAddress!);
      } else {
        final found = await _findDeviceByName(deviceName!);
        if (found == null) {
          return PrinterConnectionResult.error(
            'Устройство "$deviceName" не найдено',
          );
        }
        _fbpDevice = found;
      }

      await _fbpDevice!.connect(
        license: fbp.License.free,
        timeout: const Duration(seconds: 10),
      );

      final services = await _fbpDevice!.discoverServices();
      _writeCharacteristic = _findWriteCharacteristic(services);

      if (_writeCharacteristic == null) {
        await _fbpDevice!.disconnect();
        _fbpDevice = null;
        return PrinterConnectionResult.error(
          'Не найдена характеристика записи на устройстве',
        );
      }

      _isConnected = true;
      _device = BluetoothDevice(
        address: _fbpDevice!.remoteId.str,
        name: _fbpDevice!.platformName.isNotEmpty
            ? _fbpDevice!.platformName
            : (deviceName ?? 'BT Printer'),
      );
      _printerInfo = PrinterInfo(
        name: _device!.name,
        address: _device!.address,
        model: 'Bluetooth ESC/POS',
        paperWidth: 58,
      );

      return PrinterConnectionResult.ok(_printerInfo!);
    } catch (e) {
      _isConnected = false;
      _fbpDevice = null;
      _writeCharacteristic = null;
      return PrinterConnectionResult.error('Ошибка подключения: $e');
    }
  }

  @override
  Future<void> disconnect() async {
    try {
      await _fbpDevice?.disconnect();
    } catch (_) {}
    _isConnected = false;
    _printerInfo = null;
    _device = null;
    _fbpDevice = null;
    _writeCharacteristic = null;
  }

  @override
  Future<PrinterStatus> getStatus() async {
    if (!_isConnected || _fbpDevice == null) {
      return PrinterStatus.offline;
    }

    try {
      final connected = _fbpDevice!.isConnected;
      if (!connected) {
        _isConnected = false;
        return PrinterStatus.offline;
      }
      return PrinterStatus.ok;
    } catch (_) {
      _isConnected = false;
      return PrinterStatus.offline;
    }
  }

  @override
  Future<PrintResult> writeRaw(Uint8List data) async {
    // Подключение — часть записи: см. контракт `PrinterManager.writeRaw`.
    if (!_isConnected || _writeCharacteristic == null) {
      final connection = await connect();
      if (!connection.success) {
        return PrintResult.error(
          'Печать не удалась — принтер не подключен: '
          '${connection.errorMessage}',
        );
      }
    }
    if (_writeCharacteristic == null) {
      return PrintResult.error('Принтер не подключен');
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

      return PrintResult.ok(bytesSent: data.length);
    } catch (e) {
      _isConnected = false;
      return PrintResult.error('Ошибка отправки: $e');
    }
  }

  Future<bool> _checkBluetoothEnabled() async {
    try {
      final state = await fbp.FlutterBluePlus.adapterState.first;
      return state == fbp.BluetoothAdapterState.on;
    } catch (_) {
      return false;
    }
  }

  Future<fbp.BluetoothDevice?> _findDeviceByName(String name) async {
    try {
      await fbp.FlutterBluePlus.startScan(timeout: const Duration(seconds: 10));
      final results = await fbp.FlutterBluePlus.scanResults.first;
      await fbp.FlutterBluePlus.stopScan();

      for (final result in results) {
        if (result.device.platformName.toUpperCase().contains(
          name.toUpperCase(),
        )) {
          return result.device;
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  fbp.BluetoothCharacteristic? _findWriteCharacteristic(
    List<fbp.BluetoothService> services,
  ) {
    for (final service in services) {
      for (final characteristic in service.characteristics) {
        if (characteristic.properties.write ||
            characteristic.properties.writeWithoutResponse) {
          return characteristic;
        }
      }
    }
    return null;
  }
}

class BluetoothPrinterScanner {
  BluetoothPrinterScanner._();

  static const int scanTimeoutSeconds = 10;

  static const List<String> knownPrinterNames = [
    'POS-58',
    'POS-80',
    'RPP',
    'MPT',
    'PT-',
    'DP-',
    'ZJ-',
    'MTP-',
    'Printer',
  ];

  static Future<List<BluetoothDevice>> scan({
    Duration timeout = const Duration(seconds: 10),
  }) async {
    try {
      final devices = <BluetoothDevice>[];

      await fbp.FlutterBluePlus.startScan(timeout: timeout);

      final subscription = fbp.FlutterBluePlus.scanResults.listen((results) {
        for (final result in results) {
          final name = result.device.platformName;
          if (isPrinterDevice(name)) {
            final device = BluetoothDevice(
              address: result.device.remoteId.str,
              name: name.isNotEmpty ? name : 'Unknown',
              rssi: result.rssi,
            );
            if (!devices.contains(device)) {
              devices.add(device);
            }
          }
        }
      });

      await Future<void>.delayed(timeout);
      await subscription.cancel();

      return devices;
    } catch (_) {
      return [];
    }
  }

  static Future<List<BluetoothDevice>> getBondedDevices() async {
    try {
      final bonded = await fbp.FlutterBluePlus.bondedDevices;
      return bonded
          .map(
            (d) => BluetoothDevice(
              address: d.remoteId.str,
              name: d.platformName.isNotEmpty ? d.platformName : 'Unknown',
              isBonded: true,
            ),
          )
          .toList();
    } catch (_) {
      return [];
    }
  }

  static bool isPrinterDevice(String? name) {
    if (name == null || name.isEmpty) return false;

    final upperName = name.toUpperCase();
    for (final prefix in knownPrinterNames) {
      if (upperName.contains(prefix.toUpperCase())) {
        return true;
      }
    }
    return false;
  }

  static Future<bool> requestPermissions() async {
    try {
      final state = await fbp.FlutterBluePlus.adapterState.first;
      return state == fbp.BluetoothAdapterState.on;
    } catch (_) {
      return false;
    }
  }
}

class BluetoothDevice {
  const BluetoothDevice({
    required this.address,
    required this.name,
    this.rssi,
    this.isBonded = false,
    this.isConnected = false,
  });

  final String address;

  final String name;

  final int? rssi;

  final bool isBonded;

  final bool isConnected;

  int get signalQuality {
    if (rssi == null) return 0;
    final clamped = rssi!.clamp(-100, 0);
    return ((clamped + 100) * 100 / 100).round();
  }

  @override
  String toString() => 'BluetoothDevice($name @ $address)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BluetoothDevice &&
          runtimeType == other.runtimeType &&
          address == other.address;

  @override
  int get hashCode => address.hashCode;
}

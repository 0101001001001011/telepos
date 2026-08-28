import 'dart:typed_data';

import 'package:flutter_libserialport/flutter_libserialport.dart';
import 'package:telepos/hardware/printer/printer_manager.dart';

class WindowsPrinterManager extends BufferedPrinterManager {
  WindowsPrinterManager({this.printerName, this.portName, int? baudRate})
    : _baudRate = baudRate ?? 9600;

  final String? printerName;

  final String? portName;

  final int _baudRate;

  bool _isConnected = false;
  PrinterInfo? _printerInfo;
  SerialPort? _serialPort;

  @override
  bool get isConnected => _isConnected;

  @override
  Future<PrinterConnectionResult> connect() async {
    try {
      final targetPort = portName ?? _autoDetectPort();
      if (targetPort == null) {
        return PrinterConnectionResult.error(
          'Принтер не найден. Нет доступных COM-портов.',
        );
      }

      _serialPort = SerialPort(targetPort);

      if (!_serialPort!.openReadWrite()) {
        final err = SerialPort.lastError?.message ?? 'Unknown error';
        _serialPort?.dispose();
        _serialPort = null;
        return PrinterConnectionResult.error(
          'Не удалось открыть порт $targetPort: $err',
        );
      }

      final config = _serialPort!.config;
      config.baudRate = _baudRate;
      config.bits = 8;
      config.stopBits = 1;
      config.parity = SerialPortParity.none;
      _serialPort!.config = config;

      _isConnected = true;
      _printerInfo = PrinterInfo(
        name: printerName ?? 'POS Printer',
        address: targetPort,
        model: 'ESC/POS (Serial)',
        paperWidth: 58,
      );

      return PrinterConnectionResult.ok(_printerInfo!);
    } catch (e) {
      _serialPort?.dispose();
      _serialPort = null;
      return PrinterConnectionResult.error('Ошибка подключения: $e');
    }
  }

  @override
  Future<void> disconnect() async {
    try {
      if (_serialPort != null) {
        if (_serialPort!.isOpen) {
          _serialPort!.close();
        }
        _serialPort!.dispose();
        _serialPort = null;
      }
    } catch (_) {}
    _isConnected = false;
    _printerInfo = null;
  }

  @override
  Future<PrinterStatus> getStatus() async {
    if (!_isConnected || _serialPort == null) {
      return PrinterStatus.offline;
    }

    try {
      if (!_serialPort!.isOpen) {
        _isConnected = false;
        return PrinterStatus.offline;
      }
      return PrinterStatus.ok;
    } catch (_) {
      return PrinterStatus.offline;
    }
  }

  @override
  Future<PrintResult> writeRaw(Uint8List data) async {
    // Подключение — часть записи: см. контракт `PrinterManager.writeRaw`. У
    // COM-порта своего срока нет, поэтому открытие стоит здесь, а не у
    // вызывающего, — иначе одна отправка платила бы два бюджета на тех
    // проводах, где бюджет есть.
    if (!_isConnected || _serialPort == null) {
      final connection = await connect();
      if (!connection.success) {
        return PrintResult.error(
          'Печать не удалась — принтер не подключен: '
          '${connection.errorMessage}',
        );
      }
    }
    if (_serialPort == null) {
      return PrintResult.error('Принтер не подключен');
    }

    try {
      final bytesWritten = _serialPort!.write(data);
      if (bytesWritten < 0) {
        final err = SerialPort.lastError?.message ?? 'Write failed';
        return PrintResult.error('Ошибка записи: $err');
      }
      return PrintResult.ok(bytesSent: bytesWritten);
    } catch (e) {
      return PrintResult.error('Ошибка печати: $e');
    }
  }

  String? _autoDetectPort() {
    try {
      final ports = SerialPort.availablePorts;
      if (ports.isEmpty) return null;

      for (final port in ports) {
        final upper = port.toUpperCase();
        if (upper.startsWith('COM')) {
          final num = int.tryParse(upper.substring(3));
          if (num != null && num >= 3) {
            return port;
          }
        }
      }
      return ports.first;
    } catch (_) {
      return null;
    }
  }
}

class WindowsPrinterScanner {
  WindowsPrinterScanner._();

  static Future<List<WindowsPrinterInfo>> scanPrinters() async {
    try {
      final portNames = SerialPort.availablePorts;
      final result = <WindowsPrinterInfo>[];

      for (final name in portNames) {
        try {
          final port = SerialPort(name);
          result.add(
            WindowsPrinterInfo(
              name: port.description ?? name,
              portName: name,
              driverName: port.manufacturer ?? 'Unknown',
              isDefault: false,
            ),
          );
          port.dispose();
        } catch (_) {
          result.add(
            WindowsPrinterInfo(
              name: name,
              portName: name,
              driverName: 'Unknown',
              isDefault: false,
            ),
          );
        }
      }

      if (result.isNotEmpty) {
        final first = result.first;
        result[0] = WindowsPrinterInfo(
          name: first.name,
          portName: first.portName,
          driverName: first.driverName,
          isDefault: true,
          status: first.status,
        );
      }

      return result;
    } catch (_) {
      return [];
    }
  }

  static Future<String?> getDefaultPrinter() async {
    try {
      final ports = SerialPort.availablePorts;
      if (ports.isEmpty) return null;
      for (final port in ports) {
        final upper = port.toUpperCase();
        if (upper.startsWith('COM')) {
          final num = int.tryParse(upper.substring(3));
          if (num != null && num >= 3) return port;
        }
      }
      return ports.first;
    } catch (_) {
      return null;
    }
  }
}

class WindowsPrinterInfo {
  const WindowsPrinterInfo({
    required this.name,
    required this.portName,
    required this.driverName,
    this.isDefault = false,
    this.status = 0,
  });

  final String name;

  final String portName;

  final String driverName;

  final bool isDefault;

  final int status;

  bool get isReady => status == 0;

  @override
  String toString() => 'WindowsPrinterInfo($name @ $portName)';
}

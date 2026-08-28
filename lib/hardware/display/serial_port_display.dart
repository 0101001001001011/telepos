import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:telepos/hardware/display/display_platform.dart';

abstract class SerialPortDisplay {
  Future<bool> open();

  Future<void> close();

  Future<void> write(List<int> data);

  bool get isOpen;

  String get portName;

  factory SerialPortDisplay({
    required String port,
    int baudRate = 9600,
    int dataBits = 8,
    int stopBits = 1,
    int parity = 0,
  }) {
    if (DisplayPlatform.isSupported) {
      return _FileSerialPortDisplay(
        port: port,
        baudRate: baudRate,
        dataBits: dataBits,
        stopBits: stopBits,
        parity: parity,
      );
    }
    return _DummySerialPortDisplay(port);
  }

  static Future<List<String>> getAvailablePorts() async {
    if (!DisplayPlatform.isSupported) {
      return [];
    }

    if (Platform.isWindows) {
      final ports = <String>[];
      for (var i = 1; i <= 20; i++) {
        final port = 'COM$i';
        try {
          final file = File('\\\\.\\$port');
          if (await file.exists()) {
            ports.add(port);
          }
        } catch (_) {}
      }
      return ports.isEmpty ? DisplayPlatform.defaultPorts : ports;
    }

    if (Platform.isLinux || Platform.isMacOS) {
      final ports = <String>[];
      final devDir = Directory('/dev');

      if (await devDir.exists()) {
        await for (final entity in devDir.list()) {
          if (entity is File) {
            final name = entity.path;
            if (name.contains('ttyUSB') ||
                name.contains('ttyACM') ||
                name.contains('cu.usb')) {
              ports.add(name);
            }
          }
        }
      }

      return ports.isEmpty ? DisplayPlatform.defaultPorts : ports;
    }

    return DisplayPlatform.defaultPorts;
  }
}

class _FileSerialPortDisplay implements SerialPortDisplay {
  _FileSerialPortDisplay({
    required this.port,
    required this.baudRate,
    required this.dataBits,
    required this.stopBits,
    required this.parity,
  });

  final String port;
  final int baudRate;
  final int dataBits;
  final int stopBits;
  final int parity;

  RandomAccessFile? _file;
  bool _isOpen = false;

  @override
  String get portName => port;

  @override
  bool get isOpen => _isOpen;

  @override
  Future<bool> open() async {
    if (_isOpen) return true;

    try {
      final path = Platform.isWindows ? '\\\\.\\$port' : port;
      _file = await File(path).open(mode: FileMode.write);
      _isOpen = true;
      return true;
    } catch (e) {
      _isOpen = false;
      return false;
    }
  }

  @override
  Future<void> close() async {
    if (_file != null) {
      try {
        await _file!.close();
      } catch (_) {}
      _file = null;
    }
    _isOpen = false;
  }

  @override
  Future<void> write(List<int> data) async {
    if (!_isOpen || _file == null) return;

    try {
      await _file!.writeFrom(Uint8List.fromList(data));
      await _file!.flush();
    } catch (e) {
      _isOpen = false;
    }
  }
}

class _DummySerialPortDisplay implements SerialPortDisplay {
  _DummySerialPortDisplay(this._port);

  final String _port;

  @override
  String get portName => _port;

  @override
  bool get isOpen => false;

  @override
  Future<bool> open() async => false;

  @override
  Future<void> close() async {}

  @override
  Future<void> write(List<int> data) async {}
}

class SerialPortConfig {
  const SerialPortConfig({
    required this.port,
    this.baudRate = 9600,
    this.dataBits = 8,
    this.stopBits = 1,
    this.parity = SerialParity.none,
  });

  final String port;
  final int baudRate;
  final int dataBits;
  final int stopBits;
  final SerialParity parity;

  static SerialPortConfig get defaultConfig {
    return SerialPortConfig(port: DisplayPlatform.defaultPort ?? 'COM2');
  }

  SerialPortConfig copyWith({
    String? port,
    int? baudRate,
    int? dataBits,
    int? stopBits,
    SerialParity? parity,
  }) {
    return SerialPortConfig(
      port: port ?? this.port,
      baudRate: baudRate ?? this.baudRate,
      dataBits: dataBits ?? this.dataBits,
      stopBits: stopBits ?? this.stopBits,
      parity: parity ?? this.parity,
    );
  }
}

enum SerialParity {
  none(0),
  odd(1),
  even(2),
  mark(3),
  space(4);

  const SerialParity(this.value);
  final int value;
}

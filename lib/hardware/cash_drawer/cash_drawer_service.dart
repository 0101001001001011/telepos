import 'dart:typed_data';

import 'package:flutter_libserialport/flutter_libserialport.dart';
import 'package:talker/talker.dart';

class CashDrawerService {
  CashDrawerService({
    Talker? logger,
    this.mode = CashDrawerMode.viaPrinter,
    this.serialPort,
  }) : _logger = logger,
       _isDummy = false;

  factory CashDrawerService.dummy() {
    return CashDrawerService._dummy();
  }

  CashDrawerService._dummy()
    : _logger = null,
      mode = CashDrawerMode.viaPrinter,
      serialPort = null,
      _isDummy = true;

  final Talker? _logger;
  final CashDrawerMode mode;
  final String? serialPort;
  final bool _isDummy;

  static const List<int> openDrawerCommand = [0x1B, 0x70, 0x00, 0x20, 0xA0];

  static const List<int> openDrawerPin5Command = [0x1B, 0x70, 0x01, 0x20, 0xA0];

  bool? _isOpen;
  bool? get isOpen => _isOpen;

  Future<CashDrawerResult> open({
    Future<void> Function(List<int> data)? viaPrinter,
    int pin = 2,
  }) async {
    if (_isDummy) {
      return CashDrawerResult.notSupported();
    }

    _logger?.info('Opening cash drawer (mode: $mode, pin: $pin)');

    try {
      switch (mode) {
        case CashDrawerMode.viaPrinter:
          if (viaPrinter == null) {
            return CashDrawerResult.error('Принтер не подключен');
          }
          final command = pin == 2 ? openDrawerCommand : openDrawerPin5Command;
          await viaPrinter(command);
          break;

        case CashDrawerMode.serialPort:
          await _openViaSerialPort(pin);
          break;
      }

      _isOpen = true;
      _logger?.info('Cash drawer opened');
      return CashDrawerResult.success();
    } catch (e) {
      _logger?.error('Failed to open cash drawer: $e');
      return CashDrawerResult.error('Ошибка открытия ящика: $e');
    }
  }

  Future<void> _openViaSerialPort(int pin) async {
    if (serialPort == null || serialPort!.isEmpty) {
      throw Exception('Serial port не указан');
    }

    SerialPort? port;
    try {
      port = SerialPort(serialPort!);

      if (!port.openReadWrite()) {
        final err = SerialPort.lastError?.message ?? 'Unknown error';
        throw Exception('Не удалось открыть порт ${serialPort!}: $err');
      }

      final config = port.config;
      config.baudRate = 9600;
      config.bits = 8;
      config.stopBits = 1;
      config.parity = SerialPortParity.none;
      port.config = config;

      final command = pin == 2 ? openDrawerCommand : openDrawerPin5Command;
      final data = Uint8List.fromList(command);
      final bytesWritten = port.write(data);

      if (bytesWritten < 0) {
        final err = SerialPort.lastError?.message ?? 'Write failed';
        throw Exception('Ошибка отправки команды: $err');
      }

      _logger?.info('Cash drawer command sent ($bytesWritten bytes)');

      await Future.delayed(const Duration(milliseconds: 100));
    } finally {
      try {
        if (port != null) {
          if (port.isOpen) {
            port.close();
          }
          port.dispose();
        }
      } catch (_) {}
    }
  }

  Future<bool?> checkStatus() async {
    if (_isDummy) return null;

    return _isOpen;
  }
}

enum CashDrawerMode { viaPrinter, serialPort }

class CashDrawerResult {
  const CashDrawerResult._({
    required this.success,
    this.errorMessage,
    this.notSupported = false,
  });

  final bool success;
  final String? errorMessage;
  final bool notSupported;

  factory CashDrawerResult.success() => const CashDrawerResult._(success: true);

  factory CashDrawerResult.error(String message) =>
      CashDrawerResult._(success: false, errorMessage: message);

  factory CashDrawerResult.notSupported() => const CashDrawerResult._(
    success: false,
    notSupported: true,
    errorMessage: 'Денежный ящик не поддерживается на этой платформе',
  );

  @override
  String toString() {
    if (success) return 'CashDrawerResult.success';
    if (notSupported) return 'CashDrawerResult.notSupported';
    return 'CashDrawerResult.error($errorMessage)';
  }
}

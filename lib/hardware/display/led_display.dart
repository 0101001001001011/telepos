import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:decimal/decimal.dart';
import 'package:telepos/hardware/display/customer_display_manager.dart';

class LedDisplayManager extends BaseDisplayManager {
  LedDisplayManager(super.config);

  RandomAccessFile? _file;
  bool _connected = false;

  @override
  bool get isConnected => _connected;

  @override
  Future<bool> connect() async {
    if (_connected) return true;

    final port = config.port;
    if (port == null || port.isEmpty) {
      return false;
    }

    try {
      _file = await File(port).open(mode: FileMode.write);
      _connected = true;

      await clear();
      await showWelcome();

      return true;
    } catch (e) {
      _connected = false;
      return false;
    }
  }

  @override
  Future<void> disconnect() async {
    if (_file != null) {
      try {
        await clear();
        await _file!.close();
      } catch (_) {}
      _file = null;
    }
    _connected = false;
  }

  @override
  Future<void> clear() async {
    await _write([0x0C]);
  }

  @override
  Future<void> showPrice(Decimal price) async {
    final formatted = formatAmount(price);
    await _writeText(formatted);
  }

  @override
  Future<void> showTotal(Decimal total) async {
    final formatted = formatAmount(total);
    await _writeText(formatted);
  }

  @override
  Future<void> showText(String text) async {
    final display = fitLine(text);
    await _writeText(display);
  }

  @override
  Future<void> showWelcome() async {
    await _writeText('  HELLO ');
  }

  @override
  Future<void> showChange(Decimal change) async {
    final formatted = formatAmount(change);
    await _writeText(formatted);
  }

  Future<void> _writeText(String text) async {
    await _write([0x0C]);
    await _write(text.codeUnits);
  }

  Future<void> _write(List<int> data) async {
    if (!_connected || _file == null) return;

    try {
      await _file!.writeFrom(Uint8List.fromList(data));
      await _file!.flush();
    } catch (e) {
      _connected = false;
    }
  }
}

class LedCommands {
  LedCommands._();

  static const List<int> clear = [0x0C];

  static const List<int> newLine = [0x0D, 0x0A];

  static const int stx = 0x02;

  static const int etx = 0x03;
}

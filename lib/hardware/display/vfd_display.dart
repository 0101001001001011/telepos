import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:decimal/decimal.dart';
import 'package:telepos/hardware/display/customer_display_manager.dart';

class VfdDisplayManager extends BaseDisplayManager {
  VfdDisplayManager(super.config);

  RandomAccessFile? _file;
  bool _connected = false;

  static const int lines = 2;

  static const int charsPerLine = 20;

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

      await _init();

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

  Future<void> _init() async {
    await _write(VfdCommands.reset);
    await _write(VfdCommands.clear);
    await showWelcome();
  }

  @override
  Future<void> clear() async {
    await _write(VfdCommands.clear);
  }

  @override
  Future<void> showPrice(Decimal price) async {
    final priceStr = formatAmount(price);

    await _setCursor(0, 0);
    await _writeText(fitLine('Цена:'));

    await _setCursor(1, 0);
    await _writeText(priceStr);
  }

  @override
  Future<void> showTotal(Decimal total) async {
    final totalStr = formatAmount(total);

    await _setCursor(0, 0);
    await _writeText(fitLine('ИТОГО:'));

    await _setCursor(1, 0);
    await _writeText(totalStr);
  }

  @override
  Future<void> showText(String text) async {
    await clear();
    await _setCursor(0, 0);

    if (text.length <= charsPerLine) {
      await _writeText(centerText(text));
    } else {
      await _writeText(fitLine(text.substring(0, charsPerLine)));
      await _setCursor(1, 0);
      await _writeText(fitLine(text.substring(charsPerLine)));
    }
  }

  @override
  Future<void> showWelcome() async {
    await clear();

    await _setCursor(0, 0);
    await _writeText(centerText('Добро пожаловать!'));

    await _setCursor(1, 0);
    await _writeText(centerText('* * * * *'));
  }

  @override
  Future<void> showChange(Decimal change) async {
    final changeStr = formatAmount(change);

    await _setCursor(0, 0);
    await _writeText(fitLine('Сдача:'));

    await _setCursor(1, 0);
    await _writeText(changeStr);
  }

  Future<void> showTwoLines(String line1, String line2) async {
    await clear();

    await _setCursor(0, 0);
    await _writeText(fitLine(line1));

    await _setCursor(1, 0);
    await _writeText(fitLine(line2));
  }

  Future<void> showItem(String name, Decimal price) async {
    final priceStr = price.toStringAsFixed(2);

    final maxNameLen = charsPerLine - priceStr.length - 1;
    final displayName = name.length > maxNameLen
        ? name.substring(0, maxNameLen)
        : name;

    await _setCursor(0, 0);
    await _writeText(fitLine(displayName));

    await _setCursor(1, 0);
    await _writeText(priceStr.padLeft(charsPerLine));
  }

  Future<void> _setCursor(int line, int column) async {
    await _write([0x1B, 0x24, column, line]);
  }

  Future<void> _writeText(String text) async {
    final bytes = _encodeText(text);
    await _write(bytes);
  }

  List<int> _encodeText(String text) {
    final result = <int>[];
    for (final char in text.codeUnits) {
      if (char < 128) {
        result.add(char);
      } else if (char >= 0x410 && char <= 0x44F) {
        result.add(char - 0x410 + 0x80);
      } else if (char == 0x401) {
        result.add(0xF0);
      } else if (char == 0x451) {
        result.add(0xF1);
      } else {
        result.add(0x20);
      }
    }
    return result;
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

class VfdCommands {
  VfdCommands._();

  static const List<int> reset = [0x1B, 0x40];

  static const List<int> clear = [0x0C];

  static const List<int> home = [0x1B, 0x5B, 0x48];

  static const List<int> line1 = [0x1B, 0x24, 0x00, 0x00];

  static const List<int> line2 = [0x1B, 0x24, 0x00, 0x01];

  static const List<int> displayOn = [0x1B, 0x28];

  static const List<int> displayOff = [0x1B, 0x29];
}

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:decimal/decimal.dart';
import 'package:telepos/hardware/display/customer_display_manager.dart';
import 'package:telepos/hardware/display/display_config.dart';

class ExtendedLedDisplayManager extends BaseDisplayManager {
  ExtendedLedDisplayManager(super.config);

  RandomAccessFile? _file;
  bool _connected = false;
  Timer? _scrollTimer;
  Timer? _blinkTimer;
  bool _blinkState = true;

  LedDisplayMode mode = LedDisplayMode.display;

  int _scrollSpeed = 300;

  int _blinkSpeed = 500;

  int get scrollSpeed => _scrollSpeed;
  set scrollSpeed(int value) => _scrollSpeed = value.clamp(100, 2000);

  int get blinkSpeed => _blinkSpeed;
  set blinkSpeed(int value) => _blinkSpeed = value.clamp(100, 2000);

  @override
  bool get isConnected => _connected;

  @override
  Future<bool> connect() async {
    if (_connected) return true;

    final port = config.port;
    if (port == null || port.isEmpty) return false;

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
    stopScrolling();
    stopBlinking();

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
    stopScrolling();
    stopBlinking();
    await _write(LedExtendedCommands.clear);
  }

  @override
  Future<void> showPrice(Decimal price) async {
    stopScrolling();
    stopBlinking();
    final formatted = formatAmount(price);
    await _writeText(formatted);
  }

  @override
  Future<void> showTotal(Decimal total) async {
    stopScrolling();
    stopBlinking();
    final formatted = formatAmount(total);
    await _writeText(formatted);
  }

  @override
  Future<void> showText(String text) async {
    stopScrolling();
    stopBlinking();

    if (text.length <= lineLength) {
      await _writeText(fitLine(text));
    } else {
      startScrolling(text);
    }
  }

  @override
  Future<void> showWelcome() async {
    await _writeText('  HELLO ');
  }

  @override
  Future<void> showChange(Decimal change) async {
    stopScrolling();
    final formatted = formatAmount(change);
    startBlinking(formatted);
  }

  void startScrolling(String text) {
    stopScrolling();
    stopBlinking();

    final paddedText = '        $text        ';
    var position = 0;

    _scrollTimer = Timer.periodic(Duration(milliseconds: _scrollSpeed), (
      _,
    ) async {
      if (!_connected) {
        stopScrolling();
        return;
      }

      final frame = paddedText.substring(position, position + lineLength);
      await _writeTextDirect(frame);

      position++;
      if (position > paddedText.length - lineLength) {
        position = 0;
      }
    });
  }

  void stopScrolling() {
    _scrollTimer?.cancel();
    _scrollTimer = null;
  }

  bool get isScrolling => _scrollTimer != null;

  void startBlinking(String text) {
    stopScrolling();
    stopBlinking();

    _blinkState = true;
    final displayText = fitLine(text);
    final blankText = ' ' * lineLength;

    _blinkTimer = Timer.periodic(Duration(milliseconds: _blinkSpeed), (
      _,
    ) async {
      if (!_connected) {
        stopBlinking();
        return;
      }

      await _writeTextDirect(_blinkState ? displayText : blankText);
      _blinkState = !_blinkState;
    });
  }

  void stopBlinking() {
    _blinkTimer?.cancel();
    _blinkTimer = null;
  }

  bool get isBlinking => _blinkTimer != null;

  void setDisplayMode() {
    mode = LedDisplayMode.display;
  }

  void setPrinterMode() {
    mode = LedDisplayMode.printer;
  }

  Future<void> printLine(String text) async {
    if (mode != LedDisplayMode.printer) return;

    final line = fitLine(text);
    await _write(Cp866Encoder.encode(line));
    await _write(LedExtendedCommands.newLine);
  }

  Future<void> _writeText(String text) async {
    await _write(LedExtendedCommands.clear);
    await _write(Cp866Encoder.encode(text));
  }

  Future<void> _writeTextDirect(String text) async {
    await _write(LedExtendedCommands.cursorHome);
    await _write(Cp866Encoder.encode(text));
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

enum LedDisplayMode { display, printer }

class LedExtendedCommands {
  LedExtendedCommands._();

  static const List<int> clear = [0x0C];

  static const List<int> newLine = [0x0D, 0x0A];

  static const List<int> cursorHome = [0x0B];

  static const List<int> displayOn = [0x14];

  static const List<int> displayOff = [0x15];

  static List<int> setBrightness(int level) {
    return [0x1B, 0x2A, level.clamp(0, 7)];
  }
}

class Cp866Encoder {
  Cp866Encoder._();

  static List<int> encode(String text) {
    final result = <int>[];
    for (final char in text.codeUnits) {
      result.add(_encodeChar(char));
    }
    return result;
  }

  static int _encodeChar(int char) {
    if (char < 128) {
      return char;
    }

    if (char >= 0x410 && char <= 0x42F) {
      return char - 0x410 + 0x80;
    }

    if (char >= 0x430 && char <= 0x43F) {
      return char - 0x430 + 0xA0;
    }

    if (char >= 0x440 && char <= 0x44F) {
      return char - 0x440 + 0xE0;
    }

    if (char == 0x401) {
      return 0xF0;
    }

    if (char == 0x451) {
      return 0xF1;
    }

    return 0x20;
  }

  static String decode(List<int> bytes) {
    final buffer = StringBuffer();
    for (final byte in bytes) {
      buffer.writeCharCode(_decodeChar(byte));
    }
    return buffer.toString();
  }

  static int _decodeChar(int byte) {
    if (byte < 128) {
      return byte;
    }

    if (byte >= 0x80 && byte <= 0x9F) {
      return byte - 0x80 + 0x410;
    }

    if (byte >= 0xA0 && byte <= 0xAF) {
      return byte - 0xA0 + 0x430;
    }

    if (byte >= 0xE0 && byte <= 0xEF) {
      return byte - 0xE0 + 0x440;
    }

    if (byte == 0xF0) {
      return 0x401;
    }

    if (byte == 0xF1) {
      return 0x451;
    }

    return 0x20;
  }
}

class ExtendedLedDisplayFactory {
  ExtendedLedDisplayFactory._();

  static ExtendedLedDisplayManager createDefault() {
    return ExtendedLedDisplayManager(
      CustomerDisplayConfig(
        enabled: true,
        model: DisplayModel.led8,
        port: Platform.isWindows ? 'COM2' : '/dev/ttyUSB0',
        baudRate: 9600,
      ),
    );
  }

  static ExtendedLedDisplayManager create({
    required String port,
    int baudRate = 9600,
  }) {
    return ExtendedLedDisplayManager(
      CustomerDisplayConfig(
        enabled: true,
        model: DisplayModel.led8,
        port: port,
        baudRate: baudRate,
      ),
    );
  }
}

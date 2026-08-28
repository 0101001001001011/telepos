import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:decimal/decimal.dart';
import 'package:telepos/hardware/display/customer_display_manager.dart';
import 'package:telepos/hardware/display/display_config.dart';
import 'package:telepos/hardware/display/led_display_extended.dart';

class ExtendedVfdDisplayManager extends BaseDisplayManager {
  ExtendedVfdDisplayManager(super.config);

  RandomAccessFile? _file;
  bool _connected = false;
  Timer? _autoClearTimer;
  Timer? _greetingTimer;

  int greetingDuration = 6000;

  int autoClearDelay = 6000;

  String currency = '₸';

  static const int lines = 2;

  static const int charsPerLine = 20;

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

      await _init();
      return true;
    } catch (e) {
      _connected = false;
      return false;
    }
  }

  @override
  Future<void> disconnect() async {
    _cancelTimers();

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
    await _write(VfdExtendedCommands.reset);
    await _write(VfdExtendedCommands.clear);
    await showWelcome();
  }

  @override
  Future<void> clear() async {
    _cancelTimers();
    await _write(VfdExtendedCommands.clear);
  }

  @override
  Future<void> showPrice(Decimal price) async {
    _cancelTimers();
    await _showTwoLines('Цена:', _formatPrice(price));
    _startAutoClearTimer();
  }

  @override
  Future<void> showTotal(Decimal total) async {
    _cancelTimers();
    await _showTwoLines('ИТОГО:', _formatPrice(total));
    _startAutoClearTimer();
  }

  @override
  Future<void> showText(String text) async {
    _cancelTimers();

    if (text.length <= charsPerLine) {
      await _showTwoLines(_centerText(text), '');
    } else {
      await _showTwoLines(
        _fitLine(text.substring(0, charsPerLine)),
        _fitLine(
          text.length > charsPerLine ? text.substring(charsPerLine) : '',
        ),
      );
    }
    _startAutoClearTimer();
  }

  @override
  Future<void> showWelcome() async {
    _cancelTimers();
    await _showTwoLines(
      _centerText('Добро пожаловать!'),
      _centerText('* * * * *'),
    );
  }

  @override
  Future<void> showChange(Decimal change) async {
    _cancelTimers();
    await _showTwoLines('Сдача:', _formatPrice(change));
    _startAutoClearTimer();
  }

  Future<void> showItem({
    required String name,
    required Decimal price,
    required Decimal quantity,
  }) async {
    _cancelTimers();

    final total = price * quantity;
    final priceStr = price.toStringAsFixed(2);
    final qtyStr = quantity.toStringAsFixed(0);
    final totalStr = total.toStringAsFixed(2);

    final line2 = '$priceStr x $qtyStr = $totalStr';

    await _showTwoLines(_fitLine(name), _fitLine(line2));
    _startAutoClearTimer();
  }

  Future<void> showTotalWithCurrency(Decimal total) async {
    _cancelTimers();

    final totalStr = '${total.toStringAsFixed(2)} $currency';
    await _showTwoLines('ИТОГО:', totalStr.padLeft(charsPerLine));
    _startAutoClearTimer();
  }

  Future<void> showThankYou() async {
    _cancelTimers();
    await _showTwoLines(_centerText('Спасибо'), _centerText('за покупку!'));
    _startGreetingTimer();
  }

  Future<void> showComeAgain() async {
    _cancelTimers();
    await _showTwoLines(_centerText('Приходите'), _centerText('ещё!'));
    _startGreetingTimer();
  }

  Future<void> showGratitudeSequence() async {
    await showThankYou();

    _greetingTimer = Timer(Duration(milliseconds: greetingDuration), () async {
      await showComeAgain();

      _greetingTimer = Timer(
        Duration(milliseconds: greetingDuration),
        () async {
          await showWelcome();
        },
      );
    });
  }

  Future<void> showPayment({
    required Decimal total,
    required Decimal paid,
    required Decimal change,
  }) async {
    _cancelTimers();

    await showTotalWithCurrency(total);

    if (change > Decimal.zero) {
      _greetingTimer = Timer(const Duration(seconds: 2), () async {
        await _showTwoLines(
          'Получено: ${paid.toStringAsFixed(2)}',
          'Сдача: ${change.toStringAsFixed(2)} $currency',
        );

        _greetingTimer = Timer(const Duration(seconds: 3), () async {
          await showGratitudeSequence();
        });
      });
    } else {
      _greetingTimer = Timer(const Duration(seconds: 2), () async {
        await showGratitudeSequence();
      });
    }
  }

  String _formatPrice(Decimal price) {
    return '${price.toStringAsFixed(2)} $currency'.padLeft(charsPerLine);
  }

  String _fitLine(String text) {
    if (text.length > charsPerLine) {
      return text.substring(0, charsPerLine);
    }
    return text.padRight(charsPerLine);
  }

  String _centerText(String text) {
    if (text.length >= charsPerLine) {
      return text.substring(0, charsPerLine);
    }
    final padding = (charsPerLine - text.length) ~/ 2;
    return text.padLeft(padding + text.length).padRight(charsPerLine);
  }

  Future<void> _showTwoLines(String line1, String line2) async {
    await _write(VfdExtendedCommands.clear);

    await _setCursor(0, 0);
    await _writeText(line1);

    await _setCursor(1, 0);
    await _writeText(line2);
  }

  Future<void> _setCursor(int line, int column) async {
    await _write([0x1B, 0x24, column, line]);
  }

  Future<void> _writeText(String text) async {
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

  void _startAutoClearTimer() {
    _autoClearTimer?.cancel();
    _autoClearTimer = Timer(Duration(milliseconds: autoClearDelay), () async {
      await showWelcome();
    });
  }

  void _startGreetingTimer() {
    _greetingTimer?.cancel();
    _greetingTimer = Timer(Duration(milliseconds: greetingDuration), () async {
      await showWelcome();
    });
  }

  void _cancelTimers() {
    _autoClearTimer?.cancel();
    _autoClearTimer = null;
    _greetingTimer?.cancel();
    _greetingTimer = null;
  }
}

class VfdExtendedCommands {
  VfdExtendedCommands._();

  static const List<int> reset = [0x1B, 0x40];

  static const List<int> clear = [0x0C];

  static const List<int> home = [0x1B, 0x5B, 0x48];

  static const List<int> displayOn = [0x1B, 0x28];

  static const List<int> displayOff = [0x1B, 0x29];

  static List<int> setBrightness(int level) {
    return [0x1B, 0x2A, level.clamp(0, 7)];
  }

  static const List<int> blink = [0x1B, 0x25];
}

class ExtendedVfdDisplayFactory {
  ExtendedVfdDisplayFactory._();

  static ExtendedVfdDisplayManager createDefault() {
    return ExtendedVfdDisplayManager(
      CustomerDisplayConfig(
        enabled: true,
        model: DisplayModel.vfd20,
        port: Platform.isWindows ? 'COM2' : '/dev/ttyUSB0',
        baudRate: 9600,
      ),
    );
  }

  static ExtendedVfdDisplayManager create({
    required String port,
    int baudRate = 9600,
    String currency = '₸',
  }) {
    final display = ExtendedVfdDisplayManager(
      CustomerDisplayConfig(
        enabled: true,
        model: DisplayModel.vfd20,
        port: port,
        baudRate: baudRate,
      ),
    );
    display.currency = currency;
    return display;
  }
}

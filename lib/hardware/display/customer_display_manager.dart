import 'dart:async';
import 'dart:io';

import 'package:decimal/decimal.dart';
import 'package:telepos/hardware/display/display_config.dart';
import 'package:telepos/hardware/display/led_display.dart';
import 'package:telepos/hardware/display/vfd_display.dart';

abstract class CustomerDisplayManager {
  CustomerDisplayConfig get config;

  bool get isConnected;

  Future<bool> connect();

  Future<void> disconnect();

  Future<void> clear();

  Future<void> showPrice(Decimal price);

  Future<void> showTotal(Decimal total);

  Future<void> showText(String text);

  Future<void> showWelcome();

  Future<void> showChange(Decimal change);

  factory CustomerDisplayManager.create(CustomerDisplayConfig config) {
    if (!_isPlatformSupported()) {
      return _DummyDisplayManager(config);
    }

    switch (config.model) {
      case DisplayModel.led8:
        return LedDisplayManager(config);
      case DisplayModel.vfd20:
        return VfdDisplayManager(config);
    }
  }

  static bool _isPlatformSupported() {
    return Platform.isWindows || Platform.isLinux || Platform.isMacOS;
  }

  static bool get isSupported => _isPlatformSupported();
}

class _DummyDisplayManager implements CustomerDisplayManager {
  _DummyDisplayManager(this._config);

  final CustomerDisplayConfig _config;

  @override
  CustomerDisplayConfig get config => _config;

  @override
  bool get isConnected => false;

  @override
  Future<bool> connect() async => false;

  @override
  Future<void> disconnect() async {}

  @override
  Future<void> clear() async {}

  @override
  Future<void> showPrice(Decimal price) async {}

  @override
  Future<void> showTotal(Decimal total) async {}

  @override
  Future<void> showText(String text) async {}

  @override
  Future<void> showWelcome() async {}

  @override
  Future<void> showChange(Decimal change) async {}
}

abstract class BaseDisplayManager implements CustomerDisplayManager {
  BaseDisplayManager(this._config);

  final CustomerDisplayConfig _config;

  @override
  CustomerDisplayConfig get config => _config;

  int get lineLength => _config.model.chars;

  String formatAmount(Decimal amount) {
    final str = amount.toStringAsFixed(2);
    if (str.length > lineLength) {
      return str.substring(str.length - lineLength);
    }
    return str.padLeft(lineLength);
  }

  String fitLine(String text) {
    if (text.length > lineLength) {
      return text.substring(0, lineLength);
    }
    return text.padRight(lineLength);
  }

  String centerText(String text) {
    if (text.length >= lineLength) {
      return text.substring(0, lineLength);
    }
    final padding = (lineLength - text.length) ~/ 2;
    return text.padLeft(padding + text.length).padRight(lineLength);
  }
}

abstract class SerialPortWriter {
  Future<void> write(List<int> data);
  Future<void> close();
}

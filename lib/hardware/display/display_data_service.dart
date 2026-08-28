import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:telepos/hardware/display/customer_display_manager.dart';
import 'package:telepos/hardware/display/display_config.dart';
import 'package:telepos/hardware/display/display_platform.dart';
import 'package:telepos/hardware/display/led_display_extended.dart';
import 'package:telepos/hardware/display/vfd_display_extended.dart';

class DisplayDataService {
  DisplayDataService({CustomerDisplayConfig? config})
    : _config = config ?? CustomerDisplayConfig();

  CustomerDisplayConfig _config;
  CustomerDisplayManager? _display;
  bool _initialized = false;

  CustomerDisplayConfig get config => _config;

  bool get isInitialized => _initialized;

  bool get isConnected => _display?.isConnected ?? false;

  bool get isSupported => DisplayPlatform.isSupported;

  Future<bool> initialize([CustomerDisplayConfig? config]) async {
    if (!isSupported) {
      return false;
    }

    if (config != null) {
      _config = config;
    }

    if (!_config.enabled) {
      return false;
    }

    _display = _createDisplay(_config);
    _initialized = true;

    return connect();
  }

  Future<bool> connect() async {
    if (!_initialized || _display == null) {
      return false;
    }

    return _display!.connect();
  }

  Future<void> disconnect() async {
    await _display?.disconnect();
  }

  Future<void> updateConfig(CustomerDisplayConfig config) async {
    await disconnect();
    _config = config;
    _display = _createDisplay(_config);
    if (_config.enabled) {
      await connect();
    }
  }

  Future<void> showItemAdded({
    required String name,
    required Decimal price,
    required Decimal quantity,
  }) async {
    if (!isConnected) return;

    if (_display is ExtendedVfdDisplayManager) {
      await (_display as ExtendedVfdDisplayManager).showItem(
        name: name,
        price: price,
        quantity: quantity,
      );
    } else {
      final total = price * quantity;
      await _display!.showPrice(total);
    }
  }

  Future<void> showQuantityChanged({
    required String name,
    required Decimal price,
    required Decimal newQuantity,
  }) async {
    await showItemAdded(name: name, price: price, quantity: newQuantity);
  }

  Future<void> showSubtotal(Decimal subtotal) async {
    if (!isConnected) return;
    await _display!.showPrice(subtotal);
  }

  Future<void> showTotal(Decimal total) async {
    if (!isConnected) return;

    if (_display is ExtendedVfdDisplayManager) {
      await (_display as ExtendedVfdDisplayManager).showTotalWithCurrency(
        total,
      );
    } else {
      await _display!.showTotal(total);
    }
  }

  Future<void> showPayment({
    required Decimal total,
    required Decimal paid,
    required Decimal change,
  }) async {
    if (!isConnected) return;

    if (_display is ExtendedVfdDisplayManager) {
      await (_display as ExtendedVfdDisplayManager).showPayment(
        total: total,
        paid: paid,
        change: change,
      );
    } else {
      if (change > Decimal.zero) {
        await _display!.showChange(change);
      } else {
        await _display!.showTotal(total);
      }
    }
  }

  Future<void> showChange(Decimal change) async {
    if (!isConnected) return;
    await _display!.showChange(change);
  }

  Future<void> showThankYou() async {
    if (!isConnected) return;

    if (_display is ExtendedVfdDisplayManager) {
      await (_display as ExtendedVfdDisplayManager).showGratitudeSequence();
    } else if (_display is ExtendedLedDisplayManager) {
      (_display as ExtendedLedDisplayManager).startBlinking(' THANKS ');
      await Future.delayed(const Duration(seconds: 3));
      (_display as ExtendedLedDisplayManager).stopBlinking();
      await _display!.showWelcome();
    } else {
      await _display!.showWelcome();
    }
  }

  Future<void> showWelcome() async {
    if (!isConnected) return;
    await _display!.showWelcome();
  }

  Future<void> clear() async {
    if (!isConnected) return;
    await _display!.clear();
  }

  Future<void> showText(String text) async {
    if (!isConnected) return;
    await _display!.showText(text);
  }

  CustomerDisplayManager _createDisplay(CustomerDisplayConfig config) {
    switch (config.model) {
      case DisplayModel.led8:
        return ExtendedLedDisplayManager(config);
      case DisplayModel.vfd20:
        return ExtendedVfdDisplayManager(config);
    }
  }

  Future<void> dispose() async {
    await disconnect();
    _display = null;
    _initialized = false;
  }
}

class DisplayDataServiceBuilder {
  DisplayDataServiceBuilder();

  bool _enabled = true;
  DisplayModel _model = DisplayModel.vfd20;
  String? _port;
  int _baudRate = 9600;

  DisplayDataServiceBuilder enabled(bool value) {
    _enabled = value;
    return this;
  }

  DisplayDataServiceBuilder model(DisplayModel value) {
    _model = value;
    return this;
  }

  DisplayDataServiceBuilder port(String value) {
    _port = value;
    return this;
  }

  DisplayDataServiceBuilder baudRate(int value) {
    _baudRate = value;
    return this;
  }

  DisplayDataService build() {
    final config = CustomerDisplayConfig(
      enabled: _enabled,
      model: _model,
      port: _port ?? DisplayPlatform.defaultPort,
      baudRate: _baudRate,
    );
    return DisplayDataService(config: config);
  }

  Future<DisplayDataService> buildAndInit() async {
    final service = build();
    await service.initialize();
    return service;
  }
}

extension DisplayDataServiceExtension on CustomerDisplayConfig {
  DisplayDataService toService() => DisplayDataService(config: this);

  Future<DisplayDataService> toInitializedService() async {
    final service = toService();
    await service.initialize();
    return service;
  }
}

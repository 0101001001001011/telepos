import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:get_it/get_it.dart';
import 'package:telepos/hardware/display/customer_display_manager.dart';
import 'package:telepos/hardware/label_printer/label_printer_service.dart';
import 'package:telepos/hardware/scales/scales_service.dart';

class SaleHardware {
  SaleHardware({
    CustomerDisplayManager? display,
    ScalesService? scales,
    LabelPrinterService? labelPrinter,
  }) : _display = display ?? _tryResolve<CustomerDisplayManager>(),
       _scales = scales ?? _tryResolve<ScalesService>(),
       _labelPrinter = labelPrinter ?? _tryResolve<LabelPrinterService>();

  final CustomerDisplayManager? _display;
  final ScalesService? _scales;
  final LabelPrinterService? _labelPrinter;

  bool _displayConnectTried = false;

  static T? _tryResolve<T extends Object>() {
    try {
      if (GetIt.I.isRegistered<T>()) return GetIt.I<T>();
    } catch (_) {}
    return null;
  }

  Future<void> showTotalOnDisplay(Decimal total) async {
    final display = _display;
    if (display == null) return;
    try {
      if (!display.isConnected) {
        if (_displayConnectTried) return;
        _displayConnectTried = true;
        final ok = await display.connect();
        if (!ok) return;
      }
      await display.showTotal(total);
    } catch (_) {}
  }

  Future<void> showWelcomeOnDisplay() async {
    final display = _display;
    if (display == null) return;
    try {
      if (!display.isConnected) {
        if (_displayConnectTried) return;
        _displayConnectTried = true;
        final ok = await display.connect();
        if (!ok) return;
      }
      await display.showWelcome();
    } catch (_) {}
  }

  Future<void> disposeDisplay() async {
    final display = _display;
    if (display == null) return;
    try {
      if (display.isConnected) await display.disconnect();
    } catch (_) {}
  }

  bool get isScalesConfigured =>
      _scales != null && (_scales.port?.isNotEmpty ?? false);

  Future<Decimal?> readWeightKg({
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final scales = _scales;
    if (scales == null) return null;
    if (!(scales.port?.isNotEmpty ?? false)) return null;

    try {
      if (!scales.isConnected) {
        final res = await scales.connect();
        if (!res.success) return null;
      }
      final reading = await scales.requestWeight(timeout: timeout);
      if (reading.hasError) return null;
      if (reading.weight <= Decimal.zero) return null;
      return reading.weightKg;
    } catch (_) {
      return null;
    }
  }

  bool get isLabelPrinterConfigured =>
      _labelPrinter != null && (_labelPrinter.host?.isNotEmpty ?? false);

  Future<String?> printPriceLabel({
    required String productName,
    required String barcode,
    required Decimal price,
    int copies = 1,
  }) async {
    final printer = _labelPrinter;
    if (printer == null || !(printer.host?.isNotEmpty ?? false)) {
      return 'Принтер этикеток не настроен';
    }
    try {
      final result = await printer.printPriceLabel(
        productName: productName,
        barcode: barcode,
        price: price,
        copies: copies,
      );
      if (result.success) return null;
      return result.errorMessage ?? 'Ошибка печати этикетки';
    } catch (e) {
      return 'Ошибка печати этикетки: $e';
    }
  }
}

import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:get_it/get_it.dart';
import 'package:telepos/hardware/display/customer_display_manager.dart';
import 'package:telepos/hardware/label_printer/label_printer_service.dart';
import 'package:telepos/hardware/scales/scales_service.dart';
import 'package:telepos/l10n/app_localizations.dart';

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

  /// Напечатать ценник; возвращает текст отказа или `null`.
  ///
  /// Словарь — доводом: у службы железа контекста нет, а отказ читает
  /// кассир. До 2026-09-22 три ответа были русскими строками.
  Future<String?> printPriceLabel({
    required String productName,
    required String barcode,
    required Decimal price,
    required AppLocalizations l10n,
    int copies = 1,
  }) async {
    final printer = _labelPrinter;
    if (printer == null || !(printer.host?.isNotEmpty ?? false)) {
      return l10n.labelPrinterNotConfigured;
    }
    try {
      final result = await printer.printPriceLabel(
        productName: productName,
        barcode: barcode,
        price: price,
        copies: copies,
      );
      if (result.success) return null;
      return result.errorMessage ?? l10n.labelPrintFailed;
    } catch (e) {
      return '${l10n.labelPrintFailed}: $e';
    }
  }
}

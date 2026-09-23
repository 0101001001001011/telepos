import 'package:decimal/decimal.dart';
import 'package:telepos/l10n/app_localizations.dart';

/// Браузерная половина шва — см. докстринг `sale_hardware.dart`.
///
/// Дисплея покупателя, весов и принтера этикеток у планшета нет. Это
/// **граница спеки** (шаг 7: железо остаётся кассой), а не недоделка:
/// нативная половина ведёт себя ровно так же, когда устройство не
/// настроено, поэтому экран разницы не видит и веток «а если браузер» не
/// содержит.
///
/// Отвечать «не настроено» — не то же самое, что молчать: кнопки «Взвесить»
/// и «Этикетка» экран не показывает вовсе ([isScalesConfigured],
/// [isLabelPrinterConfigured] — оба `false`), а [printPriceLabel] возвращает
/// названную причину, если до неё всё-таки дошли.
class SaleHardware {
  SaleHardware();

  Future<void> showTotalOnDisplay(Decimal total) async {}

  Future<void> showWelcomeOnDisplay() async {}

  Future<void> disposeDisplay() async {}

  bool get isScalesConfigured => false;

  Future<Decimal?> readWeightKg({
    Duration timeout = const Duration(seconds: 10),
  }) async => null;

  bool get isLabelPrinterConfigured => false;

  Future<String?> printPriceLabel({
    required String productName,
    required String barcode,
    required Decimal price,
    required AppLocalizations l10n,
    int copies = 1,
  }) async => l10n.labelPrintFromTillOnly;
}

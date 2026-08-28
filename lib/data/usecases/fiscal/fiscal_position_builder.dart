import 'package:decimal/decimal.dart';
import 'package:telepos/domain/fiscal/fiscal_models.dart';
import 'package:telepos/domain/fiscal/fiscal_settings.dart';

class FiscalPositionBuilder {
  const FiscalPositionBuilder();

  static final Decimal _hundred = Decimal.fromInt(100);

  static Decimal vatFromGross(Decimal lineTotal, Decimal ratePercent) {
    if (ratePercent <= Decimal.zero) return Decimal.zero;
    final denominator = _hundred + ratePercent;
    final rational = (lineTotal * ratePercent) / denominator;
    return rational.toDecimal(scaleOnInfinitePrecision: 2).round(scale: 2);
  }

  FiscalPosition build({
    required String name,
    required Decimal quantity,
    required Decimal unitPrice,
    required Decimal lineTotal,
    required FiscalSettings settings,
    int? productVatRate,
    String? ntin,
    String? barcode,
    bool isMarkable = false,
    List<String> markCodes = const [],
    int? unitCode,
    Decimal? discount,
  }) {
    final tax = _buildTax(
      lineTotal: lineTotal,
      productVatRate: productVatRate,
      settings: settings,
    );

    return FiscalPosition(
      name: name,
      quantity: quantity,
      unitPrice: unitPrice,
      lineTotal: lineTotal,
      tax: tax,
      discount: discount,
      ntin: ntin,
      barcode: barcode,
      unitCode: unitCode,
      markCodes: isMarkable ? markCodes : const [],
    );
  }

  FiscalTax _buildTax({
    required Decimal lineTotal,
    required int? productVatRate,
    required FiscalSettings settings,
  }) {
    if (!settings.isVatPayer) return FiscalTax.none();

    final Decimal rate;
    if (productVatRate != null) {
      rate = Decimal.fromInt(productVatRate);
    } else {
      rate = settings.vatRatePercent;
    }

    if (rate <= Decimal.zero) {
      return FiscalTax.none();
    }

    return FiscalTax(
      mode: FiscalTaxMode.vat,
      ratePercent: rate,
      amount: vatFromGross(lineTotal, rate),
    );
  }
}

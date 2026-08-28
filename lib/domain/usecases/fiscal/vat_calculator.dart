import 'package:decimal/decimal.dart';

class VatCalculator {
  VatCalculator._();

  static const int standardRatePercent = 16;

  static final Decimal _four = Decimal.fromInt(4);
  static final Decimal _twentyNine = Decimal.fromInt(29);
  static final Decimal _hundred = Decimal.fromInt(100);
  static final Decimal _hundredSixteen = Decimal.fromInt(116);

  static Decimal extractVatFromGross(Decimal grossAmount) {
    final rational = grossAmount * _four / _twentyNine;
    return rational.toDecimal(scaleOnInfinitePrecision: 2);
  }

  static Decimal extractNetFromGross(Decimal grossAmount) {
    final vat = extractVatFromGross(grossAmount);
    return grossAmount - vat;
  }

  static Decimal addVatToNet(Decimal netAmount) {
    final rational = netAmount * _hundredSixteen / _hundred;
    return rational.toDecimal(scaleOnInfinitePrecision: 2);
  }

  static Decimal calculateVatFromNet(Decimal netAmount) {
    return (netAmount * Decimal.parse('0.16')).round(scale: 2);
  }

  static VatBreakdown breakdown(Decimal grossAmount) {
    final vat = extractVatFromGross(grossAmount);
    final net = grossAmount - vat;
    return VatBreakdown(
      netAmount: net,
      vatAmount: vat,
      grossAmount: grossAmount,
      vatRatePercent: standardRatePercent,
    );
  }

  static Decimal calculateTotalVat(List<Decimal> grossAmounts) {
    return grossAmounts.fold(
      Decimal.zero,
      (total, amount) => total + extractVatFromGross(amount),
    );
  }

  static bool isStandardRate(int ratePercent) {
    return ratePercent == standardRatePercent;
  }

  static String formatVatLine(Decimal vatAmount, {String currency = '₸'}) {
    return 'в т.ч. НДС $standardRatePercent%: ${vatAmount.toStringAsFixed(2)} $currency';
  }
}

class VatBreakdown {
  const VatBreakdown({
    required this.netAmount,
    required this.vatAmount,
    required this.grossAmount,
    required this.vatRatePercent,
  });

  final Decimal netAmount;

  final Decimal vatAmount;

  final Decimal grossAmount;

  final int vatRatePercent;

  double get effectiveRatePercent {
    if (netAmount == Decimal.zero) return 0;
    final ratioRational = vatAmount * Decimal.fromInt(100) / netAmount;
    return ratioRational.toDecimal(scaleOnInfinitePrecision: 4).toDouble();
  }

  @override
  String toString() {
    return 'VatBreakdown('
        'net: ${netAmount.toStringAsFixed(2)}, '
        'vat: ${vatAmount.toStringAsFixed(2)}, '
        'gross: ${grossAmount.toStringAsFixed(2)}, '
        'rate: $vatRatePercent%)';
  }
}

class VatCalculationException implements Exception {
  const VatCalculationException(this.message);

  final String message;

  @override
  String toString() => 'VatCalculationException: $message';
}

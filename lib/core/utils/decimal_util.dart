import 'package:decimal/decimal.dart';

import '../constants/app_constants.dart';

class DecimalUtil {
  DecimalUtil._();

  static final zero = Decimal.zero;

  static final one = Decimal.one;

  static final hundred = Decimal.fromInt(100);

  static final thousand = Decimal.fromInt(1000);

  static Decimal fromInt(int value) => Decimal.fromInt(value);

  static Decimal fromDouble(double value) =>
      Decimal.parse(value.toStringAsFixed(AppConstants.moneyScale));

  static Decimal? tryParse(String? value) {
    if (value == null || value.isEmpty) return null;
    try {
      return Decimal.parse(value.replaceAll(',', '.'));
    } catch (_) {
      return null;
    }
  }

  static Decimal parse(String? value, {Decimal? defaultValue}) =>
      tryParse(value) ?? defaultValue ?? zero;

  static Decimal round(Decimal value, {int? scale}) =>
      value.round(scale: scale ?? AppConstants.moneyScale);

  static Decimal roundPrice(Decimal value) =>
      value.round(scale: AppConstants.priceScale);

  static Decimal roundQuantity(Decimal value) =>
      value.round(scale: AppConstants.quantityScale);

  static Decimal roundPercent(Decimal value) =>
      value.round(scale: AppConstants.percentScale);

  static Decimal roundMoney(Decimal value) =>
      value.round(scale: AppConstants.moneyScale);

  static Decimal percent(Decimal amount, Decimal percent) =>
      roundMoney((amount * percent / hundred).toDecimal());

  static Decimal addPercent(Decimal amount, Decimal percent) =>
      amount + DecimalUtil.percent(amount, percent);

  static Decimal subtractPercent(Decimal amount, Decimal percent) =>
      amount - DecimalUtil.percent(amount, percent);

  static Decimal vatFromSum(Decimal sum) {
    final numerator = Decimal.fromInt(AppConstants.vatNumerator);
    final denominator = Decimal.fromInt(AppConstants.vatDenominator);
    return roundMoney((sum * numerator / denominator).toDecimal());
  }

  static Decimal addVat(Decimal sum) {
    final rate = Decimal.fromInt(100 + AppConstants.vatRate);
    return roundMoney((sum * rate / hundred).toDecimal());
  }

  static Decimal removeVat(Decimal sum) {
    final rate = Decimal.fromInt(100 + AppConstants.vatRate);
    return roundMoney((sum * hundred / rate).toDecimal());
  }

  static String formatMoney(
    Decimal value, {
    int? decimals,
    String separator = ' ',
  }) {
    final rounded = round(value, scale: decimals ?? 2);
    final parts = rounded.toString().split('.');
    final intPart = parts[0];
    final decPart = parts.length > 1 ? parts[1] : '00';

    final buffer = StringBuffer();
    for (var i = 0; i < intPart.length; i++) {
      if (i > 0 && (intPart.length - i) % 3 == 0) {
        buffer.write(separator);
      }
      buffer.write(intPart[i]);
    }

    return '${buffer.toString()}.${decPart.padRight(decimals ?? 2, '0')}';
  }

  static String formatWithCurrency(
    Decimal value, {
    String currency = 'тг',
    bool currencyAfter = true,
  }) {
    final formatted = formatMoney(value);
    return currencyAfter ? '$formatted $currency' : '$currency $formatted';
  }

  static String formatQuantity(Decimal value) {
    return roundQuantity(value).toStringAsFixed(AppConstants.quantityScale);
  }

  static String formatPercent(Decimal value, {bool showSymbol = true}) {
    final str = roundPercent(value).toString();
    return showSymbol ? '$str%' : str;
  }

  static bool isZero(Decimal value) => value == zero;

  static bool isPositive(Decimal value) => value > zero;

  static bool isNegative(Decimal value) => value < zero;

  static Decimal min(Decimal a, Decimal b) => a < b ? a : b;

  static Decimal max(Decimal a, Decimal b) => a > b ? a : b;

  static Decimal abs(Decimal value) => value.abs();

  static bool isInRange(Decimal value, {Decimal? min, Decimal? max}) {
    if (min != null && value < min) return false;
    if (max != null && value > max) return false;
    return true;
  }
}

extension DecimalExtension on Decimal {
  Decimal get money => DecimalUtil.roundMoney(this);

  Decimal get price => DecimalUtil.roundPrice(this);

  Decimal get quantity => DecimalUtil.roundQuantity(this);

  String get formatted => DecimalUtil.formatMoney(this);

  String get withCurrency => DecimalUtil.formatWithCurrency(this);

  Decimal get vat => DecimalUtil.vatFromSum(this);

  Decimal get withVat => DecimalUtil.addVat(this);

  Decimal get withoutVat => DecimalUtil.removeVat(this);
}

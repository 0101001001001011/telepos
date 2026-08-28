import 'package:telepos/core/constants/enums/currency.dart';

enum CountryCode {
  kzt(
    headerCode: '77',
    phoneMask: '+7 (7##) ### ## ##',
    currencySymbol: '₸',
    currencyName: 'Казахстанский тенге',
    currencyShort: 'KZT',
    countryName: 'Казахстан',
    countryNameEn: 'Kazakhstan',
    taxIdLabel: 'БИН/ИИН',
    taxIdHint: '123456789012',
    taxIdLength: 12,
    vatRate: 16,
    vatNumerator: 4,
    vatDenominator: 29,
    language: 'kk',
    decimalSeparator: ',',
    thousandSeparator: ' ',
    currencyAfterAmount: true,
    decimalDigits: 2,
    defaultCurrency: Currency.kzt,
  ),

  rub(
    headerCode: '7',
    phoneMask: '+7 (###) ### ## ##',
    currencySymbol: '₽',
    currencyName: 'Российский рубль',
    currencyShort: 'RUB',
    countryName: 'Россия',
    countryNameEn: 'Russia',
    taxIdLabel: 'ИНН',
    taxIdHint: '1234567890',
    taxIdLength: 10,
    vatRate: 22,
    vatNumerator: 11,
    vatDenominator: 61,
    language: 'ru',
    decimalSeparator: ',',
    thousandSeparator: ' ',
    currencyAfterAmount: true,
    decimalDigits: 2,
    defaultCurrency: Currency.rub,
  ),

  kgs(
    headerCode: '996',
    phoneMask: '+996 (###) ## ## ##',
    currencySymbol: 'сом',
    currencyName: 'Кыргызский сом',
    currencyShort: 'KGS',
    countryName: 'Кыргызстан',
    countryNameEn: 'Kyrgyzstan',
    taxIdLabel: 'ИНН',
    taxIdHint: '12345678901234',
    taxIdLength: 14,
    vatRate: 12,
    vatNumerator: 3,
    vatDenominator: 28,
    language: 'ky',
    decimalSeparator: ',',
    thousandSeparator: ' ',
    currencyAfterAmount: true,
    decimalDigits: 2,
    defaultCurrency: Currency.kgs,
  ),

  uzs(
    headerCode: '998',
    phoneMask: '+998 (##) #### ###',
    currencySymbol: 'сўм',
    currencyName: 'Узбекский сум',
    currencyShort: 'UZS',
    countryName: 'Узбекистан',
    countryNameEn: 'Uzbekistan',
    taxIdLabel: 'СТИР/ИНН',
    taxIdHint: '123456789',
    taxIdLength: 9,
    vatRate: 12,
    vatNumerator: 3,
    vatDenominator: 28,
    language: 'uz',
    decimalSeparator: ',',
    thousandSeparator: ' ',
    currencyAfterAmount: true,
    decimalDigits: 0,
    defaultCurrency: Currency.uzs,
  ),

  usd(
    headerCode: '1',
    phoneMask: '+1 (###) ### ####',
    currencySymbol: '\$',
    currencyName: 'US Dollar',
    currencyShort: 'USD',
    countryName: 'США',
    countryNameEn: 'United States',
    taxIdLabel: 'EIN/TIN',
    taxIdHint: '12-3456789',
    taxIdLength: 9,
    vatRate: 0,
    vatNumerator: 0,
    vatDenominator: 1,
    language: 'en',
    decimalSeparator: '.',
    thousandSeparator: ',',
    currencyAfterAmount: false,
    decimalDigits: 2,
    defaultCurrency: Currency.usd,
  ),

  tmt(
    headerCode: '993',
    phoneMask: '+993 (##) ## ## ##',
    currencySymbol: 'TMT',
    currencyName: 'Туркменский манат',
    currencyShort: 'TMT',
    countryName: 'Туркменистан',
    countryNameEn: 'Turkmenistan',
    taxIdLabel: 'ИНН',
    taxIdHint: '123456789012',
    taxIdLength: 12,
    vatRate: 15,
    vatNumerator: 3,
    vatDenominator: 23,
    language: 'tk',
    decimalSeparator: ',',
    thousandSeparator: ' ',
    currencyAfterAmount: true,
    decimalDigits: 2,
    defaultCurrency: Currency.tmt,
  );

  const CountryCode({
    required this.headerCode,
    required this.phoneMask,
    required this.currencySymbol,
    required this.currencyName,
    required this.currencyShort,
    required this.countryName,
    required this.countryNameEn,
    required this.taxIdLabel,
    required this.taxIdHint,
    required this.taxIdLength,
    required this.vatRate,
    required this.vatNumerator,
    required this.vatDenominator,
    required this.language,
    required this.decimalSeparator,
    required this.thousandSeparator,
    required this.currencyAfterAmount,
    required this.decimalDigits,
    required this.defaultCurrency,
  });

  final String headerCode;

  final String phoneMask;

  final String currencySymbol;

  final String currencyName;

  final String currencyShort;

  final String countryName;

  final String countryNameEn;

  final String taxIdLabel;

  final String taxIdHint;

  final int taxIdLength;

  final int vatRate;

  final int vatNumerator;

  final int vatDenominator;

  final String language;

  final String decimalSeparator;

  final String thousandSeparator;

  final bool currencyAfterAmount;

  final int decimalDigits;

  final Currency defaultCurrency;

  bool isValidTaxId(String taxId) {
    final digitsOnly = taxId.replaceAll(RegExp(r'[^0-9]'), '');
    return digitsOnly.length == taxIdLength;
  }

  String formatTaxId(String taxId) {
    final digitsOnly = taxId.replaceAll(RegExp(r'[^0-9]'), '');
    if (this == CountryCode.usd && digitsOnly.length == 9) {
      return '${digitsOnly.substring(0, 2)}-${digitsOnly.substring(2)}';
    }
    return digitsOnly;
  }

  String formatMoney(num amount, {bool showCurrency = true}) {
    final value = amount.toDouble();
    final fixed = value.toStringAsFixed(decimalDigits);
    final parts = fixed.split('.');
    final intPart = parts[0];
    final decPart = parts.length > 1 ? parts[1] : '';

    final buffer = StringBuffer();
    final isNegative = intPart.startsWith('-');
    final digits = isNegative ? intPart.substring(1) : intPart;

    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) {
        buffer.write(thousandSeparator);
      }
      buffer.write(digits[i]);
    }

    var formatted = isNegative ? '-${buffer.toString()}' : buffer.toString();

    if (decimalDigits > 0) {
      formatted =
          '$formatted$decimalSeparator${decPart.padRight(decimalDigits, '0')}';
    }

    if (!showCurrency) return formatted;

    if (currencyAfterAmount) {
      return '$formatted $currencySymbol';
    } else {
      return '$currencySymbol$formatted';
    }
  }

  String formatAmount(num amount) => formatMoney(amount, showCurrency: false);

  double calculateVatFromSum(double sum) {
    if (vatNumerator == 0 || vatDenominator == 0) return 0;
    return sum * vatNumerator / vatDenominator;
  }

  double addVat(double sum) {
    return sum * (100 + vatRate) / 100;
  }

  double removeVat(double sumWithVat) {
    if (vatRate == 0) return sumWithVat;
    return sumWithVat * 100 / (100 + vatRate);
  }
}

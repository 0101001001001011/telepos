import 'package:decimal/decimal.dart';

class AmountFormatter {
  const AmountFormatter({
    this.symbol = 'тг',
    this.symbolAfter = true,
    this.decimalDigits = 2,
    this.thousandSeparator = ' ',
    this.decimalSeparator = '.',
    this.showZeroDecimals = true,
  });

  final String symbol;

  final bool symbolAfter;

  final int decimalDigits;

  final String thousandSeparator;

  final String decimalSeparator;

  final bool showZeroDecimals;

  static const kzt = AmountFormatter(
    symbol: 'тг',
    symbolAfter: true,
    decimalDigits: 2,
  );

  static const rub = AmountFormatter(
    symbol: '₽',
    symbolAfter: true,
    decimalDigits: 2,
  );

  static const kgs = AmountFormatter(
    symbol: 'сом',
    symbolAfter: true,
    decimalDigits: 2,
  );

  static const uzs = AmountFormatter(
    symbol: 'сум',
    symbolAfter: true,
    decimalDigits: 0,
  );

  static const usd = AmountFormatter(
    symbol: '\$',
    symbolAfter: false,
    decimalDigits: 2,
    thousandSeparator: ',',
    decimalSeparator: '.',
  );

  String format(Decimal amount) {
    final rounded = amount.round(scale: decimalDigits);
    final str = rounded.toString();

    final parts = str.split('.');
    var intPart = parts[0];
    var decPart = parts.length > 1 ? parts[1] : '';

    final isNegative = intPart.startsWith('-');
    if (isNegative) intPart = intPart.substring(1);

    final buffer = StringBuffer();
    for (var i = 0; i < intPart.length; i++) {
      if (i > 0 && (intPart.length - i) % 3 == 0) {
        buffer.write(thousandSeparator);
      }
      buffer.write(intPart[i]);
    }
    intPart = buffer.toString();

    if (decimalDigits > 0) {
      decPart = decPart.padRight(decimalDigits, '0');
      if (decPart.length > decimalDigits) {
        decPart = decPart.substring(0, decimalDigits);
      }
    }

    String result;
    if (decimalDigits == 0) {
      result = intPart;
    } else if (!showZeroDecimals && decPart == '0' * decimalDigits) {
      result = intPart;
    } else {
      result = '$intPart$decimalSeparator$decPart';
    }

    if (isNegative) result = '-$result';

    if (symbol.isNotEmpty) {
      result = symbolAfter ? '$result $symbol' : '$symbol$result';
    }

    return result;
  }

  String formatInt(int amount) => format(Decimal.fromInt(amount));

  String formatDouble(double amount) =>
      format(Decimal.parse(amount.toStringAsFixed(decimalDigits)));
}

class PhoneMaskFormatter {
  const PhoneMaskFormatter({required this.mask, this.placeholder = '_'});

  final String mask;

  final String placeholder;

  static const kz = PhoneMaskFormatter(mask: '+7 (###) ###-##-##');

  static const ru = PhoneMaskFormatter(mask: '+7 (###) ###-##-##');

  static const kg = PhoneMaskFormatter(mask: '+996 (###) ###-###');

  static const uz = PhoneMaskFormatter(mask: '+998 (##) ###-##-##');

  static PhoneMaskFormatter byCountryCode(String code) {
    switch (code.toUpperCase()) {
      case 'KZ':
        return kz;
      case 'RU':
        return ru;
      case 'KG':
        return kg;
      case 'UZ':
        return uz;
      default:
        return kz;
    }
  }

  String format(String phone) {
    final digits = phone.replaceAll(RegExp(r'[^\d]'), '');

    final result = StringBuffer();
    var digitIndex = 0;

    for (var i = 0; i < mask.length; i++) {
      if (mask[i] == '#') {
        if (digitIndex < digits.length) {
          result.write(digits[digitIndex]);
          digitIndex++;
        } else {
          result.write(placeholder);
        }
      } else {
        result.write(mask[i]);
      }
    }

    return result.toString();
  }

  String unformat(String formatted) {
    return formatted.replaceAll(RegExp(r'[^\d]'), '');
  }

  bool isComplete(String phone) {
    final digits = unformat(phone);
    final requiredDigits = mask.split('').where((c) => c == '#').length;
    return digits.length == requiredDigits;
  }

  int get requiredDigits => mask.split('').where((c) => c == '#').length;
}

class IinBinFormatter {
  const IinBinFormatter({required this.length, this.separator = ' '});

  final int length;

  final String separator;

  static const kzIin = IinBinFormatter(length: 12);

  static const kzBin = IinBinFormatter(length: 12);

  static const ruInnPerson = IinBinFormatter(length: 12);

  static const ruInnCompany = IinBinFormatter(length: 10);

  String format(String number) {
    final digits = number.replaceAll(RegExp(r'[^\d]'), '');
    if (digits.isEmpty) return '';

    final buffer = StringBuffer();
    for (var i = 0; i < digits.length && i < length; i++) {
      if (i > 0 && i % 3 == 0) {
        buffer.write(separator);
      }
      buffer.write(digits[i]);
    }

    return buffer.toString();
  }

  String unformat(String formatted) {
    return formatted.replaceAll(RegExp(r'[^\d]'), '');
  }

  bool isComplete(String number) {
    final digits = unformat(number);
    return digits.length == length;
  }

  bool isValidIin(String iin) {
    final digits = unformat(iin);
    if (digits.length != 12) return false;

    final month = int.tryParse(digits.substring(2, 4)) ?? 0;
    final day = int.tryParse(digits.substring(4, 6)) ?? 0;

    if (month < 1 || month > 12) return false;
    if (day < 1 || day > 31) return false;

    final centuryGender = int.tryParse(digits[6]) ?? 0;
    if (centuryGender < 1 || centuryGender > 6) return false;

    return true;
  }
}

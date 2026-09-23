enum Currency {
  kzt(
    code: 'KZT',
    symbol: '₸',
    name: 'Казахстанский тенге',
    nameEn: 'Kazakhstani Tenge',
    decimalSeparator: ',',
    thousandSeparator: ' ',
    symbolAfterAmount: true,
    decimalDigits: 2,
    denominations: [
      20000,
      10000,
      5000,
      2000,
      1000,
      500,
      200,
      100,
      50,
      20,
      10,
      5,
      2,
      1,
    ],
  ),

  rub(
    code: 'RUB',
    symbol: '₽',
    name: 'Российский рубль',
    nameEn: 'Russian Ruble',
    decimalSeparator: ',',
    thousandSeparator: ' ',
    symbolAfterAmount: true,
    decimalDigits: 2,
    denominations: [5000, 2000, 1000, 500, 200, 100, 50, 10, 5, 2, 1],
  ),

  kgs(
    code: 'KGS',
    symbol: 'сом',
    name: 'Кыргызский сом',
    nameEn: 'Kyrgyzstani Som',
    decimalSeparator: ',',
    thousandSeparator: ' ',
    symbolAfterAmount: true,
    decimalDigits: 2,
    denominations: [5000, 2000, 1000, 500, 200, 100, 50, 20, 10, 5, 1],
  ),

  uzs(
    code: 'UZS',
    symbol: 'сўм',
    name: 'Узбекский сум',
    nameEn: 'Uzbekistani Som',
    decimalSeparator: ',',
    thousandSeparator: ' ',
    symbolAfterAmount: true,
    decimalDigits: 0,
    denominations: [
      200000,
      100000,
      50000,
      20000,
      10000,
      5000,
      2000,
      1000,
      500,
      200,
      100,
      50,
    ],
  ),

  usd(
    code: 'USD',
    symbol: '\$',
    name: 'Доллар США',
    nameEn: 'US Dollar',
    decimalSeparator: '.',
    thousandSeparator: ',',
    symbolAfterAmount: false,
    decimalDigits: 2,
    denominations: [100, 50, 20, 10, 5, 2, 1],
  ),

  tmt(
    code: 'TMT',
    symbol: 'TMT',
    name: 'Туркменский манат',
    nameEn: 'Turkmenistani Manat',
    decimalSeparator: ',',
    thousandSeparator: ' ',
    symbolAfterAmount: true,
    decimalDigits: 2,
    denominations: [500, 100, 50, 20, 10, 5, 1],
  ),

  eur(
    code: 'EUR',
    symbol: '€',
    name: 'Евро',
    nameEn: 'Euro',
    decimalSeparator: ',',
    thousandSeparator: ' ',
    symbolAfterAmount: true,
    decimalDigits: 2,
    denominations: [500, 200, 100, 50, 20, 10, 5, 2, 1],
  ),

  cny(
    code: 'CNY',
    symbol: '¥',
    name: 'Китайский юань',
    nameEn: 'Chinese Yuan',
    decimalSeparator: '.',
    thousandSeparator: ',',
    symbolAfterAmount: false,
    decimalDigits: 2,
    denominations: [100, 50, 20, 10, 5, 1],
  ),

  gbp(
    code: 'GBP',
    symbol: '£',
    name: 'Фунт стерлингов',
    nameEn: 'Pound Sterling',
    decimalSeparator: '.',
    thousandSeparator: ',',
    symbolAfterAmount: false,
    decimalDigits: 2,
    denominations: [50, 20, 10, 5, 2, 1],
  ),

  pln(
    code: 'PLN',
    symbol: 'zł',
    name: 'Польский злотый',
    nameEn: 'Polish Zloty',
    decimalSeparator: ',',
    thousandSeparator: ' ',
    symbolAfterAmount: true,
    decimalDigits: 2,
    denominations: [500, 200, 100, 50, 20, 10, 5, 2, 1],
  ),

  tryy(
    code: 'TRY',
    symbol: '₺',
    name: 'Турецкая лира',
    nameEn: 'Turkish Lira',
    decimalSeparator: ',',
    thousandSeparator: '.',
    symbolAfterAmount: true,
    decimalDigits: 2,
    denominations: [200, 100, 50, 20, 10, 5, 1],
  ),

  jpy(
    code: 'JPY',
    symbol: '¥',
    name: 'Японская иена',
    nameEn: 'Japanese Yen',
    decimalSeparator: '.',
    thousandSeparator: ',',
    symbolAfterAmount: false,
    decimalDigits: 0,
    denominations: [10000, 5000, 2000, 1000, 500, 100, 50, 10, 5, 1],
  ),

  krw(
    code: 'KRW',
    symbol: '₩',
    name: 'Южнокорейская вона',
    nameEn: 'South Korean Won',
    decimalSeparator: '.',
    thousandSeparator: ',',
    symbolAfterAmount: false,
    decimalDigits: 0,
    denominations: [50000, 10000, 5000, 1000, 500, 100, 50, 10],
  ),

  aed(
    code: 'AED',
    symbol: 'د.إ',
    name: 'Дирхам ОАЭ',
    nameEn: 'UAE Dirham',
    decimalSeparator: '.',
    thousandSeparator: ',',
    symbolAfterAmount: false,
    decimalDigits: 2,
    denominations: [1000, 500, 200, 100, 50, 20, 10, 5],
  ),

  sar(
    code: 'SAR',
    symbol: '﷼',
    name: 'Саудовский риял',
    nameEn: 'Saudi Riyal',
    decimalSeparator: '.',
    thousandSeparator: ',',
    symbolAfterAmount: false,
    decimalDigits: 2,
    denominations: [500, 100, 50, 10, 5, 1],
  ),

  inr(
    code: 'INR',
    symbol: '₹',
    name: 'Индийская рупия',
    nameEn: 'Indian Rupee',
    decimalSeparator: '.',
    thousandSeparator: ',',
    symbolAfterAmount: false,
    decimalDigits: 2,
    denominations: [500, 200, 100, 50, 20, 10, 5, 2, 1],
  ),

  cad(
    code: 'CAD',
    symbol: r'$',
    name: 'Канадский доллар',
    nameEn: 'Canadian Dollar',
    decimalSeparator: '.',
    thousandSeparator: ',',
    symbolAfterAmount: false,
    decimalDigits: 2,
    denominations: [100, 50, 20, 10, 5, 2, 1],
  ),

  aud(
    code: 'AUD',
    symbol: r'$',
    name: 'Австралийский доллар',
    nameEn: 'Australian Dollar',
    decimalSeparator: '.',
    thousandSeparator: ',',
    symbolAfterAmount: false,
    decimalDigits: 2,
    denominations: [100, 50, 20, 10, 5, 2, 1],
  );

  const Currency({
    required this.code,
    required this.symbol,
    required this.name,
    required this.nameEn,
    required this.decimalSeparator,
    required this.thousandSeparator,
    required this.symbolAfterAmount,
    required this.decimalDigits,
    required this.denominations,
  });

  final String code;

  final String symbol;

  final String name;

  final String nameEn;

  final String decimalSeparator;

  final String thousandSeparator;

  final bool symbolAfterAmount;

  final int decimalDigits;

  final List<int> denominations;

  String formatMoney(num amount, {bool showSymbol = true}) {
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

    if (!showSymbol) return formatted;

    if (symbolAfterAmount) {
      return '$formatted $symbol';
    } else {
      return '$symbol$formatted';
    }
  }

  String formatAmount(num amount) => formatMoney(amount, showSymbol: false);

  double? parseAmount(String text) {
    var cleaned = text.replaceAll(symbol, '').trim();

    cleaned = cleaned.replaceAll(thousandSeparator, '');
    cleaned = cleaned.replaceAll(decimalSeparator, '.');

    return double.tryParse(cleaned);
  }

  static Currency? fromCode(String code) {
    try {
      return Currency.values.firstWhere(
        (c) => c.code.toUpperCase() == code.toUpperCase(),
      );
    } catch (_) {
      return null;
    }
  }

  static Currency? fromIndex(int index) {
    if (index >= 0 && index < Currency.values.length) {
      return Currency.values[index];
    }
    return null;
  }
}

import 'package:decimal/decimal.dart';

abstract class DenominationService {
  List<int> getDenominations(Currency currency);

  List<int> getQuickAmounts({
    required Decimal saleAmount,
    required Currency currency,
  });

  List<int> getMobileDenominations(Currency currency, {int maxButtons = 4});

  List<int> getDesktopDenominations(Currency currency, {int maxButtons = 8});
}

enum Currency { kzt, rub, kgs, uzs, usd, tmt }

extension CurrencyExtension on Currency {
  String get code {
    switch (this) {
      case Currency.kzt:
        return 'KZT';
      case Currency.rub:
        return 'RUB';
      case Currency.kgs:
        return 'KGS';
      case Currency.uzs:
        return 'UZS';
      case Currency.usd:
        return 'USD';
      case Currency.tmt:
        return 'TMT';
    }
  }

  String get symbol {
    switch (this) {
      case Currency.kzt:
        return '₸';
      case Currency.rub:
        return '₽';
      case Currency.kgs:
        return 'с';
      case Currency.uzs:
        return 'сум';
      case Currency.usd:
        return '\$';
      case Currency.tmt:
        return 'm';
    }
  }

  static Currency? fromCode(String code) {
    switch (code.toUpperCase()) {
      case 'KZT':
        return Currency.kzt;
      case 'RUB':
        return Currency.rub;
      case 'KGS':
        return Currency.kgs;
      case 'UZS':
        return Currency.uzs;
      case 'USD':
        return Currency.usd;
      case 'TMT':
        return Currency.tmt;
      default:
        return null;
    }
  }
}

import 'package:telepos/core/constants/enums/country_code.dart';
import 'package:telepos/core/constants/enums/currency.dart';

abstract class CurrencyService {
  CountryCode get country;

  Currency get currency;

  List<Currency> get availableCurrencies;

  Future<void> load();

  Future<void> setCurrency(Currency currency);

  String formatMoney(num amount, {bool showSymbol = true});

  String formatAmount(num amount);

  double? parseAmount(String text);

  List<int> get denominations;

  String get symbol;

  String get code;

  int get vatRate;

  double calculateVatFromSum(double sum);
}

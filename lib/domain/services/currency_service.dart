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

  String get symbol;

  String get code;
}

// Здесь были `vatRate`, `calculateVatFromSum` и `denominations`. Первые два
// считали налог в `double` — прямо против правила проекта «деньги только
// Decimal», — и не были спрошены ни разу. Номиналы купюр живут у страны
// (`CountryCode.banknotes`), одним источником с 2026-09-22.

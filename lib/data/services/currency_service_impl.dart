import 'package:talker/talker.dart';

import 'package:telepos/core/constants/enums/country_code.dart';
import 'package:telepos/core/constants/enums/currency.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/domain/services/currency_service.dart';

class CurrencyServiceImpl implements CurrencyService {
  final AppDatabase _db;
  final Talker _logger;

  CountryCode _country = CountryCode.kzt;
  Currency _currency = Currency.kzt;
  bool _isLoaded = false;

  CurrencyServiceImpl({required AppDatabase db, required Talker logger})
    : _db = db,
      _logger = logger;

  @override
  CountryCode get country => _country;

  @override
  Currency get currency => _currency;

  @override
  List<Currency> get availableCurrencies => Currency.values;

  @override
  String get symbol => _currency.symbol;

  @override
  String get code => _currency.code;

  @override
  Future<void> load() async {
    if (_isLoaded) return;

    try {
      final thisPos = await _db.thisPosDao.get();

      if (thisPos != null) {
        if (thisPos.countryCode != null &&
            thisPos.countryCode! >= 0 &&
            thisPos.countryCode! < CountryCode.values.length) {
          _country = CountryCode.values[thisPos.countryCode!];
        }

        if (thisPos.currencyCode != null &&
            thisPos.currencyCode! >= 0 &&
            thisPos.currencyCode! < Currency.values.length) {
          _currency = Currency.values[thisPos.currencyCode!];
        } else {
          _currency = _country.defaultCurrency;
        }

        _logger.info(
          'CurrencyService loaded: country=${_country.countryName}, '
          'currency=${_currency.code}',
        );
      } else {
        _logger.warning('ThisPos not found, using defaults');
      }

      _isLoaded = true;
    } catch (e, st) {
      _logger.error('Failed to load currency settings', e, st);
      _country = CountryCode.kzt;
      _currency = Currency.kzt;
      _isLoaded = true;
    }
  }

  @override
  Future<void> setCurrency(Currency newCurrency) async {
    try {
      final thisPos = await _db.thisPosDao.get();
      if (thisPos != null) {
        await _db.thisPosDao.updateCurrency(
          currencyCode: newCurrency.index,
          currencySymbol: newCurrency.symbol,
          currencyNameShort: newCurrency.code,
          currencyNameLong: newCurrency.name,
        );
      }

      _currency = newCurrency;
      _logger.info('Currency changed to ${newCurrency.code}');
    } catch (e, st) {
      _logger.error('Failed to save currency', e, st);
      rethrow;
    }
  }

  @override
  String formatMoney(num amount, {bool showSymbol = true}) {
    return _currency.formatMoney(amount, showSymbol: showSymbol);
  }

  @override
  String formatAmount(num amount) {
    return _currency.formatAmount(amount);
  }

  @override
  double? parseAmount(String text) {
    return _currency.parseAmount(text);
  }
}

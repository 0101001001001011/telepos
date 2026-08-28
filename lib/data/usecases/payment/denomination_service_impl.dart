import 'package:decimal/decimal.dart';
import 'package:telepos/domain/usecases/payment/denomination_service.dart';

class DenominationServiceImpl implements DenominationService {
  static const Map<Currency, List<int>> _denominations = {
    Currency.kzt: [200, 500, 1000, 2000, 5000, 10000, 20000],

    Currency.rub: [50, 100, 200, 500, 1000, 2000, 5000],

    Currency.kgs: [20, 50, 100, 200, 500, 1000, 2000, 5000],

    Currency.uzs: [1000, 2000, 5000, 10000, 20000, 50000, 100000],

    Currency.usd: [1, 5, 10, 20, 50, 100],

    Currency.tmt: [1, 5, 10, 20, 50, 100, 500],
  };

  @override
  List<int> getDenominations(Currency currency) {
    return _denominations[currency] ?? _denominations[Currency.usd]!;
  }

  @override
  List<int> getQuickAmounts({
    required Decimal saleAmount,
    required Currency currency,
  }) {
    final denominations = getDenominations(currency);
    final amount = saleAmount.toDouble().ceil();

    final quickAmounts = <int>[];

    for (final denom in denominations) {
      if (denom >= amount) {
        quickAmounts.add(denom);
        if (quickAmounts.length >= 4) break;
      }
    }

    if (quickAmounts.isEmpty) {
      final maxDenom = denominations.last;
      var multiplier = (amount / maxDenom).ceil();
      for (var i = 0; i < 4; i++) {
        quickAmounts.add(maxDenom * multiplier);
        multiplier++;
      }
    }

    return quickAmounts;
  }

  @override
  List<int> getMobileDenominations(Currency currency, {int maxButtons = 4}) {
    final all = getDenominations(currency);
    if (all.length <= maxButtons) return all;

    final step = all.length / maxButtons;
    final result = <int>[];
    for (var i = 0; i < maxButtons; i++) {
      final index = (i * step).floor();
      if (index < all.length) {
        result.add(all[index]);
      }
    }
    return result;
  }

  @override
  List<int> getDesktopDenominations(Currency currency, {int maxButtons = 8}) {
    final all = getDenominations(currency);
    if (all.length <= maxButtons) return all;
    return all.take(maxButtons).toList();
  }
}

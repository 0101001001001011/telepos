import 'package:decimal/decimal.dart';
import 'package:telepos/domain/usecases/sale/sale_round_option_use_case.dart';

class SaleRoundOptionUseCaseImpl implements SaleRoundOptionUseCase {
  static final Decimal _five = Decimal.fromInt(5);
  static final Decimal _ten = Decimal.fromInt(10);

  @override
  Decimal roundPrice({
    required Decimal price,
    required bool isWeightProduct,
    required bool hasDiscount,
    required int weightProductRoundType,
    required int discountsRoundType,
  }) {
    var result = price;

    if (isWeightProduct) {
      result = applyRoundOption(result, weightProductRoundType);
    }

    if (hasDiscount) {
      result = applyRoundOption(result, discountsRoundType);
    }

    return result;
  }

  @override
  Decimal applyRoundOption(Decimal value, int roundOption) {
    if (roundOption == 0 || roundOption > 6) {
      return value;
    }

    final roundUp = roundOption.isOdd;

    if (roundOption <= 2) {
      return roundUp ? value.ceil() : value.floor();
    } else if (roundOption <= 4) {
      return _roundToUnit(value, _five, roundUp);
    } else {
      return _roundToUnit(value, _ten, roundUp);
    }
  }

  Decimal _roundToUnit(Decimal value, Decimal unit, bool roundUp) {
    final divided = (value / unit).toDecimal(scaleOnInfinitePrecision: 10);
    final rounded = roundUp ? divided.ceil() : divided.floor();
    return rounded * unit;
  }
}

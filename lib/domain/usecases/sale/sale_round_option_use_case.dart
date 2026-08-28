import 'package:decimal/decimal.dart';

abstract class SaleRoundOptionUseCase {
  Decimal roundPrice({
    required Decimal price,
    required bool isWeightProduct,
    required bool hasDiscount,
    required int weightProductRoundType,
    required int discountsRoundType,
  });

  Decimal applyRoundOption(Decimal value, int roundOption);
}

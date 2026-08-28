import 'package:decimal/decimal.dart';

class DishIngredientEntity {
  DishIngredientEntity({
    this.id,
    required this.dishUcode,
    required this.ingredientUcode,
    required this.grossQuantity,
    required this.netQuantity,
    Decimal? coldLossPercent,
    Decimal? hotLossPercent,
    this.sortOrder = 0,
    this.ingredientName,
    this.purchasePrice,
    this.ingredientMeasure,
    this.calories,
    this.proteins,
    this.fats,
    this.carbs,
    Decimal? seasonCoefficient,
  }) : coldLossPercent = coldLossPercent ?? Decimal.zero,
       hotLossPercent = hotLossPercent ?? Decimal.zero,
       seasonCoefficient = seasonCoefficient ?? Decimal.one;

  final int? id;
  final int dishUcode;
  final int ingredientUcode;

  final Decimal grossQuantity;

  final Decimal netQuantity;

  final Decimal coldLossPercent;

  final Decimal hotLossPercent;

  final int sortOrder;

  final String? ingredientName;
  final Decimal? purchasePrice;
  final int? ingredientMeasure;

  final double? calories;
  final double? proteins;
  final double? fats;
  final double? carbs;

  final Decimal seasonCoefficient;

  Decimal get finalYield {
    final hundred = Decimal.fromInt(100);
    return (netQuantity * (hundred - hotLossPercent) / hundred)
        .toDecimal(scaleOnInfinitePrecision: 3)
        .round(scale: 3);
  }

  Decimal get ingredientCost => grossQuantity * (purchasePrice ?? Decimal.zero);

  double get caloriesPerServing =>
      (calories ?? 0) * finalYield.toDouble() / 100.0;

  double get proteinsPerServing =>
      (proteins ?? 0) * finalYield.toDouble() / 100.0;

  double get fatsPerServing => (fats ?? 0) * finalYield.toDouble() / 100.0;

  double get carbsPerServing => (carbs ?? 0) * finalYield.toDouble() / 100.0;

  String get measureLabel => switch (ingredientMeasure) {
    1 => 'кг',
    2 => 'л',
    3 => 'м',
    _ => 'шт',
  };

  DishIngredientEntity copyWith({
    int? id,
    int? dishUcode,
    int? ingredientUcode,
    Decimal? grossQuantity,
    Decimal? netQuantity,
    Decimal? coldLossPercent,
    Decimal? hotLossPercent,
    int? sortOrder,
    String? ingredientName,
    Decimal? purchasePrice,
    int? ingredientMeasure,
    double? calories,
    double? proteins,
    double? fats,
    double? carbs,
    Decimal? seasonCoefficient,
  }) {
    return DishIngredientEntity(
      id: id ?? this.id,
      dishUcode: dishUcode ?? this.dishUcode,
      ingredientUcode: ingredientUcode ?? this.ingredientUcode,
      grossQuantity: grossQuantity ?? this.grossQuantity,
      netQuantity: netQuantity ?? this.netQuantity,
      coldLossPercent: coldLossPercent ?? this.coldLossPercent,
      hotLossPercent: hotLossPercent ?? this.hotLossPercent,
      sortOrder: sortOrder ?? this.sortOrder,
      ingredientName: ingredientName ?? this.ingredientName,
      purchasePrice: purchasePrice ?? this.purchasePrice,
      ingredientMeasure: ingredientMeasure ?? this.ingredientMeasure,
      calories: calories ?? this.calories,
      proteins: proteins ?? this.proteins,
      fats: fats ?? this.fats,
      carbs: carbs ?? this.carbs,
      seasonCoefficient: seasonCoefficient ?? this.seasonCoefficient,
    );
  }
}

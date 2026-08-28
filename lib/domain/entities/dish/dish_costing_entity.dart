import 'package:decimal/decimal.dart';
import 'package:telepos/domain/entities/dish/dish_ingredient_entity.dart';

class DishCostingEntity {
  const DishCostingEntity({
    required this.dishUcode,
    required this.dishName,
    required this.ingredients,
    required this.sellingPrice,
    this.servingsPerRecipe = 1,
  });

  final int dishUcode;
  final String dishName;
  final List<DishIngredientEntity> ingredients;
  final Decimal sellingPrice;
  final int servingsPerRecipe;

  Decimal get dishCost =>
      ingredients.fold(Decimal.zero, (sum, i) => sum + i.ingredientCost);

  Decimal get totalYield =>
      ingredients.fold(Decimal.zero, (sum, i) => sum + i.finalYield);

  double get markupPercent =>
      dishCost > Decimal.zero ? (sellingPrice / dishCost).toDouble() * 100 : 0;

  double get marginPercent => sellingPrice > Decimal.zero
      ? ((sellingPrice - dishCost) / sellingPrice).toDouble() * 100
      : 0;

  double get foodCostPercent => sellingPrice > Decimal.zero
      ? (dishCost / sellingPrice).toDouble() * 100
      : 0;

  Decimal get costPerServing => servingsPerRecipe > 0
      ? (dishCost / Decimal.fromInt(servingsPerRecipe))
            .toDecimal(scaleOnInfinitePrecision: 3)
            .round(scale: 3)
      : dishCost;

  Decimal get pricePerServing => servingsPerRecipe > 0
      ? (sellingPrice / Decimal.fromInt(servingsPerRecipe))
            .toDecimal(scaleOnInfinitePrecision: 3)
            .round(scale: 3)
      : sellingPrice;

  bool get hasMissingPrices => ingredients.any(
    (i) => i.purchasePrice == null || i.purchasePrice == Decimal.zero,
  );

  double get totalCalories =>
      ingredients.fold(0.0, (sum, i) => sum + i.caloriesPerServing);

  double get totalProteins =>
      ingredients.fold(0.0, (sum, i) => sum + i.proteinsPerServing);

  double get totalFats =>
      ingredients.fold(0.0, (sum, i) => sum + i.fatsPerServing);

  double get totalCarbs =>
      ingredients.fold(0.0, (sum, i) => sum + i.carbsPerServing);

  bool get hasKbjuData => ingredients.any(
    (i) =>
        i.calories != null ||
        i.proteins != null ||
        i.fats != null ||
        i.carbs != null,
  );
}

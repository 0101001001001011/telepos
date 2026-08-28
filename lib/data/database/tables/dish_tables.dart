import 'package:drift/drift.dart';
import 'package:telepos/data/database/converters/decimal_converter.dart';

class DishIngredients extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get dishUcode => integer()();

  IntColumn get ingredientUcode => integer()();

  RealColumn get grossQuantity => real().map(const DecimalConverter())();

  RealColumn get netQuantity => real().map(const DecimalConverter())();

  RealColumn get coldLossPercent =>
      real().map(const DecimalConverter()).withDefault(const Constant(0.0))();

  RealColumn get hotLossPercent =>
      real().map(const DecimalConverter()).withDefault(const Constant(0.0))();

  RealColumn get calories => real().nullable()();

  RealColumn get proteins => real().nullable()();

  RealColumn get fats => real().nullable()();

  RealColumn get carbs => real().nullable()();

  RealColumn get seasonCoefficient =>
      real().map(const DecimalConverter()).withDefault(const Constant(1.0))();

  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
}

class DishRecipeVersions extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get dishUcode => integer()();

  IntColumn get versionNumber => integer()();

  TextColumn get changeSummary => text()();

  IntColumn get changedBy => integer()();

  IntColumn get changedAt => integer()();

  TextColumn get recipeSnapshot => text()();
}

class DishPhotos extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get dishUcode => integer()();

  TextColumn get filePath => text()();

  IntColumn get createdAt => integer()();
}

class GostLossNorms extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get productName => text()();

  RealColumn get coldLossPercent => real().map(const DecimalConverter())();

  RealColumn get hotLossPercent => real().map(const DecimalConverter())();

  IntColumn get season => integer().withDefault(const Constant(0))();
}

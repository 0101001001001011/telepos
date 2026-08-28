import 'package:drift/drift.dart';

class ModifierGroups extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get dishUcode => integer().nullable()();
  TextColumn get name => text()();
  IntColumn get modifierType => integer().withDefault(const Constant(0))();
  IntColumn get minSelection => integer().withDefault(const Constant(0))();
  IntColumn get maxSelection => integer().withDefault(const Constant(1))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  BoolColumn get isRequired => boolean().withDefault(const Constant(false))();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
}

class ModifierOptions extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get groupId => integer().references(ModifierGroups, #id)();
  TextColumn get name => text()();
  RealColumn get priceAdjustment => real().withDefault(const Constant(0))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  BoolColumn get isAvailable => boolean().withDefault(const Constant(true))();
  BoolColumn get isDefault => boolean().withDefault(const Constant(false))();
}

class SaleProductModifiers extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get saleProductId => integer()();
  IntColumn get modifierGroupId => integer().references(ModifierGroups, #id)();
  IntColumn get modifierOptionId =>
      integer().references(ModifierOptions, #id)();
  RealColumn get priceAdjustment => real().withDefault(const Constant(0))();
}

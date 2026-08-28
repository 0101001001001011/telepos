import 'package:drift/drift.dart';
import 'package:telepos/data/database/converters/decimal_converter.dart';

class Categories extends Table {
  IntColumn get id => integer()();

  IntColumn get parentId => integer().nullable()();

  TextColumn get name => text().nullable()();

  IntColumn get globalCategory => integer().nullable().unique()();

  DateTimeColumn get createTime => dateTime()();

  DateTimeColumn get editTime => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class CategoryRestrictions extends Table {
  IntColumn get id => integer()();

  IntColumn get categoryId => integer().references(Categories, #id)();

  BoolColumn get isActive => boolean().withDefault(const Constant(false))();

  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();

  TextColumn get beginTime => text().nullable()();

  TextColumn get endTime => text().nullable()();

  DateTimeColumn get createTime => dateTime().nullable()();

  DateTimeColumn get editTime => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

class GlobalProducts extends Table {
  IntColumn get code => integer()();

  TextColumn get name => text()();

  RealColumn get arrivalCost => real().map(const DecimalConverter())();

  RealColumn get sellingPrice => real().map(const DecimalConverter())();

  DateTimeColumn get editTime => dateTime()();

  IntColumn get categoryId =>
      integer().nullable().references(Categories, #id)();

  @override
  Set<Column> get primaryKey => {code};
}

class ProductInfos extends Table {
  IntColumn get ucode => integer()();

  IntColumn get barcode => integer()();

  TextColumn get name => text()();

  DateTimeColumn get localEditTime => dateTime().nullable()();

  DateTimeColumn get serverEditTime => dateTime().nullable()();

  IntColumn get categoryId =>
      integer().nullable().references(Categories, #id)();

  IntColumn get type => integer()();

  IntColumn get measure => integer()();

  RealColumn get quantity => real().nullable().map(const DecimalConverter())();

  TextColumn get description => text().nullable()();

  TextColumn get imagePath => text().nullable()();

  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();

  IntColumn get vatRate => integer().nullable()();

  TextColumn get ntin => text().nullable()();

  BoolColumn get isMarkable => boolean().withDefault(const Constant(false))();

  TextColumn get brand => text().nullable()();

  TextColumn get manufacturer => text().nullable()();

  TextColumn get countryOfOrigin => text().nullable()();

  @override
  Set<Column> get primaryKey => {ucode};
}

class ProductPrices extends Table {
  IntColumn get ucode => integer()();

  IntColumn get barcode => integer()();

  RealColumn get sellingPrice =>
      real().nullable().map(const DecimalConverter())();

  RealColumn get wholesalePrice =>
      real().nullable().map(const DecimalConverter())();

  DateTimeColumn get editTime => dateTime().nullable()();

  DateTimeColumn get serverEditTime => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {ucode};
}

class ProductInfoEditions extends Table {
  IntColumn get ucode => integer()();

  IntColumn get userId => integer()();

  DateTimeColumn get editTime => dateTime()();

  @override
  Set<Column> get primaryKey => {ucode};
}

class ProductPriceEditions extends Table {
  IntColumn get ucode => integer()();

  IntColumn get userId => integer()();

  DateTimeColumn get editTime => dateTime()();

  @override
  Set<Column> get primaryKey => {ucode};
}

class ProductAliases extends Table {
  TextColumn get code => text()();

  IntColumn get productUcode => integer()();

  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();

  DateTimeColumn get time => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {code};
}

class Promotions extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get name => text()();

  IntColumn get type => integer().withDefault(const Constant(0))();

  IntColumn get triggerUcode => integer()();

  IntColumn get triggerQty => integer().withDefault(const Constant(2))();

  IntColumn get rewardUcode => integer()();

  IntColumn get rewardQty => integer().withDefault(const Constant(1))();

  BoolColumn get supplierFunded =>
      boolean().withDefault(const Constant(false))();

  BoolColumn get enabled => boolean().withDefault(const Constant(true))();
}

class MarkUps extends Table {
  IntColumn get categoryId => integer()();

  IntColumn get storeId => integer().nullable()();

  RealColumn get markup =>
      real().map(const DecimalConverter()).withDefault(const Constant(0.0))();

  @override
  Set<Column> get primaryKey => {categoryId};
}

class PackageProducts extends Table {
  IntColumn get packageUcode => integer()();

  IntColumn get ucode => integer()();

  BoolColumn get isDeleted => boolean().nullable()();

  DateTimeColumn get createTime => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {packageUcode, ucode};
}

class QuickProducts extends Table {
  IntColumn get id => integer()();

  IntColumn get productId => integer().nullable()();

  IntColumn get parentId => integer().nullable()();

  IntColumn get ucode => integer().nullable()();

  TextColumn get name => text().nullable()();

  IntColumn get editTime => integer().nullable()();

  BoolColumn get isActive => boolean().nullable()();

  IntColumn get orderName =>
      integer().nullable().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}

class CancelledProducts extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get userId => integer().nullable()();

  RealColumn get quantity => real().nullable().map(const DecimalConverter())();

  IntColumn get ucode => integer().nullable()();

  RealColumn get expectedQuantity =>
      real().nullable().map(const DecimalConverter())();

  DateTimeColumn get date => dateTime().nullable()();

  IntColumn get syncStatus => integer().withDefault(const Constant(1))();
}

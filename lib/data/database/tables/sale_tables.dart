import 'package:drift/drift.dart';
import 'package:telepos/data/database/converters/decimal_converter.dart';

class Sales extends Table {
  IntColumn get receiptNo => integer()();

  IntColumn get posId => integer()();

  IntColumn get saleId => integer().nullable().unique()();

  IntColumn get userId => integer()();

  RealColumn get amount => real().map(const DecimalConverter())();

  RealColumn get change => real().nullable().map(const DecimalConverter())();

  IntColumn get time => integer()();

  IntColumn get storeId => integer().nullable()();

  IntColumn get customerLocalId => integer().nullable()();

  IntColumn get customerServerId => integer().nullable()();

  IntColumn get loyalCustomerPhone => integer().nullable()();

  BoolColumn get isOfd => boolean().withDefault(const Constant(false))();

  IntColumn get state => integer().nullable()();

  BoolColumn get isWholesale => boolean().withDefault(const Constant(false))();

  IntColumn get weightProductRoundType => integer().nullable()();

  IntColumn get discountsRoundType => integer().nullable()();

  TextColumn get customerBin => text().nullable()();

  IntColumn get orderType => integer().nullable()();

  RealColumn get serviceCharge =>
      real().nullable().map(const DecimalConverter())();

  @override
  Set<Column> get primaryKey => {receiptNo, posId};
}

class SaleProducts extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get receiptNo => integer().nullable()();

  IntColumn get posId => integer().nullable()();

  IntColumn get saleId => integer().nullable()();

  IntColumn get ucode => integer()();

  IntColumn get barcode => integer().nullable()();

  IntColumn get categoryId => integer().nullable()();

  RealColumn get quantity => real().map(const DecimalConverter())();

  RealColumn get price => real().map(const DecimalConverter())();

  RealColumn get priceBefore => real().map(const DecimalConverter())();
}

class SaleProductMarks extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get mark => text().nullable()();

  IntColumn get saleProductId => integer().nullable()();
}

class SaleWithdrawals extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get receiptNo => integer().nullable()();

  IntColumn get posId => integer().nullable()();

  IntColumn get saleId => integer().nullable()();

  IntColumn get agentAccountId => integer().nullable()();

  RealColumn get amount => real().nullable().map(const DecimalConverter())();
}

class SaleCustomFields extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get receiptNo => integer().nullable()();

  IntColumn get posId => integer().nullable()();

  IntColumn get customFieldId => integer().nullable()();

  IntColumn get customFieldItemId => integer().nullable()();
}

class UniversalProducts extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get receiptNo => integer().nullable()();

  IntColumn get posId => integer().nullable()();

  IntColumn get refundLocalId => integer().nullable()();

  RealColumn get quantity => real().map(const DecimalConverter())();

  RealColumn get price => real().map(const DecimalConverter())();

  RealColumn get priceBefore =>
      real().nullable().map(const DecimalConverter())();

  RealColumn get inSalePrice =>
      real().nullable().map(const DecimalConverter())();

  RealColumn get inSaleQuantity =>
      real().nullable().map(const DecimalConverter())();
}

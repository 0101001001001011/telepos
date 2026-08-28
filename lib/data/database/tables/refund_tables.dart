import 'package:drift/drift.dart';
import 'package:telepos/data/database/converters/decimal_converter.dart';

class Refunds extends Table {
  IntColumn get localId => integer().autoIncrement()();

  IntColumn get serverId => integer().nullable().unique()();

  IntColumn get saleId => integer().nullable()();

  IntColumn get saleReceiptNo => integer().nullable()();

  IntColumn get salePosId => integer().nullable()();

  IntColumn get userId => integer()();

  RealColumn get amount =>
      real().map(const DecimalConverter()).withDefault(const Constant(0.0))();

  RealColumn get cashbackAmount =>
      real().nullable().map(const DecimalConverter())();

  IntColumn get time => integer()();

  IntColumn get state => integer().nullable()();

  IntColumn get customerLocalId => integer().nullable()();

  IntColumn get customerServerId => integer().nullable()();

  IntColumn get weightProductRoundType => integer().nullable()();

  IntColumn get discountsRoundType => integer().nullable()();

  BoolColumn get isOfd => boolean().withDefault(const Constant(false))();

  @override
  List<Set<Column>> get uniqueKeys => [
    {saleReceiptNo, salePosId},
  ];
}

class RefundProducts extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get refundLocalId => integer().nullable()();

  IntColumn get refundServerId => integer().nullable()();

  IntColumn get ucode => integer()();

  RealColumn get price => real().map(const DecimalConverter())();

  RealColumn get quantity => real().map(const DecimalConverter())();

  IntColumn get weightProductRoundType => integer().nullable()();

  IntColumn get discountsRoundType => integer().nullable()();

  RealColumn get inSaleQuantity =>
      real().nullable().map(const DecimalConverter())();

  RealColumn get inSalePrice =>
      real().nullable().map(const DecimalConverter())();

  RealColumn get inSalePriceBefore =>
      real().nullable().map(const DecimalConverter())();
}

class RefundProductMarks extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get mark => text().nullable()();

  IntColumn get refundProductId => integer().nullable()();
}

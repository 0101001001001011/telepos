import 'package:drift/drift.dart';
import 'package:telepos/data/database/converters/decimal_converter.dart';

class RestaurantTables extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get name => text()();

  IntColumn get capacity => integer().withDefault(const Constant(4))();

  IntColumn get status => integer().withDefault(const Constant(0))();

  TextColumn get zone => text().nullable()();

  RealColumn get positionX => real().nullable()();

  RealColumn get positionY => real().nullable()();

  BoolColumn get isActive => boolean().withDefault(const Constant(true))();

  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
}

class RestaurantZones extends Table {
  TextColumn get name => text()();

  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {name};
}

class RestaurantOrders extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get tableId => integer().nullable()();

  IntColumn get receiptNo => integer().nullable()();

  IntColumn get posId => integer().nullable()();

  IntColumn get partySize => integer().withDefault(const Constant(1))();

  IntColumn get orderType => integer().withDefault(const Constant(0))();

  IntColumn get openTime => integer()();

  IntColumn get closeTime => integer().nullable()();

  IntColumn get waiterId => integer().nullable()();

  RealColumn get tips => real().nullable().map(const DecimalConverter())();

  TextColumn get deliveryAddress => text().nullable()();

  TextColumn get deliveryPhone => text().nullable()();

  TextColumn get note => text().nullable()();
}

class GuestSplits extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get orderId => integer()();

  IntColumn get guestNumber => integer()();

  IntColumn get saleProductId => integer()();

  RealColumn get shareQuantity => real().map(const DecimalConverter())();
}

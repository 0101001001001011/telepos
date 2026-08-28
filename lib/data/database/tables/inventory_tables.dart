import 'package:drift/drift.dart';
import 'package:telepos/data/database/converters/decimal_converter.dart';

class Inventories extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get userId => integer().nullable()();

  IntColumn get startTime => integer().nullable()();

  IntColumn get endTime => integer().nullable()();

  IntColumn get status => integer().nullable()();

  TextColumn get comment => text().nullable()();

  IntColumn get discrepancyCount => integer().nullable()();

  BoolColumn get isFullCount => boolean().nullable()();

  IntColumn get state => integer().nullable()();

  TextColumn get msg => text().nullable()();
}

class InventoryProducts extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get inventoryId => integer()();

  IntColumn get ucode => integer()();

  RealColumn get expectedQty => real().map(const DecimalConverter())();

  RealColumn get actualQty => real().map(const DecimalConverter())();

  RealColumn get difference => real().map(const DecimalConverter())();

  RealColumn get price => real().map(const DecimalConverter())();
}

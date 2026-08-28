import 'package:drift/drift.dart';
import 'package:telepos/data/database/converters/decimal_converter.dart';

class SupplierReturns extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get userId => integer().nullable()();

  IntColumn get supplierId => integer().nullable()();

  IntColumn get editTime => integer().nullable()();

  RealColumn get amount => real().nullable().map(const DecimalConverter())();

  IntColumn get accountId => integer().nullable()();

  TextColumn get comment => text().nullable()();

  IntColumn get supplyId => integer().nullable()();

  IntColumn get state => integer().nullable()();

  IntColumn get status => integer().nullable()();

  TextColumn get msg => text().nullable()();
}

class SupplierReturnProducts extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get supplierReturnId => integer()();

  IntColumn get ucode => integer()();

  RealColumn get quantity => real().map(const DecimalConverter())();

  RealColumn get price => real().map(const DecimalConverter())();

  RealColumn get amount => real().map(const DecimalConverter())();
}

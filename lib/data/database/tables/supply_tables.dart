import 'package:drift/drift.dart';
import 'package:telepos/data/database/converters/decimal_converter.dart';

class Supplies extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get operationType => integer().nullable()();

  IntColumn get userId => integer().nullable()();

  IntColumn get supplierId => integer().nullable()();

  IntColumn get editTime => integer().nullable()();

  RealColumn get amount => real().nullable().map(const DecimalConverter())();

  IntColumn get paymentType => integer().nullable()();

  IntColumn get accountId => integer().nullable()();

  TextColumn get comment => text().nullable()();

  RealColumn get payment => real().nullable().map(const DecimalConverter())();

  RealColumn get consignmentAmount =>
      real().nullable().map(const DecimalConverter())();

  RealColumn get paidAmount =>
      real().nullable().map(const DecimalConverter())();

  IntColumn get state => integer().nullable()();

  IntColumn get status => integer().nullable()();

  TextColumn get msg => text().nullable()();
}

class SupplyProducts extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get supplyId => integer()();

  IntColumn get ucode => integer()();

  RealColumn get quantity => real().map(const DecimalConverter())();

  RealColumn get price => real().map(const DecimalConverter())();

  RealColumn get amount => real().map(const DecimalConverter())();

  TextColumn get serialNumbers => text().nullable()();
}

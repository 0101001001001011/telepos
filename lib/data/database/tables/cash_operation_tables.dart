import 'package:drift/drift.dart';
import 'package:telepos/data/database/converters/decimal_converter.dart';

class CashOperations extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get storeId => integer().nullable()();

  RealColumn get amount => real().map(const DecimalConverter())();

  IntColumn get accountId => integer().nullable()();

  IntColumn get type => integer()();

  IntColumn get userId => integer().nullable()();

  TextColumn get note => text().nullable()();

  IntColumn get docTime => integer().nullable()();

  IntColumn get state => integer().nullable()();
}

class CashOperationCustomFields extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get cashOperationId => integer().nullable()();

  IntColumn get customFieldId => integer().nullable()();

  IntColumn get customFieldItemId => integer().nullable()();
}

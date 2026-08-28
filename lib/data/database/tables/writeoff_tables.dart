import 'package:drift/drift.dart';
import 'package:telepos/data/database/converters/decimal_converter.dart';

class Writeoffs extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get userId => integer().nullable()();

  IntColumn get docTime => integer().nullable()();

  IntColumn get reason => integer().nullable()();

  TextColumn get comment => text().nullable()();

  RealColumn get amount => real().nullable().map(const DecimalConverter())();

  IntColumn get state => integer().nullable()();

  TextColumn get msg => text().nullable()();
}

class WriteoffProducts extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get writeoffId => integer()();

  IntColumn get ucode => integer()();

  RealColumn get quantity => real().map(const DecimalConverter())();

  RealColumn get price => real().map(const DecimalConverter())();

  RealColumn get amount => real().map(const DecimalConverter())();
}

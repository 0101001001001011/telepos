import 'package:drift/drift.dart';
import 'package:telepos/data/database/converters/decimal_converter.dart';

class Movements extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get userId => integer().nullable()();

  IntColumn get editTime => integer().nullable()();

  RealColumn get amount => real().nullable().map(const DecimalConverter())();

  TextColumn get comment => text().nullable()();

  TextColumn get fromLocation => text().nullable()();

  TextColumn get toLocation => text().nullable()();

  IntColumn get state => integer().nullable()();

  IntColumn get status => integer().nullable()();

  TextColumn get msg => text().nullable()();
}

class MovementProducts extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get movementId => integer()();

  IntColumn get ucode => integer()();

  RealColumn get quantity => real().map(const DecimalConverter())();

  RealColumn get price => real().map(const DecimalConverter())();

  RealColumn get amount => real().map(const DecimalConverter())();
}

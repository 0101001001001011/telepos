import 'package:drift/drift.dart';
import 'package:telepos/data/database/converters/decimal_converter.dart';

class Shifts extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get userId => integer()();

  IntColumn get openTime => integer()();

  BoolColumn get isOpened => boolean()();

  IntColumn get closeTime => integer().nullable()();

  RealColumn get cashInPosOnShiftClose =>
      real().nullable().map(const DecimalConverter())();

  RealColumn get openingCash =>
      real().nullable().map(const DecimalConverter())();

  BoolColumn get isSynced => boolean()();
}

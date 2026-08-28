import 'package:drift/drift.dart';
import 'package:telepos/data/database/converters/decimal_converter.dart';

class Payments extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get userId => integer()();

  IntColumn get receiptNo => integer().nullable()();

  IntColumn get posId => integer().nullable()();

  IntColumn get refundLocalId => integer().nullable()();

  IntColumn get customerLocalId => integer().nullable()();

  IntColumn get payeeAccountId => integer()();

  RealColumn get amount => real().map(const DecimalConverter())();

  IntColumn get time => integer()();

  IntColumn get state => integer().nullable()();

  TextColumn get approvalCode => text().nullable()();

  TextColumn get cardMask => text().nullable()();

  TextColumn get terminalTransactionId => text().nullable()();

  @override
  List<Set<Column>> get uniqueKeys => [
    {receiptNo, posId, payeeAccountId},
    {refundLocalId, payeeAccountId},
  ];
}

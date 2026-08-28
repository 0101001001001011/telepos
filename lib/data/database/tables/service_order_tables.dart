import 'package:drift/drift.dart';
import 'package:telepos/data/database/converters/decimal_converter.dart';

class ServiceOrders extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get orderNumber => text().unique()();

  IntColumn get receiptNo => integer().nullable()();

  IntColumn get posId => integer().nullable()();

  IntColumn get status => integer().withDefault(const Constant(0))();

  IntColumn get userId => integer()();

  IntColumn get assigneeId => integer().nullable()();

  IntColumn get clientAgentId => integer().nullable()();

  TextColumn get clientName => text().nullable()();

  TextColumn get clientPhone => text().nullable()();

  TextColumn get clientNote => text().nullable()();

  TextColumn get deviceDescription => text().nullable()();

  TextColumn get serialNumber => text().nullable()();

  TextColumn get complaint => text().nullable()();

  IntColumn get intakeTime => integer()();

  IntColumn get estimatedCompletionTime => integer().nullable()();

  RealColumn get estimatedAmount =>
      real().nullable().map(const DecimalConverter())();

  RealColumn get prepaymentAmount =>
      real().nullable().map(const DecimalConverter())();

  RealColumn get finalAmount =>
      real().nullable().map(const DecimalConverter())();

  IntColumn get warrantyDays => integer().nullable()();

  IntColumn get qualityRating => integer().nullable()();

  TextColumn get qualityNote => text().nullable()();

  TextColumn get intakeInventory => text().nullable()();
}

class ServiceMarks extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get serviceOrderId => integer()();

  TextColumn get description => text()();

  IntColumn get markType => integer().withDefault(const Constant(4))();

  IntColumn get userId => integer()();

  RealColumn get cost => real().nullable().map(const DecimalConverter())();

  IntColumn get createdAt => integer()();

  TextColumn get note => text().nullable()();

  IntColumn get productUcode => integer().nullable()();

  IntColumn get approvalStatus => integer().nullable()();

  RealColumn get quantity =>
      real().map(const DecimalConverter()).withDefault(const Constant(1.0))();
}

class ServiceOrderPhotos extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get serviceOrderId => integer()();

  TextColumn get filePath => text()();

  IntColumn get photoType => integer()();

  IntColumn get mediaType => integer().withDefault(const Constant(0))();

  IntColumn get createdAt => integer()();
}

class ServiceTypes extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get productUcode => integer()();

  IntColumn get estimatedDurationMinutes => integer().nullable()();

  IntColumn get warrantyDays => integer().nullable()();

  BoolColumn get requiresDevice =>
      boolean().withDefault(const Constant(false))();

  BoolColumn get requiresIntakePhotos =>
      boolean().withDefault(const Constant(false))();

  BoolColumn get requiresRepairPhotos =>
      boolean().withDefault(const Constant(false))();

  BoolColumn get requiresQualityCheck =>
      boolean().withDefault(const Constant(false))();

  BoolColumn get requiresIntakeInventory =>
      boolean().withDefault(const Constant(false))();

  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
}

class ServiceConsumables extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get serviceProductUcode => integer()();

  IntColumn get consumableUcode => integer()();

  RealColumn get quantity =>
      real().map(const DecimalConverter()).withDefault(const Constant(1.0))();
}

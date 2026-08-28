import 'package:drift/drift.dart';

class AdditionalPrinters extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
}

class AppVersionStatuses extends Table {
  BoolColumn get id => boolean()();

  TextColumn get status => text().nullable()();

  IntColumn get statusChangeDate => integer().nullable()();

  TextColumn get latestVersionName => text().nullable()();

  TextColumn get link => text().nullable()();

  TextColumn get md5sum => text().nullable()();

  TextColumn get updates => text().nullable()();

  TextColumn get fixes => text().nullable()();

  DateTimeColumn get releaseDate => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class AttrDates extends Table {
  TextColumn get name => text().withLength(max: 32)();

  DateTimeColumn get date => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {name};
}

class UpdateProperties extends Table {
  TextColumn get name => text()();

  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {name};
}

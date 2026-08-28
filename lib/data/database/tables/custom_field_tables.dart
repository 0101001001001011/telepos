import 'package:drift/drift.dart';

class CustomFields extends Table {
  IntColumn get id => integer()();

  IntColumn get companyId => integer().nullable()();

  TextColumn get name => text().nullable()();

  BoolColumn get deleted => boolean().withDefault(const Constant(false))();

  IntColumn get createTime => integer().nullable()();

  IntColumn get editTime => integer().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class CustomFieldItems extends Table {
  IntColumn get id => integer()();

  IntColumn get customFieldId => integer().nullable()();

  TextColumn get name => text().nullable()();

  BoolColumn get deleted => boolean().withDefault(const Constant(false))();

  IntColumn get createTime => integer().nullable()();

  IntColumn get editTime => integer().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

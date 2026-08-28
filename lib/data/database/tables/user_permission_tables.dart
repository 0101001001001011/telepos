import 'package:drift/drift.dart';

class UserPermissions extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get userId => integer()();

  TextColumn get permissionKey => text()();

  BoolColumn get isAllowed => boolean().withDefault(const Constant(true))();
}

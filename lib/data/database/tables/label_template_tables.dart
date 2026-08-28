import 'package:drift/drift.dart';

class LabelTemplates extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get name => text()();

  IntColumn get widthMm => integer().withDefault(const Constant(58))();

  IntColumn get heightMm => integer().withDefault(const Constant(40))();

  TextColumn get fieldsJson => text().withDefault(const Constant('[]'))();

  BoolColumn get isDefault => boolean().withDefault(const Constant(false))();
}

import 'package:drift/drift.dart';

class ReceiptTemplates extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get name => text()();

  TextColumn get optionsJson => text().withDefault(const Constant('{}'))();

  BoolColumn get isDefault => boolean().withDefault(const Constant(false))();

  BoolColumn get isSelected => boolean().withDefault(const Constant(false))();
}

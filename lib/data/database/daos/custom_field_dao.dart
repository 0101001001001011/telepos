import 'package:drift/drift.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/database/tables/custom_field_tables.dart';
import 'package:telepos/data/database/tables/organization_tables.dart';

part 'custom_field_dao.g.dart';

@DriftAccessor(
  tables: [CustomFields, CustomFieldItems, CustomFieldClassRelations],
)
class CustomFieldDao extends DatabaseAccessor<AppDatabase>
    with _$CustomFieldDaoMixin {
  CustomFieldDao(super.db);

  static const String cashInOutClassName = 'CashInOut';

  static const String expenseTypeFieldName = 'Тип расхода';

  Future<List<CustomField>> findByName(String name) =>
      (select(customFields)..where((cf) => cf.name.equals(name))).get();

  Future<List<CustomField>> findByClassName(String className) =>
      customSelect(
        'SELECT cf.* FROM custom_fields cf '
        'INNER JOIN custom_field_class_relations cfcr ON cf.id = cfcr.custom_field_id '
        'WHERE cfcr.class_name = ? AND cf.deleted = 0',
        variables: [Variable.withString(className)],
        readsFrom: {customFields, customFieldClassRelations},
      ).get().then(
        (_) => (select(
          customFields,
        )..where((cf) => cf.deleted.equals(false))).get(),
      );

  Future<List<CustomFieldItem>> findItemsByFieldId(int customFieldId) =>
      (select(customFieldItems)..where(
            (cfi) =>
                cfi.deleted.equals(false) &
                cfi.customFieldId.equals(customFieldId),
          ))
          .get();

  Future<CustomField?> getExpenseTypeField() async {
    final fields =
        await (select(customFields)..where(
              (cf) =>
                  cf.name.equals(expenseTypeFieldName) &
                  cf.deleted.equals(false),
            ))
            .get();
    return fields.isEmpty ? null : fields.first;
  }

  Future<List<CustomFieldItem>> getExpenseTypeItems() async {
    final field = await getExpenseTypeField();
    if (field == null) return [];
    return findItemsByFieldId(field.id);
  }

  Future<CustomFieldItem?> getExpenseTypeById(int id) => (select(
    customFieldItems,
  )..where((cfi) => cfi.id.equals(id))).getSingleOrNull();

  Future<int> ensureExpenseTypeFieldExists({int? companyId}) async {
    final existing = await getExpenseTypeField();
    if (existing != null) return existing.id;

    final id = await into(customFields).insert(
      CustomFieldsCompanion.insert(
        id: Value(1),
        companyId: Value(companyId),
        name: const Value(expenseTypeFieldName),
        createTime: Value(DateTime.now().millisecondsSinceEpoch ~/ 1000),
        editTime: Value(DateTime.now().millisecondsSinceEpoch ~/ 1000),
      ),
    );

    await into(customFieldClassRelations).insert(
      CustomFieldClassRelationsCompanion.insert(
        customFieldId: id,
        className: cashInOutClassName,
      ),
    );

    return id;
  }

  Future<int> addExpenseTypeItem({required String name, int? companyId}) async {
    final fieldId = await ensureExpenseTypeFieldExists(companyId: companyId);

    final maxIdResult = await customSelect(
      'SELECT MAX(id) as max_id FROM custom_field_items',
    ).getSingle();
    final nextId = ((maxIdResult.data['max_id'] as int?) ?? 0) + 1;

    return into(customFieldItems).insert(
      CustomFieldItemsCompanion.insert(
        id: Value(nextId),
        customFieldId: Value(fieldId),
        name: Value(name),
        createTime: Value(DateTime.now().millisecondsSinceEpoch ~/ 1000),
        editTime: Value(DateTime.now().millisecondsSinceEpoch ~/ 1000),
      ),
    );
  }

  Future<int> deleteExpenseTypeItem(int id) =>
      (update(customFieldItems)..where((cfi) => cfi.id.equals(id))).write(
        const CustomFieldItemsCompanion(deleted: Value(true)),
      );
}

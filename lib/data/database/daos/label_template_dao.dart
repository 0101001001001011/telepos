import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/database/tables/label_template_tables.dart';

part 'label_template_dao.g.dart';

@DriftAccessor(tables: [LabelTemplates])
class LabelTemplateDao extends DatabaseAccessor<AppDatabase>
    with _$LabelTemplateDaoMixin {
  LabelTemplateDao(super.db);

  Future<List<LabelTemplate>> getAll() =>
      (select(labelTemplates)..orderBy([
            (t) => OrderingTerm.desc(t.isDefault),
            (t) => OrderingTerm.asc(t.id),
          ]))
          .get();

  Future<LabelTemplate?> getById(int id) =>
      (select(labelTemplates)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<int> insertTemplate(LabelTemplatesCompanion entry) =>
      into(labelTemplates).insert(entry);

  Future<bool> updateTemplate(int id, LabelTemplatesCompanion entry) async {
    final count = await (update(
      labelTemplates,
    )..where((t) => t.id.equals(id))).write(entry);
    return count > 0;
  }

  Future<int> deleteTemplate(int id) => (delete(
    labelTemplates,
  )..where((t) => t.id.equals(id) & t.isDefault.equals(false))).go();

  Future<void> seedDefaults() async {
    final existing =
        await (select(labelTemplates)
              ..where((t) => t.isDefault.equals(true))
              ..limit(1))
            .getSingleOrNull();
    if (existing != null) return;

    for (final def in builtInTemplates) {
      await into(labelTemplates).insert(def);
    }
  }

  static List<LabelTemplatesCompanion> get builtInTemplates => [
    LabelTemplatesCompanion.insert(
      name: 'Ценник 58×40',
      widthMm: const Value(58),
      heightMm: const Value(40),
      isDefault: const Value(true),
      fieldsJson: Value(
        jsonEncode([
          {
            'kind': 'name',
            'x': 20,
            'y': 20,
            'fontSize': 28,
            'bold': true,
            'align': 'left',
          },
          {
            'kind': 'price',
            'x': 20,
            'y': 70,
            'fontSize': 48,
            'bold': true,
            'align': 'left',
          },
          {
            'kind': 'barcode',
            'x': 20,
            'y': 130,
            'fontSize': 0,
            'bold': false,
            'align': 'left',
          },
        ]),
      ),
    ),
    LabelTemplatesCompanion.insert(
      name: 'Этикетка 30×20',
      widthMm: const Value(30),
      heightMm: const Value(20),
      isDefault: const Value(true),
      fieldsJson: Value(
        jsonEncode([
          {
            'kind': 'name',
            'x': 10,
            'y': 8,
            'fontSize': 20,
            'bold': false,
            'align': 'left',
          },
          {
            'kind': 'barcode',
            'x': 10,
            'y': 40,
            'fontSize': 0,
            'bold': false,
            'align': 'left',
          },
        ]),
      ),
    ),
    LabelTemplatesCompanion.insert(
      name: 'Ценник 40×30',
      widthMm: const Value(40),
      heightMm: const Value(30),
      isDefault: const Value(true),
      fieldsJson: Value(
        jsonEncode([
          {
            'kind': 'name',
            'x': 15,
            'y': 12,
            'fontSize': 24,
            'bold': true,
            'align': 'left',
          },
          {
            'kind': 'price',
            'x': 15,
            'y': 48,
            'fontSize': 40,
            'bold': true,
            'align': 'left',
          },
          {
            'kind': 'sku',
            'x': 15,
            'y': 92,
            'fontSize': 18,
            'bold': false,
            'align': 'left',
          },
          {
            'kind': 'barcode',
            'x': 15,
            'y': 120,
            'fontSize': 0,
            'bold': false,
            'align': 'left',
          },
        ]),
      ),
    ),
  ];
}

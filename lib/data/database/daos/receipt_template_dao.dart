import 'package:drift/drift.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/database/tables/receipt_template_tables.dart';
import 'package:telepos/domain/entities/receipt/receipt_options.dart';

part 'receipt_template_dao.g.dart';

@DriftAccessor(tables: [ReceiptTemplates])
class ReceiptTemplateDao extends DatabaseAccessor<AppDatabase>
    with _$ReceiptTemplateDaoMixin {
  ReceiptTemplateDao(super.db);

  Future<List<ReceiptTemplate>> getAll() =>
      (select(receiptTemplates)..orderBy([
            (t) => OrderingTerm.desc(t.isDefault),
            (t) => OrderingTerm.asc(t.id),
          ]))
          .get();

  Future<ReceiptTemplate?> getById(int id) => (select(
    receiptTemplates,
  )..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<ReceiptTemplate?> getSelected() async {
    final selected =
        await (select(receiptTemplates)
              ..where((t) => t.isSelected.equals(true))
              ..limit(1))
            .getSingleOrNull();
    if (selected != null) return selected;
    final all = await getAll();
    return all.isEmpty ? null : all.first;
  }

  Future<ReceiptOptions> getSelectedOptions() async {
    final t = await getSelected();
    if (t == null) return ReceiptOptions.kzDefault;
    return ReceiptOptions.decode(t.optionsJson);
  }

  Future<int> insertTemplate(ReceiptTemplatesCompanion entry) =>
      into(receiptTemplates).insert(entry);

  Future<bool> updateTemplate(int id, ReceiptTemplatesCompanion entry) async {
    final count = await (update(
      receiptTemplates,
    )..where((t) => t.id.equals(id))).write(entry);
    return count > 0;
  }

  Future<int> deleteTemplate(int id) => (delete(
    receiptTemplates,
  )..where((t) => t.id.equals(id) & t.isDefault.equals(false))).go();

  Future<void> selectTemplate(int id) async {
    await transaction(() async {
      await (update(
        receiptTemplates,
      )).write(const ReceiptTemplatesCompanion(isSelected: Value(false)));
      await (update(receiptTemplates)..where((t) => t.id.equals(id))).write(
        const ReceiptTemplatesCompanion(isSelected: Value(true)),
      );
    });
  }

  /// Засевает шаблон по умолчанию, если его ещё нет.
  ///
  /// Ширины ленты здесь нет и быть не должно: она — свойство принтера и живёт
  /// в его привязке (`ReceiptPaperWidthSource`). Шаблон, помнивший ширину со
  /// дня мастера, и был причиной «узкого чека при выбранном широком».
  Future<void> seedDefaults({String? header, String? footer}) async {
    final existing =
        await (select(receiptTemplates)
              ..where((t) => t.isDefault.equals(true))
              ..limit(1))
            .getSingleOrNull();
    if (existing != null) return;

    final hasOverride =
        (header != null && header.trim().isNotEmpty) ||
        (footer != null && footer.trim().isNotEmpty);

    if (hasOverride) {
      const base = ReceiptOptions();
      final opts = base.copyWith(
        header: (header != null && header.trim().isNotEmpty)
            ? base.header.copyWith(text: header.trim())
            : base.header,
        // `null` у подвала значит «не задан», и благодарность поставит
        // печать на своём языке. Тут её не подставить: языка в слое данных
        // нет.
        footer: (footer != null && footer.trim().isNotEmpty)
            ? ReceiptTextBlock(text: footer.trim())
            : null,
      );
      await into(receiptTemplates).insert(
        ReceiptTemplatesCompanion.insert(
          name: 'РК (стандарт)',
          isDefault: const Value(true),
          isSelected: const Value(true),
          optionsJson: Value(opts.encode()),
        ),
      );
      return;
    }

    for (final def in builtInTemplates) {
      await into(receiptTemplates).insert(def);
    }
  }

  static List<ReceiptTemplatesCompanion> get builtInTemplates => [
    ReceiptTemplatesCompanion.insert(
      name: 'РК (стандарт)',
      isDefault: const Value(true),
      isSelected: const Value(true),
      optionsJson: Value(const ReceiptOptions().encode()),
    ),
  ];
}

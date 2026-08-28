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

  Future<void> seedDefaults({
    String? header,
    String? footer,
    int? paperWidthMm,
  }) async {
    final existing =
        await (select(receiptTemplates)
              ..where((t) => t.isDefault.equals(true))
              ..limit(1))
            .getSingleOrNull();
    if (existing != null) return;

    final hasOverride =
        (header != null && header.trim().isNotEmpty) ||
        (footer != null && footer.trim().isNotEmpty) ||
        paperWidthMm != null;

    if (hasOverride) {
      const base = ReceiptOptions();
      final opts = base.copyWith(
        headerText: (header != null && header.trim().isNotEmpty)
            ? header.trim()
            : base.headerText,
        footerText: (footer != null && footer.trim().isNotEmpty)
            ? footer.trim()
            : base.footerText,
        paperWidth: paperWidthMm != null
            ? ReceiptPaperWidth.fromMm(paperWidthMm)
            : base.paperWidth,
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

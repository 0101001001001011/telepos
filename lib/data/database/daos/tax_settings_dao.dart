/// Чтение и запись налоговой настройки: юрисдикции, категории, правила.
///
/// # Зачем отдельный DAO
///
/// Три таблицы описывают одну вещь и по отдельности бессмысленны: правило
/// без юрисдикции не применяется, категория без правила ничего не меняет.
/// Собирать их порознь в экране значило бы разложить эту связность по
/// кнопкам и однажды сохранить половину.
///
/// # Применение пресета — замена, а не добавление
///
/// Пресет ставит настройку целиком. Доливать его в существующую означало бы
/// складывать доли двух штатов, и касса молча начала бы брать двойной налог.
/// Поэтому [applyPreset] сначала чистит, и всё — одной сделкой.
library;

import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/database/tables/tax_tables.dart';
import 'package:telepos/data/database/tables/this_pos_tables.dart';
import 'package:telepos/domain/tax/tax_preset.dart';
import 'package:telepos/domain/tax/tax_resolution.dart' as domain;

part 'tax_settings_dao.g.dart';

@DriftAccessor(
  tables: [TaxJurisdictions, TaxCategories, TaxRules, ThisPosEntries],
)
class TaxSettingsDao extends DatabaseAccessor<AppDatabase>
    with _$TaxSettingsDaoMixin {
  TaxSettingsDao(super.db);

  Future<List<TaxJurisdictionRow>> allJurisdictions() =>
      (select(taxJurisdictions)..orderBy([
            (j) => OrderingTerm(expression: j.level),
            (j) => OrderingTerm(expression: j.sortOrder),
            (j) => OrderingTerm(expression: j.id),
          ]))
          .get();

  Future<List<TaxCategory>> allCategories() =>
      (select(taxCategories)..orderBy([
            (c) =>
                OrderingTerm(expression: c.isDefault, mode: OrderingMode.desc),
            (c) => OrderingTerm(expression: c.title),
          ]))
          .get();

  Future<List<TaxRuleRow>> allRules() => select(taxRules).get();

  Stream<List<TaxJurisdictionRow>> watchJurisdictions() =>
      select(taxJurisdictions).watch();

  /// Всё, что нужно движку, одним снимком.
  ///
  /// Одним, а не тремя запросами из экрана: правила, прочитанные в другой
  /// миг, чем юрисдикции, могут ссылаться на удалённую — и позиция молча
  /// потеряет долю.
  Future<TaxConfiguration> load() async {
    final jurisdictions = await allJurisdictions();
    final categories = await allCategories();
    final rules = await allRules();

    return TaxConfiguration(
      jurisdictions: {
        for (final j in jurisdictions)
          j.id: domain.TaxJurisdictionNode(
            id: j.id,
            name: j.name,
            parentId: j.parentId,
            depth: j.level,
            sortOrder: j.sortOrder,
            isActive: j.isActive,
          ),
      },
      tillJurisdictionIds: jurisdictions
          .where((j) => j.isTillLocation)
          .map((j) => j.id)
          .toList(),
      categories: categories,
      defaultCategoryId: categories.where((c) => c.isDefault).isEmpty
          ? null
          : categories.firstWhere((c) => c.isDefault).id,
      rules: [
        for (final r in rules)
          domain.TaxRule(
            jurisdictionId: r.jurisdictionId,
            categoryId: r.categoryId,
            kind: domain.TaxRuleKind.values[r.kind],
            ratePercent: r.ratePercent,
            validFrom: r.validFrom,
            validTo: r.validTo,
          ),
      ],
    );
  }

  /// Ставит настройку из пресета целиком, одной сделкой.
  ///
  /// Возвращает соответствие «код категории в пресете → её `id` в базе»:
  /// без него нечем пометить товары, а категории без товаров бесполезны.
  Future<Map<String, int>> applyPreset(TaxPreset preset) {
    return transaction(() async {
      // Чистим ПЕРЕД записью и в одной сделке. Пресет ставит настройку
      // целиком: долить его к существующей значило бы сложить доли двух
      // штатов, и касса молча взяла бы двойной налог.
      await delete(taxRules).go();
      await delete(taxJurisdictions).go();
      await delete(taxCategories).go();

      // Уклад и валюта — тоже часть набора, и применяться обязаны вместе
      // с долями.
      //
      // До этой правки применение ставило юрисдикции и молча оставляло
      // «налог включён в цену» и казахстанский знак: пользователь выбирал
      // Денвер, видел на экране 9,15 % — и получал на чеке налог внутри
      // цены и «11.93$». Набор, применённый наполовину, хуже неприменённого:
      // он выглядит применённым.
      await update(thisPosEntries).write(
        ThisPosEntriesCompanion(
          taxTreatment: Value(preset.taxTreatment.index),
          currencySymbol: Value(preset.currencySymbol),
        ),
      );

      final categoryIds = <String, int>{};
      for (final category in preset.categories) {
        categoryIds[category.code] = await into(taxCategories).insert(
          TaxCategoriesCompanion.insert(
            code: category.code,
            title: category.title,
            isDefault: Value(category.isDefault),
          ),
        );
      }

      final jurisdictionIds = <String, int>{};
      // Сначала все узлы, потом связи: родитель может стоять в файле после
      // ребёнка, и разбор этого не запрещает.
      for (var i = 0; i < preset.jurisdictions.length; i++) {
        final j = preset.jurisdictions[i];
        jurisdictionIds[j.code] = await into(taxJurisdictions).insert(
          TaxJurisdictionsCompanion.insert(
            name: j.name,
            level: Value(j.level),
            sortOrder: Value(i),
            isTillLocation: Value(j.isTillLocation),
          ),
        );
      }
      for (final j in preset.jurisdictions) {
        final parent = j.parentCode;
        if (parent == null) continue;
        await (update(
          taxJurisdictions,
        )..where((t) => t.id.equals(jurisdictionIds[j.code]!))).write(
          TaxJurisdictionsCompanion(parentId: Value(jurisdictionIds[parent])),
        );
      }

      final validFrom = DateTime.parse(preset.validFrom);
      for (final j in preset.jurisdictions) {
        for (final r in j.rules) {
          await into(taxRules).insert(
            TaxRulesCompanion.insert(
              jurisdictionId: jurisdictionIds[j.code]!,
              categoryId: Value(
                r.categoryCode == null ? null : categoryIds[r.categoryCode],
              ),
              kind: Value(r.kind.index),
              ratePercent: r.ratePercent,
              validFrom: validFrom,
            ),
          );
        }
      }

      return categoryIds;
    });
  }

  Future<int> addJurisdiction({
    required String name,
    int? parentId,
    int level = 0,
    bool isTillLocation = false,
  }) => into(taxJurisdictions).insert(
    TaxJurisdictionsCompanion.insert(
      name: name,
      parentId: Value(parentId),
      level: Value(level),
      isTillLocation: Value(isTillLocation),
    ),
  );

  Future<void> setTillLocation(int jurisdictionId, {required bool value}) =>
      (update(taxJurisdictions)..where((t) => t.id.equals(jurisdictionId)))
          .write(TaxJurisdictionsCompanion(isTillLocation: Value(value)));

  /// Удаляет юрисдикцию вместе с её правилами и потомками.
  ///
  /// Вместе, а не отдельно: правило осиротевшей юрисдикции не применяется,
  /// но в базе остаётся, и следующая юрисдикция с тем же `id` получила бы
  /// чужую ставку.
  Future<void> removeJurisdiction(int jurisdictionId) {
    return transaction(() async {
      final children = await (select(
        taxJurisdictions,
      )..where((t) => t.parentId.equals(jurisdictionId))).get();
      for (final child in children) {
        await removeJurisdiction(child.id);
      }
      await (delete(
        taxRules,
      )..where((t) => t.jurisdictionId.equals(jurisdictionId))).go();
      await (delete(
        taxJurisdictions,
      )..where((t) => t.id.equals(jurisdictionId))).go();
    });
  }

  Future<int> addCategory({
    required String code,
    required String title,
    bool isDefault = false,
  }) => into(taxCategories).insert(
    TaxCategoriesCompanion.insert(
      code: code,
      title: title,
      isDefault: Value(isDefault),
    ),
  );

  Future<int> addRule({
    required int jurisdictionId,
    int? categoryId,
    domain.TaxRuleKind kind = domain.TaxRuleKind.taxed,
    required Decimal ratePercent,
    required DateTime validFrom,
    DateTime? validTo,
  }) {
    // Проверка домена — здесь же, до записи: противоречивое правило,
    // попавшее в базу, всплывёт у кассира на чеке.
    domain.TaxRule(
      jurisdictionId: jurisdictionId,
      categoryId: categoryId,
      kind: kind,
      ratePercent: ratePercent,
      validFrom: validFrom,
      validTo: validTo,
    );

    return into(taxRules).insert(
      TaxRulesCompanion.insert(
        jurisdictionId: jurisdictionId,
        categoryId: Value(categoryId),
        kind: Value(kind.index),
        ratePercent: ratePercent,
        validFrom: validFrom,
        validTo: Value(validTo),
      ),
    );
  }

  Future<void> removeRule(int ruleId) =>
      (delete(taxRules)..where((t) => t.id.equals(ruleId))).go();
}

/// Снимок налоговой настройки, готовый к передаче в движок.
class TaxConfiguration {
  const TaxConfiguration({
    required this.jurisdictions,
    required this.tillJurisdictionIds,
    required this.categories,
    required this.defaultCategoryId,
    required this.rules,
  });

  final Map<int, domain.TaxJurisdictionNode> jurisdictions;

  /// Где стоит касса. Пусто — настройка не заведена, налога нет.
  final List<int> tillJurisdictionIds;

  final List<TaxCategory> categories;
  final int? defaultCategoryId;
  final List<domain.TaxRule> rules;

  /// Ставка для позиции этой категории на эту дату.
  ///
  /// `null` в [categoryId] означает «категория по умолчанию», и подставить
  /// её надо здесь: движок о таком соглашении не знает и понял бы `null`
  /// как «правило без категории», а это другое.
  domain.ResolvedTax resolve({int? categoryId, DateTime? on}) =>
      domain.resolveTax(
        jurisdictionIds: tillJurisdictionIds,
        categoryId: categoryId ?? defaultCategoryId,
        on: on ?? DateTime.now(),
        jurisdictions: jurisdictions,
        rules: rules,
      );

  /// Настройка заведена: есть где стоять и есть чему применяться.
  bool get isConfigured => tillJurisdictionIds.isNotEmpty && rules.isNotEmpty;
}

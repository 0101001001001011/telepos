/// Налоговый пресет: готовый набор настройки для страны, штата или города.
///
/// # Зачем
///
/// Решение заказчика 2026-09-21: «набор настроек должен привязываться к
/// стране, механика должна быть универсальной, и нужно место для пресетов,
/// чтобы их можно было в виде json положить — и всё».
///
/// Пресеты лежат в `assets/tax_presets/*.json`. Добавить страну или штат —
/// значит положить файл, а не править код.
///
/// # Пресет — отправная точка, а не власть
///
/// Загрузка **копирует** значения в настройку кассы. Дальше касса живёт
/// своей настройкой, и обновление продукта её не трогает.
///
/// Иначе вышло бы худшее: магазин настроил ставку под себя, приехало
/// обновление с «более свежим» пресетом — и налог в чеках поменялся сам, без
/// ведома владельца. За налог отвечает налогоплательщик, а не продукт, и
/// менять его молча нельзя.
///
/// # Ставка приходит строкой, а не числом JSON
///
/// `"ratePercent": "8.25"`, не `8.25`. Числа JSON — двоичные `double`, и
/// 0,1 в них не представима точно. Деньги и ставки в этом проекте —
/// `Decimal`, никогда `double`; пропустить ставку через `double` значит
/// внести ошибку там, где она дороже всего.
library;

import 'package:decimal/decimal.dart';
import 'package:telepos/core/constants/enums/tax_treatment.dart';
import 'package:telepos/domain/tax/tax_resolution.dart';

/// Налоговая категория в пресете.
class TaxPresetCategory {
  const TaxPresetCategory({
    required this.code,
    required this.title,
    required this.isDefault,
  });

  final String code;
  final String title;
  final bool isDefault;
}

/// Правило в пресете: что юрисдикция делает с категорией.
class TaxPresetRule {
  /// Отказывает на противоречии **при загрузке**, а не при продаже.
  ///
  /// Ту же проверку держит `TaxRule`, но она срабатывала бы только когда
  /// движок соберёт правило — то есть у кассира на чеке. Пресет с ошибкой
  /// обязан не доехать до пользователя вовсе.
  TaxPresetRule({
    required this.categoryCode,
    required this.kind,
    required this.ratePercent,
  }) {
    if (kind != TaxRuleKind.taxed && ratePercent != Decimal.zero) {
      throw ArgumentError.value(
        ratePercent,
        'ratePercent',
        'правило вида $kind обязано иметь нулевую ставку: '
            '«освобождено по ставке $ratePercent%» истолковать нельзя',
      );
    }
  }

  /// `null` — все категории, у которых нет своего правила.
  final String? categoryCode;

  final TaxRuleKind kind;
  final Decimal ratePercent;
}

/// Юрисдикция в пресете.
class TaxPresetJurisdiction {
  const TaxPresetJurisdiction({
    required this.code,
    required this.name,
    required this.level,
    required this.parentCode,
    required this.isTillLocation,
    required this.rules,
  });

  /// Устойчивый код: по нему на юрисдикцию ссылаются родитель и правила.
  final String code;

  /// Название так, как его печатают на чеке.
  final String name;

  /// Глубина: 0 страна, 1 штат, 2 округ, 3 город, 4 спецрайон.
  final int level;

  final String? parentCode;

  /// Касса стоит в этой юрисдикции.
  ///
  /// Отметок несколько: город и спецрайоны. Предки отмечаться не обязаны —
  /// они добавляются сами.
  final bool isTillLocation;

  final List<TaxPresetRule> rules;
}

/// Набор налоговой настройки, готовый к применению.
class TaxPreset {
  const TaxPreset({
    required this.id,
    required this.title,
    required this.countryCode,
    required this.region,
    required this.city,
    required this.taxTreatment,
    required this.hasFiscalisation,
    required this.currencySymbol,
    required this.currencyBeforeAmount,
    required this.expectedStandardRatePercent,
    required this.categories,
    required this.jurisdictions,
    required this.validFrom,
    required this.source,
  });

  /// Разбирает пресет и **отказывает**, если он не сходится.
  ///
  /// Отказ, а не терпимость: пресет с ошибкой выдаст покупателю неверный
  /// налоговый документ. Такой пресет до пользователя доезжать не должен
  /// вовсе.
  factory TaxPreset.fromJson(Map<String, Object?> json) {
    final id = json['id'];

    String need(String key) {
      final value = json[key];
      if (value is! String || value.isEmpty) {
        throw FormatException(
          'Пресет «${id ?? '?'}»: поле "$key" обязательно и должно быть '
          'непустой строкой',
        );
      }
      return value;
    }

    Decimal rate(String key, Object? raw) {
      if (raw is! String) {
        throw FormatException(
          'Пресет «${id ?? '?'}»: "$key" обязан быть СТРОКОЙ ("8.25"), а не '
          'числом JSON. Числа JSON — двоичные double, и ставка через них '
          'теряет точность.',
        );
      }
      return Decimal.parse(raw);
    }

    final categories = (json['categories'] as List<Object?>? ?? [])
        .cast<Map<String, Object?>>()
        .map(
          (c) => TaxPresetCategory(
            code: c['code']! as String,
            title: c['title']! as String,
            isDefault: c['isDefault'] as bool? ?? false,
          ),
        )
        .toList();

    final defaults = categories.where((c) => c.isDefault);
    if (categories.isNotEmpty && defaults.length != 1) {
      throw FormatException(
        'Пресет «$id»: категорий по умолчанию ${defaults.length}, а нужна '
        'ровно одна. Ноль означал бы товар без облагаемости вовсе, две — '
        'что выбор между ними делает случай.',
      );
    }

    final codes = categories.map((c) => c.code).toSet();

    final jurisdictions = (json['jurisdictions'] as List<Object?>? ?? [])
        .cast<Map<String, Object?>>()
        .map((j) {
          final rules = (j['rules'] as List<Object?>? ?? [])
              .cast<Map<String, Object?>>()
              .map((r) {
                final category = r['category'] as String?;
                if (category != null && !codes.contains(category)) {
                  throw FormatException(
                    'Пресет «$id»: правило ссылается на категорию '
                    '«$category», которой в пресете нет. Молча пропустить '
                    'значит обложить её по общей ставке — а заводили её '
                    'ровно затем, чтобы этого не было.',
                  );
                }
                return TaxPresetRule(
                  categoryCode: category,
                  kind: _kind(r['kind'], id),
                  ratePercent: rate('rules[].ratePercent', r['ratePercent']),
                );
              })
              .toList();

          return TaxPresetJurisdiction(
            code: j['code']! as String,
            name: j['name']! as String,
            level: j['level']! as int,
            parentCode: j['parent'] as String?,
            isTillLocation: j['tillLocation'] as bool? ?? false,
            rules: rules,
          );
        })
        .toList();

    final jurisdictionCodes = jurisdictions.map((j) => j.code).toSet();
    for (final j in jurisdictions) {
      final parent = j.parentCode;
      if (parent != null && !jurisdictionCodes.contains(parent)) {
        throw FormatException(
          'Пресет «$id»: юрисдикция «${j.code}» ссылается на родителя '
          '«$parent», которого в пресете нет — доля родителя не взимется',
        );
      }
    }

    if (jurisdictions.isNotEmpty &&
        !jurisdictions.any((j) => j.isTillLocation)) {
      throw FormatException(
        'Пресет «$id»: ни одна юрисдикция не отмечена как место кассы. '
        'Такой пресет заводит ставки и не применяет ни одной: касса '
        'посчитала бы ноль.',
      );
    }

    return TaxPreset(
      id: need('id'),
      title: need('title'),
      countryCode: need('countryCode'),
      region: json['region'] as String?,
      city: json['city'] as String?,
      taxTreatment: _treatment(json['taxTreatment'], id),
      hasFiscalisation: json['hasFiscalisation'] as bool? ?? true,
      currencySymbol: need('currencySymbol'),
      currencyBeforeAmount: json['currencyBeforeAmount'] as bool? ?? false,
      expectedStandardRatePercent: rate(
        'expectedStandardRatePercent',
        json['expectedStandardRatePercent'],
      ),
      categories: categories,
      jurisdictions: jurisdictions,
      // Обязательны оба: пресет без даты и ссылки нельзя проверить —
      // непонятно, устарел он или нет и где смотреть правду. Ставки
      // Колорадо, например, меняются дважды в год.
      validFrom: need('validFrom'),
      source: need('source'),
    );
  }

  static TaxTreatment _treatment(Object? raw, Object? id) => switch (raw) {
    'inclusive' => TaxTreatment.inclusive,
    'exclusive' => TaxTreatment.exclusive,
    'none' => TaxTreatment.none,
    _ => throw FormatException(
      'Пресет «$id»: "taxTreatment" обязан быть одним из inclusive / '
      'exclusive / none, а не «$raw»',
    ),
  };

  static TaxRuleKind _kind(Object? raw, Object? id) => switch (raw) {
    'taxed' || null => TaxRuleKind.taxed,
    'zero' => TaxRuleKind.zero,
    'exempt' => TaxRuleKind.exempt,
    _ => throw FormatException(
      'Пресет «$id»: "kind" обязан быть одним из taxed / zero / exempt, а не '
      '«$raw». Ноль и освобождение — разные режимы, и подменить одно другим '
      'значит соврать в отчётности.',
    ),
  };

  final String id;
  final String title;

  /// Двухбуквенный код страны: первый уровень выбора.
  final String countryCode;

  /// Штат или область: второй уровень. `null` — пресет на всю страну.
  final String? region;

  /// Город: третий уровень. `null` — пресет на весь регион.
  final String? city;

  final TaxTreatment taxTreatment;
  final bool hasFiscalisation;
  final String currencySymbol;
  final bool currencyBeforeAmount;

  /// Какую ставку пресет обещает для обычного товара.
  ///
  /// Не используется в расчёте: это **заявление**, которое сторож проверяет,
  /// прогоняя пресет через настоящий движок. Заявленное число сверяют с
  /// источником глазами, а совпадение с выведенным — пробой.
  final Decimal expectedStandardRatePercent;

  final List<TaxPresetCategory> categories;
  final List<TaxPresetJurisdiction> jurisdictions;

  /// С какой даты ставки верны.
  final String validFrom;

  /// Откуда взяты числа. Обязательно — иначе пресет непроверяем.
  final String source;

  /// Собирает из пресета то, что нужно движку, и выводит ставку.
  ///
  /// Нужен сторожу и предпросмотру в настройке: пользователь обязан видеть,
  /// что получится, **до** того как применит пресет.
  ResolvedTax resolveFor(String? categoryCode) {
    final ids = <String, int>{};
    for (final j in jurisdictions) {
      ids[j.code] = ids.length + 1;
    }
    final categoryIds = <String, int>{};
    for (final c in categories) {
      categoryIds[c.code] = categoryIds.length + 1;
    }

    final nodes = {
      for (final j in jurisdictions)
        ids[j.code]!: TaxJurisdictionNode(
          id: ids[j.code]!,
          name: j.name,
          parentId: j.parentCode == null ? null : ids[j.parentCode],
          depth: j.level,
        ),
    };

    final rules = [
      for (final j in jurisdictions)
        for (final r in j.rules)
          TaxRule(
            jurisdictionId: ids[j.code]!,
            categoryId: r.categoryCode == null
                ? null
                : categoryIds[r.categoryCode],
            kind: r.kind,
            ratePercent: r.ratePercent,
            validFrom: DateTime.utc(2000),
          ),
    ];

    return resolveTax(
      jurisdictionIds: jurisdictions
          .where((j) => j.isTillLocation)
          .map((j) => ids[j.code]!),
      categoryId: categoryCode == null ? null : categoryIds[categoryCode],
      on: DateTime.utc(2000),
      jurisdictions: nodes,
      rules: rules,
    );
  }
}

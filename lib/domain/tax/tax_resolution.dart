/// Вывод ставки: где продали + что продали + когда продали.
///
/// # Зачем отдельный слой
///
/// Ставка нигде не хранится готовым числом. Разбор мировой практики
/// (`docs/internal/research/2026-09-21-tax-configuration-models.md`) показал,
/// что везде она выводится из юрисдикции, категории товара и даты. Этот файл
/// и есть тот вывод — чистый Dart, без базы и без интерфейса, чтобы его
/// можно было проверять на бумажных примерах из налоговых руководств.
///
/// # Главный случай, ради которого всё это
///
/// Денвер, еда для дома. Штат Колорадо её **не облагает**, а Денвер берёт
/// свои 5,15 % — город с самоуправлением вправе облагать то, что штат
/// освободил. Плоская ставка этот случай не выражает: пришлось бы облагать
/// еду целиком или освобождать целиком, и то и другое неверно.
///
/// # Касса стоит в НАБОРЕ юрисдикций, а не на ветке
///
/// Иерархия нужна для выбора и наследования: выбрал страну — стали доступны
/// штаты, выбрал штат — города. Но арифметику по ней вести нельзя.
///
/// Спецрайоны Денвера — RTD (транспорт) и SCFD (культура) — накрывают
/// несколько городов сразу и потому **не являются предками** Денвера.
/// Подъём по цепочке родителей их не достаёт: касса в Денвере получила бы
/// 8,05 % вместо 9,15 %. Так же устроены и базы ставок, которые SSUTA
/// требует от штатов: почтовый индекс отображается в **список** органов, а
/// не в путь по дереву.
///
/// Поэтому касса хранит набор юрисдикций, а предки к нему добавляются.
library;

import 'package:decimal/decimal.dart';

/// Узел иерархии юрисдикций.
class TaxJurisdictionNode {
  const TaxJurisdictionNode({
    required this.id,
    required this.name,
    required this.parentId,
    this.depth = 0,
    this.sortOrder = 0,
    this.isActive = true,
  });

  final int id;
  final String name;
  final int? parentId;

  /// Насколько глубоко в иерархии: страна 0, штат 1, город 3 и так далее.
  /// Задаёт порядок печати разбивки — сверху вниз.
  final int depth;

  /// Порядок внутри одной глубины.
  final int sortOrder;

  final bool isActive;
}

/// Что юрисдикция делает с категорией.
enum TaxRuleKind {
  /// Облагается по ставке.
  taxed,

  /// Облагается по нулевой ставке: в базе есть, налог ноль.
  zero,

  /// Освобождено: вне налоговой базы.
  exempt,
}

/// Правило «юрисдикция × категория × срок».
class TaxRule {
  /// Отказывает на противоречивом правиле, а не молчит.
  ///
  /// Правило «освобождено по ставке 5 %» невозможно истолковать: оно
  /// одновременно утверждает, что налога нет и что он пять процентов.
  /// Пропустить такое значит выбрать за пользователя одно из двух
  /// толкований и напечатать его на налоговом документе.
  TaxRule({
    required this.jurisdictionId,
    required this.categoryId,
    required this.kind,
    required this.ratePercent,
    required this.validFrom,
    this.validTo,
  }) {
    if (kind != TaxRuleKind.taxed && ratePercent != Decimal.zero) {
      throw ArgumentError.value(
        ratePercent,
        'ratePercent',
        'правило вида $kind обязано иметь нулевую ставку: '
            '«освобождено по ставке $ratePercent%» истолковать нельзя',
      );
    }
    if (ratePercent < Decimal.zero) {
      throw ArgumentError.value(ratePercent, 'ratePercent', 'ставка < 0');
    }
    if (validTo != null && validTo!.isBefore(validFrom)) {
      throw ArgumentError.value(
        validTo,
        'validTo',
        'срок правила кончается раньше, чем начинается',
      );
    }
  }

  final int jurisdictionId;

  /// `null` — правило для всех категорий, у которых нет своего.
  final int? categoryId;

  final TaxRuleKind kind;
  final Decimal ratePercent;
  final DateTime validFrom;
  final DateTime? validTo;

  bool appliesOn(DateTime moment) {
    if (moment.isBefore(validFrom)) return false;
    final until = validTo;
    return until == null || !moment.isAfter(until);
  }
}

/// Доля одной юрисдикции в выведенной ставке.
class ResolvedTaxShare {
  const ResolvedTaxShare({
    required this.jurisdictionId,
    required this.name,
    required this.ratePercent,
    required this.kind,
  });

  final int jurisdictionId;
  final String name;
  final Decimal ratePercent;
  final TaxRuleKind kind;
}

/// Итог вывода для одной позиции чека.
class ResolvedTax {
  const ResolvedTax({required this.shares});

  /// Доли сверху вниз: страна, штат, округ, город, спецрайоны.
  ///
  /// Освобождённые юрисдикции сюда не попадают — на чеке их печатать
  /// нечем, а в сумме они дают ноль.
  final List<ResolvedTaxShare> shares;

  /// Суммарная ставка. Ноль, если облагать нечему.
  Decimal get totalRatePercent =>
      shares.fold(Decimal.zero, (sum, share) => sum + share.ratePercent);

  /// Позиция вне налоговой базы: **ни одна** юрисдикция её не облагает.
  ///
  /// Не то же, что нулевая ставка. Позиция с нулевой ставкой в базе есть и
  /// в отчётность попадает; освобождённая — нет. ЕС разводит эти режимы
  /// формально, по праву вычета.
  bool get isExempt => shares.isEmpty;

  /// Позиция в базе, но налог по ней ноль.
  bool get isZeroRated => shares.isNotEmpty && totalRatePercent == Decimal.zero;
}

/// Выводит ставку для позиции.
///
/// [jurisdictionIds] — где стоит касса. Обычно это одна запись (город) и
/// сколько-то спецрайонов; предки добавляются сами, потому что доля штата
/// взимается и без отдельного упоминания.
///
/// Каждая юрисдикция спрашивается **отдельно**: ответы у них независимые.
/// Правило со своей категорией бьёт правило без категории — «штат берёт
/// 2,9 % со всего, кроме еды» записывается двумя правилами, и правило про
/// еду обязано победить.
///
/// Юрисдикция, у которой правила нет вовсе, в разбивку не попадает: молчание
/// — это «меня не касается», а не «ноль».
ResolvedTax resolveTax({
  required Iterable<int> jurisdictionIds,
  required int? categoryId,
  required DateTime on,
  required Map<int, TaxJurisdictionNode> jurisdictions,
  required List<TaxRule> rules,
}) {
  final collected = <int, TaxJurisdictionNode>{};

  for (final start in jurisdictionIds) {
    final seen = <int>{};
    int? cursor = start;
    while (cursor != null) {
      // Цикл в родителях — испорченная настройка, а не повод зациклиться:
      // без этой проверки касса вешалась бы при пробитии чека.
      if (!seen.add(cursor)) {
        throw StateError(
          'Цикл в иерархии юрисдикций около #$cursor: настройка испорчена',
        );
      }
      final node = jurisdictions[cursor];
      if (node == null) break;
      // Выключенная выпадает сама, но подъём продолжается: доля штата
      // взимается независимо от того, выключен ли город под ним.
      if (node.isActive) collected[node.id] = node;
      cursor = node.parentId;
    }
  }

  // Сверху вниз: так печатают чек и так читает бухгалтер.
  final ordered = collected.values.toList()
    ..sort((a, b) {
      final byDepth = a.depth.compareTo(b.depth);
      if (byDepth != 0) return byDepth;
      final byOrder = a.sortOrder.compareTo(b.sortOrder);
      return byOrder != 0 ? byOrder : a.id.compareTo(b.id);
    });

  final shares = <ResolvedTaxShare>[];
  for (final node in ordered) {
    final applicable = rules
        .where((r) => r.jurisdictionId == node.id && r.appliesOn(on))
        .toList();

    final specific = applicable.where((r) => r.categoryId == categoryId);
    final wildcard = applicable.where((r) => r.categoryId == null);

    final rule = specific.isNotEmpty
        ? specific.first
        : (wildcard.isNotEmpty ? wildcard.first : null);

    if (rule == null || rule.kind == TaxRuleKind.exempt) continue;

    shares.add(
      ResolvedTaxShare(
        jurisdictionId: node.id,
        name: node.name,
        ratePercent: rule.ratePercent,
        kind: rule.kind,
      ),
    );
  }

  return ResolvedTax(shares: shares);
}

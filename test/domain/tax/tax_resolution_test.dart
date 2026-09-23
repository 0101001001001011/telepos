/// Вывод ставки проверяется бумажными примерами из налоговых руководств.
///
/// # Почему именно Денвер
///
/// Заказчик просил взять самый сложный штат, «чтобы больше поймать gap».
/// Колорадо — штат с городским самоуправлением: Денвер администрирует свою
/// долю сам и облагает то, что штат освободил. Плюс два спецрайона, которые
/// накрывают несколько городов и потому не вкладываются в город. Это худший
/// случай, и если модель выражает его, она выражает и простые.
///
/// Числа: Denver Tax Guide Topic No. 70 (2026), Colorado DR 1002.
library;

import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telepos/domain/tax/tax_resolution.dart';

void main() {
  Decimal d(String s) => Decimal.parse(s);

  // Штат — корень. Денвер и оба спецрайона висят на штате: RTD и SCFD
  // накрывают несколько городов сразу и предками Денвера не являются.
  const co = TaxJurisdictionNode(id: 1, name: 'CO State', parentId: null);
  const denver = TaxJurisdictionNode(
    id: 2,
    name: 'Denver',
    parentId: 1,
    depth: 3,
  );
  const rtd = TaxJurisdictionNode(
    id: 3,
    name: 'RTD',
    parentId: 1,
    depth: 4,
    sortOrder: 1,
  );
  const scfd = TaxJurisdictionNode(
    id: 4,
    name: 'SCFD',
    parentId: 1,
    depth: 4,
    sortOrder: 2,
  );

  final tree = {1: co, 2: denver, 3: rtd, 4: scfd};

  /// Где стоит касса: город и оба спецрайона. Штат добавится сам.
  const denverTill = [2, 3, 4];

  const standard = 10;
  const foodHome = 11;

  final jan = DateTime.utc(2026, 1, 15);

  List<TaxRule> denverRules() => [
    TaxRule(
      jurisdictionId: 1,
      categoryId: null,
      kind: TaxRuleKind.taxed,
      ratePercent: d('2.90'),
      validFrom: DateTime.utc(2026),
    ),
    // Колорадо не облагает еду для дома.
    TaxRule(
      jurisdictionId: 1,
      categoryId: foodHome,
      kind: TaxRuleKind.exempt,
      ratePercent: Decimal.zero,
      validFrom: DateTime.utc(2026),
    ),
    // А Денвер — облагает, и по своей полной ставке.
    TaxRule(
      jurisdictionId: 2,
      categoryId: null,
      kind: TaxRuleKind.taxed,
      ratePercent: d('5.15'),
      validFrom: DateTime.utc(2026),
    ),
    TaxRule(
      jurisdictionId: 3,
      categoryId: null,
      kind: TaxRuleKind.taxed,
      ratePercent: d('1.00'),
      validFrom: DateTime.utc(2026),
    ),
    TaxRule(
      jurisdictionId: 4,
      categoryId: null,
      kind: TaxRuleKind.taxed,
      ratePercent: d('0.10'),
      validFrom: DateTime.utc(2026),
    ),
  ];

  ResolvedTax resolveIn(
    List<int> where,
    int? category, {
    DateTime? on,
    Map<int, TaxJurisdictionNode>? tree_,
  }) => resolveTax(
    jurisdictionIds: where,
    categoryId: category,
    on: on ?? jan,
    jurisdictions: tree_ ?? tree,
    rules: denverRules(),
  );

  group('Денвер, обычный товар', () {
    test('ставка складывается из четырёх долей и равна 9,15 %', () {
      expect(resolveIn(denverTill, standard).totalRatePercent, d('9.15'));
    });

    test('штат попадает в разбивку, хотя касса о нём не заявляла', () {
      expect(
        resolveIn(denverTill, standard).shares.map((s) => s.name).toList(),
        ['CO State', 'Denver', 'RTD', 'SCFD'],
        reason:
            'разбивка идёт сверху вниз: бухгалтер отчитывается по каждой '
            'юрисдикции отдельно и читает её в этом порядке',
      );
    });

    test('спецрайоны НЕ достаются подъёмом по родителям', () {
      // Проба ловит ровно ту ошибку, что была в первой версии: подъём от
      // города вверх добирает штат, но не соседей по штату.
      expect(
        resolveIn(const [2], standard).totalRatePercent,
        d('8.05'),
        reason:
            'если бы это давало 9,15 %, значит спецрайоны добираются '
            'иерархией — а они накрывают несколько городов и предками '
            'города не являются',
      );
    });
  });

  group('еда для дома: штат освободил, город облагает', () {
    test('еда облагается по 6,25 %, а не по 9,15 и не по нулю', () {
      expect(
        resolveIn(denverTill, foodHome).totalRatePercent,
        d('6.25'),
        reason:
            'ради этого случая вся модель и переделана: плоская ставка '
            'заставила бы облагать еду целиком или освободить целиком',
      );
    });

    test('доля штата из разбивки исчезает, а не становится нулём', () {
      expect(
        resolveIn(denverTill, foodHome).shares.map((s) => s.name).toList(),
        ['Denver', 'RTD', 'SCFD'],
        reason:
            'печатать «CO State 0,00 %» значит утверждать, что штат '
            'облагает по нулю; он не облагает вовсе — это разные режимы',
      );
    });

    test('там, где только штат, еда не облагается и позиция освобождена', () {
      final resolved = resolveIn(const [1], foodHome);
      expect(resolved.shares, isEmpty);
      expect(resolved.isExempt, isTrue);
      expect(resolved.totalRatePercent, Decimal.zero);
    });
  });

  test('нулевая ставка остаётся в разбивке, освобождение — нет', () {
    final zero = resolveTax(
      jurisdictionIds: const [1],
      categoryId: standard,
      on: jan,
      jurisdictions: tree,
      rules: [
        TaxRule(
          jurisdictionId: 1,
          categoryId: standard,
          kind: TaxRuleKind.zero,
          ratePercent: Decimal.zero,
          validFrom: DateTime.utc(2026),
        ),
      ],
    );
    expect(zero.totalRatePercent, Decimal.zero);
    expect(zero.isZeroRated, isTrue);
    expect(
      zero.isExempt,
      isFalse,
      reason:
          'нулевая ставка оставляет позицию в налоговой базе, освобождение '
          'выводит из неё; ЕС разводит их по праву вычета',
    );
  });

  group('дата', () {
    List<TaxRule> fromJuly() => [
      TaxRule(
        jurisdictionId: 1,
        categoryId: null,
        kind: TaxRuleKind.taxed,
        ratePercent: d('3.90'),
        validFrom: DateTime.utc(2026, 7),
      ),
    ];

    test('ставка «с первого июля» до июля не действует', () {
      final before = resolveTax(
        jurisdictionIds: const [1],
        categoryId: standard,
        on: DateTime.utc(2026, 6, 30),
        jurisdictions: tree,
        rules: fromJuly(),
      );
      final after = resolveTax(
        jurisdictionIds: const [1],
        categoryId: standard,
        on: DateTime.utc(2026, 7),
        jurisdictions: tree,
        rules: fromJuly(),
      );

      expect(before.shares, isEmpty);
      expect(
        after.totalRatePercent,
        d('3.90'),
        reason:
            'ставки Колорадо меняются дважды в год; перепечатанный задним '
            'числом чек обязан считаться по ставке своего дня',
      );
    });

    test('истёкшая ставка не действует', () {
      final resolved = resolveTax(
        jurisdictionIds: const [1],
        categoryId: standard,
        on: jan,
        jurisdictions: tree,
        rules: [
          TaxRule(
            jurisdictionId: 1,
            categoryId: null,
            kind: TaxRuleKind.taxed,
            ratePercent: d('2.90'),
            validFrom: DateTime.utc(2025),
            validTo: DateTime.utc(2025, 12, 31),
          ),
        ],
      );
      expect(resolved.shares, isEmpty);
    });
  });

  group('испорченная настройка отказывает, а не считает', () {
    test('противоречивое правило не создаётся', () {
      expect(
        () => TaxRule(
          jurisdictionId: 1,
          categoryId: null,
          kind: TaxRuleKind.exempt,
          ratePercent: d('5.00'),
          validFrom: DateTime.utc(2026),
        ),
        throwsArgumentError,
        reason:
            '«освобождено по ставке 5 %» истолковать нельзя; пропустить '
            'значит выбрать толкование за пользователя и напечатать его',
      );
    });

    test('цикл в родителях не вешает кассу', () {
      const a = TaxJurisdictionNode(id: 1, name: 'A', parentId: 2);
      const b = TaxJurisdictionNode(id: 2, name: 'B', parentId: 1);
      expect(
        () => resolveTax(
          jurisdictionIds: const [1],
          categoryId: null,
          on: jan,
          jurisdictions: {1: a, 2: b},
          rules: const [],
        ),
        throwsStateError,
        reason: 'иначе касса зависла бы при пробитии чека',
      );
    });

    test('выключённый город выпадает, но штат и районы остаются', () {
      const off = TaxJurisdictionNode(
        id: 2,
        name: 'Denver',
        parentId: 1,
        depth: 3,
        isActive: false,
      );
      expect(
        resolveIn(
          denverTill,
          standard,
          tree_: {1: co, 2: off, 3: rtd, 4: scfd},
        ).shares.map((s) => s.name).toList(),
        ['CO State', 'RTD', 'SCFD'],
        reason:
            'выключение города не должно отрезать штат: доля штата '
            'взимается независимо',
      );
    });
  });
}

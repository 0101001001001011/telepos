import 'package:decimal/decimal.dart';
import 'package:telepos/domain/fiscal/fiscal_models.dart';
import 'package:telepos/domain/fiscal/fiscal_settings.dart';

/// Сборка позиции фискального документа — и **единственное место, где
/// рождается число поля `Discount`**.
///
/// # Владелец поля один, и это [lineDiscount]
///
/// У позиции в конверте оператора одно поле скидки
/// (`WebKassaProvider._positionToJson`, ключ `Discount`). Формула его
/// значения живёт здесь и больше нигде. Всё, что должно уменьшить сумму
/// строки — ручная скидка кассира и списанный бонус покупателя, — входит
/// в **эту** формулу **слагаемым** ([extraDiscount]), а не заводит второе
/// поле и не добавляет второй независимый `totalDiscount` чеку.
///
/// **Точка расширения занята бонусом (задача 7)**, и занята она именно
/// так, как была задумана: `FiscalServiceImpl._buildSalePositions`
/// раскладывает списанный бонус по строкам ([distributeBonus]) и отдаёт
/// долю каждой строки сюда доводом [extraDiscount]. Следующему, кому
/// понадобится уменьшить платёж покупателя, — сюда же.
///
/// **Цена ошибки посчитана.** `_buildTax` считает НДС от [taxableLine], то
/// есть от суммы, которую покупатель платит за строку. Скидка, посчитанная
/// дважды — своим полем и вычетом из `lineTotal`, — занижает базу налога на
/// 10,71 % от суммы второго слагаемого, а оператор отвергает расхождение
/// сумм кодом 9 (`FiscalErrorCode.validation`). Для кассира это выглядит
/// как «деньги взяты, документа нет» на **каждой** такой продаже.
///
/// # Почему скидка выводится, а не приходит извне
///
/// Оператор считает строку как `round(Count × Price, 2) − Discount`, то
/// есть **по уже округлённым** числам конверта: `Price` уезжает с двумя
/// разрядами (`WebKassaProvider._money`), `Count` с тремя (`_qty`). Цена же
/// единицы лежит в базе с запасом по разрядам —
/// `LocalCartService._perUnitScale` = 10, `LocalSaleCheckoutService
/// ._moneyScale` = 3, — потому что скидка, не делящаяся нацело на
/// количество, иначе искажалась бы при обратном чтении.
///
/// Из-за этого разрыва масштабов скидка, посчитанная из **неокруглённых**
/// чисел, не сводит строку. Замер: три штуки по 100 со скидкой 100 дают
/// цену единицы 66.6666666667 → в конверте 66.67 → `3 × 66.67 = 200.01`
/// против оплаты 200.00. Семь штук по 100 со скидкой 100 промахиваются уже
/// на три копейки: `7 × 85.71 = 599.97` против 600.00.
///
/// Поэтому [lineDiscount] округляет **сначала**, вычитает **потом**:
/// скидка — это разность между тем, что оператор насчитает по конверту, и
/// тем, что с покупателя действительно взяли. При таком порядке
/// `Price × Count − Discount` равно сумме строки **тождественно**, при
/// любом масштабе хранения цены. Обратный порядок — округлить готовую
/// скидку — возвращает ровно ту копейку, ради которой это написано.
class FiscalPositionBuilder {
  const FiscalPositionBuilder();

  static final Decimal _hundred = Decimal.fromInt(100);

  /// Разряды денег в конверте — те же, что у `WebKassaProvider._money`.
  static const int moneyScale = 2;

  /// Разряды количества в конверте — те же, что у `WebKassaProvider._qty`.
  static const int quantityScale = 3;

  /// НДС, выделенный из суммы **с налогом**.
  ///
  /// # Округление здесь считалось дважды, а работало один раз
  ///
  /// Стояло `toDecimal(scaleOnInfinitePrecision: 2).round(scale: 2)`, и
  /// это не «округлить с запасом, потом до копейки»:
  /// `Rational.toDecimal` при бесконечной дроби **отсекает**
  /// (`Rational.truncate` — умолчание пакета), поэтому до `round` уже
  /// доезжали два разряда, и сам `round` был пустым действием.
  ///
  /// Измерено (задача 7, эта правка): 12 % от 200 — это 21.428571…,
  /// отсечение давало **21.42**, а пересчёт оператора
  /// (`lib/emulators/webkassa/state.dart`, `scaleOnInfinitePrecision: 4`)
  /// даёт **21.43** и отвергает расхождение. Копейка на строку, всегда в
  /// сторону занижения налога, на каждом чеке плательщика НДС.
  ///
  /// Найдено оттого, что бонусная проба впервые прогнала пересчёт
  /// оператора **с включённым НДС** над позицией, собранной продуктом:
  /// живой проход и пробы задачи 6 идут с `VatMode.off`, где эта ветка
  /// пересчёта не выполняется вовсе.
  ///
  /// Разрядов теперь с запасом, и округляет **только** `round`.
  static Decimal vatFromGross(Decimal lineTotal, Decimal ratePercent) {
    if (ratePercent <= Decimal.zero) return Decimal.zero;
    final denominator = _hundred + ratePercent;
    final rational = (lineTotal * ratePercent) / denominator;
    return rational
        .toDecimal(scaleOnInfinitePrecision: moneyScale + 8)
        .round(scale: moneyScale);
  }

  /// Скидка строки — число поля `Discount` позиции.
  ///
  /// `discount = round(round(quantity) × round(priceBefore)) −
  /// round(lineTotal) + round(extraDiscount)`
  ///
  /// - [priceBefore] — цена единицы **до** скидки: та, что уезжает в
  ///   конверт полем `Price`;
  /// - [lineTotal] — сколько за строку берут с покупателя **сегодняшними**
  ///   средствами (ручная скидка кассира уже сидит в цене единицы, см.
  ///   `LocalCartService`);
  /// - [extraDiscount] — **точка расширения**. Слагаемое для всего, что
  ///   уменьшает платёж покупателя, не трогая цену строки в базе. Первый
  ///   такой случай — списанный бонус: он уходит с бонусного счёта, в
  ///   оплаты чека не попадает, и без слагаемого сумма позиций окажется
  ///   больше суммы оплат ровно на бонус. Добавлять сюда, а не заводить
  ///   второе поле.
  ///
  /// Отрицательной не бывает: если цена после «скидки» выше цены до неё
  /// (наценка), возвращается ноль, а разность уходит в [lineMarkup] —
  /// иначе `_positionToJson` молча выбросил бы отрицательное значение и
  /// строка разошлась бы с оплатой.
  static Decimal lineDiscount({
    required Decimal quantity,
    required Decimal priceBefore,
    required Decimal lineTotal,
    Decimal? extraDiscount,
  }) {
    final delta = _delta(
      quantity: quantity,
      priceBefore: priceBefore,
      lineTotal: lineTotal,
      extraDiscount: extraDiscount,
    );
    return delta > Decimal.zero ? delta : Decimal.zero;
  }

  /// Наценка строки — та же разность с обратным знаком.
  ///
  /// Существует не ради полноты: `_positionToJson` кладёт `Discount`
  /// только при положительном значении, поэтому отрицательная скидка
  /// исчезла бы бесследно и увела бы чек в отказ кодом 9.
  static Decimal lineMarkup({
    required Decimal quantity,
    required Decimal priceBefore,
    required Decimal lineTotal,
    Decimal? extraDiscount,
  }) {
    final delta = _delta(
      quantity: quantity,
      priceBefore: priceBefore,
      lineTotal: lineTotal,
      extraDiscount: extraDiscount,
    );
    return delta < Decimal.zero ? -delta : Decimal.zero;
  }

  /// Что оператор насчитает по конверту минус то, что взято с покупателя.
  ///
  /// Порядок здесь — всё: округляется **каждый множитель отдельно и до
  /// умножения**, ровно как это делает конверт, и только потом берётся
  /// разность. Стоит переставить округление за вычитание — и копейка
  /// возвращается.
  static Decimal _delta({
    required Decimal quantity,
    required Decimal priceBefore,
    required Decimal lineTotal,
    Decimal? extraDiscount,
  }) {
    final gross =
        (quantity.round(scale: quantityScale) *
                priceBefore.round(scale: moneyScale))
            .round(scale: moneyScale);
    final paid = lineTotal.round(scale: moneyScale);
    final extra = (extraDiscount ?? Decimal.zero).round(scale: moneyScale);
    return gross - paid + extra;
  }

  /// Строка, какой её насчитает оператор, — она же база налога.
  ///
  /// `round2(lineTotal) − round2(extraDiscount)` тождественно равно
  /// `round2(quantity) × round2(priceBefore) − Discount + Markup`
  /// (подставьте [_delta] и сократите `gross`), то есть это ровно то
  /// число, от которого считает НДС пересчёт оператора
  /// (`lib/emulators/webkassa/state.dart`). Своё второе выражение здесь
  /// разошлось бы с ним молча.
  static Decimal taxableLine({
    required Decimal lineTotal,
    Decimal? extraDiscount,
  }) =>
      lineTotal.round(scale: moneyScale) -
      (extraDiscount ?? Decimal.zero).round(scale: moneyScale);

  /// Разложить списанный бонус по строкам чека — **правило, записанное
  /// один раз**.
  ///
  /// Возвращает долю на каждую строку [lineTotals], в том же порядке.
  /// Каждая доля потом уезжает в [lineDiscount] слагаемым
  /// ([lineDiscount.extraDiscount]) — не вторым полем и не вычетом из
  /// цены.
  ///
  /// # Правило
  ///
  /// 1. Вес строки — её сумма, округлённая до копейки ([moneyScale]): это
  ///    ровно те деньги, которые оператор насчитает по строке без бонуса.
  /// 2. Доля — `round2(bonus × вес / Σ весов)`.
  /// 3. Остаток `round2(bonus) − Σ долей` достаётся строке с **наибольшим
  ///    весом**; при равенстве весов — **первой** (строки приходят из
  ///    `SaleProductDao.findBySale`, то есть по возрастанию `id`).
  ///
  /// # Почему масштаб 2, а не 3
  ///
  /// Деньги в базе лежат с тремя разрядами, но в конверт уезжают с двумя
  /// (`WebKassaProvider._money`), и оператор сводит чек по тому, что
  /// приехало. Доля, посчитанная до тысячных, округлилась бы уже внутри
  /// конверта, сумма округлённых долей разошлась бы с бонусом, и чек ушёл
  /// бы в отказ кодом 9 — ровно та беда, ради которой всё это написано.
  /// Поэтому остаток раздаётся **здесь**, в тех же разрядах, в каких
  /// поедет.
  ///
  /// # Границы, названные значением, а не падением
  ///
  /// Пустой чек даёт пустой список; неположительный бонус — нули;
  /// чек нулевой суммы (делить пропорционально нечему) — тоже нули.
  /// Ни один из трёх случаев не бросает: раскладка стоит на пути денег,
  /// и исключение здесь означало бы «деньги взяты, документа нет» на
  /// ровном месте.
  static List<Decimal> distributeBonus({
    required Decimal bonus,
    required List<Decimal> lineTotals,
  }) {
    if (lineTotals.isEmpty) return const <Decimal>[];

    final zeros = List<Decimal>.filled(lineTotals.length, Decimal.zero);
    final target = bonus.round(scale: moneyScale);
    if (target <= Decimal.zero) return zeros;

    final weights = [
      for (final t in lineTotals) t.round(scale: moneyScale),
    ];
    final total = weights.fold(Decimal.zero, (Decimal a, b) => a + b);
    if (total <= Decimal.zero) return zeros;

    final shares = <Decimal>[];
    var handed = Decimal.zero;
    for (final w in weights) {
      final share = ((target * w) / total)
          .toDecimal(scaleOnInfinitePrecision: moneyScale + 8)
          .round(scale: moneyScale);
      shares.add(share);
      handed += share;
    }

    final remainder = target - handed;
    if (remainder != Decimal.zero) {
      var best = 0;
      for (var i = 1; i < weights.length; i++) {
        if (weights[i] > weights[best]) best = i;
      }
      shares[best] += remainder;
    }
    return shares;
  }

  /// Итоговая скидка чека — **сумма позиционных**, а не своё число.
  ///
  /// Оператор складывает итог по позициям сам, и второе независимое число
  /// дало бы второй способ разойтись. До этой правки в четырёх местах
  /// (`fiscal_service_impl.dart:66,114`, `webkassa_service_impl.dart:71,113`)
  /// стоял захардкоженный ноль.
  static Decimal sumDiscounts(Iterable<FiscalPosition> positions) =>
      positions.fold(Decimal.zero, (s, p) => s + p.discountOr);

  /// Итоговая наценка чека — тем же правилом.
  static Decimal sumMarkups(Iterable<FiscalPosition> positions) =>
      positions.fold(Decimal.zero, (s, p) => s + p.markupOr);

  /// Собрать позицию.
  ///
  /// [unitPrice] — цена **до** скидки. Скидку позиция не принимает
  /// готовым числом намеренно: она выводится здесь из [unitPrice],
  /// [quantity] и [lineTotal], и вызывающий не может ни забыть её
  /// передать, ни принести своё число. Ровно эта возможность и была
  /// дефектом: `discount` был необязательным доводом, и **ни один** из
  /// четырёх вызовов его не передавал — скидка не доезжала до оператора
  /// никогда.
  FiscalPosition build({
    required String name,
    required Decimal quantity,
    required Decimal unitPrice,
    required Decimal lineTotal,
    required FiscalSettings settings,
    int? productVatRate,
    String? ntin,
    String? barcode,
    bool isMarkable = false,
    List<String> markCodes = const [],
    int? unitCode,
    Decimal? extraDiscount,
  }) {
    // База налога — **строка, какой её насчитает оператор**:
    // `Count × Price − Discount + Markup`, то есть сумма строки за
    // вычетом всего, что уменьшило платёж покупателя, включая списанный
    // бонус. Оператор пересчитывает НДС от неё же, и разойтись с ним
    // нельзя: расхождение — тот же отказ кодом 9.
    final tax = _buildTax(
      lineTotal: taxableLine(lineTotal: lineTotal, extraDiscount: extraDiscount),
      productVatRate: productVatRate,
      settings: settings,
    );

    final discount = lineDiscount(
      quantity: quantity,
      priceBefore: unitPrice,
      lineTotal: lineTotal,
      extraDiscount: extraDiscount,
    );
    final markup = lineMarkup(
      quantity: quantity,
      priceBefore: unitPrice,
      lineTotal: lineTotal,
      extraDiscount: extraDiscount,
    );

    return FiscalPosition(
      name: name,
      quantity: quantity,
      unitPrice: unitPrice,
      lineTotal: lineTotal,
      tax: tax,
      discount: discount > Decimal.zero ? discount : null,
      markup: markup > Decimal.zero ? markup : null,
      ntin: ntin,
      barcode: barcode,
      unitCode: unitCode,
      markCodes: isMarkable ? markCodes : const [],
    );
  }

  /// НДС считается от суммы **после** всех скидок, то есть от денег
  /// покупателя. Довод не поменялся с задачи 6, поменялось слагаемое:
  /// зовущий передаёт сюда [taxableLine], а не сырой `lineTotal`, потому
  /// что списанный бонус тоже уменьшает платёж.
  ///
  /// Обе стороны названы числом. Выравнивание базы к `unitPrice ×
  /// quantity` завысило бы налог ровно на скидку; забыть вычесть бонус —
  /// то же самое на бонус (32.14 вместо 21.42 при 12 % на чеке 300 с
  /// бонусом 100); вычесть его дважды — занизить базу на
  /// `rate/(100+rate) × бонус`. Закреплено пробами
  /// (`test/data/fiscal/fiscal_kopeck_test.dart`,
  /// `test/data/fiscal/fiscal_envelope_balance_test.dart`).
  FiscalTax _buildTax({
    required Decimal lineTotal,
    required int? productVatRate,
    required FiscalSettings settings,
  }) {
    if (!settings.isVatPayer) return FiscalTax.none();

    final Decimal rate;
    if (productVatRate != null) {
      rate = Decimal.fromInt(productVatRate);
    } else {
      rate = settings.vatRatePercent;
    }

    if (rate <= Decimal.zero) {
      return FiscalTax.none();
    }

    return FiscalTax(
      mode: FiscalTaxMode.vat,
      ratePercent: rate,
      amount: vatFromGross(lineTotal, rate),
    );
  }
}

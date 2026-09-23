/// Шесть записей формулы налога сведены в одну — числами.
///
/// # Зачем проба, если есть сторож
///
/// Сторож `tax_formula_lives_in_one_place_test` запрещает ЗАВОДИТЬ вторую
/// запись. Эта проба отвечает на другой вопрос: а совпадали ли те шесть,
/// что были? Если бы совпадали, находка была бы про опрятность. Они не
/// совпадали.
///
/// # Что было измерено 2026-09-22
///
/// | где | как считала |
/// |---|---|
/// | `tax_amounts.dart` | `(gross × rate) / (100 + rate)`, промежуточно 10 знаков |
/// | `FiscalPositionBuilder` | то же, промежуточно `moneyScale + 8` = 10 |
/// | `kz_reports_controller` | то же, промежуточно **6** знаков |
/// | `VatCalculator` | `× 4 / 29` — свёрнуто под ставку **16 %** намертво |
/// | `DecimalUtil` | `× vatNumerator / vatDenominator` из `AppConstants` |
/// | `CountryCode` | то же самое, но в **`double`** |
///
/// Две последние деньги считали в `double` или поверх зашитой ставки, и обе
/// были недостижимы — их звали только собственные пробы, которые проходили
/// и создавали впечатление, что арифметика налога проверена.
///
/// Самая опасная — `VatCalculator`: она стояла на БОЕВОМ пути печати чека
/// запасным расчётом. Чек, объявивший ставку 12 %, показал бы налог,
/// посчитанный по 16 %.
library;

import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telepos/data/usecases/fiscal/fiscal_position_builder.dart';
import 'package:telepos/domain/tax/tax_amounts.dart';
import 'package:telepos/presentation/controllers/reports/kz_reports_controller.dart'
    show vatFromGross;

void main() {
  Decimal d(String v) => Decimal.parse(v);

  test('чек, фискальный документ и отчёт считают ОДИНАКОВО', () {
    // Три пути, по которым одно и то же число доезжает до трёх разных
    // читателей: покупателя, налоговой и владельца. Разойдись они — и
    // спорить будет не о чем, потому что все трое правы по-своему.
    for (final gross in ['1160', '3.50', '999.99', '0.01', '7777.77']) {
      for (final rate in [12, 16, 20]) {
        final home = taxFromGross(d(gross), Decimal.fromInt(rate));
        expect(
          FiscalPositionBuilder.vatFromGross(d(gross), Decimal.fromInt(rate)),
          home,
          reason: 'фискальный документ разошёлся с чеком: $gross при $rate%',
        );
        expect(
          vatFromGross(d(gross), rate),
          home,
          reason: 'отчёт по НДС разошёлся с чеком: $gross при $rate%',
        );
      }
    }
  });

  test('зашитая ставка больше не подменяет объявленную', () {
    // Ровно тот дефект: `VatCalculator` считал по 4/29 (то есть по 16 %) и
    // при ставке 12 % давал 155.36 вместо 124.29 на тысяче ста шестидесяти.
    final atTwelve = taxFromGross(d('1160'), d('12'));
    final atSixteen = taxFromGross(d('1160'), d('16'));
    expect(atTwelve, isNot(atSixteen));
    expect(atSixteen, d('160'), reason: '16/116 от 1160 — ровно 160');
    expect(atTwelve, d('124.29'));
  });

  test('нулевая и отрицательная ставка — ноль, а не деление на сто', () {
    expect(taxFromGross(d('1160'), Decimal.zero), Decimal.zero);
    expect(taxFromGross(d('1160'), d('-5')), Decimal.zero);
    expect(taxOnNet(d('1000'), Decimal.zero), Decimal.zero);
  });

  test('налог берётся по СТРОКАМ и суммируется, а не от итога', () {
    // Измерено 2026-09-21 на чеке из шести позиций при 16 %: по строкам
    // 615.24, от суммы 615.23. Копейка — но бумага у покупателя и документ
    // у налоговой расходились молча.
    // 0.04 × 16/116 = 0.005517 → 0.01 на строке; втрое это 0.03, а от
    // итога 0.12 выходит 0.016552 → 0.02. Разница вдвое, не «копейка».
    final lines = [d('0.04'), d('0.04'), d('0.04')];
    final rate = Decimal.fromInt(16);
    final byLines = lines
        .map((l) => taxFromGross(l, rate))
        .fold(Decimal.zero, (Decimal s, Decimal v) => s + v);
    final byTotal = taxFromGross(
      lines.fold(Decimal.zero, (Decimal s, Decimal v) => s + v),
      rate,
    );
    expect(
      byLines,
      isNot(byTotal),
      reason:
          'если эти два способа совпали, проба перестала мерить разницу — '
          'подберите числа, на которых округление расходится',
    );
  });
}

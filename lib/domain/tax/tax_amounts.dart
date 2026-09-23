/// Сумма налога по ставке — ОДНА формула на весь продукт.
///
/// # Зачем отдельный файл ради двух функций
///
/// Эти же две формулы жили внутри `receipt_print_service.dart`, а корзине
/// понадобились свои. Скопировать их значило бы завести две копии денежной
/// арифметики — ровно ту ловушку, которая 2026-09-21 уже стоила копейки:
/// печатаемый чек и фискальный документ считали налог по-разному, и бумага
/// у покупателя расходилась с документом у налоговой.
///
/// Копии расходятся не сразу. Они расходятся тогда, когда кто-то поправит
/// одну — и не найдёт вторую.
///
/// # Округление до сотых на КАЖДОЙ строке, а не на итоге
///
/// Так считает фискальный документ: налог берётся по позициям и
/// суммируется. Посчитать «от итога» — другой результат, и разница не
/// теоретическая: на чеке из шести позиций при 16 % она составила копейку.
library;

import 'package:decimal/decimal.dart';

/// Налог, УЖЕ СОДЕРЖАЩИЙСЯ в сумме: выделяется из брутто.
///
/// Уклад СНГ и ЕС: на ценнике цена с налогом.
Decimal taxFromGross(Decimal gross, Decimal ratePercent) {
  if (ratePercent <= Decimal.zero) return Decimal.zero;
  final hundred = Decimal.fromInt(100);
  return ((gross * ratePercent) / (hundred + ratePercent))
      .toDecimal(scaleOnInfinitePrecision: 10)
      .round(scale: 2);
}

/// Налог, ДОБАВЛЯЕМЫЙ к сумме: начисляется на нетто.
///
/// Уклад США: на ценнике налога нет, он прибавляется к подытогу.
Decimal taxOnNet(Decimal net, Decimal ratePercent) {
  if (ratePercent <= Decimal.zero) return Decimal.zero;
  return ((net * ratePercent) / Decimal.fromInt(100))
      .toDecimal(scaleOnInfinitePrecision: 10)
      .round(scale: 2);
}

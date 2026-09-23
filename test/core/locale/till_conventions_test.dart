/// Дата на чеке пишется по условиям страны кассы.
///
/// # Что измерено 2026-09-22
///
/// Чек печатал `ДД.ММ.ГГГГ` всегда, в любой стране. Для американца
/// «05.09.2026» — это девятое мая, а не пятое сентября: дата читается
/// ДРУГИМ днём, и на чеке нет ничего, что сказало бы, какое прочтение
/// верное. Спорить в этом случае не о чем — оба правы.
///
/// Разделители чисел при этом были объявлены ДВАЖДЫ — у страны и у валюты,
/// сорок шесть значений — и не читались ни одним местом продукта.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:telepos/core/constants/enums/country_code.dart';
import 'package:telepos/core/locale/till_conventions.dart';

void main() {
  final moment = DateTime(2026, 9, 5, 14, 7);

  TillConventions of(CountryCode country) => TillConventions(
    dateFormat: country.dateFormat,
    decimalSeparator: country.decimalSeparator,
    thousandSeparator: country.thousandSeparator,
  );

  tearDown(() {
    // Держатель общий на процесс: оставить его переставленным значит
    // покрасить соседнюю пробу чужой страной.
    TillConventions.current = const TillConventions(
      dateFormat: 'dd.MM.yyyy',
      decimalSeparator: ',',
      thousandSeparator: ' ',
    );
  });

  test('день и месяц не путаются между странами', () {
    // Пятое сентября. Три страны напишут его тремя разными способами, и
    // каждый будет верным ТАМ.
    expect(of(CountryCode.kzt).formatDate(moment), '05.09.2026');
    expect(of(CountryCode.usd).formatDate(moment), '9/5/2026');
    expect(of(CountryCode.jpn).formatDate(moment), '2026/09/05');
    expect(of(CountryCode.gbr).formatDate(moment), '05/09/2026');
    expect(of(CountryCode.can).formatDate(moment), '2026-09-05');
  });

  test('американская дата — не просто другой разделитель', () {
    // Главное в этой правке: на американской кассе меняется ПОРЯДОК, а не
    // точка вместо косой черты. Проба ловит именно порядок.
    final us = of(CountryCode.usd).formatDate(moment);
    expect(us.startsWith('9/'), isTrue, reason: 'месяц обязан идти первым');
    expect(us, isNot('05.09.2026'));
  });

  test('время одинаково везде, разнится только дата', () {
    for (final country in CountryCode.values) {
      expect(
        of(country).formatDateTime(moment),
        endsWith(' 14:07'),
        reason: '${country.name}: время написано иначе',
      );
    }
  });

  test('однобуквенный день не съедает двухбуквенный', () {
    // `d` после `dd` — ловушка замены: наивный порядок съел бы первую букву
    // `dd`, и шаблон рассыпался бы в «5d.09.2026».
    const us = TillConventions(
      dateFormat: 'M/d/yyyy',
      decimalSeparator: '.',
      thousandSeparator: ',',
    );
    expect(us.formatDate(DateTime(2026, 12, 25)), '12/25/2026');
    expect(us.formatDate(DateTime(2026, 1, 2)), '1/2/2026');
  });

  test('у каждой страны шаблон даты объявлен и осмыслен', () {
    // Сторож ходит по НАСТОЯЩЕМУ перечислению: страна, добавленная без
    // шаблона, покраснеет здесь, а не на чеке у покупателя.
    for (final country in CountryCode.values) {
      final f = country.dateFormat;
      expect(f, contains('yyyy'), reason: '${country.name}: нет года');
      expect(
        f.contains('MM') || f.contains('M'),
        isTrue,
        reason: '${country.name}: нет месяца',
      );
      expect(
        f.contains('dd') || f.contains('d'),
        isTrue,
        reason: '${country.name}: нет дня',
      );
      // Написанная дата обязана отличаться от шаблона: иначе подстановка не
      // сработала, и на чек уехало бы «dd.MM.yyyy» буквами.
      expect(of(country).formatDate(moment), isNot(f));
    }
  });

  test('умолчание — прежнее поведение', () {
    // Касса, которую не обновляли и не перенастраивали, пишет ровно так же,
    // как писала. Менять вид документа молча нельзя.
    expect(TillConventions.current.formatDate(moment), '05.09.2026');
  });
}

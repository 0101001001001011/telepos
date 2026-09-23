/// Фискализация страны объявлена ОДИН раз.
///
/// # Что измерено 2026-09-22
///
/// Источников было два, и они разошлись:
///
/// * `CountryCode.hasFiscalisation` — признак «да/нет» у девяти стран:
///   Казахстан, Россия, Киргизия, Узбекистан, Туркмения, Польша, Турция,
///   Китай, Саудовская Аравия;
/// * таблица в мастере настройки (`fiscal_step.dart`) — оператор ровно для
///   ДВУХ: Казахстана (WebKassa) и России (ОФД).
///
/// Семь стран оказались между: мастер говорил «фискализация не требуется» и
/// пропускал шаг, а чек печатал фискальный блок. Покупателю обещали
/// документ, которого никто не настраивал и которого не существует.
///
/// # Как сведено
///
/// У страны остался ОДИН `fiscalProtocol`, а `hasFiscalisation` выводится
/// из него. Разойтись им больше негде.
///
/// # Что значит `none` у Польши и Турции
///
/// Не «фискализации там нет» — она есть по закону. Значит «эта касса её там
/// не умеет». Объявить умение, которого нет, значило бы соврать владельцу
/// ещё раз, только с другой стороны.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:telepos/core/constants/enums/country_code.dart';
import 'package:telepos/domain/setup/setup_draft.dart';

void main() {
  test('признак выводится из протокола, а не живёт отдельно', () {
    for (final country in CountryCode.values) {
      expect(
        country.hasFiscalisation,
        country.fiscalProtocol != FiscalType.none,
        reason:
            '${country.name}: признак и протокол снова разошлись — именно '
            'это и печатало фискальный блок в семи странах',
      );
    }
  });

  test('протокол назван у каждой страны', () {
    for (final country in CountryCode.values) {
      expect(
        country.fiscalProtocol,
        isNotNull,
        reason: '${country.name}: протокол не объявлен',
      );
    }
  });

  test('Казахстан идёт своим протоколом, СНГ — общим ОФД', () {
    // Решение заказчика 2026-09-15: операторы разные по странам, протокол
    // ОФД в СНГ один. Казахстан — исключение, у него WebKassa.
    expect(CountryCode.kzt.fiscalProtocol, FiscalType.webkassa);
    for (final country in [
      CountryCode.rub,
      CountryCode.kgs,
      CountryCode.uzs,
      CountryCode.tmt,
    ]) {
      expect(
        country.fiscalProtocol,
        FiscalType.ofd,
        reason:
            '${country.name}: страна СНГ осталась без протокола, и мастер '
            'снова пропустит шаг, а чек напечатает фискальный блок',
      );
    }
  });

  test('где касса не умеет — там и не обещает', () {
    // США, Канада, ЕС, Япония, Корея, ОАЭ, Индия — фискализации у нас нет.
    // Польша, Турция, Китай и Саудовская Аравия попали сюда же: закон там
    // есть, реализации у нас нет, и печатать блок значит обещать документ.
    for (final country in [
      CountryCode.usd,
      CountryCode.can,
      CountryCode.deu,
      CountryCode.pol,
      CountryCode.tur,
      CountryCode.chn,
      CountryCode.sau,
    ]) {
      expect(country.fiscalProtocol, FiscalType.none, reason: country.name);
      expect(country.hasFiscalisation, isFalse, reason: country.name);
    }
  });

  test('мастер спрашивает страну, а не держит свою таблицу', () {
    // Сторож читает исходник: вторая таблица «страна → оператор» и была
    // причиной расхождения, и завести её обратно проще всего.
    final step = File(
      'lib/presentation/screens/setup/steps/fiscal_step.dart',
    ).readAsStringSync();

    expect(
      step,
      contains('.fiscalProtocol'),
      reason: 'мастер перестал спрашивать протокол у страны',
    );
    expect(
      step,
      isNot(contains('CountryCode.kzt => FiscalType')),
      reason: 'в мастере снова завелась своя таблица страна → оператор',
    );
  });
}

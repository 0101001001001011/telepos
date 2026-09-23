/// У каждой страны есть название и валюта на языке интерфейса.
///
/// # Что измерено
///
/// Пробный проход мастера 2026-09-21: первый экран показывал иностранцу
/// «Казахстан · Казахстанский тенге», «США», «Туркменистан» — по-русски, на
/// английском интерфейсе. Поле `countryNameEn` в перечислении при этом было
/// и не звалось ниоткуда.
///
/// # Сторож ходит по НАСТОЯЩЕМУ перечислению
///
/// `CountryCode.values`, а не по списку, повторённому здесь. Повторённый
/// список молчал бы ровно в том случае, ради которого сторож и заведён: в
/// перечисление добавили страну и забыли слово.
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telepos/core/constants/enums/country_code.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/presentation/common/utils/country_label.dart';

void main() {
  final cyrillic = RegExp(r'[А-Яа-яЁё]');

  for (final locale in AppLocalizations.supportedLocales) {
    test('${locale.languageCode}: у каждой страны есть слово', () {
      final l10n = lookupAppLocalizations(locale);
      for (final country in CountryCode.values) {
        final name = countryTitle(country, l10n);
        final currency = currencyTitle(country, l10n);

        expect(
          name.trim(),
          isNotEmpty,
          reason: '${country.name}: пустое название страны',
        );
        expect(
          currency.trim(),
          isNotEmpty,
          reason: '${country.name}: пустое название валюты',
        );
      }
    });
  }

  test('на английском ни одна строка не осталась русской', () {
    final l10n = lookupAppLocalizations(const Locale('en'));
    final offenders = <String>[];

    for (final country in CountryCode.values) {
      for (final text in [
        countryTitle(country, l10n),
        currencyTitle(country, l10n),
      ]) {
        if (cyrillic.hasMatch(text)) offenders.add('${country.name}: $text');
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'это первый экран, который видит иностранец, и он говорит с ним '
          'по-русски:\n${offenders.join('\n')}',
    );
  });

  test('у каждой страны СВОЁ имя', () {
    // Без этого проба прошла бы при словаре, где все страны зовутся
    // одинаково: непустое и нерусское — ещё не верное.
    final l10n = lookupAppLocalizations(const Locale('en'));
    final names = CountryCode.values.map((c) => countryTitle(c, l10n)).toSet();
    expect(names, hasLength(CountryCode.values.length));
  });

  test('валюты повторяются ровно там, где они общие', () {
    // Здесь стояло «у каждой страны своя валюта», и это было НЕВЕРНОЕ
    // правило: евро один на Германию, Францию, Испанию и Италию, и так
    // устроен мир, а не наш словарь. Сторож покраснел на правде — правило и
    // поправлено.
    //
    // Проверять всё же есть что: имя валюты обязано совпадать ровно у тех
    // стран, у которых совпадает сама валюта.
    final l10n = lookupAppLocalizations(const Locale('en'));
    final byCurrency = <String, Set<String>>{};
    for (final country in CountryCode.values) {
      (byCurrency[country.defaultCurrency.name] ??= {})
          .add(currencyTitle(country, l10n));
    }

    for (final entry in byCurrency.entries) {
      expect(
        entry.value,
        hasLength(1),
        reason:
            'у валюты «${entry.key}» в словаре ${entry.value.length} разных '
            'имени: ${entry.value.join(", ")}',
      );
    }

    expect(
      byCurrency.keys.toSet(),
      hasLength(greaterThan(1)),
      reason: 'все страны свелись к одной валюте — сторож смотрит не туда',
    );
  });
}

/// Ставка налога нигде не зашита числом.
///
/// # Что сказал заказчик 2026-09-22
///
/// «Мы же говорили про полную настройку, и там перечислений быть не может,
/// вдруг завтра поменяют и сделают 18 %, и всё, работа кассы встанет тогда
/// в России. Всё должно настраиваться, ну пресеты конечно должны быть, это
/// мы обсуждали, когда США делали, но настройка должна быть, или к примеру
/// у них есть ставки 0 % и т.д.»
///
/// # Что было
///
/// `CountryCode.vatRate` — одно число на страну, в коде. Три беды сразу:
///
/// * закон меняет ставку, а число ждёт сборки;
/// * одной ставки не хватает: почти везде есть пониженные и нулевая, а поле
///   знало только общую;
/// * наборов было два (Казахстан и один город США), мастер их не применял
///   вовсе, и касса любой другой страны жила умолчанием в 16 %.
///
/// # Что стало
///
/// Ставки живут в наборах (`assets/tax_presets/*.json`) — файлах, которые
/// правятся без сборки. Мастер применяет набор страны в настройку кассы,
/// дальше касса живёт СВОЕЙ настройкой, а владелец правит её экраном.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:telepos/core/constants/enums/country_code.dart';

void main() {
  test('у страны больше нет поля со ставкой', () {
    final source = File(
      'lib/core/constants/enums/country_code.dart',
    ).readAsStringSync();

    // Ищем ОБЪЯВЛЕНИЕ поля, а не слово: докстрока рядом объясняет, почему
    // поля нет, и запрещать само слово значило бы запретить объяснение.
    expect(
      source,
      isNot(contains('final int vatRate;')),
      reason:
          'ставка снова стала числом в коде. Поменяют закон — касса будет '
          'считать по старой, пока не выйдет сборка',
    );
    expect(
      source,
      isNot(matches(RegExp(r'\n\s*vatRate: \d+,'))),
      reason: 'у страны снова проставлена ставка числом',
    );
  });

  test('ставку не берут у страны нигде в продукте', () {
    final offenders = <String>[];
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final path = entity.path.replaceAll(r'\', '/');
      if (path.endsWith('.g.dart')) continue;
      final lines = entity.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (lines[i].trimLeft().startsWith('//')) continue;
        // `country.vatRate`, `selectedCountry?.vatRate` и подобное.
        if (RegExp(r'[Cc]ountry[A-Za-z]*\??\.vatRate\b').hasMatch(lines[i])) {
          offenders.add('$path:${i + 1}: ${lines[i].trim()}');
        }
      }
    }
    expect(
      offenders,
      isEmpty,
      reason:
          'ставка снова читается у страны, а не из настройки:'
          '\n${offenders.join('\n')}',
    );
  });

  test('у каждой страны есть код, по которому находится её набор', () {
    // Сопоставление «страна → набор» живёт у страны одним местом. Держать
    // его в экране или в пробе значило бы завести второй источник — то
    // самое, из-за чего разошлись признак фискализации и таблица мастера.
    final codes = <String>{};
    for (final country in CountryCode.values) {
      expect(
        country.isoCode,
        matches(RegExp(r'^[A-Z]{2}$')),
        reason: '${country.name}: код страны не похож на ISO 3166-1',
      );
      expect(
        codes.add(country.isoCode),
        isTrue,
        reason: '${country.name}: код «${country.isoCode}» уже занят',
      );
    }
  });

  test('мастер заводит налог из набора, а не оставляет умолчание', () {
    // Ровно та дыра, из-за которой зашитые 16 % и работали: наборы
    // применялись ТОЛЬКО с экрана налогов, и касса после мастера не имела
    // налоговой настройки вовсе.
    // Смотрим слой ДАННЫХ: первая редакция звала это из контроллера
    // мастера и потянула в презентацию каталог наборов и базу — сторожа
    // поймали нарушение И5 и слом браузерной сборки.
    final wizard = File(
      'lib/data/setup/setup_repository_local.dart',
    ).readAsStringSync();

    expect(
      wizard,
      contains('_seedTaxFromPreset'),
      reason: 'мастер перестал заводить налог из набора',
    );
    expect(
      wizard,
      contains('applyPreset'),
      reason: 'набор больше не применяется в настройку кассы',
    );
  });
}

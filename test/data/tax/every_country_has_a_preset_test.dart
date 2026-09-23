/// У каждой страны есть налоговый набор, и все они разбираются.
///
/// # Что измерено 2026-09-22
///
/// Наборов было два: Казахстан и один город США. Остальные восемнадцать
/// стран не имели налоговой настройки вовсе, и чек брал ставку из
/// перечисления `CountryCode.vatRate` — числа, зашитого в код.
///
/// Заказчик назвал это прямо: «вдруг завтра поменяют и сделают 18 %, и всё,
/// работа кассы встанет тогда в России». Ставка обязана настраиваться, а
/// набор — быть отправной точкой, а не властью (README наборов, правило 1).
///
/// # Что проверяет проба
///
/// Не «верна ли ставка» — этого проба знать не может, закон меняется. А то,
/// что набор ЕСТЬ, что он разбирается настоящим разборщиком продукта и что
/// в нём есть категории, которые делают настройку осмысленной: общая
/// ставка и освобождение.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:telepos/core/constants/enums/country_code.dart';
import 'package:telepos/domain/tax/tax_preset.dart';

void main() {
  late Map<String, List<TaxPreset>> byCountry;

  setUpAll(() {
    byCountry = {};
    for (final entity in Directory('assets/tax_presets').listSync()) {
      if (entity is! File || !entity.path.endsWith('.json')) continue;
      final preset = TaxPreset.fromJson(
        jsonDecode(entity.readAsStringSync()) as Map<String, Object?>,
      );
      (byCountry[preset.countryCode] ??= []).add(preset);
    }
  });

  test('каждый файл набора разбирается продуктовым разборщиком', () {
    // Разборщик отказывает придирчиво: ставка числом JSON, ссылка на
    // несуществующую категорию, набор без места кассы, две категории по
    // умолчанию. Набор с ошибкой выдал бы покупателю неверный документ.
    expect(
      byCountry,
      isNotEmpty,
      reason: 'наборов нет вовсе — проба смотрит не туда',
    );
  });

  test('у каждой страны продукта есть набор', () {
    /// Страны, у которых набора нет НАМЕРЕННО, — поимённо и с доводом.
    const without = <String, String>{
      // Налог в США задаётся городом, и общенационального набора не
      // существует: ставка в Денвере и в Сиэтле разная. Наборы там
      // городские, и один из них поставляется (`us-co-denver`).
      'US': 'налог задаётся городом; поставляется городской набор',
    };

    final missing = <String>[];
    for (final country in CountryCode.values) {
      final code = country.isoCode;
      if (without.containsKey(code)) continue;
      if (!byCountry.containsKey(code)) missing.add('${country.name} ($code)');
    }

    expect(
      missing,
      isEmpty,
      reason:
          'у этих стран налоговой настройки нет вовсе, и ставка взялась бы '
          'из числа, зашитого в код:\n${missing.join('\n')}',
    );
  });

  test('в каждом наборе есть общая ставка и освобождение', () {
    // Набор из одной строки не настройка: без освобождённой категории
    // владелец не сможет отделить необлагаемый товар, а ради этого
    // категории и заведены.
    final thin = <String>[];
    for (final entry in byCountry.entries) {
      for (final preset in entry.value) {
        final codes = preset.categories.map((c) => c.code).toSet();
        if (codes.length < 2) {
          thin.add('${preset.id}: категорий ${codes.length}');
        }
        final defaults = preset.categories.where((c) => c.isDefault);
        if (defaults.length != 1) {
          thin.add('${preset.id}: категорий по умолчанию ${defaults.length}');
        }
      }
    }
    expect(thin, isEmpty, reason: thin.join('\n'));
  });

  test('набор называет свой источник — и что его надо проверить', () {
    // Наборы устаревают по построению: закон меняется, а файл лежит. Строка
    // источника — единственное, что отличает «мы посмотрели» от «мы
    // придумали».
    final silent = <String>[];
    for (final presets in byCountry.values) {
      for (final preset in presets) {
        if (preset.source == null || preset.source!.trim().length < 10) {
          silent.add(preset.id);
        }
      }
    }
    expect(
      silent,
      isEmpty,
      reason: 'набор без источника: ${silent.join(", ")}',
    );
  });

  test('ставка в наборе — СТРОКА, а не число JSON', () {
    // Правило 2 из README: 8,25 в двоичном `double` представима, 0,1 уже
    // нет. Разборщик это и проверяет — проба следит, что проверка живая.
    final broken = File(
      'assets/tax_presets/kz.json',
    ).readAsStringSync().replaceAll('"16"', '16');
    expect(
      () => TaxPreset.fromJson(jsonDecode(broken) as Map<String, Object?>),
      throwsA(isA<FormatException>()),
      reason: 'разборщик перестал ловить ставку числом',
    );
  });
}

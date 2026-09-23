/// Государственные системы показываются только своей стране.
///
/// # Что измерено 2026-09-22
///
/// Четыре казахстанские системы — ЭСФ, СНТ, ЕСУТД, ИС МПТ — стояли в
/// настройках на кассе ЛЮБОЙ страны, и пятой шла вкладка отчётов
/// «Tax / KZ» с формами 910 и 300. Владелец магазина в США, Германии или
/// Корее видел пять входов в казахстанский документооборот и не мог понять,
/// что это.
///
/// Страна у кассы была с самого начала. Её здесь просто никто не
/// спрашивал: во всей презентации `CountryCode` читался четырьмя местами, и
/// ни одно из них не было меню.
///
/// # Почему сторож смотрит исходник
///
/// Экранный обходчик ходит по кассе, настроенной на Казахстан, — то есть по
/// той единственной стране, где эти пункты законны. Дефект он увидеть не
/// мог по построению.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:telepos/core/constants/enums/country_code.dart';
import 'package:telepos/core/constants/enums/national_system.dart';

void main() {
  test('набор систем объявлен у каждой страны', () {
    for (final country in CountryCode.values) {
      expect(
        country.nationalSystems,
        isNotNull,
        reason: '${country.name}: набор систем не объявлен',
      );
    }
  });

  test('системы есть ровно у той страны, где мы их умеем', () {
    // Казахстан — единственный, и это говорит о НАС, а не о законе:
    // электронная счёт-фактура есть и в ЕС, и в Турции, и в России.
    // Объявить их, не реализовав, значило бы соврать владельцу.
    final withSystems = CountryCode.values
        .where((c) => c.nationalSystems.isNotEmpty)
        .map((c) => c.name)
        .toList();
    expect(withSystems, ['kzt']);

    expect(
      CountryCode.kzt.nationalSystems,
      containsAll(NationalSystem.values),
      reason: 'у Казахстана пропала система, которую касса умеет',
    );
    expect(
      CountryCode.usd.nationalSystems,
      isEmpty,
      reason: 'американской кассе показали чужой документооборот',
    );
  });

  test('каждый пункт меню госсистем спрашивает страну', () {
    // Сторож читает ИСХОДНИК настроек: плитка, добавленная без проверки,
    // видна всем, а обходчик экранов ходит по казахстанской кассе и этого
    // не покажет.
    final settings = File(
      'lib/presentation/screens/settings/general_settings_screen.dart',
    );
    expect(settings.existsSync(), isTrue);
    final lines = settings.readAsLinesSync();

    /// Пункты меню, ведущие в государственные системы, — поимённо.
    const gated = <String, String>{
      'l10n.esfSettingsTitle': 'NationalSystem.electronicInvoice',
      'l10n.sntTitle': 'NationalSystem.goodsNote',
      'l10n.esutdTitle': 'NationalSystem.transportWaybill',
      'l10n.ismptSettingsTitle': 'NationalSystem.productMarking',
    };

    final ungated = <String>[];
    for (var i = 0; i < lines.length; i++) {
      for (final entry in gated.entries) {
        if (!lines[i].contains('title: ${entry.key}')) continue;
        // Проверка стоит НАД плиткой: `if (systems.contains(...))`.
        final above = lines.sublist(i - 3 < 0 ? 0 : i - 3, i).join(' ');
        if (!above.contains(entry.value)) {
          ungated.add('строка ${i + 1}: ${entry.key} без ${entry.value}');
        }
      }
    }

    expect(
      ungated,
      isEmpty,
      reason:
          'пункт ведёт в чужой государственный документооборот и показан '
          'всем странам:\n${ungated.join('\n')}',
    );
  });

  test('вкладка отчётов с формами тоже спрашивает страну', () {
    final reports = File(
      'lib/presentation/screens/reports/reports_screen.dart',
    );
    expect(reports.existsSync(), isTrue);
    final text = reports.readAsStringSync();

    expect(
      text,
      contains('NationalSystem.taxForms'),
      reason:
          'вкладка с формами 910 и 300 снова показана всем: она стояла так '
          'до 2026-09-22 и на американской кассе не значила ничего',
    );
    expect(
      text,
      contains('ReportTab.kz'),
      reason: 'сторож ищет вкладку, которой больше нет — он мерит не то',
    );
  });
}

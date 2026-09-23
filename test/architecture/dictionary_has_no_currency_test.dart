/// В словаре нет валюты: валюта — не свойство языка.
///
/// # Что измерено 2026-09-22
///
/// Три сторожа языка и валюты читают `lib/`. В СЛОВАРЬ не смотрел ни один,
/// а там оказалось восемнадцать ключей с зашитым `₸` — по одному и тому же
/// тексту во всех пяти языках:
///
/// * подзаголовки всех отчётов КЗ («Облагаемый доход: {income} ₸»);
/// * шапка столбца «Сумма, ₸»;
/// * подсказки графиков по покупателям и заказам;
/// * строки вложений, дивидендов, прибыли и расходов в финансах;
/// * `shiftFixedAmount` — «Будет зафиксирована сумма: {amount} KZT», прямо
///   в окне закрытия смены, которое снимает урок 7;
/// * ключ `currencySymbol`, возвращавший `₸` на любом языке, — третий
///   источник знака валюты после `Currency.symbol` и `CountryCode`, и его
///   звали одиннадцать мест модуля услуг.
///
/// Казахский интерфейс американской кассы обязан показывать доллары:
/// валюта — настройка кассы, а язык — настройка человека, и связывать их
/// значило бы менять цену вместе с языком.
///
/// # Чего сторож НЕ проверяет
///
/// Названия валют («Казахстанский тенге») в словаре законны и нужны: это
/// слова, которыми мастер настройки предлагает ВЫБРАТЬ валюту. Он смотрит
/// только знаки и трёхбуквенные коды.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:telepos/core/constants/enums/currency.dart';

void main() {
  /// Ключи, которым код валюты положен по смыслу, — поимённо и с доводом.
  const allowed = <String, String>{
    // Мастер настройки предлагает выбрать валюту — и называет варианты.
    'setupCurrencyKzt': 'название валюты в выборе валюты',
    'setupCurrencyRub': 'название валюты в выборе валюты',
    'setupCurrencyUsd': 'название валюты в выборе валюты',
    'setupCurrencyEur': 'название валюты в выборе валюты',
  };

  late Map<String, dynamic> ru;

  setUpAll(() {
    ru =
        jsonDecode(File('assets/i18n/intl_ru.arb').readAsStringSync())
            as Map<String, dynamic>;
  });

  test('сторож смотрит не в пустоту: словарь на месте', () {
    expect(
      ru.keys.where((k) => !k.startsWith('@')).length,
      greaterThan(3000),
      reason: 'словарь почти пуст — сторож читает не тот файл',
    );
  });

  test('ни один ключ не несёт знака или кода валюты', () {
    // Знаки и коды — из НАСТОЯЩЕГО перечисления валют. Список, повторённый
    // здесь, молчал бы ровно тогда, когда валюту добавили.
    final signs = Currency.values
        .map((c) => c.symbol)
        .where((s) => s.length == 1)
        .where((s) => !RegExp(r'[A-Za-z0-9]').hasMatch(s))
        .toSet();
    final codes = Currency.values.map((c) => c.code).toSet();
    expect(signs, isNotEmpty);
    expect(codes, contains('KZT'));

    final offenders = <String>[];

    for (final locale in ['ru', 'en', 'kk', 'ky', 'uz']) {
      final map =
          jsonDecode(File('assets/i18n/intl_$locale.arb').readAsStringSync())
              as Map<String, dynamic>;
      for (final entry in map.entries) {
        if (entry.key.startsWith('@')) continue;
        final value = entry.value;
        if (value is! String) continue;
        if (allowed.containsKey(entry.key)) continue;

        for (final sign in signs) {
          if (value.contains(sign)) {
            offenders.add('$locale/${entry.key}: «$value» — знак «$sign»');
          }
        }
        for (final code in codes) {
          if (RegExp('\\b$code\\b').hasMatch(value)) {
            offenders.add('$locale/${entry.key}: «$value» — код «$code»');
          }
        }
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'валюта зашита в словаре, и тогда язык решает, в чём считают '
          'деньги. Уберите её из текста и подставьте знак кассы у '
          'вызывающего — `tillCurrencySymbol()` или '
          '`ReportMoney.withCurrency`:\n${offenders.join('\n')}',
    );
  });

  test('ключа currencySymbol в словаре больше нет', () {
    // Отдельной пробой, потому что это не «текст с валютой», а ЗАПИСЬ о
    // том, что знак валюты берётся у языка. Вернуть её было бы возвратом
    // третьего источника, а не опечаткой.
    for (final locale in ['ru', 'en', 'kk', 'ky', 'uz']) {
      final map =
          jsonDecode(File('assets/i18n/intl_$locale.arb').readAsStringSync())
              as Map<String, dynamic>;
      expect(
        map.containsKey('currencySymbol'),
        isFalse,
        reason:
            '$locale: знак валюты снова взят у языка. Валюта — настройка '
            'кассы: `tillCurrencySymbol()`',
      );
    }
  });
}

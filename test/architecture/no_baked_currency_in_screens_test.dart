/// В экранах нет зашитых знаков валют.
///
/// # Что измерено 2026-09-22
///
/// В `lib/presentation` было **52** зашитых `₸`: отчёты (30), калькуляция
/// блюда (10), история смен, ценники, реестр ЭСФ, общие настройки. На
/// американской кассе владелец видел выручку за день в тенге — на экране, по
/// которому он судит о деньгах.
///
/// Рядом жил второй источник знаков — `CurrencySymbols` в `money_field.dart`:
/// семь валют против двадцати одной в перечислении, и «с» вместо «сом» у
/// Киргизии. Его не звал никто ни разу — снят.
///
/// # Почему сторож смотрит исходник
///
/// Экранный обходчик до отчётов, ценников и калькуляции блюда не доходит:
/// они открываются только при заведённых данных. Зашитый знак валюты
/// пережил бы его молча.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:telepos/core/constants/enums/currency.dart';

void main() {
  /// Файлы, где знак валюты законен, — поимённо и с доводом.
  ///
  /// Оба — докстроки, объясняющие ЭТОТ дефект. Молчаливое исключение
  /// превратило бы сторожа в украшение.
  const allowed = <String, String>{
    'lib/presentation/common/utils/till_money.dart':
        'единственный дом знака валюты в презентации; знак назван в докстроке',
    'lib/presentation/screens/customer_display/customer_display_data.dart':
        'докстрока называет снятый дефект экрана покупателя',
  };

  test('сторож смотрит не в пустоту: экраны на месте', () {
    final dir = Directory('lib/presentation');
    expect(dir.existsSync(), isTrue);
    expect(
      dir
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))
          .length,
      greaterThan(50),
      reason: 'экранов почти нет — сторож ищет не там',
    );
  });

  test('знаки валют берутся у кассы, а не пишутся в экране', () {
    // Знаки — из НАСТОЯЩЕГО перечисления валют, а не из списка, повторённого
    // здесь: повторённый молчал бы ровно тогда, когда валюту добавили.
    final signs = Currency.values
        .map((c) => c.symbol)
        .where((s) => s.length == 1)
        // Два вычета, и каждый по делу: знак доллара — он же знак
        // подстановки в строках Dart, и стоит в каждой второй строке
        // кода (зашитый доллар ловится обходчиком экранов); буквенные
        // обозначения (`TMT`, `сом`, `сўм`) — слова, а не знаки, и их
        // ловит сторож русских строк.
        .where((s) => !RegExp(r'[A-Za-z0-9\$]').hasMatch(s))
        .toSet();
    expect(
      signs,
      isNotEmpty,
      reason: 'знаков валют нет — сторожу нечем мерить',
    );
    expect(
      signs,
      contains('₸'),
      reason: 'тенге выпал из набора — сторож не поймал бы дефект',
    );

    final offenders = <String>[];
    for (final entity in Directory(
      'lib/presentation',
    ).listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final path = entity.path.replaceAll(r'\', '/');
      if (allowed.containsKey(path)) continue;

      final lines = entity.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        if (line.trimLeft().startsWith('//')) continue;
        for (final sign in signs) {
          if (!line.contains(sign)) continue;
          offenders.add('$path:${i + 1}: «$sign» в «${line.trim()}»');
        }
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'это деньги чужой страны на экране. Знак валюты берётся у кассы: '
          '`tillCurrencySymbol()`, а в отчётах — `ReportMoney.withCurrency`:'
          '\n${offenders.join('\n')}',
    );
  });
}

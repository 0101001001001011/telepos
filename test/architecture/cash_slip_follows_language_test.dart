/// Квитанция кассовой операции говорит на языке кассы.
///
/// # Чем это оплачено
///
/// `printed_documents_follow_language_test` проверяет чек, X- и Z-отчёт —
/// и **не собирал квитанцию кассовой операции**. Она осталась целиком
/// русской: «КВИТАНЦИЯ», «Тип:», «Дата:», «Кассир:», «Сумма:»,
/// «Комментарий:», «ВНЕСЕНИЕ», «РАСХОД», «ИЗЪЯТИЕ» — на любой кассе,
/// включая американскую. Это бумага, которую человек уносит с собой.
///
/// Нашлось не пробой, а замером мёртвых ключей словаря: `receiptLabelAmount`
/// («Сумма») лежал в словаре и не спрашивался нигде, потому что рядом был
/// зашит литерал.
///
/// Дисплей покупателя (`vfd_display.dart`) страдал тем же — «Цена:»,
/// «ИТОГО:», «Сдача:», «Добро пожаловать!», — и его читает ПОКУПАТЕЛЬ, а
/// не сотрудник. Проверить его собранным текстом нечем: он пишет байты в
/// порт, а не строит документ. Сторожит его источник —
/// `display_words_live_in_l10n_test` не поможет (там нет `displayName`), и
/// потому здесь стоит прямая проверка файла.
///
/// # Почему глобальный держатель, а не довод
///
/// `printed_documents_follow_language_test` передаёт словарь доводом и
/// прямо объясняет почему: глобальное состояние связало бы прогоны
/// порядком запуска. У квитанции точки внедрения нет — она строится из
/// данных и больше ни из чего, — поэтому язык берётся у [TillLanguage], а
/// проба возвращает его обратно в `tearDown`. Внутри одного файла пробы
/// идут по очереди, так что связать они могут только друг друга.
library;

import 'dart:io';

import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:telepos/core/locale/app_locale.dart';
import 'package:telepos/core/locale/till_language.dart';
import 'package:telepos/domain/entities/cash_operation/cash_operation_receipt_data.dart';
import 'package:telepos/domain/usecases/cash_operation/cash_in_out_controller.dart';
import 'package:telepos/hardware/printer/receipt/cash_operation_receipt_builder.dart';

final _cyrillic = RegExp('[Ѐ-ӿ]');

void main() {
  late AppLocale before;

  setUp(() {
    before = TillLanguage.current;
    TillLanguage.current = AppLocale.en;
  });
  tearDown(() => TillLanguage.current = before);

  /// Данные намеренно английские: имя кассира и название магазина — данные
  /// магазина, а не интерфейс, и кириллица в них законна. Сторож,
  /// краснеющий на имени «Иванова», проверял бы затравку, а не продукт.
  CashOperationReceiptData dataOf(CashInOutType type, {String? note}) =>
      CashOperationReceiptData(
        companyName: 'Corner Store',
        receiptNumber: '42',
        type: type,
        docTime: DateTime(2026, 9, 23, 10, 15),
        cashierName: 'A. Ivanova',
        amount: Decimal.parse('150.00'),
        currencySymbol: r'$',
        note: note,
      );

  for (final type in CashInOutType.values) {
    test('квитанция $type на английском не содержит кириллицы', () {
      final text = CashOperationReceiptBuilder(
        data: dataOf(type, note: 'for the coffee machine'),
      ).toDebugString();

      final offenders = text
          .split('\n')
          .where((l) => _cyrillic.hasMatch(l))
          .toList();

      expect(
        offenders,
        isEmpty,
        reason:
            'на английской кассе квитанция напечатана по-русски:\n'
            '${offenders.join('\n')}\n\nВесь документ:\n$text',
      );
    });
  }

  test('род операции переведён, а не просто набран заглавными', () {
    final text = CashOperationReceiptBuilder(
      data: dataOf(CashInOutType.investment),
    ).toDebugString();
    expect(
      text.toUpperCase(),
      contains('CASH IN'),
      reason: 'строка «Тип» обязана назвать род словом словаря',
    );
  });

  test('дисплей покупателя не несёт зашитых слов', () {
    // Покупатель читает дисплей, а не сотрудник, и подсунуть ему чужой
    // язык хуже, чем кассиру: кассира хотя бы можно научить.
    // Построчно и без комментариев. Первая редакция искала по всему
    // файлу разом, и `[^']*` перешагнул через переводы строк: сторож
    // «нашёл» кириллицу в докстроках и покраснел на собственном описании.
    final lines = File(
      'lib/hardware/display/vfd_display.dart',
    ).readAsLinesSync();

    // Применяется к ОДНОЙ строке (`readAsLines` перевод строки
    // снимает), поэтому классу `[^']` шагнуть некуда.
    final inLine = RegExp("'[^']*[Ѐ-ӿ][^']*'");
    final literals = <String>[];
    for (final line in lines) {
      final code = line.trimLeft();
      if (code.startsWith('//')) continue;
      for (final m in inLine.allMatches(line)) {
        literals.add(m.group(0)!);
      }
    }

    expect(
      literals,
      isEmpty,
      reason: 'зашитые слова на дисплее покупателя: ${literals.join(", ")}',
    );
  });
}

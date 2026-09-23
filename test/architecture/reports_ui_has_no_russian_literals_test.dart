/// В экранах отчётов не остаётся русских строковых литералов.
///
/// # Зачем он, если есть сторож по экрану
///
/// `test/e2e/english_screens_have_no_russian_test.dart` меряет то, что видно,
/// и это правильный способ. Но он видит **только те состояния, до которых
/// дошёл**: на пустой затравке графики и таблицы отчётов показывают «нет
/// данных», а две сотни подписей — колонки, подсказки столбиков, заголовки
/// выгрузки CSV — не строятся вовсе. Ровно там и жило большинство русских
/// слов: экранный сторож их не назвал, они нашлись чтением.
///
/// Поэтому у модуля отчётов есть второй сторож, от данных не зависящий. Он
/// узкий намеренно: в остальной презентации кириллица в литералах бывает
/// законной (записи в журнал, символ киргизского сома `с`, запасные значения
/// рядом с `??`), и сторож на весь слой краснел бы на законном. Здесь же
/// после разбора 2026-09-20 не осталось ни одного литерала с кириллицей —
/// значит правило можно сформулировать без оговорок, а без оговорок его не
/// обойдут случайно.
///
/// # Что делать, когда он покраснел
///
/// Не добавлять сюда исключение. Завести ключ в `assets/i18n/intl_*.arb`
/// (все пять языков разом), выполнить `flutter gen-l10n` и взять текст из
/// словаря.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Весь кириллический блок Unicode: казахская `қ` и киргизская `ү` лежат вне
/// диапазона `а-я`, и проверка по нему их пропустила бы.
final _cyrillic = RegExp('[Ѐ-ӿ]');

/// Строковые литералы Dart. Их два выражения, а не одно: собрать оба вида
/// кавычек в один литерал Dart без нечитаемого экранирования нельзя.
final _literals = [
  // Одинарные кавычки, включая тройные.
  RegExp(r"'''(?:[^\\]|\\.)*?'''|'(?:[^'\\\n]|\\.)*'"),
  // Двойные кавычки, включая тройные.
  RegExp(r'"""(?:[^\\]|\\.)*?"""|"(?:[^"\\\n]|\\.)*"'),
];

void main() {
  test('экраны отчётов не держат русских строковых литералов', () {
    final dir = Directory('lib/presentation/screens/reports');
    expect(
      dir.existsSync(),
      isTrue,
      reason:
          'каталог отчётов переехал — сторож, не нашедший файлов, зелен '
          'всегда и не проверяет ничего',
    );

    final files = dir
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .toList();

    expect(
      files.length,
      greaterThanOrEqualTo(10),
      reason:
          'файлов стало подозрительно мало: сторож, которому нечего читать, '
          'зелен по недосмотру, а не по делу',
    );

    final offences = <String>[];
    for (final file in files) {
      var inBlockComment = false;
      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final trimmed = lines[i].trim();

        if (inBlockComment) {
          if (trimmed.contains('*/')) inBlockComment = false;
          continue;
        }
        if (trimmed.startsWith('/*')) {
          if (!trimmed.contains('*/')) inBlockComment = true;
          continue;
        }
        // Комментарии в этом проекте русские по решению заказчика.
        if (trimmed.startsWith('///') ||
            trimmed.startsWith('//') ||
            trimmed.startsWith('*')) {
          continue;
        }

        for (final pattern in _literals) {
          for (final match in pattern.allMatches(lines[i])) {
            final value = match.group(0)!;
            if (!_cyrillic.hasMatch(value)) continue;
            offences.add(
              '  ${file.path.replaceAll(r'\', '/')}:${i + 1}  $value',
            );
          }
        }
      }
    }

    expect(
      offences,
      isEmpty,
      reason:
          'русский текст в экранах отчётов доедет до человека, выбравшего '
          'английский. Заведите ключ в словаре, а не исключение здесь:\n'
          '${offences.join('\n')}',
    );
  });
}

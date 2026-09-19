import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Таблица знаков бумаги в дереве **одна**.
///
/// ## Почему сторож, а не договорённость
///
/// На 2026-09-19 таблиц кириллицы в `lib/` было **восемь**, и они
/// расходились между собой (измерено поимённо):
///
/// | где | что делал | расхождение |
/// |---|---|---|
/// | `printer/receipt_builder.dart` | кодировщик чека | `₸ → '?'` |
/// | `printer/receipt/receipt_builder.dart` | второй кодировщик | `₸ → 'T'` |
/// | `printer/text_formatter.dart` | звал второй | то же |
/// | `printer/print_utility.dart` | кодировщик пробной печати | `₸ → '?'` |
/// | `printer/escpos_text_preview.dart` | декодировщик предпросмотра | `0xFC → №` |
/// | `emulators/escpos/render.dart` | декодировщик эмулятора | `0xFC → ·` |
/// | `emulators/labels/zpl.dart` | декодировщик этикеток (1251) | `« → ?` |
/// | `display/vfd_display.dart` | кодировщик табло | «р»…«я» в псевдографику |
///
/// Последняя строка — не мелочь: покупатель видел на табло рамки вместо
/// букв, и **ни одна проба туда не смотрела**. Расхождение кодировщика с
/// декодировщиком хуже каждого из них: оно красит верный код и зеленит
/// неверный.
///
/// Девятая появится незаметно — восьмую никто не заметил. Поэтому сторож.
///
/// ## Чем краснеет
///
/// Заведите в любом файле `lib/` собственное соответствие кодовой точки и
/// байта — хоть `codePoint - 0x410 + 0x80`, хоть `0x0451` рядом с `0xF1`, —
/// и проба назовёт файл и строку.
///
/// ## Чего это НЕ доказывает
///
/// Что таблица верна: за это отвечает `test/unit/hardware/paper_charset_test`.
/// И ничего о том, что нарисует принтер.
void main() {
  /// Файл, которому **можно** знать таблицу, — ровно один.
  const String home = 'lib/hardware/paper_charset.dart';

  /// Кодовые точки кириллицы, по которым узнаётся частная таблица.
  ///
  /// `0x410`/`0x0410` — начало «А»; `0x451`/`0x0451` — «ё», лежащая вне
  /// непрерывного участка и потому названная отдельно в каждой самодельной
  /// таблице; `0x2116` — «№», у которой байт есть только в таблице.
  final markers = <RegExp>[
    RegExp(r'0x0?410\b'),
    RegExp(r'0x0?430\b'),
    RegExp(r'0x0?451\b'),
    RegExp(r'0x2116\b'),
  ];

  test('соответствие «кодовая точка ↔ байт» объявлено ровно в одном файле', () {
    final offenders = <String>[];

    final root = Directory('lib');
    expect(root.existsSync(), isTrue, reason: 'проба запущена не из корня');

    for (final entity in root.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final path = entity.path.replaceAll(r'\', '/');
      if (path == home) continue;
      // Сгенерированное drift — не рукописная таблица.
      if (path.endsWith('.g.dart') || path.endsWith('.freezed.dart')) continue;

      final lines = entity.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        // Ссылка в докстринге — это рассказ о таблице, а не таблица.
        if (line.trimLeft().startsWith('///')) continue;
        if (line.trimLeft().startsWith('//')) continue;
        if (markers.any((m) => m.hasMatch(line))) {
          offenders.add('$path:${i + 1}: ${line.trim()}');
        }
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'частная таблица знаков вне $home — её место там, иначе бумага и '
          'её чтение разойдутся молча:\n${offenders.join('\n')}',
    );
  });
}

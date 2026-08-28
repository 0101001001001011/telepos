import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Страж правила «фон берётся ролью темы, а не константой палитры».
///
/// Появился по конкретному дефекту, а не из общих соображений. Когда
/// `AppTextStyles` перестал запекать светлый цвет, текст пошёл из
/// `colorScheme.onSurface` и в тёмной теме стал белым — правильно. Но 104
/// экрана красили фон константой (`backgroundColor: AppColors.background`,
/// `color: AppColors.white`), и фон остался светлым. Получилось белое по
/// белому: до правки темы экран читался, после — перестал.
///
/// Важное свойство того дефекта: **он не ломал ни одной проверки**. Экран
/// собирался, тесты проходили, светлые эталоны совпадали до пикселя. Заметить
/// его можно было только глазами и только в тёмной теме. Поэтому страж читает
/// исходник: во время работы `AppColors.white` и `colorScheme.surface` в
/// светлой теме — один и тот же `Color(0xFFFFFFFF)`, и по отрисованному дереву
/// их не различить вовсе.
///
/// Проверяются оба каталога UI, а не только `screens/`: оболочка, диалоги и
/// общие виджеты живут в `common/` и красили фон ровно так же.
const _roots = <String>[
  'lib/presentation/screens',
  'lib/presentation/common',
];

/// Нейтральные роли палитры — те, что не значат ничего, кроме «поверхность»
/// или «холст».
///
/// Именно они обязаны приходить из темы. Акценты (`primary`, `error`,
/// `success`, `warning`, `paymentCash`, …) сюда НЕ входят намеренно: залитая
/// красным кнопка удаления красная в обеих темах, и это её смысл, а не
/// недосмотр. Запретить их заодно значило бы получить стража, который красен
/// с первого дня, — а такой страж не охраняет ничего.
const _neutralRoles = <String>[
  'white',
  'black',
  'background',
  'surface',
  'greyLight',
  'tgSheet',
  'tgCanvas',
  'tgHairline',
  'tgDarkSheet',
  'tgDarkCanvas',
];

/// Конструкторы, у которых `color:` — это заливка, а не обводка и не значок.
///
/// Без этого списка страж ловил бы `Icon(color: AppColors.white)` и
/// `BorderSide(color: AppColors.greyLight)` — белый значок на синей кнопке и
/// цвет волоска. Ни то, ни другое фоном не является.
const _panelCtors = <String>[
  'Container',
  'BoxDecoration',
  'Material',
  'Card',
  'ColoredBox',
  'DecoratedBox',
  'AnimatedContainer',
];

final _roleAlternatives = _neutralRoles.join('|');

/// `backgroundColor: AppColors.<нейтральная роль>` — где бы ни стояло.
final _backgroundRule = RegExp(
  'backgroundColor:\\s*AppColors\\.($_roleAlternatives)\\b',
);

/// `color: AppColors.<нейтральная роль>` — но только внутри заливаемого
/// конструктора и только как **первое** на строке.
///
/// Якорь `^\s*` здесь не косметика. Без него правило ловило
/// `border: Border.all(color: AppColors.greyLight)` на строке сразу после
/// `decoration: BoxDecoration(` — то есть цвет **волоска**, а не заливки, и
/// объявляло дефектом ровно то, что дефектом не является. Измерено: семь из
/// семнадцати первых срабатываний были такими.
final _colorRule = RegExp('^\\s*color:\\s*AppColors\\.($_roleAlternatives)\\b');

/// Тот же `color:` на одной строке с конструктором: `Container(color: ...)`.
final _inlinePanelRule = RegExp(
  '(${_panelCtors.join('|')})\\(\\s*color:\\s*AppColors\\.($_roleAlternatives)\\b',
);

/// Строка кода без комментария: в комментариях эти имена как раз и объясняют,
/// почему их здесь больше нет.
String _strip(String line) {
  final i = line.indexOf('//');
  return i == -1 ? line : line.substring(0, i);
}

/// Открывает ли строка заливаемый конструктор, ничего в него не передав.
///
/// `dart format` разносит длинный вызов так, что имя конструктора остаётся на
/// одной строке, а `color:` уезжает на следующую. Смотреть на предыдущую
/// строку достаточно и точно: сам `color:` всегда идёт первым или почти первым
/// аргументом, а между именем и им перевод строки один.
bool _opensPanel(String line) {
  final code = _strip(line).trimRight();
  for (final ctor in _panelCtors) {
    if (code.endsWith('$ctor(')) return true;
  }
  return false;
}

void main() {
  test('в экранах и общих виджетах фон не задаётся константой палитры', () {
    final offenders = <String>[];
    var filesChecked = 0;

    for (final root in _roots) {
      final dir = Directory(root);
      expect(dir.existsSync(), isTrue, reason: 'каталог $root не найден');

      for (final entity in dir.listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        filesChecked++;
        final lines = entity.readAsLinesSync();

        for (var i = 0; i < lines.length; i++) {
          final code = _strip(lines[i]);
          final where = '${entity.path}:${i + 1}';

          final bg = _backgroundRule.firstMatch(code);
          if (bg != null) {
            offenders.add(
              '$where  фон константой AppColors.${bg.group(1)} — '
              'убрать (тему задаёт Theme) или взять роль',
            );
          }

          final inline = _inlinePanelRule.firstMatch(code);
          if (inline != null) {
            offenders.add(
              '$where  ${inline.group(1)} залит AppColors.${inline.group(2)} — '
              'взять colorScheme.surface или context.semantic.canvas',
            );
            continue;
          }

          // Перенесённый вариант: конструктор на прошлой строке, `color:` тут.
          if (i > 0 && _opensPanel(lines[i - 1])) {
            final m = _colorRule.firstMatch(code);
            if (m != null) {
              offenders.add(
                '$where  заливка AppColors.${m.group(1)} — '
                'взять colorScheme.surface или context.semantic.canvas',
              );
            }
          }
        }
      }
    }

    // Страж бесполезен, если каталоги переехали: пустой обход прошёл бы молча
    // и «зелёный» означал бы только то, что читать было нечего.
    expect(
      filesChecked,
      greaterThan(200),
      reason: 'проверено файлов: $filesChecked',
    );

    expect(
      offenders,
      isEmpty,
      reason:
          'Фон, взятый константой, остаётся светлым в тёмной теме, а текст '
          'поверх приходит из темы белым. Найдено ${offenders.length}:\n'
          '${offenders.join('\n')}',
    );
  });
}

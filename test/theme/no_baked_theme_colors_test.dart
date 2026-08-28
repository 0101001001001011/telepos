import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Страж правила «цвет, зависящий от темы, берётся у темы».
///
/// # Зачем, если есть `no_style_literals_test`
///
/// Тот стережёт литералы оформления (`Color(0x…)`, `fontSize: 14`) и только в
/// `lib/presentation/screens/setup/`. Здесь другое: константа
/// `AppColors.textPrimary` литералом не выглядит и сторожем не ловилась, а
/// беда от неё та же — **одно значение на обе темы**.
///
/// # Что измерено
///
/// Собранная касса в тёмной теме, 2026-08-27:
///
/// | место | было | стало |
/// |---|---|---|
/// | имя выбранного кассира | **1.12:1** | 11.23 |
/// | названия плиток настроек | **1.35:1** | 13.97 |
/// | заголовок пустого состояния сети | **1.17:1** | 16.1 |
///
/// Порог AA для текста — 4.5:1. Ни одно из этих мест не краснело ни в одном
/// тесте: в светлой теме константа верна, и увидеть беду можно было только
/// глазами и только на тёмной.
///
/// # Почему список именно такой
///
/// Здесь перечислены **только те** константы, чьё значение различается между
/// светлой и тёмной темой (`AppTheme.light` против `AppTheme.dark`). Замена
/// `success`/`warning`/`info` ничего бы не изменила: они сегодня одинаковы в
/// обеих темах намеренно, и сторож, требующий менять их, был бы шумом.
///
/// `primary` и `white` намеренно **не** в списке, и это не забывчивость:
/// заливка акцентом и текст поверх неё лечатся разными ролями
/// (`semantic.accentFill` против `colorScheme.primary`, см. докстринг
/// `AppSemanticColors.accentFill`), а `white` верен на цветной плашке и
/// неверен на поверхности. Разбор по месту — отдельная работа, и сторож,
/// поставленный до неё, заставил бы чинить наугад.
const _forbidden = <String>[
  'textPrimary',
  'textSecondary',
  'textHint',
  'grey',
  'tgMuted',
  'border',
  'borderLight',
  'divider',
  'greyMedium',
  'greyLight',
  'surfaceVariant',
  'primaryLighter',
  'error',
];

const _root = 'lib/presentation';

/// Строка кода без комментария: в комментариях имена объясняют, а не задают.
String _strip(String line) {
  final i = line.indexOf('//');
  return i == -1 ? line : line.substring(0, i);
}

/// Внутри списка значений `enum` контекста не существует.
///
/// Поле перечисления вычисляется до того, как появится хоть какой-нибудь
/// `BuildContext`, — роль темы туда подставить нечем. Это не послабление, а
/// граница языка: обойти её можно было бы только глобальным навигатором, то
/// есть заведя вторую правду о цвете.
///
/// Лечится не здесь: цвет должен перестать быть полем перечисления и стать
/// свойством виджета. Пока не стал — такие места сторож пропускает, и их
/// видно поимённо в отчёте теста ниже.
bool _insideEnumValues(List<String> lines, int index) {
  for (var i = index; i >= 0; i--) {
    final code = _strip(lines[i]);
    if (RegExp(r'^\s*enum\s+\w+').hasMatch(code)) return true;
    // `;` заканчивает список значений — дальше идут методы, у них контекст
    // уже бывает.
    if (code.trimRight().endsWith(';') && i != index) return false;
    if (RegExp(r'^\s*(class|mixin|extension)\s+\w+').hasMatch(code)) {
      return false;
    }
  }
  return false;
}

void main() {
  final pattern = RegExp(r'\bAppColors\.(' + _forbidden.join('|') + r')\b');

  test('цвет, зависящий от темы, не берётся константой в lib/presentation', () {
    final dir = Directory(_root);
    expect(dir.existsSync(), isTrue, reason: 'каталог $_root не найден');

    final offenders = <String>[];
    final exempt = <String>[];
    var filesChecked = 0;

    for (final entity in dir.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      filesChecked++;
      final lines = entity.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final code = _strip(lines[i]);
        final match = pattern.firstMatch(code);
        if (match == null) continue;
        final where = '${entity.path}:${i + 1}  ${code.trim()}';
        if (_insideEnumValues(lines, i)) {
          exempt.add(where);
        } else {
          offenders.add(where);
        }
      }
    }

    // Страховка от вырожденного обхода: пустой список файлов дал бы зелёный
    // тест, ничего не проверив, — та же ловушка, что у `no_style_literals`.
    expect(
      filesChecked,
      greaterThan(150),
      reason: 'обход $_root вернул $filesChecked файлов — сторож сломан',
    );

    expect(
      offenders,
      isEmpty,
      reason:
          'эти места берут цвет константой, одинаковой в обеих темах. В тёмной '
          'это даёт нечитаемый текст, и ни один другой тест того не увидит.\n'
          'Лечение: `Theme.of(context).colorScheme.<роль>` для чернил и границ, '
          '`context.semantic.canvas` для холста, `selectedSurfaceOf(context)` '
          'для плашки выбранного.\n\n${offenders.join('\n')}\n\n'
          'Пропущено внутри списков значений `enum` (контекста там нет): '
          '${exempt.length}',
    );
  });
}

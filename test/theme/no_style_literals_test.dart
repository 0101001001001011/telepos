import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Страж правила «стиль живёт только в теме».
///
/// Условие завершённости из спеки: в `lib/presentation/screens/setup/` не
/// остаётся ни одного литерала цвета, радиуса или отступа.
///
/// Проверка идёт по исходнику, а не по отрисованному дереву. Стиль, взятый из
/// темы, во время работы всё равно превращается в `TextStyle` с конкретным
/// размером — по нему литерал от не-литерала не отличить. Отличить их можно
/// только там, где они пишутся.
const _root = 'lib/presentation/screens/setup';

/// Что считается литералом оформления.
///
/// Числа внутри имён токенов (`AppTokens.space16`) не считаются: иначе счёт
/// объявляет нарушением ровно то поведение, которого добивались. Это не
/// послабление, а причина, по которой grep из отчёта завышал число — он
/// считал `EdgeInsets.all(AppTokens.space16)` литералом.
final _rules = <String, RegExp>{
  'EdgeInsets с числом': RegExp(
    r'EdgeInsets\.(all|symmetric|only|fromLTRB)\([^)]*(?<!AppTokens\.\w{0,20})\b\d',
  ),
  'BorderRadius.circular с числом': RegExp(r'BorderRadius\.circular\(\s*\d'),
  'шестнадцатеричный цвет': RegExp(r'Color\(0x'),
  'палитра Material': RegExp(r'\bColors\.(?!transparent\b)'),
  'кегль на месте': RegExp(r'fontSize:\s*\d'),
  'SizedBox с числом': RegExp(r'SizedBox\(\s*(height|width):\s*\d'),
  'размер иконки на месте': RegExp(r'\bsize:\s*\d'),
  'своя тень': RegExp(r'elevation:\s*[1-9]'),
};

/// Строка кода без комментария: в комментариях числа объясняют, а не задают.
String _strip(String line) {
  final i = line.indexOf('//');
  return i == -1 ? line : line.substring(0, i);
}

void main() {
  test('в экранах настройки не осталось литералов оформления', () {
    final dir = Directory(_root);
    expect(dir.existsSync(), isTrue, reason: 'каталог $_root не найден');

    final offenders = <String>[];
    var filesChecked = 0;

    for (final entity in dir.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      filesChecked++;
      final lines = entity.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final code = _strip(lines[i]);
        _rules.forEach((name, pattern) {
          if (pattern.hasMatch(code)) {
            offenders.add('${entity.path}:${i + 1}  [$name]  ${code.trim()}');
          }
        });
      }
    }

    // Страж бесполезен, если каталог переехал: пустой обход прошёл бы молча.
    expect(
      filesChecked,
      greaterThan(10),
      reason: 'проверено файлов: $filesChecked',
    );

    expect(
      offenders,
      isEmpty,
      reason:
          'Стиль задаётся темой: AppTokens, AppTypography, AppColors, '
          'context.semantic. Найдено:\n${offenders.join('\n')}',
    );
  });
}

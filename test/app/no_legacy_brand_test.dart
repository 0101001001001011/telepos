import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Проект переименован обратно в TelePOS 2026-07-29.
///
/// Что имя осталось в коде, обнаружил внешний анализ, а не сборка и не тесты —
/// то есть внутри проекта это никто не проверял. Этот тест проверяет.
void main() {
  test('в коде, тестах и ресурсах не осталось имени mynova', () {
    final pattern = RegExp('mynova', caseSensitive: false);
    final offenders = <String>[];

    for (final root in ['lib', 'test', 'assets/i18n']) {
      final dir = Directory(root);
      if (!dir.existsSync()) continue;

      for (final entity in dir.listSync(recursive: true)) {
        if (entity is! File) continue;
        if (!entity.path.endsWith('.dart') && !entity.path.endsWith('.arb')) {
          continue;
        }
        // Этот файл содержит искомое имя по долгу службы.
        if (entity.path.endsWith('no_legacy_brand_test.dart')) continue;

        final lines = entity.readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          if (pattern.hasMatch(lines[i])) {
            offenders.add('${entity.path}:${i + 1}: ${lines[i].trim()}');
          }
        }
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'Проект называется TelePOS. Осталось:\n${offenders.join('\n')}',
    );
  });
}

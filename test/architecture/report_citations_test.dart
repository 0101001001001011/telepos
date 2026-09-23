import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Ссылка на отчёт задачи ведёт в файл, который есть в git — задача 39.
///
/// `.superpowers/sdd/.gitignore` содержит `*`: отчёты задач по умолчанию в
/// дерево не попадают, и ссылка на такой отчёт — это проза, выглядящая
/// ссылкой. Читатель идёт по ней и не находит ничего, а текст рядом держится
/// на том, чего проверить нельзя.
///
/// # Почему путь, а не имя
///
/// Имя отчёта не уникально: отчёты задач 2, 6 и 17 в git есть — **у других
/// планов**. Проверка «такое имя где-то есть» зеленела бы на ссылке в чужой
/// отчёт. Поэтому ссылка обязана быть полным путём от корня репозитория, и
/// путь обязан быть в `git ls-files`.
void main() {
  test('каждая ссылка на отчёт задачи — отслеживаемый путь', () {
    final tracked =
        (Process.runSync('git', [
                  'ls-files',
                ], stdoutEncoding: systemEncoding).stdout
                as String)
            .split('\n')
            .map((line) => line.trim())
            .where((line) => line.isNotEmpty)
            .toSet();
    expect(tracked, isNotEmpty, reason: 'предпосылка: git ответил');

    // Перенос строки внутри комментария склеивается: путь в докстринге
    // рвётся на `///` так же часто, как и не рвётся.
    final continuation = RegExp(r'\r?\n[ \t]*//+[ \t]*');
    final citation = RegExp(
      r'([A-Za-z0-9_.\-]+/(?:[A-Za-z0-9_.\-]+/)*)?task-\d+-report\.md',
    );

    final dangling = <String>[];
    for (final root in ['lib', 'test']) {
      for (final entity in Directory(root).listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        final path = entity.path.replaceAll(r'\', '/');
        final text = entity.readAsStringSync().replaceAll(continuation, '');
        for (final match in citation.allMatches(text)) {
          final cited = match.group(0)!;
          if (match.group(1) == null || !tracked.contains(cited)) {
            dangling.add('$path: $cited');
          }
        }
      }
    }

    expect(
      dangling,
      isEmpty,
      reason:
          'ссылка на отчёт, которого нет в git, — проза, а не ссылка: '
          'перенесите отчёт в docs/internal/superpowers/reports/ или снимите '
          'ссылку, оставив сам довод',
    );
  });
}

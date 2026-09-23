/// Ход подъёма везёт КОД, а не готовые слова.
///
/// # Что измерено 2026-09-21
///
/// На заставке английской кассы стояло «Готово» — по-русски. И не только
/// оно: тридцать сообщений о ходе подъёма собирались готовым русским
/// текстом в `lib/app/config` и `lib/app/services`, то есть в слое, который
/// языка интерфейса не знает.
///
/// Заставка — первое, что показывает приложение, и висит она секунд десять.
/// Видел это каждый, кто запускал кассу не по-русски.
///
/// # Что именно ищется
///
/// Строковый литерал вторым доводом `onProgress`. Ловится след, а не
/// кириллица: напишут то же самое по-английски — и слой подъёма снова
/// начнёт решать за интерфейс, на каком языке говорить.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  /// Где живут те, кто сообщает о ходе подъёма.
  const roots = [
    'lib/app/config',
    'lib/app/services',
    'lib/web',
    'lib/backend',
    'lib/presentation',
  ];

  /// `onProgress(…, '…')` и `onProgress?.call(…, '…')` — строка вторым.
  final freeText = RegExp(
    r'''onProgress(\?\.call)?\(\s*[^,()]+,\s*['"]''',
  );

  test('сторож смотрит не в пустоту: вызовы вообще есть', () {
    var calls = 0;
    for (final root in roots) {
      final dir = Directory(root);
      if (!dir.existsSync()) continue;
      for (final file in dir.listSync(recursive: true)) {
        if (file is! File || !file.path.endsWith('.dart')) continue;
        calls += RegExp(
          r'onProgress(\?\.call)?\(',
        ).allMatches(file.readAsStringSync()).length;
      }
    }
    expect(
      calls,
      greaterThan(10),
      reason:
          'вызовов о ходе подъёма почти нет — либо их убрали, либо сторож '
          'ищет не то',
    );
  });

  test('ни один этап не сообщается готовой строкой', () {
    final offenders = <String>[];

    for (final root in roots) {
      final dir = Directory(root);
      if (!dir.existsSync()) continue;
      for (final file in dir.listSync(recursive: true)) {
        if (file is! File || !file.path.endsWith('.dart')) continue;
        final text = file.readAsStringSync();
        for (final match in freeText.allMatches(text)) {
          final line = '\n'.allMatches(text.substring(0, match.start)).length + 1;
          offenders.add('${file.path.replaceAll(r'\', '/')}:$line');
        }
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'этап подъёма сообщается словами. Слой подъёма отвечает на вопрос '
          '«где мы сейчас», а какими словами об этом сказать — знает только '
          'тот, кто знает язык. Заведите значение в `BootStage` и ключ в '
          '`assets/i18n/*.arb`:\n${offenders.join('\n')}',
    );
  });
}

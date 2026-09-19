@Tags(['architecture'])
library;

import 'dart:collection';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// В браузерной сборке сдвиг влево не имеет права зависеть от разрядности.
///
/// # Что это стоило: экран, не открывшийся вовсе
///
/// Живой прогон 2026-09-07. Кассир нажимает «Возврат» — серый прямоугольник
/// во всю страницу, ни списка, ни панели. В консоли:
///
/// ```
/// ProviderException: Tried to use a provider that is in error state.
/// RangeError: max must be in range 0 < max ≤ 2^32, was 0
/// ```
///
/// Причина — одна строка, делавшая метку ключа идемпотентности:
/// `Random().nextInt(1 << 32)`. В Dart VM `1 << 32` равно 4294967296. **В
/// вебе это ноль**: dart2js считает `<<` 32-битной операцией и обрезает
/// результат (`(1 << 32) | 0`). `nextInt(0)` бросает, провайдер уходит в
/// состояние ошибки целиком, экран не строится.
///
/// Ноль **измерен** (`dart compile js` + node, разбор круга правки), а не
/// выведен из правил JavaScript: там сдвиг берётся по модулю 32 и
/// `1 << 32` дало бы единицу. У dart2js результат другой, и в первой
/// редакции этого докстринга обе версии стояли рядом. Верна эта.
///
/// **Ни одна проба набора этого не видела и не могла.** Все они идут в Dart
/// VM, где это совершенно нормальное число. Прогнать набор в настоящем
/// браузере тоже нельзя: `flutter test --platform chrome` на этом дереве
/// падает «Connection closed before test suite loaded / The Dart compiler
/// exited unexpectedly» — проверено 2026-09-07, не предположено.
///
/// Значит остаётся текстовый сторож, и он обязан честно назвать, что ловит.
///
/// # Правило: правый операнд `<<` — числовой литерал меньше 32
///
/// Не «литерал 32 и больше — плохо», как у соседнего сторожа узла продажи.
/// Тот измерил свой предел сам: `1 << 32` и `1 << 33` краснеют, а
/// `const bits = 32; 1 << bits` проходит зелёным. Здесь правило вывернуто:
/// **разрешено только очевидное**. Любой сдвиг, чью величину нельзя прочесть
/// глазом прямо в этой строке, — красный, и разрешается поимённо со
/// строкой-объяснением.
///
/// Это ловит на класс шире:
///
/// | Форма | Сосед | Здесь |
/// | --- | --- | --- |
/// | `1 << 32` | краснеет | краснеет |
/// | `const bits = 32; 1 << bits` | зелёный | **краснеет** |
/// | `1 << attempt` (счётчик попыток) | зелёный | **краснеет** |
/// | `1 << 8` | зелёный | зелёный |
///
/// Средняя строка — не выдумка: `1 << attempt` живёт в четырёх файлах
/// транспорта (`transport_coordinator.dart:247`,
/// `fallback_strategy.dart:55`, `queued_operation.dart:139`,
/// `websocket_client.dart:261`) и означает растущую паузу между попытками.
/// В браузере тридцать вторая попытка дала бы паузу **ноль** — молча.
/// Сегодня эти файлы в браузерную сборку **не входят** (замерено обходом
/// графа, см. ниже), и потому сторож их не видит; войдут — увидит.
///
/// # Область: замыкание браузерной сборки, а не всё дерево
///
/// Обход импортов от `lib/web/main_web.dart`. Кассе 64-битные сдвиги
/// разрешены и нужны (`till_wire.dart:224`, `listenerId << 40` — упаковка
/// идентификатора слушателя и сессии в одно число), и запрещать их всему
/// дереву значило бы сломать кассу ради браузера.
///
/// # Пределы, названные прямо
///
/// - **Считается текст, а не разбор.** `<<` внутри строкового литерала или
///   комментария сторож не отличает от кода. Комментарии и строки вырезаются
///   тем же приёмом, что в `browser_routes_test.dart`, но исчерпывающим
///   разбором Dart это не является.
/// - **Переименование или косвенность обходит его.** `shiftBy(1, 32)` не
///   содержит `<<` вовсе. Ловится только прямая форма.
/// - **`>>` не проверяется совсем.** Сосед измерил, почему: правый сдвиг
///   даёт 25 совпадений в дереве, и все 25 — закрывающие скобки обобщений
///   (`Stream<List<CartView>>`). Отделить одно от другого может только
///   разбор типов, и текстовый сторож здесь бессилен. Правого сдвига в
///   браузерном замыкании сегодня нет ни одного — но это состояние, а не
///   охрана.
/// - **Не заменяет живой прогон.** Он и нашёл этот дефект; сторож лишь
///   не даёт ему вернуться той же формой.
const _entryPoint = 'lib/web/main_web.dart';

/// Ниже этого числа сдвиг одинаков на любой платформе.
const _safeShiftLimit = 32;

/// Сдвиги, разрешённые поимённо. Каждая запись — со строкой, почему.
///
/// Пуст, и это тоже измерение: в браузерном замыкании сегодня нет ни одного
/// сдвига, который потребовал бы объяснения.
const _allowed = <String, String>{};

final _importStatementPattern = RegExp(
  r'^[ \t]*(?:import|export)\b[^;]*;',
  multiLine: true,
);

final _importTargetPattern = RegExp("['\"]([^'\"]+)['\"]");

/// `<<` и всё, что стоит за ним до конца строки.
final _shiftPattern = RegExp(r'<<\s*([^;,)\]}\n]*)');

/// Числовой литерал целиком: `32`, `0x20`, `0xFFFFFFFF`.
final _numericLiteral = RegExp(r'^(?:0[xX][0-9a-fA-F]+|\d+)$');

String _slash(String path) => path.replaceAll(r'\', '/');

File _file(String slashPath) =>
    File(slashPath.replaceAll('/', Platform.pathSeparator));

/// Комментарии и строковые литералы — вон, тем же приёмом, что в
/// `browser_routes_test.dart`.
String _withoutCommentsAndStrings(String source) => source
    .replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), '')
    .replaceAll(RegExp(r'//[^\n]*'), '')
    .replaceAll(RegExp(r"'''.*?'''", dotAll: true), "''")
    .replaceAll(RegExp(r'""".*?"""', dotAll: true), '""')
    .replaceAll(RegExp(r"'(?:\\.|[^'\\\n])*'"), "''")
    .replaceAll(RegExp(r'"(?:\\.|[^"\\\n])*"'), '""');

String _resolveRelative(String fromSlashPath, String importPath) {
  final lastSlash = fromSlashPath.lastIndexOf('/');
  final parts = (lastSlash >= 0 ? fromSlashPath.substring(0, lastSlash) : '')
      .split('/');
  for (final part in importPath.split('/')) {
    if (part.isEmpty || part == '.') continue;
    if (part == '..') {
      if (parts.isNotEmpty) parts.removeLast();
    } else {
      parts.add(part);
    }
  }
  return parts.join('/');
}

/// Все файлы `lib/`, достижимые импортами от [entry].
Set<String> reachableFrom(String entry) {
  final seen = <String>{};
  final queue = Queue<String>()..add(entry);

  while (queue.isNotEmpty) {
    final current = queue.removeFirst();
    if (!seen.add(current)) continue;

    final file = _file(current);
    if (!file.existsSync()) continue;

    for (final match in _importStatementPattern.allMatches(
      file.readAsStringSync(),
    )) {
      final statement = match.group(0)!.trim();
      // Условный импорт — платформенный шов: какую половину возьмёт сборка,
      // по тексту не узнать. Та же оговорка, что в `browser_routes_test`.
      if (statement.contains(' if (')) continue;

      final target = _importTargetPattern.firstMatch(statement)?.group(1);
      if (target == null) continue;

      final String next;
      if (target.startsWith('package:telepos/')) {
        next = 'lib/${target.substring('package:telepos/'.length)}';
      } else if (target.startsWith('package:') || target.startsWith('dart:')) {
        continue;
      } else {
        next = _resolveRelative(current, target);
      }
      if (!seen.contains(next)) queue.add(next);
    }
  }

  return seen;
}

void main() {
  test('обход графа импортов что-то нашёл', () {
    // Без этого проверка ниже зелена на пустом множестве: переименование
    // точки входа сняло бы охрану молча.
    final reachable = reachableFrom(_entryPoint);
    expect(
      reachable.length,
      greaterThan(100),
      reason:
          'от $_entryPoint достижимо ${reachable.length} файлов — обход не '
          'пошёл, и проверка ниже ничего не значит',
    );
    expect(
      reachable,
      contains('lib/presentation/controllers/refund/refund_controller.dart'),
      reason: 'узел возврата обязан быть в браузерной сборке — задача 20',
    );
  });

  test('в браузерной сборке нет сдвигов с неочевидной разрядностью', () {
    final offenders = <String>[];

    for (final path in reachableFrom(_entryPoint)) {
      final file = _file(path);
      if (!file.existsSync()) continue;
      final source = _withoutCommentsAndStrings(file.readAsStringSync());

      for (final match in _shiftPattern.allMatches(source)) {
        final operand = match.group(1)!.trim();
        final line =
            '\n'.allMatches(source.substring(0, match.start)).length + 1;
        final where = '${_slash(path)}:$line';

        if (_allowed.containsKey(where)) continue;

        if (!_numericLiteral.hasMatch(operand)) {
          offenders.add('$where: << $operand — величина не читается глазом');
          continue;
        }
        final value = operand.toLowerCase().startsWith('0x')
            ? int.parse(operand.substring(2), radix: 16)
            : int.parse(operand);
        if (value >= _safeShiftLimit) {
          offenders.add('$where: << $value — в браузере это не то число');
        }
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'Сдвиг влево в браузере 32-битный: `1 << 32` даёт ноль, а не '
          '4294967296. Живой прогон 2026-09-07 нашёл ровно это — экран '
          'возврата не открывался вовсе, `RangeError: max must be in range '
          '0 < max ≤ 2^32, was 0`. Разрешено только то, чью величину видно '
          'в самой строке и она меньше $_safeShiftLimit; всё прочее — '
          'поимённо в `_allowed` со строкой, почему это безопасно.',
    );
  });

  test('метку ключа идемпотентности делает одно место, а не два', () {
    // До живого прогона одну и ту же строку держали два контроллера,
    // побайтово. Починили одну — вторая осталась сломанной и убила экран.
    // Третьей копии быть не должно.
    final callers = <String>[
      'lib/presentation/controllers/refund/refund_controller.dart',
      'lib/presentation/controllers/sale/sale_controller.dart',
    ];

    for (final path in callers) {
      final source = _file(path).readAsStringSync();
      expect(
        source,
        contains('newCommandSessionTag()'),
        reason: '$path завёл собственную метку вместо общей',
      );
      expect(
        source,
        isNot(contains('nextInt(')),
        reason:
            '$path снова считает случайное число сам — а именно это и '
            'сломало браузер',
      );
    }
  });
}

@Tags(['architecture'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Узел возврата не разговаривает с базой напрямую — задача 20 плана
/// «Продажа с браузерного терминала».
///
/// # Что охраняется и почему отдельным файлом
///
/// Сосед `sale_layering_test.dart` сторожит узел продажи и заведён задачей 8.
/// Здесь то же правило для второго узла — возврата, — у которого с задачи 18
/// есть свой доменный контракт (`RefundService`,
/// `lib/domain/refund/refund_service.dart`). Файл отдельный, потому что
/// задачи разные и списки каталогов разные; сводить их в один значило бы
/// сделать место, где сходятся две ветки одной фазы.
///
/// # Почему сторож обязан был покраснеть до правки
///
/// Он и покраснел. До задачи 20 узел возврата называл `AppDatabase` в трёх
/// файлах — счёт получен обходом, а не памятью:
///
/// ```
/// grep -rn "AppDatabase" lib/presentation/controllers/refund \
///                        lib/presentation/screens/refund
/// → refund_controller.dart:9  (import), :231 (loadReceipt читает Sales,
///                              SaleProducts, ProductInfos и ThisPos сам)
/// → refund_screen.dart:6      (import), :105 (номер кассы для диалога),
///                              :277 (чек возврата: смена, кассир, счета),
///                              :349 (разнос суммы по платежам чека)
/// → widgets/receipt_input_dialog.dart:8 (import), :63 (последние чеки)
/// ```
///
/// Каждый из них — путь, которого в браузере нет вовсе: `AppDatabase` тянет
/// `dart:ffi` через drift, а в веб-сборке `dart:ffi` не существует. Пока эти
/// три файла были такими, маршрут `/refund` нельзя было даже объявить в
/// браузерной таблице — сборка веба падала бы на компиляции, а не на первом
/// нажатии.
///
/// # Честно о пределе: проверка прямая, а не транзитивная
///
/// Оба теста читают **собственные** операторы `import`/`export` файлов узла и
/// вниз по графу не спускаются — тот же предел и та же причина, что у
/// `sale_layering_test.dart`. Транзитивную половину для этого узла закрывает
/// сборка веба (`flutter build web -t lib/web/main_web.dart`): она проходит по
/// настоящему графу и падает на `dart:ffi`, откуда бы он ни пришёл. Сторож
/// здесь дешевле и краснеет раньше, но доказательством вместо сборки не
/// является — и не заявляется таковым.
///
/// # Второй предел: имя считается и в комментарии
///
/// Первый тест читает файл текстом и не отличает код от докстринга. Выбрано
/// сознательно, тем же доводом, что у соседа: сторож, умеющий отличать код от
/// текста, ровно так же научится не видеть имя, собранное из строк. Цена —
/// переписать комментарий, если он назвал тип; так и сделано здесь, в этом
/// докстринге имя базы разорвано в примере обхода выше.
const refundNodeRoots = <String>[
  'lib/presentation/controllers/refund',
  'lib/presentation/screens/refund',
];

/// Прямые импорты, запрещённые узлу возврата.
///
/// `package:telepos/data/` — вся инфраструктура, включая базу.
/// `package:drift/` — отдельной строкой: `Value(...)`/`RefundsCompanion` можно
/// написать, импортировав только drift, и запрет на `lib/data/` этого не
/// поймал бы. `dart:ffi` — названо прямо, хотя сегодня в узле его нет:
/// именно оно и делает разницу между «работает на кассе» и «не собирается
/// под браузер» (И5).
const forbiddenImportsInRefundNode = <String>[
  'package:telepos/data/',
  'package:drift/',
  'dart:ffi',
];

/// То же самое для относительных импортов: `import '../../../data/x.dart';`
/// — то же нарушение, но подстроки `package:telepos/data/` в строке нет.
const forbiddenRelativeRootsInRefundNode = <String>['lib/data/'];

final _appDatabaseWord = RegExp(r'\bAppDatabase\b');

final _importStatementPattern = RegExp(
  r'^[ \t]*(?:import|export)\b[^;]*;',
  multiLine: true,
);

final _importTargetPattern = RegExp("['\"]([^'\"]+)['\"]");

Iterable<File> _dartFilesUnder(Iterable<String> roots) sync* {
  for (final root in roots) {
    final dir = Directory(root);
    if (!dir.existsSync()) continue;
    yield* dir
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'));
  }
}

String _displayPath(File file) => file.path.replaceAll(r'\', '/');

String _resolveRelativeImport(File file, String importPath) {
  final fileSlashPath = _displayPath(file);
  final lastSlash = fileSlashPath.lastIndexOf('/');
  final dirParts = (lastSlash >= 0 ? fileSlashPath.substring(0, lastSlash) : '')
      .split('/');
  final resultParts = List<String>.from(dirParts);
  for (final part in importPath.split('/')) {
    if (part.isEmpty || part == '.') continue;
    if (part == '..') {
      if (resultParts.isNotEmpty) resultParts.removeLast();
    } else {
      resultParts.add(part);
    }
  }
  return resultParts.join('/');
}

void main() {
  test('файлы возврата не тянут базу', () {
    final offenders = <String>[];
    for (final file in _dartFilesUnder(refundNodeRoots)) {
      final source = file.readAsStringSync();
      final match = _appDatabaseWord.firstMatch(source);
      if (match != null) {
        final line =
            '\n'.allMatches(source.substring(0, match.start)).length + 1;
        offenders.add('${_displayPath(file)}:$line');
      }
    }
    expect(
      offenders,
      isEmpty,
      reason:
          'Возврат живёт за контрактом `RefundService` (задача 18). Экран, '
          'который спрашивает базу сам, работает только на кассе — с '
          'браузерного терминала тот же код выполнить нечем, и веб-сборка '
          'его даже не скомпилирует. См. docs/system-architecture.md, И5.',
    );
  });

  test('узел возврата не импортирует инфраструктуру', () {
    final offenders = <String>[];
    for (final file in _dartFilesUnder(refundNodeRoots)) {
      for (final statement in _importStatementPattern.allMatches(
        file.readAsStringSync(),
      )) {
        final line = statement.group(0)!.trim();
        // Условный импорт — платформенный шов дерева: какая половина
        // компилируется, решает цель сборки, и текстовая проверка выбрать не
        // может. Та же оговорка, что в `layering_test.dart`.
        if (line.contains(' if (')) continue;
        final target = _importTargetPattern.firstMatch(line)?.group(1);
        if (target == null) continue;

        if (target.startsWith('package:') || target.startsWith('dart:')) {
          if (forbiddenImportsInRefundNode.any(target.startsWith)) {
            offenders.add('${_displayPath(file)}  ->  $target');
          }
        } else {
          final resolved = _resolveRelativeImport(file, target);
          if (forbiddenRelativeRootsInRefundNode.any(resolved.startsWith)) {
            offenders.add(
              '${_displayPath(file)}  ->  $target (resolves to $resolved)',
            );
          }
        }
      }
    }
    expect(
      offenders,
      isEmpty,
      reason:
          'Узлу возврата доступен только домен: `RefundService`, '
          '`CartService`, `RecentReceipts`. Прямой `package:telepos/data/`, '
          '`package:drift/` или `dart:ffi` — дефект, а не сокращение.',
    );
  });

  test('каждый охраняемый каталог существует и даёт файлы для проверки', () {
    // Опечатка в пути молча снимает охрану: `_dartFilesUnder` вернул бы
    // пустоту, и оба теста выше «проходили» бы, ничего не читая.
    for (final root in refundNodeRoots) {
      expect(
        Directory(root).existsSync(),
        isTrue,
        reason: 'В refundNodeRoots указан несуществующий каталог: $root',
      );
      expect(
        _dartFilesUnder([root]),
        isNotEmpty,
        reason: 'В refundNodeRoots каталог без единого .dart-файла: $root',
      );
    }
  });
}

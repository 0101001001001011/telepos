@Tags(['architecture'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Узел продажи не разговаривает с базой напрямую — задача 8 плана
/// «Продажа с браузерного терминала».
///
/// # Что охраняется
///
/// Экран продажи и его контроллер — единственный узел интерфейса, у которого
/// с задачи 7 есть доменный контракт корзины (`CartService`,
/// `lib/domain/sale/cart_service.dart`). До этой работы контроллер держал
/// корзину в памяти и сам ходил в `AppDatabase` восемнадцатью вызовами, а
/// экран и сетка быстрых товаров — ещё пятью. Смысл задачи 8 в том, что
/// корзина стала одна на два фронта: касса и браузер зовут один контракт, и
/// «сокращение» в виде прямого запроса к базе из экрана эту единственность
/// молча ломает — браузер такого запроса выполнить не может вовсе.
///
/// # Почему сторож обязан был покраснеть до правки
///
/// Он и покраснел: до коммита, вводящего эту проверку, оба теста ниже
/// называли три файла —
///
/// ```
///   lib/presentation/controllers/sale/sale_controller.dart
///   lib/presentation/screens/sale/sale_screen.dart
///   lib/presentation/screens/sale/widgets/quick_products_grid.dart
/// ```
///
/// Зелёный сторож, заведённый уже поверх исправленного кода, не доказывает
/// ничего: он не отличает «правило соблюдено» от «проверка смотрит не туда»
/// (правило дерева — [[feedback_guard_must_redden]]).
///
/// # Честно о пределе: проверка прямая, а не транзитивная
///
/// Оба теста читают **собственные** операторы `import`/`export` файлов узла и
/// не спускаются по графу вниз. Значит помощник в `lib/presentation/common/`,
/// импортирующий `AppDatabase` и вызванный отсюда, сторожа не покрасит.
/// Транзитивный обход здесь неприменим не по лени, а по измеренной причине:
/// `lib/presentation/screens/sale/sale_hardware.dart` законно импортирует
/// `package:telepos/hardware/` (дисплей покупателя, весы, принтер этикеток),
/// а `lib/hardware/` ниже по графу доходит до `lib/data/` — транзитивный
/// сторож красил бы узел за то, чего эта задача не чинит и не обещала
/// починить (прямой импорт `lib/hardware/` из интерфейса — известное
/// нарушение слоёв в 17 файлах дерева, отдельная работа).
///
/// Транзитивную половину закрывает `layering_test.dart` для тех каталогов,
/// которые уже целиком чисты; узел продажи попадёт туда, когда `lib/hardware/`
/// уйдёт за контракт.
///
/// # Второй предел, названный намеренно: имя считается и в комментарии
///
/// Первый тест читает файл **текстом** и не отличает код от докстринга —
/// упомянуть `AppDatabase` в комментарии значит покрасить сторожа. Это
/// выбрано, а не упущено: разбор комментариев требует разбора Dart, а
/// сторож, умеющий отличать код от текста, ровно так же научится не видеть
/// имя, собранное из строк. Цена — переписать комментарий, если он назвал
/// тип; так и сделано в `sale_controller._resolveTerminalId`.
const saleNodeRoots = <String>[
  'lib/presentation/controllers/sale',
  'lib/presentation/screens/sale',
];

/// Прямые импорты, запрещённые узлу продажи.
///
/// `package:telepos/data/` — вся инфраструктура, включая `AppDatabase`.
/// `package:drift/` — отдельной строкой: `Value(...)`/`SalesCompanion` можно
/// написать, импортировав только drift, и запрет на `lib/data/` этого не
/// поймал бы (именно так контроллер и писал строки чека до задачи 8).
const forbiddenImportsInSaleNode = <String>[
  'package:telepos/data/',
  'package:drift/',
];

/// То же самое для относительных импортов: `import '../../../data/x.dart';`
/// — то же нарушение, но подстроки `package:telepos/data/` в строке нет.
const forbiddenRelativeRootsInSaleNode = <String>['lib/data/'];

/// Имя типа базы. Проверяется как **слово**, а не подстрока: `AppDatabase`
/// внутри `MyAppDatabaseThing` — другое имя, и ложная краснота сторожа стоит
/// доверия к нему.
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
  test('файлы продажи не тянут AppDatabase', () {
    final offenders = <String>[];
    for (final file in _dartFilesUnder(saleNodeRoots)) {
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
          'Корзина живёт за контрактом `CartService` (задача 7). Экран, '
          'который спрашивает базу сам, работает только на кассе — с '
          'браузерного терминала тот же код выполнить нечем. См. '
          'docs/system-architecture.md, И5.',
    );
  });

  test('узел продажи не импортирует инфраструктуру', () {
    final offenders = <String>[];
    for (final file in _dartFilesUnder(saleNodeRoots)) {
      for (final statement in _importStatementPattern.allMatches(
        file.readAsStringSync(),
      )) {
        final line = statement.group(0)!.trim();
        // Условный импорт (`import 'a.dart' if (dart.library.io) 'b.dart';`)
        // — платформенный шов дерева: какая половина компилируется, решает
        // цель сборки, и текстовая проверка выбрать не может. Тот же вывод и
        // та же оговорка, что в `layering_test.dart`.
        if (line.contains(' if (')) continue;
        final target = _importTargetPattern.firstMatch(line)?.group(1);
        if (target == null) continue;

        if (target.startsWith('package:') || target.startsWith('dart:')) {
          if (forbiddenImportsInSaleNode.any(target.startsWith)) {
            offenders.add('${_displayPath(file)}  ->  $target');
          }
        } else {
          final resolved = _resolveRelativeImport(file, target);
          if (forbiddenRelativeRootsInSaleNode.any(resolved.startsWith)) {
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
          'Узлу продажи доступен только домен: `CartService`, '
          '`SaleUseCase`, `QuickProductCatalog`. Прямой `package:telepos/'
          'data/` или `package:drift/` — дефект, а не сокращение.',
    );
  });

  test('каждый охраняемый каталог существует и даёт файлы для проверки', () {
    // Опечатка в пути молча снимает охрану: `_dartFilesUnder` вернул бы
    // пустоту, и оба теста выше «проходили» бы, ничего не читая. Тот же
    // урок, что записан в `layering_test.dart`.
    for (final root in saleNodeRoots) {
      expect(
        Directory(root).existsSync(),
        isTrue,
        reason: 'В saleNodeRoots указан несуществующий каталог: $root',
      );
      expect(
        _dartFilesUnder([root]),
        isNotEmpty,
        reason: 'В saleNodeRoots каталог без единого .dart-файла: $root',
      );
    }
  });
}

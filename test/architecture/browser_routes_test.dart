@Tags(['architecture'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Браузерная таблица маршрутов обязана отвечать на каждый переход, который
/// умеют делать её собственные экраны.
///
/// # Что это стоило
///
/// 2026-08-06 заказчик прошёл мастер настройки в браузере до конца и получил
/// «Page Not Found: `GoException: no routes for location: /login`».
/// `createSetupRouter` объявлял три маршрута — заставка, мастер, выбор
/// восстановления, — а компилируемые ими экраны звали `/login` из пяти мест и
/// `/network-settings` из кнопки Wi-Fi, которая стоит на **каждом** шаге
/// мастера. Ни `flutter analyze`, ни набор, ни сборка веба не могли этого
/// заметить: путь — это строка, таблица — это список, и разойтись они могут
/// только молча. Обнаруживается такое в браузере, руками, после полного
/// прохода настройки.
///
/// # Почему проверка ходит по графу импортов, а не по всему `lib/presentation`
///
/// В браузерную сборку попадают не все экраны, а только достижимые от
/// `setup_router.dart` — в этом и смысл отдельной таблицы: выбор области
/// компиляцией, а не условием во время выполнения. Проверять весь
/// `lib/presentation` значило бы требовать от браузерной таблицы маршрута на
/// экран продажи, которого в её сборке нет вовсе, — и такой сторож пришлось бы
/// глушить списком исключений в тот же день. Здесь обход ровно того множества
/// файлов, которое компилятор действительно возьмёт.
///
/// # Почему по исходникам, а не поднятием `GoRouter`
///
/// Поднять маршрутизатор и перебрать переходы можно только вместе с DI, живой
/// сессией к кассе и всем деревом виджетов. Дефект же — текстовый: маршрута
/// нет в таблице. Читать надо то, что расходится, а не то, что из этого
/// вырастает.

const _routesFile = 'lib/app/router/app_routes.dart';
const _tableFile = 'lib/app/router/setup_router.dart';

const _teleposPackagePrefix = 'package:telepos/';

/// `static const login = '/login';` — имя и путь.
final _routeConstantPattern = RegExp(
  r"static\s+const\s+(\w+)\s*=\s*'([^']*)'\s*;",
);

/// `path: AppRoutes.login,` в таблице маршрутов.
final _tableEntryPattern = RegExp(r'path:\s*AppRoutes\.(\w+)');

/// Переход по константе: `context.go(AppRoutes.login)`.
final _navByConstantPattern = RegExp(
  r'context\.(?:go|push|replace|pushReplacement)\(\s*AppRoutes\.(\w+)',
);

/// Переход по строке: `context.go('/shift')`. Такие в коде есть
/// (`adaptive_scaffold.dart`), и обход обязан их видеть — иначе достаточно
/// написать путь буквой, чтобы пройти мимо сторожа.
final _navByLiteralPattern = RegExp(
  r'''context\.(?:go|push|replace|pushReplacement)\(\s*(['"])(/[^'"]*)\1''',
);

final _importStatementPattern = RegExp(
  r'^[ \t]*(?:import|export)\b[^;]*;',
  multiLine: true,
);

final _importTargetPattern = RegExp("['\"]([^'\"]+)['\"]");

String _slash(String path) => path.replaceAll(r'\', '/');

/// Комментарии и блочные комментарии — вон.
///
/// Не косметика: этот сторож нашёл `context.go('/login')` внутри строки
/// документации, которая **объясняет** дефект. Комментарий никуда не ведёт, и
/// требовать от него объявленного маршрута значит запретить объяснять на
/// примере — то есть отучить писать комментарии, ради которых всё и заведено.
String _withoutComments(String source) => source
    .replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), '')
    .replaceAll(RegExp(r'//[^\n]*'), '');

File _file(String slashPath) =>
    File(slashPath.replaceAll('/', Platform.pathSeparator));

/// Разрешает относительный импорт относительно каталога импортирующего файла.
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
///
/// Условный импорт (`import 'a.dart' if (dart.library.js_interop) 'b.dart';`)
/// пропускается целиком — какую ветку возьмёт сборка, по тексту не узнать, и
/// обе они в этом проекте платформенный шов, а не навигация.
Set<String> _reachableFrom(String entry) {
  final seen = <String>{};
  final queue = <String>[entry];

  while (queue.isNotEmpty) {
    final current = queue.removeLast();
    if (!seen.add(current)) continue;

    final file = _file(current);
    if (!file.existsSync()) continue;

    for (final match in _importStatementPattern.allMatches(
      file.readAsStringSync(),
    )) {
      final statement = match.group(0)!.trim();
      if (statement.contains(' if (')) continue;

      final target = _importTargetPattern.firstMatch(statement)?.group(1);
      if (target == null) continue;

      final String next;
      if (target.startsWith(_teleposPackagePrefix)) {
        next = 'lib/${target.substring(_teleposPackagePrefix.length)}';
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
  late Map<String, String> routePathByName;
  late Set<String> servedNames;
  late Set<String> servedPaths;

  setUpAll(() {
    final routesSource = _file(_routesFile).readAsStringSync();
    routePathByName = {
      for (final m in _routeConstantPattern.allMatches(routesSource))
        m.group(1)!: m.group(2)!,
    };

    final tableSource = _file(_tableFile).readAsStringSync();
    servedNames = {
      for (final m in _tableEntryPattern.allMatches(tableSource)) m.group(1)!,
    };
    servedPaths = {
      for (final name in servedNames)
        if (routePathByName.containsKey(name)) routePathByName[name]!,
    };
  });

  test('разбор исходников что-то нашёл', () {
    // Без этого остальные проверки зелены на пустых множествах: переименование
    // файла или смена формы объявления сняли бы охрану молча.
    expect(
      routePathByName.length,
      greaterThan(50),
      reason: '$_routesFile разобран не был — проверки ниже ничего не значат',
    );
    expect(
      servedNames,
      contains('splash'),
      reason: '$_tableFile разобран не был — проверки ниже ничего не значат',
    );
  });

  test('браузерная таблица объявляет только существующие маршруты', () {
    final unknown = servedNames.where(
      (name) => !routePathByName.containsKey(name),
    );
    expect(
      unknown,
      isEmpty,
      reason: 'в $_tableFile объявлен маршрут, которого нет в AppRoutes',
    );
  });

  test('каждый переход достижимого экрана ведёт на объявленный маршрут', () {
    final reachable = _reachableFrom(_tableFile);
    expect(
      reachable.length,
      greaterThan(3),
      reason: 'обход графа импортов не пошёл — проверка ничего не значит',
    );

    final offenders = <String>[];

    for (final path in reachable) {
      final file = _file(path);
      if (!file.existsSync()) continue;
      final source = _withoutComments(file.readAsStringSync());

      for (final m in _navByConstantPattern.allMatches(source)) {
        final name = m.group(1)!;
        if (servedNames.contains(name)) continue;
        final target = routePathByName[name] ?? '(нет такой константы)';
        offenders.add('${_slash(path)}: AppRoutes.$name -> $target');
      }

      for (final m in _navByLiteralPattern.allMatches(source)) {
        final literal = m.group(2)!;
        // Интерполяция (`'/orders/$id'`) разрешима только до первого `$`:
        // сравнивается начало, и объявленный `/orders/:orderId` его накроет.
        final probe = literal.split(r'$').first;
        final covered = servedPaths.any((p) => p.startsWith(probe));
        if (covered) continue;
        offenders.add('${_slash(path)}: "$literal"');
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'Экран, попадающий в браузерную сборку, уходит на маршрут, которого '
          'нет в $_tableFile. В браузере это «Page Not Found: GoException» — '
          'для кассира то же самое, что белый экран. Либо заведите маршрут '
          '(экран, ещё не переехавший на провод, получает WtNotPortedScreen), '
          'либо уберите переход. См. docs/system-architecture.md, И144.',
    );
  });
}

@Tags(['architecture'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:telepos/app/router/app_router.dart';

/// У каждого объявленного маршрута есть хотя бы один переход из кода.
///
/// # Зачем сторож: двенадцатая подсистема без входа
///
/// `promotions_screen.dart` — 323 строки полного CRUD по акциям. Маршрут
/// `/promotions` объявлен в `AppRoutes` и зарегистрирован в `_buildRoutes()`.
/// И перехода на него не было **ниоткуда**: `git grep -rn
/// "AppRoutes.promotions" -- lib` давал только сам роутер, ни одного
/// `context.push`/`context.go`, ни одного пункта меню. Завести акцию можно
/// было, только набрав адрес руками или через SQL.
///
/// Это не единичная описка, а семья: на 2026-09-07 в проекте насчитали
/// одиннадцать подсистем, где механика написана целиком, а входа нет.
/// `/promotions` была двенадцатой. Пункт меню чинит её один раз; сторож
/// чинит её навсегда — тринадцатая покрасит именно этот тест.
///
/// # Что сторож читает и чего он НЕ доказывает
///
/// Таблица маршрутов берётся из настоящего дерева
/// `createRouter().configuration.routes` — тем же обходом, что и у соседа
/// `route_permission_coverage_test.dart`, а не из производных списков
/// `AppRoutes.shellRoutes`/`standaloneRoutes` (они, как нашла задача 17,
/// с самой таблицей разошлись).
///
/// Переходы ищутся **по коду** `lib/`, а не по рукописному списку: имена
/// констант маршрутов читаются из `app_routes.dart` (`static const foo =
/// '/foo';`), а места перехода — по формам, которыми переход в этом проекте
/// вообще записывается (см. [_navigationMarkers]).
///
/// Сторож доказывает, что **ссылка существует в коде**. Он не доказывает,
/// что эта ссылка достижима вошедшему (это соседний
/// `route_permission_coverage_test.dart`), что пункт меню виден в нужном
/// режиме торговли и что он не спрятан под условием `if (false)`. Он читает
/// текст, а не поднимает интерфейс.
///
/// Маршруты браузерной таблицы (`setup_router.dart`) сторож не обходит —
/// он берёт десктопное дерево. Файл `setup_router.dart` при этом
/// **сканируется** как источник переходов: его `redirect` — настоящий
/// переход.
///
/// # Проверено обратным ходом (2026-09-07), а не написано и оставлено
///
/// Сторож, который ничего не ловит, зелен по недосмотру — поэтому каждая
/// сторона проверена диверсией на дереве:
///
/// 1. **Убрать пункт меню** (`onTap`/`permissionKey` у пункта «Акции» в
///    `general_settings_screen.dart` → `onTap: () {}`) — красный,
///    `['/promotions']`.
/// 2. **Подсадить маршрут без перехода** (`AppRoutes.plantedOrphan` +
///    `GoRoute` в `_buildRoutes()`) — красный, `['/planted-orphan']`.
/// 3. **Упомянуть подсаженный маршрут, но не перейти на него**: строка
///    `'/planted-orphan': opEditPrice` в карте прав **и** комментарий
///    `// see also AppRoutes.plantedOrphan at '/planted-orphan'` в
///    `promotions_screen.dart` — по-прежнему красный. Сторож не покупается
///    на упоминание; ровно этим он отличается от `git grep`, которым долг и
///    не был замечен.
/// 4. **Завести настоящий переход** (`context.push(AppRoutes.plantedOrphan)`
///    в сетке настроек) — зелёный. Значит зелёный цвет означает найденный
///    переход, а не пустой обход.
///
/// Отдельно, соседним сторожем: **убрать право** (строку `'/promotions':
/// opEditPrice` из `permission_keys.dart`) — красный в
/// `route_permission_coverage_test.dart` дважды: счёт покрытия 34 → 33 и
/// «маршрут не получил решения».
void main() {
  group('у каждого маршрута есть переход из кода', () {
    late List<String> allRoutes;
    late _NavigationIndex index;

    setUpAll(() {
      allRoutes = _allGoRoutePaths(createRouter().configuration.routes);
      index = _NavigationIndex.scan();
    });

    test('сторож действительно что-то прочитал (пустой набор — не зелёный, '
        'а слепой)', () {
      // Ловушка, на которой сегодня обожглись дважды: сторож, ничего не
      // нашедший, зелен по недосмотру. Три счёта, каждый обязан быть
      // больше нуля: файлов прочитано, констант маршрутов разобрано,
      // переходов найдено.
      expect(
        index.filesScanned,
        greaterThan(200),
        reason:
            'Сторож не прочитал lib/ — путь, фильтр расширения или рабочий '
            'каталог теста сломаны. Пустой обход дал бы «переходов нет ни '
            'на один маршрут», что покрасило бы всё; но обход, упавший до '
            'нуля файлов при пустом списке маршрутов, был бы зелёным.',
      );
      expect(
        index.routeConstants,
        greaterThan(50),
        reason:
            'app_routes.dart разобран в ноль констант — выражение разбора '
            '`static const name = \'/path\';` больше не совпадает с файлом.',
      );
      expect(
        index.navigatedPaths.length,
        greaterThan(20),
        reason:
            'Ни одного перехода не найдено во всём lib/ — значит совпадают '
            'не формы перехода, а ничего. Проверь _navigationMarkers.',
      );
      expect(allRoutes.length, greaterThan(50));
    });

    test('ни один маршрут не остался без перехода сверх поимённого списка', () {
      final orphans = <String>[];
      for (final route in allRoutes) {
        if (index.hasNavigationTo(route)) continue;
        if (_reachedWithoutCodeReference.containsKey(route)) continue;
        if (_knownUnreachableRoutes.containsKey(route)) continue;
        orphans.add(route);
      }

      expect(
        orphans,
        isEmpty,
        reason:
            'Маршрут объявлен и зарегистрирован, но перехода на него нет '
            'нигде в lib/: ни `context.go`/`context.push`, ни пункта меню '
            '(`route:` у NavDestination), ни возврата из `redirect`. Экран '
            'написан и недостижим — открыть его можно только набрав адрес '
            'руками. Заведи вход (пункт меню, кнопка, переход из соседнего '
            'экрана) — либо, если маршрут достижим механизмом, которого '
            'этот сторож не читает, назови его поимённо в '
            '_reachedWithoutCodeReference с обоснованием: $orphans',
      );
    });

    test('поимённые списки не врут: каждая запись — настоящий маршрут '
        'настоящей таблицы', () {
      // Иначе список гниёт: маршрут переименовали или удалили, запись
      // осталась и молча прощает следующий маршрут с похожим именем.
      final stale = [
        ..._reachedWithoutCodeReference.keys,
        ..._knownUnreachableRoutes.keys,
      ].where((r) => !allRoutes.contains(r)).toList();
      expect(
        stale,
        isEmpty,
        reason:
            'Запись в _reachedWithoutCodeReference/_knownUnreachableRoutes '
            'не соответствует ни одному маршруту из _buildRoutes(): $stale',
      );
    });

    test('запись «достижим не константой» не врёт: перехода из кода на этот '
        'маршрут действительно нет', () {
      // Обратная сторона предыдущей проверки — та же, которой сосед
      // (`route_permission_coverage_test.dart`) ловит лживое «нет ключа
      // права ни для одной роли». Если у маршрута появился нормальный
      // переход константой, запись обязана уйти, а не остаться прощать
      // будущее.
      final redundant = [
        ..._reachedWithoutCodeReference.keys,
        ..._knownUnreachableRoutes.keys,
      ].where(index.hasNavigationTo).toList();
      expect(
        redundant,
        isEmpty,
        reason:
            'На маршрут теперь есть переход из кода — убери запись из '
            'списка, она больше ничего не охраняет: $redundant',
      );
    });

    test('счёт маршрутов без входа — точное число, а не диапазон', () {
      // Тот же протокол, каким сосед
      // (`route_permission_coverage_test.dart`) держит счёт покрытия
      // ключами права: точное число, чтобы список не рос молча. Рост
      // обязан объясняться поимённо.
      expect(
        _knownUnreachableRoutes.length,
        3,
        reason:
            'Список экранов без входа изменился. Если он вырос — это '
            'тринадцатая подсистема без входа, и её надо чинить, а не '
            'вписывать. Если сократился — обнови число (и порадуйся).',
      );
      expect(
        _reachedWithoutCodeReference.length,
        2,
        reason:
            'Список маршрутов, достижимых собранным на ходу адресом, '
            'изменился. Обнови число поимённо.',
      );
    });
  });
}

/// Обходит дерево маршрутов рекурсивно (`ShellRoute` не сама `GoRoute`, её
/// `path` не читается — только вложенные `routes`, у любого `RouteBase`).
List<String> _allGoRoutePaths(List<RouteBase> routes) {
  final result = <String>[];
  for (final route in routes) {
    if (route is GoRoute) {
      result.add(route.path);
    }
    result.addAll(_allGoRoutePaths(route.routes));
  }
  return result;
}

/// Маршруты, которые **достижимы**, но механизмом, которого этот сторож не
/// читает: адрес собирается на ходу, а не пишется константой.
///
/// Отдельно от [_knownUnreachableRoutes] намеренно: смешать их в один
/// список — ровно та ложь, которую соседний
/// `route_permission_coverage_test.dart` ловит третьей проверкой
/// («обоснование не врёт»). Здесь — «вход есть, сторож его не видит»; там —
/// «входа нет вовсе».
const Map<String, String> _reachedWithoutCodeReference = {
  // `context.push('${GoRouterState.of(context).uri.path}/edit', ...)` —
  // `label_templates_screen.dart:46,53` и
  // `receipt_templates_screen.dart:47,55`. Адрес складывается из текущего
  // пути и суффикса, константа `AppRoutes.labelTemplateEdit` в переходе не
  // участвует вовсе. Вход настоящий: кнопка «создать» и нажатие на строку
  // списка.
  '/label-templates/edit':
      'context.push с собранным путём — label_templates_screen.dart:46,53',
  '/receipt-templates/edit':
      'context.push с собранным путём — receipt_templates_screen.dart:47,55',
};

/// **Находки, а не решения**: экраны написаны, маршруты объявлены и
/// зарегистрированы, входа нет ниоткуда.
///
/// Задача 19 плана «полнота продажи» (2026-09-07) чинила `/promotions` и
/// нашла этим сторожем ещё три таких же. Они здесь **не потому, что так
/// решено**, а потому, что чинить их молча в чужой задаче — хуже, чем
/// назвать: у каждого свой вопрос «а где ему место», и отвечать на него
/// надо заказчику, а не сторожу. Каждая запись — открытый долг.
///
/// Правило: запись отсюда исчезает, когда у экрана появляется вход. Новая
/// запись здесь не заводится — новый маршрут без входа обязан получить вход,
/// а не строку в списке.
const Map<String, String> _knownUnreachableRoutes = {
  // `MarkupSettingsScreen` — настройки наценки. Ни `AppRoutes.markupSettings`,
  // ни литерала `'/markup-settings'` нет нигде в `lib/`, кроме таблицы
  // маршрутов. Соседний экран того же класса (`/reorder-rules`) в меню
  // настроек есть — этот нет.
  '/markup-settings': 'экран наценок написан, входа нет ниоткуда',

  // `CustomerDisplayScreen` — витрина покупателя. Соседний сторож
  // (`route_permission_coverage_test.dart`, `_intentionallyOpenRoutes`)
  // обосновывает его открытость словами «вызывается только из потока
  // оплаты» — **это неправда**: из потока оплаты (и ниоткуда ещё) на него
  // не ведёт ни одна ссылка. Обоснование написано по замыслу, а не по
  // измерению.
  '/customer-display': 'витрина покупателя написана, входа нет ниоткуда',

  // `StaffChatScreen` — внутренний чат сотрудников. Маршрут в shell-таблице,
  // экран собран, перехода нет.
  '/staff-chat': 'чат сотрудников написан, входа нет ниоткуда',
};

/// Формы, которыми переход в этом проекте вообще записывается.
///
/// Не «любое упоминание пути в lib/»: карта прав
/// (`permission_keys.dart`, `_routePermissions`) перечисляет те же строки
/// маршрутов, и упоминание там переходом не является — сторож, считающий
/// упоминания, объявил бы достижимым ровно тот `/promotions`, из-за
/// которого он и написан.
///
/// - `.go(` / `.push(` / `.replace(` / `.pushReplacement(` / `.goNamed(` /
///   `.pushNamed(` — вызов навигации `go_router` (`context.go(...)`,
///   `router.go(...)`, `GoRouter.of(context).push(...)`).
/// - `route:` — объявление пункта меню (`NavDestination(route: '/sale',
///   ...)`, `nav_destinations.dart`): сам переход делает
///   `context.go(destination.route)` в `tg_nav_column`/`app_drawer` с
///   переменной, поэтому имя маршрута видно только здесь.
/// - `return ` / `=> ` — возврат адреса из `redirect` маршрутизатора
///   (`return AppRoutes.login;`) и из коротких стрелочных функций.
/// - `initialLocation:` — точка входа `GoRouter`, единственный способ,
///   которым достигается `/`.
const List<String> _navigationMarkers = [
  '.go(',
  '.push(',
  '.replace(',
  '.pushReplacement(',
  '.goNamed(',
  '.pushNamed(',
  'route:',
  'return ',
  '=> ',
  'initialLocation:',
];

/// Файлы-объявления: перечисляют маршруты, но переходов не содержат.
///
/// `app_routes.dart` — сами константы (`static const promotions =
/// '/promotions';`), из него читается карта имя → путь.
/// `permission_keys.dart` — карта «маршрут → ключ права»: те же строки,
/// но это про допуск, а не про вход.
const Set<String> _declarationOnlyFiles = {
  'lib/app/router/app_routes.dart',
  'lib/core/constants/permission_keys.dart',
};

class _NavigationIndex {
  _NavigationIndex._(
    this.filesScanned,
    this.routeConstants,
    this.navigatedPaths,
    this.navigatedPrefixes,
  );

  final int filesScanned;
  final int routeConstants;

  /// Пути, на которые найден переход буквально или через `AppRoutes.x`.
  final Set<String> navigatedPaths;

  /// Строковые литералы перехода целиком — для параметрических маршрутов
  /// (`/tables/:tableId` достигается как `context.go('/tables/${t.id}')`).
  final List<String> navigatedPrefixes;

  bool hasNavigationTo(String route) {
    if (navigatedPaths.contains(route)) return true;

    // Параметрический маршрут: сравниваем по неизменяемому началу пути.
    final colon = route.indexOf('/:');
    if (colon > 0) {
      final prefix = route.substring(0, colon + 1);
      for (final literal in navigatedPrefixes) {
        if (literal.startsWith(prefix) && literal.length > prefix.length) {
          return true;
        }
      }
    }
    return false;
  }

  static _NavigationIndex scan() {
    final nameToPath = _readRouteConstants();

    var files = 0;
    final paths = <String>{};
    final literals = <String>[];

    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File) continue;
      if (!entity.path.endsWith('.dart')) continue;
      final normalized = entity.path.replaceAll(r'\', '/');
      if (normalized.endsWith('.g.dart')) continue;
      if (_declarationOnlyFiles.contains(normalized)) continue;

      files++;
      final source = entity.readAsStringSync();
      for (final marker in _navigationMarkers) {
        var from = 0;
        while (true) {
          final at = source.indexOf(marker, from);
          if (at < 0) break;
          from = at + marker.length;

          final argument = _argumentAfter(source, from);
          if (argument == null) continue;

          for (final m in _appRoutesRef.allMatches(argument)) {
            final path = nameToPath[m.group(1)];
            if (path != null) paths.add(path);
          }
          for (final m in _stringLiteral.allMatches(argument)) {
            final value = m.group(1)!;
            if (!value.startsWith('/')) continue;
            paths.add(value);
            literals.add(value);
          }
        }
      }
    }

    return _NavigationIndex._(files, nameToPath.length, paths, literals);
  }

  /// Кусок исходника сразу за маркером, в котором ищется имя маршрута.
  ///
  /// Не «следующие N символов»: 300 символов после `.go(` втягивают
  /// соседний вызов и объявляют достижимым чужой маршрут. Берётся ровно
  /// один довод — до закрывающей скобки того же уровня, до запятой того же
  /// уровня или до конца выражения (`;`), что раньше. Кавычки при подсчёте
  /// уровня пропускаются, иначе `')'` внутри строки закрыл бы довод.
  static String? _argumentAfter(String source, int start) {
    var depth = 0;
    final buffer = StringBuffer();
    for (var i = start; i < source.length && i < start + 400; i++) {
      final c = source[i];
      if (c == "'" || c == '"') {
        final quote = c;
        buffer.write(c);
        i++;
        while (i < source.length) {
          buffer.write(source[i]);
          if (source[i] == r'\') {
            i += 2;
            if (i - 1 < source.length) buffer.write(source[i - 1]);
            continue;
          }
          if (source[i] == quote) break;
          i++;
        }
        continue;
      }
      if (c == '(' || c == '[' || c == '{') depth++;
      if (c == ')' || c == ']' || c == '}') {
        if (depth == 0) break;
        depth--;
      }
      if (depth == 0 && (c == ',' || c == ';')) break;
      buffer.write(c);
    }
    return buffer.isEmpty ? null : buffer.toString();
  }

  static Map<String, String> _readRouteConstants() {
    final source = File('lib/app/router/app_routes.dart').readAsStringSync();
    final result = <String, String>{};
    for (final m in _routeConstantDeclaration.allMatches(source)) {
      result[m.group(1)!] = m.group(2)!;
    }
    return result;
  }
}

final _routeConstantDeclaration = RegExp(
  r"static const (\w+)\s*=\s*'([^']*)'\s*;",
);
final _appRoutesRef = RegExp(r'AppRoutes\.(\w+)');
final _stringLiteral = RegExp(r"'([^'\n]*)'");

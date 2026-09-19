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

/// Экран продажи — задача 13. Отдельным семенем, а не только через таблицу:
/// сторож обязан краснеть **до** того, как маршрут заведён, иначе он ничего
/// не доказывает про работу, которая его чинит.
const _saleScreenFile = 'lib/presentation/screens/sale/sale_screen.dart';

/// Экран оплаты — задача 17. Отдельным семенем по той же причине, что и
/// экран продажи выше.
///
/// **Почему для оплаты одного «маршрут объявлен» мало.** У продажи маршрута
/// в таблице не было вовсе, и проверка `servedNames.contains('sale')` честно
/// краснела до задачи 13. У оплаты запись `path: AppRoutes.payment` стоит в
/// таблице **с задачи 13** — и ведёт на `WtNotPortedScreen`. Тот же сторож,
/// написанный для оплаты слово в слово, был бы зелёным на заглушке: кассир
/// упирается в «Этот экран пока только на кассе», а набор рапортует, что
/// маршрут обслужен. Поэтому у оплаты сторож смотрит не на наличие записи, а
/// на то, **куда ведёт её `builder`** ([_stubbedRouteNames]).
const _paymentScreenFile =
    'lib/presentation/screens/payment/payment_screen.dart';

/// Настоящая точка входа браузерной сборки.
///
/// **Не то же, что таблица маршрутов, и это измерено.** Замыкание от
/// `setup_router.dart` — 152 файла, от `main_web.dart` — 192: на сорок
/// больше, и среди них весь `lib/web/` и весь `lib/domain/wire/`, то есть
/// ровно те места, где живёт работа с битами и кадрами. Проверка на сдвиги,
/// посеянная только от маршрутизатора, их не смотрела бы вовсе.
///
/// Правило «`lib/data/` в браузере не бывает» к этому семени **неприменимо**,
/// и это тоже измерено: `main_web.dart` сам импортирует два файла
/// `lib/data/` — `device_profile_catalog_builtin.dart` и
/// `terminal_identity_local.dart`, — оба честно веб-безопасные (чистый Dart
/// поверх `shared_preferences`). Значит запрет на каталог держится ровно на
/// том, что обход начинается от таблицы маршрутов, а не от точки входа. Здесь
/// это сказано вслух, чтобы следующий читатель не «починил» одно, сломав
/// другое.
const _webEntryFile = 'lib/web/main_web.dart';

/// Регистрация каскадом в `main_web.dart`: `..registerLazySingleton<Foo>(`.
final _registrationPattern = RegExp(
  r'\.\.register(?:LazySingleton|Singleton|Factory)<(\w+)>',
);

/// Просьба к контейнеру: `GetIt.I<Foo>()`, `GetIt.instance.get<Foo>()`,
/// `getIt<Foo>()` — и `isRegistered<Foo>()`, которой отсутствие прячут.
final _containerAskPatterns = <RegExp>[
  RegExp(r'(?:GetIt\.I|GetIt\.instance|getIt)\s*(?:\.get)?\s*<(\w+)>\s*\('),
  RegExp(r'isRegistered<(\w+)>'),
];

/// Договоры, которые экран продажи просит, а браузер не привязывает, —
/// **поимённо и с доводом**. Каждая строка — известный долг, а не разрешение:
/// сторож краснеет, когда строка перестаёт быть нужной.
///
/// **`BatchTrackingUseCase` и `WmsConfigUseCase` отсюда сняты — пункт 11
/// ревизии 2026-09-19.** Предупреждение о просроченной партии уехало за
/// договор `ExpiryWarningReader`: на кассе за ним те же два юзкейса, в
/// браузере — операция провода `sale.expiryWarning`. Экран продажи их
/// больше не просит вовсе, и запись, оставленная здесь, краснела бы как
/// устаревшая — это тоже сторож.
const _saleAsksNotBoundInBrowser = <String, String>{
  'EmulatedScannerSourceFactory':
      '`BarcodeScannerMixin` — эмулятор сканера стенда кассы; в браузере '
      'сканер клавиатурный.',
};

/// Два файла `lib/data/`, которые точка входа импортирует законно.
///
/// Оба честно веб-безопасны: `BuiltinDeviceProfileCatalog` — чистый Dart
/// поверх `lib/domain/device/`, `PrefsTerminalIdentity` — поверх
/// `shared_preferences`. Перечислены **поимённо**, а не разрешены каталогом:
/// третий файл `lib/data/`, добавленный в точку входа не глядя, обязан
/// покраснеть.
const _webEntryDataFiles = <String>[
  'lib/data/device/device_profile_catalog_builtin.dart',
  'lib/data/terminal/terminal_identity_local.dart',
];

const _teleposPackagePrefix = 'package:telepos/';

/// Точки входа таблицы: до них не «доходят» нажатием.
///
/// `splash` — `initialLocation` самой таблицы. `initialSetup` и
/// `restoreOrNew` — шаги мастера первого запуска, куда заставка уводит
/// `redirect`-ом по состоянию установки, а не кнопкой. Список короткий и
/// закрытый нарочно: каждая новая запись здесь — это признание, что до
/// экрана нельзя дойти, и она обязана быть объяснена.
const _entryRoutes = <String>{'splash', 'initialSetup', 'restoreOrNew'};

/// `static const login = '/login';` — имя и путь.
final _routeConstantPattern = RegExp(
  r"static\s+const\s+(\w+)\s*=\s*'([^']*)'\s*;",
);

/// `path: AppRoutes.login,` в таблице маршрутов.
final _tableEntryPattern = RegExp(r'path:\s*AppRoutes\.(\w+)');

/// Переход по константе: `context.go(AppRoutes.login)`.
///
/// `(?:<[^>]*>)?` — **найдено обратной проверкой ниже, задача 13.** Переход
/// с ожидаемым ответом пишется с типом: `context.push<bool>('/payment')`
/// (`sale_screen.dart`, кнопка «Оплатить»). Без этой скобки регулярное
/// выражение такого перехода не видело **вовсе** — то есть прямая проверка
/// «каждый переход ведёт на объявленный маршрут» пропускала все переходы с
/// типом, а их в дереве не один.
final _navByConstantPattern = RegExp(
  r'context\.(?:go|push|replace|pushReplacement)(?:<[^>]*>)?\(\s*AppRoutes\.(\w+)',
);

/// Переход по строке: `context.go('/shift')`. Такие в коде есть
/// (`adaptive_scaffold.dart`), и обход обязан их видеть — иначе достаточно
/// написать путь буквой, чтобы пройти мимо сторожа.
final _navByLiteralPattern = RegExp(
  r'''context\.(?:go|push|replace|pushReplacement)(?:<[^>]*>)?\(\s*(['"])(/[^'"]*)\1''',
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

/// Имена маршрутов таблицы, чей `builder` ведёт на заглушку
/// [_notPortedScreenName].
///
/// # Зачем это отдельно от [_tableEntryPattern]
///
/// `servedNames` отвечает на вопрос «есть ли запись», а он для оплаты
/// бесполезен: запись есть с задачи 13 и ведёт на «Этот экран пока только на
/// кассе». Между «маршрут объявлен» и «маршрут работает» помещается вся эта
/// задача, и различить их можно только по телу `builder`.
///
/// Разбор нарочно грубый: [source] режется по `path: AppRoutes.<имя>` на
/// куски, и кусок считается заглушкой, если в нём встречается имя экрана-
/// заглушки. `errorBuilder` таблицы стоит **до** первой записи `path:` и в
/// куски не попадает — иначе заглушкой считался бы первый маршрут списка.
/// Комментарии снимаются вызывающим: соседний маршрут объясняет заглушку
/// словами (`/shift` — граница спеки), и текст объяснения не должен
/// зачитываться за код.
Set<String> _stubbedRouteNames(String sourceWithoutComments) {
  final matches = _tableEntryPattern.allMatches(sourceWithoutComments).toList();
  final stubbed = <String>{};
  for (var i = 0; i < matches.length; i++) {
    final name = matches[i].group(1)!;
    final from = matches[i].end;
    final to = i + 1 < matches.length
        ? matches[i + 1].start
        : sourceWithoutComments.length;
    if (sourceWithoutComments
        .substring(from, to)
        .contains(_notPortedScreenName)) {
      stubbed.add(name);
    }
  }
  return stubbed;
}

/// Экран «этот экран пока только на кассе» — `lib/web/wt_not_ported_screen.dart`.
const _notPortedScreenName = 'WtNotPortedScreen';

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

// ── Транзитивное замыкание импортов глазами веб-сборки ──────────────────────
//
// `_reachableFrom` выше пропускает условный импорт целиком: ему важна
// навигация, а платформенный шов её не меняет. Здесь вопрос другой — «что
// возьмёт компилятор веба», — и шов как раз и есть ответ. Поэтому у обхода
// ниже своё разрешение целей: берётся ветка, которую выберет **браузер**.

/// Библиотеки, наличие которых компилятор веба подтверждает. Условный импорт
/// `import 'a.dart' if (dart.library.js_interop) 'b.dart';` под вебом
/// разрешается в `b.dart`; под VM — в `a.dart`. Порядок в объявлении важен:
/// Dart берёт **первое** удовлетворённое условие.
const _webConditions = <String>[
  'dart.library.js_interop',
  'dart.library.html',
  'dart.library.js',
  'dart.library.js_util',
];

/// Каталоги дерева, которых в браузерной сборке быть не может.
///
/// `lib/data/` — инфраструктура кассы: `AppDatabase` тянет `dart:io` и
/// `package:sqlite3/sqlite3.dart` (то есть `dart:ffi`). `lib/hardware/` —
/// последовательные порты и `dart:io`.
///
/// **Именно транзитивно, а не по списку импортов файла.** Прямой сторож уже
/// есть (`test/architecture/sale_layering_test.dart`) и он зелёный: экран
/// продажи `AppDatabase` не называет. Базу он тянул через **один прыжок** —
/// `sale_controller.dart` импортировал четыре чужих контроллера ради
/// `ref.invalidate`, а каждый из них импортирует `AppDatabase`. Список
/// импортов файла такого не показывает вовсе.
const _forbiddenWebRoots = <String>['lib/data/', 'lib/hardware/'];

/// `dart:`-библиотеки, которых в вебе нет.
const _forbiddenWebLibraries = <String>[
  'dart:io',
  'dart:ffi',
  'dart:isolate',
  'dart:mirrors',
];

/// Точки пакетов, которых в вебе нет.
///
/// Названы точками входа, а не пакетами целиком, и это измеренная разница:
/// `package:sqlite3/common.dart` (оттуда `SqliteException`, которым
/// пользуется `lib/core/errors/safe_error_text.dart`) в вебе компилируется —
/// `dart:ffi` живёт в `package:sqlite3/sqlite3.dart`. Сторож, запрещающий
/// пакет целиком, покрасил бы половину `lib/core/` за то, чего в вебе не
/// происходит.
const _forbiddenWebPackages = <String>[
  'package:sqlite3/sqlite3.dart',
  'package:sqlite3/open.dart',
  'package:drift/native.dart',
  'package:drift/isolate.dart',
  'package:flutter_libserialport/',
  'package:sqlite3_flutter_libs/',
];

/// Все цели одного оператора `import`/`export` — в порядке объявления.
List<({String? condition, String target})> _importTargets(String statement) {
  final out = <({String? condition, String target})>[];
  final conditions = RegExp(
    r'if\s*\(\s*([A-Za-z0-9_.]+)',
  ).allMatches(statement);
  final targets = _importTargetPattern
      .allMatches(statement)
      .map((m) => m.group(1)!)
      .toList();
  if (targets.isEmpty) return out;
  out.add((condition: null, target: targets.first));
  final conditionNames = conditions.map((m) => m.group(1)!).toList();
  for (var i = 1; i < targets.length; i++) {
    out.add((
      condition: i - 1 < conditionNames.length ? conditionNames[i - 1] : null,
      target: targets[i],
    ));
  }
  return out;
}

/// Цель, которую выберет компилятор **веба**.
String _webTargetOf(String statement) {
  final targets = _importTargets(statement);
  for (final t in targets.skip(1)) {
    if (t.condition != null && _webConditions.contains(t.condition)) {
      return t.target;
    }
  }
  return targets.first.target;
}

/// Что найдено в транзитивном замыкании импортов от [entry] глазами веба.
({Set<String> files, List<String> offenders}) _webClosure(
  String entry, {
  // Идти ли **сквозь** запрещённые каталоги вместо того, чтобы записывать их
  // нарушением. Нужно семени `main_web.dart`: два его файла `lib/data/`
  // законны, а сканировать их всё равно надо — они уезжают в бандл.
  bool followForbidden = false,
}) {
  final seen = <String>{};
  final offenders = <String>[];
  final queue = <String>[entry];
  final via = <String, String>{};

  String chain(String path) {
    final parts = <String>[path];
    var cursor = path;
    while (via.containsKey(cursor)) {
      cursor = via[cursor]!;
      parts.add(cursor);
    }
    return parts.reversed.join(' -> ');
  }

  while (queue.isNotEmpty) {
    final current = queue.removeLast();
    if (!seen.add(current)) continue;

    final file = _file(current);
    if (!file.existsSync()) continue;

    for (final match in _importStatementPattern.allMatches(
      file.readAsStringSync(),
    )) {
      final statement = match.group(0)!.trim();
      final target = _webTargetOf(statement);

      if (target.startsWith('dart:')) {
        if (_forbiddenWebLibraries.contains(target)) {
          offenders.add('${chain(current)}  ->  $target');
        }
        continue;
      }
      if (target.startsWith('package:') &&
          !target.startsWith(_teleposPackagePrefix)) {
        if (_forbiddenWebPackages.any(target.startsWith)) {
          offenders.add('${chain(current)}  ->  $target');
        }
        continue;
      }

      final next = target.startsWith(_teleposPackagePrefix)
          ? 'lib/${target.substring(_teleposPackagePrefix.length)}'
          : _resolveRelative(current, target);

      if (_forbiddenWebRoots.any(next.startsWith) && !followForbidden) {
        offenders.add('${chain(current)}  ->  $next');
        continue;
      }
      if (!seen.contains(next)) {
        via.putIfAbsent(next, () => current);
        queue.add(next);
      }
    }
  }

  return (files: seen, offenders: offenders);
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

  /// Названный список — вторая половина охраны, и без неё первая ничего не
  /// требует.
  ///
  /// Тест «каждый переход ведёт на объявленный маршрут» держит таблицу
  /// **не меньше** множества переходов достижимых экранов, но не держит её
  /// снизу: убери запись из таблицы вместе с экраном, который на неё
  /// переходил, — и сторож останется зелёным, потому что расходиться станет
  /// нечему. Ровно так маршрут можно потерять при слиянии двух веток одной
  /// фазы: одна убрала экран, другая рассчитывала на маршрут.
  ///
  /// Поэтому здесь перечислено поимённо то, что браузерный терминал обязан
  /// уметь открыть **сегодня**. Список растёт по одной строке за задачу
  /// переноса и никогда не сокращается молча: снятие строки — решение, а не
  /// следствие правки в соседнем файле.
  test('браузерная таблица служит каждому перенесённому экрану', () {
    const mustServe = <String>[
      'splash',
      'initialSetup',
      'restoreOrNew',
      'login',
      'terminalHome',
      'hardwareSettings',
      'sessions',
      'networkSettings',
      // Задача 20 плана «Продажа с браузерного терминала»: возврат по чеку и
      // без чека с планшета. Контракт — `RefundService` (задача 18),
      // провод — `RefundOps` (задача 19), браузерная реализация —
      // `lib/web/wt_refund_service.dart`.
      'refund',
    ];

    final missing = mustServe.where((name) => !servedNames.contains(name));
    expect(
      missing,
      isEmpty,
      reason:
          'Экран уже перенесён на провод, но его маршрута в $_tableFile нет. '
          'В браузере это «Page Not Found: GoException» на кнопке, которая '
          'вчера работала.',
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

  test('на каждый объявленный маршрут кто-то ведёт', () {
    // **Обратное направление, которого у этого сторожа не было.**
    //
    // Проверка выше говорит «каждый переход ведёт на объявленный маршрут».
    // Обратного она не говорит, и по устройству сказать не может: маршрут,
    // на который не ведёт ни одна кнопка, ей безразличен. В этом дереве так
    // выходило **дважды** — `/sessions` и `/refund` жили заведёнными, а
    // дойти до них можно было только набрав адрес. Оба раза это находила
    // живая проверка, а не набор.
    //
    // Здесь считаются переходы из **достижимых** экранов таблицы — тем же
    // обходом, что и проверка выше, — и сверяются с объявленными
    // маршрутами.
    final reachable = _reachableFrom(_tableFile);
    final linked = <String>{};
    for (final path in reachable) {
      final file = _file(path);
      if (!file.existsSync()) continue;
      final source = _withoutComments(file.readAsStringSync());
      for (final m in _navByConstantPattern.allMatches(source)) {
        linked.add(m.group(1)!);
      }
      for (final m in _navByLiteralPattern.allMatches(source)) {
        final literal = m.group(2)!.split(r'$').first;
        for (final entry in routePathByName.entries) {
          if (entry.value == literal) linked.add(entry.key);
        }
      }
    }

    final orphans = servedNames.difference(linked).difference(_entryRoutes);
    expect(
      orphans,
      isEmpty,
      reason:
          'Маршрут объявлен, а нажать на него негде: дойти можно только '
          'набрав адрес. Заведите кнопку (плитку, пункт) — либо снимите '
          'маршрут. Исключения — только точки входа: $_entryRoutes.',
    );
  });

  // ── Задача 13: экран продажи в браузерной таблице ────────────────────────

  test('браузерная таблица объявляет маршрут продажи', () {
    // Красный до задачи 13: в таблице было восемь маршрутов из 75, и продажи
    // среди них не было — `/sale` уходил в `errorBuilder`, то есть в
    // `WtNotPortedScreen`.
    expect(
      servedNames,
      contains('sale'),
      reason:
          'Без этой строки браузерный терминал умеет войти, показать права и '
          'настроить железо — и не умеет главного (спека 2026-09-06, шаг 5).',
    );
  });

  // ── Задача 17: оплата в браузерной таблице ───────────────────────────────

  test('разбор заглушек умеет их видеть', () {
    // Сторож заглушек — единственный, у кого нет права быть зелёным по
    // недосмотру: он и заведён затем, что «запись есть» ничего не значит.
    // Поэтому сначала доказывается, что он **видит** заглушку там, где она
    // стоит намеренно.
    //
    // **Полюс — выдуманная таблица, а не настоящая (задача 37).** Прежде
    // обратным полюсом служил `/shift` браузерной таблицы, «граница спеки»,
    // — и тем самым сторож **узаконивал** мёртвый маршрут: единственный
    // переход на него, диалог просроченной смены, сработать не мог никогда
    // (задача 27), а проба требовала, чтобы заглушка стояла. Разбор — чистая
    // функция текста; проверять его зрение на настоящей таблице значило
    // держать в ней заглушку ради пробы.
    const synthetic = '''
      errorBuilder: (context, state) => WtNotPortedScreen(location: ''),
      routes: [
        GoRoute(path: AppRoutes.splash, builder: (c, s) => const Splash()),
        GoRoute(path: AppRoutes.shift,
          builder: (c, s) => WtNotPortedScreen(location: s.uri.toString())),
        GoRoute(path: AppRoutes.sale, builder: (c, s) => const SaleScreen()),
      ],
    ''';
    final stubbed = _stubbedRouteNames(synthetic);

    expect(
      stubbed,
      contains('shift'),
      reason:
          'Разбор не увидел заглушку там, где она заведомо стоит, — значит '
          'проверка «оплата не заглушка» ниже зелена ни на чём.',
    );
    expect(
      stubbed,
      isNot(contains('sale')),
      reason:
          'Разбор считает заглушкой перенесённый экран — куски разрезаны '
          'неверно, и любой маршрут ниже будет ложно краснеть.',
    );
    expect(
      stubbed,
      isNot(contains('splash')),
      reason:
          '`errorBuilder` таблицы стоит до первой записи `path:` и не должен '
          'попадать в кусок первого маршрута.',
    );
  });

  test('в браузерной таблице нет ни одной заглушки', () {
    // Задача 37: «переход есть, сработать не может никогда». `/shift` стоял
    // в браузерной таблице заглушкой, единственный путь к нему — диалог
    // «смена открыта более 24ч» — не срабатывал в браузере вовсе (касса не
    // проверяла возраст смены, а клиентская проверка молча пропускалась без
    // `ShiftService`), и обе обратные проверки выше были на нём зелёные:
    // «переход ведёт на объявленный маршрут» — да, «на маршрут кто-то
    // ведёт» — да. Существование перехода они доказывали, достижимость —
    // нет.
    //
    // Правило теперь без исключений: маршрут браузерной таблицы ведёт к
    // экрану, который работает. Чего браузер не умеет, того в таблице нет, а
    // экран, откуда туда вели, говорит словами, где это делается (диалог
    // просроченной смены: «закройте смену на кассе»). Незаявленный адрес по-
    // прежнему ловит `errorBuilder` — он стоит до первой записи и в разбор не
    // попадает.
    final table = _withoutComments(_file(_tableFile).readAsStringSync());
    expect(
      _stubbedRouteNames(table),
      isEmpty,
      reason:
          'Маршрут объявлен и ведёт на $_notPortedScreenName. Заглушка в '
          'таблице — это переход, который кассир может нажать и упереться в '
          '«пока только на кассе». Либо перенесите экран, либо снимите '
          'маршрут и назовите на исходном экране, где это делается.',
    );
  });

  test('маршрут оплаты ведёт к экрану, а не к заглушке', () {
    // **Дыра, ради которой задача 17 и делается, жила именно потому, что
    // такого сторожа не было нигде.** План ставил «маршрут не заглушка» для
    // `/sale` (задача 13) и `/refund` (задача 20) и не поставил его для
    // оплаты. Кассир набирал чек, жал «Оплатить» и упирался в «Этот экран
    // пока только на кассе» — при полностью зелёном наборе, включая
    // `wt_payment_service_test.dart` с его шестью пробами.
    final table = _withoutComments(_file(_tableFile).readAsStringSync());

    expect(
      servedNames,
      contains('payment'),
      reason: 'записи `path: AppRoutes.payment` в $_tableFile нет вовсе',
    );
    expect(
      _stubbedRouteNames(table),
      isNot(contains('payment')),
      reason:
          '`/payment` объявлен, но ведёт на $_notPortedScreenName. Браузерный '
          'терминал набирает чек и не может его оплатить — то, ради чего '
          'затевалась вся работа (спека 2026-09-06, шаг 7).',
    );
  });

  test('экран оплаты компилируем браузерной сборкой', () {
    // **Красный до задачи 17, и вот чем.** `payment_controller.dart` тянул
    // `package:telepos/data/database/app_database.dart` прямым импортом —
    // ради `denominationsProvider`, которому нужен один `int?`
    // (`ThisPos.countryCode`) на раскладку номиналов. Один провайдер на
    // 1221 строку файла держал в браузере всю drift-схему из 91 таблицы,
    // `dart:ffi` и нативный sqlite3.
    //
    // Сам экран и все шесть его виджетов от базы чисты — и именно поэтому
    // прямой послойный сторож на них зелёный. База приходит одним прыжком
    // через контроллер, ровно как приходила у экрана продажи.
    final closure = _webClosure(_paymentScreenFile);
    expect(
      closure.offenders,
      isEmpty,
      reason:
          'Экран оплаты попадает в браузерную сборку. Всё, что он тянет по '
          'графу импортов, компилятор веба обязан уметь собрать: `dart:io`, '
          '`dart:ffi` и `AppDatabase` в браузере не существуют.',
    );
  });

  test('точка входа привязывает оплату', () {
    // Та же беда и та же форма, что у «точка входа привязывает корзину»:
    // экранные пробы регистрируют `PaymentService` сами, поэтому отсутствие
    // строки в `main_web.dart` не красит ни одной из них. Измерено: до этой
    // задачи строки не было **ни одной**, набор был зелёный целиком, а
    // `/payment` в браузере не построился бы и с живым маршрутом —
    // `GetIt<PaymentService>` бросает на первом же кадре.
    final source = _withoutComments(_file(_webEntryFile).readAsStringSync());
    expect(
      source,
      contains('registerLazySingleton<PaymentService>'),
      reason:
          'Без этой строки экран оплаты в браузере не построится вовсе. '
          'Набор при этом останется зелёным: пробы регистрируют службу сами.',
    );
    expect(
      source,
      contains('WtPaymentService('),
      reason:
          'оплата обязана быть проводной: `LocalPaymentService` в браузере '
          'не компилируется вовсе (принтер, ящик, drift), а любая третья '
          'реализация здесь — вторая правда о деньгах',
    );
  });

  test('обход замыкания глазами веба вообще работает', () {
    // Тот же урок, что у «разбор исходников что-то нашёл»: опечатка в имени
    // файла или сломанный разбор оператора `import` сделали бы обе проверки
    // ниже зелёными на пустом множестве.
    final closure = _webClosure(_tableFile);
    expect(
      closure.files.length,
      greaterThan(50),
      reason: 'обход от $_tableFile не пошёл — проверки ниже ничего не значат',
    );
    final entry = _webClosure(_webEntryFile, followForbidden: true);
    expect(
      entry.files.length,
      greaterThan(closure.files.length),
      reason:
          'замыкание точки входа обязано быть шире замыкания таблицы: в него '
          'входят биндинги провода, которых таблица не видит',
    );
    expect(
      entry.files,
      contains('lib/web/wt_cart_service.dart'),
      reason: 'обход от точки входа не дошёл до браузерной корзины',
    );
    expect(
      closure.files,
      contains('lib/presentation/screens/auth/login_screen.dart'),
      reason: 'обход не дошёл до экрана, который таблица заведомо строит',
    );

    // Ветка условного импорта выбирается **веб**овская, а не первая попавшаяся.
    // Без этого правила сторож краснел бы на `lib/core/platform/host_process.dart`
    // (`dart:io` в нативной половине шва) и его пришлось бы глушить списком
    // исключений в тот же день.
    expect(
      _webTargetOf(
        "import 'host_process_native.dart'\n"
        "    if (dart.library.js_interop) 'host_process_web.dart';",
      ),
      'host_process_web.dart',
    );
    expect(
      _webTargetOf("import 'package:telepos/domain/sale/cart_service.dart';"),
      'package:telepos/domain/sale/cart_service.dart',
    );
  });

  test('экран продажи компилируем браузерной сборкой', () {
    // **Красный до задачи 13, и вот чем.** Замыкание импортов от
    // `sale_screen.dart` содержало 108 файлов `lib/data/` и `lib/hardware/`,
    // причём ни одного прямым импортом — все шестью прыжками:
    //
    //   sale_screen -> barcode_scanner_mixin -> AppDatabase
    //   sale_screen -> sale_controller -> catalog_controller -> AppDatabase
    //   sale_screen -> sale_controller -> history_controller -> AppDatabase
    //   sale_screen -> sale_controller -> shift_controller -> AppDatabase
    //   sale_screen -> sale_controller -> stock_registry_controller -> AppDatabase
    //   sale_screen -> sale_hardware -> lib/hardware/display/... -> dart:io
    //
    // Прямой сторож (`sale_layering_test.dart`) на всём этом зелёный: он
    // читает импорты самого файла, а база пришла через контроллер.
    final closure = _webClosure(_saleScreenFile);
    expect(
      closure.offenders,
      isEmpty,
      reason:
          'Экран продажи попадает в браузерную сборку. Всё, что он тянет '
          'по графу импортов, компилятор веба обязан уметь собрать: '
          '`dart:io`, `dart:ffi` и `AppDatabase` в браузере не существуют. '
          'Одного прыжка через контроллер довольно, чтобы сборка легла.',
    );
  });

  test('сдвиги, ломающиеся в вебе', () {
    // **Найдено живым прогоном 2026-09-07, набор был зелёный.**
    //
    // `sale_controller.dart` считал метку сеанса экрана как
    // `Random().nextInt(1 << 32)`. На VM это 4294967296; в вебе целые —
    // `double`, побитовые операции 32-битные, и `1 << 32` равно **нулю**.
    // `nextInt(0)` бросает `RangeError`, бросок происходит в инициализаторе
    // поля, то есть в конструкторе `SaleNotifier`, — проваливается создание
    // провайдера целиком. Живьём: экран открылся, шапка на месте, вместо
    // чека и итога два серых прямоугольника.
    //
    // Ни один тест на VM этого увидеть не мог по построению: там сдвиг
    // верен. Значит проверка обязана быть **текстовой** и обязана смотреть
    // ровно на то множество файлов, которое попадает в веб-сборку.
    // Оба семени: таблица маршрутов **и** настоящая точка входа. Второе
    // добавляет сорок файлов, которых первое не видит вовсе, — см. докстринг
    // `_webEntryFile`. Дыра была пустой (сдвигов там сегодня нет), но
    // «пустая» и «не проверяется» — разные слова.
    final closure = {
      ..._webClosure(_tableFile).files,
      ..._webClosure(_webEntryFile, followForbidden: true).files,
    };
    final offenders = <String>[];
    final shift = RegExp(r'<<\s*(\d+)');

    for (final path in closure) {
      final file = _file(path);
      if (!file.existsSync()) continue;
      final source = _withoutComments(file.readAsStringSync());
      for (final m in shift.allMatches(source)) {
        final bits = int.parse(m.group(1)!);
        if (bits < 32) continue;
        final line = '\n'.allMatches(source.substring(0, m.start)).length + 1;
        offenders.add('${_slash(path)}:$line  ->  ${m.group(0)}');
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'Сдвиг на 32 бита и больше в файле, попадающем в браузерную '
          'сборку. В вебе целое — это `double`, а `<<` работает по 32 битам: '
          'значение молча становится нулём или мусором, и ломается это '
          'только в браузере. Пишите число (`4294967296`), а не сдвиг.',
    );
  });

  test('точка входа привязывает корзину', () {
    // **Единственная строка, которой держится вся браузерная продажа, не
    // упомянута ни одним тестом.** Экранные пробы регистрируют `CartService`
    // сами (иначе им не над чем работать), поэтому её удаление из
    // `main_web.dart` не красит ничего: набор целиком зелёный, а в браузере
    // экран продажи даёт ровно картину Н1 — шапка на месте, вместо чека и
    // итога два серых прямоугольника, в консоли «провайдер в состоянии
    // ошибки».
    //
    // Проверка текстовая нарочно: поднять `main_web.dart` под тестом нельзя
    // (`dart:js_interop`), а расходится здесь именно текст — строка есть или
    // её нет.
    // Комментарии снимаются: закомментированная строка — **реалистичная**
    // молчаливая регрессия, а не выдуманная. Каскад `..` остаётся
    // синтаксически верным без неё, и `// ..registerLazySingleton<CartService>`
    // проходил зелёным.
    final source = _withoutComments(_file(_webEntryFile).readAsStringSync());
    expect(
      source,
      contains('registerLazySingleton<CartService>'),
      reason:
          'Без этой строки `SaleController` не найдёт корзину, и экран '
          'продажи в браузере не построится вовсе. Набор при этом останется '
          'зелёным: пробы регистрируют службу сами.',
    );
    expect(
      // Без закрывающей скобки: добавление второго довода конструктору —
      // законная правка, а прежняя проверка на ней ложно краснела
      // (`Expected: contains 'WtCartService(wire)'`). Сторож обязан молчать
      // на том, что не является дефектом.
      source,
      contains('WtCartService('),
      reason:
          'корзина обязана быть проводной: `LocalCartService` в браузере не '
          'компилируется вовсе, а любая третья реализация здесь — вторая '
          'правда о чеке',
    );
  });

  test('каждый договор, который экран продажи просит у контейнера, привязан '
      'точкой входа', () {
    // **Задачи 44–45 плана 2026-09-06, живая приёмка 2026-09-13.** Скидку с
    // браузерного терминала ввести было нельзя вовсе: `sale_screen.dart`
    // прятал «Редактировать» проверкой
    // `GetIt.I.isRegistered<SaleCheckoutService>()`, а браузерной реализации
    // не было. Приём «нет привязки — нет кнопки» превращал ошибку сборки
    // контейнера в **режим работы**: набор зелёный, сборка веба зелёная, а
    // функции у кассира нет, и никто об этом не узнаёт.
    //
    // Замер того же дня по замыканию импортов экрана продажи (85 файлов):
    // десять договоров просятся у контейнера и в `main_web.dart` не
    // привязаны. Среди них — `CurrencyService` у диалога скидки, то есть
    // даже со снятой проверкой кнопки диалог бросил бы на первом кадре, и
    // `DiscountPolicy`, на который контроллер отвечал правдоподобным «сто
    // процентов, предел не прочитан».
    //
    // `isRegistered<…>` считается просьбой наравне с `GetIt.I<…>()`: это и
    // есть способ спрятать отсутствие.
    //
    // # Чего сторож не видит
    //
    // Читает текст, а не поднимает контейнер: просьбу через переменную
    // (`final g = GetIt.I; g<Foo>()`) и регистрацию, собранную не каскадом,
    // он пропустит. Замыкание — от экрана продажи, а не от всей таблицы:
    // остальные экраны браузера живут со своими долгами, и глушить их
    // списком здесь значило бы разучиться читать этот.
    final entry = _withoutComments(_file(_webEntryFile).readAsStringSync());
    final registered = {
      for (final m in _registrationPattern.allMatches(entry)) m.group(1)!,
    };
    expect(
      registered.length,
      greaterThan(15),
      reason: 'регистрации в $_webEntryFile не разобраны — сторож ослеп',
    );

    final asked = <String, Set<String>>{};
    for (final path in _webClosure(_saleScreenFile).files) {
      final file = _file(path);
      if (!file.existsSync()) continue;
      final source = _withoutComments(file.readAsStringSync());
      for (final pattern in _containerAskPatterns) {
        for (final m in pattern.allMatches(source)) {
          (asked[m.group(1)!] ??= <String>{}).add(path);
        }
      }
    }
    expect(
      asked.keys,
      // Оба заведомо просятся экраном продажи и привязаны браузером:
      // `SaleNotifier._cart` и терминал рабочего места.
      containsAll(<String>['CartService', 'TerminalRepository']),
      reason: 'просьбы к контейнеру не разобраны — сторож ослеп',
    );

    final unbound = <String>[
      for (final e in asked.entries)
        if (!registered.contains(e.key) &&
            !_saleAsksNotBoundInBrowser.containsKey(e.key))
          '${e.key} ← ${e.value.join(', ')}',
    ]..sort();
    expect(
      unbound,
      isEmpty,
      reason:
          'Экран продажи в браузере просит у контейнера договор, которого '
          '$_webEntryFile не привязывает. Это ошибка сборки контейнера, а не '
          'режим «без кнопки»: заведите браузерную реализацию и строку '
          'регистрации.',
    );

    // Исключение, которое больше ничего не пропускает, — гниль: оно
    // разрешит тот же договор следующему, кто его попросит.
    final stale = <String>[
      for (final name in _saleAsksNotBoundInBrowser.keys)
        if (!asked.containsKey(name) || registered.contains(name)) name,
    ];
    expect(stale, isEmpty, reason: 'исключения больше не нужны: $stale');
  });

  test('точка входа браузера компилируема браузерной сборкой', () {
    // **Найдено разбором: семя было посеяно, а урожай не собирали.** Проверка
    // на сдвиги брала у этого замыкания только `files`, а `offenders` не
    // утверждались нигде — то есть весь `lib/web/` и весь
    // `lib/domain/wire/`, сорок файлов, ради которых семя и добавляли, на
    // `dart:io`, `dart:ffi` и железо не проверялись **вовсе**. Слом
    // (`import 'dart:io';` в `lib/web/wt_cart_service.dart`) давал
    // `+87: All tests passed!`.
    //
    // **Обход идёт `followForbidden: true`, и это исправление, а не
    // послабление.** Первая редакция звала обход **без** него и вычёркивала
    // два законных файла `lib/data/` из списка нарушений. Обход на таком
    // файле **останавливается** — то есть содержимое обоих не сканировалось
    // вовсе. Измерено: `import 'dart:io';` первой строкой в
    // `lib/data/terminal/terminal_identity_local.dart` — файле, который
    // честно уезжает в бандл, — давало `+875: All tests passed!`. Сторож,
    // заведённый ровно чтобы это ловить, слеп на два файла из своего же
    // исключения.
    //
    // Разрешение «идти сквозь» само по себе снимало бы вторую половину
    // правила — «третий файл `lib/data/` у точки входа обязан покраснеть», —
    // поэтому её держит отдельная проверка ниже, по **прямым** импортам.
    // Две проверки вместо одной, слепого пятна нет.
    final closure = _webClosure(_webEntryFile, followForbidden: true);

    expect(
      closure.offenders,
      isEmpty,
      reason:
          'Файл, который уезжает в бандл, тянет то, чего в браузере нет. '
          'Таблица маршрутов этого не видит: в бандл едет то, что тянет '
          '$_webEntryFile, а это на сорок файлов больше.',
    );
    expect(
      closure.files,
      contains('lib/web/wt_cart_service.dart'),
      reason: 'обход от точки входа не дошёл до браузерной корзины',
    );
  });

  test('точка входа импортирует ровно два файла lib/data/', () {
    // Вторая половина правила из проверки выше: обход теперь идёт **сквозь**
    // `lib/data/`, значит «третий файл, добавленный не глядя» ловится не им,
    // а здесь — по **прямым** импортам точки входа. Список именной: каталог
    // целиком разрешать нельзя, а два конкретных файла честно веб-безопасны
    // (докстринг `_webEntryDataFiles`).
    final source = _withoutComments(_file(_webEntryFile).readAsStringSync());
    final imported = <String>[];
    for (final match in _importStatementPattern.allMatches(source)) {
      final target = _importTargetPattern.firstMatch(match.group(0)!)?.group(1);
      if (target == null || !target.startsWith(_teleposPackagePrefix)) continue;
      final path = 'lib/${target.substring(_teleposPackagePrefix.length)}';
      if (path.startsWith('lib/data/')) imported.add(path);
    }

    expect(
      imported..sort(),
      _webEntryDataFiles.toList()..sort(),
      reason:
          'Точка входа браузера может импортировать из `lib/data/` только то, '
          'что честно компилируется в вебе, и каждый такой файл назван '
          'поимённо. Новый — либо в список с доводом, либо не сюда.',
    );
  });

  test('вся браузерная таблица компилируема браузерной сборкой', () {
    // Тот же обход, но от таблицы: маршрут, заведённый на экран с базой под
    // ним, кладёт `flutter build web` целиком, а не только свой экран.
    final closure = _webClosure(_tableFile);
    expect(
      closure.offenders,
      isEmpty,
      reason:
          'Экран в браузерной таблице тянет то, чего в браузере нет. '
          'Собранная страница не соберётся вовсе — это не деградация одного '
          'экрана, а белый экран целиком.',
    );
  });
}

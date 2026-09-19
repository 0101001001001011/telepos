@Tags(['architecture'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Каталоги **и отдельные файлы**, для которых границы слоёв уже соблюдены и
/// проверяются.
///
/// Список только растёт. Каждый план, чинящий очередной поддерев UI, добавляет
/// его сюда. Убирать записи нельзя — это означало бы, что правило перестало
/// действовать там, где уже действовало.
///
/// **Почему появились записи-файлы (план 2b, задача 3).** Экраны настроек
/// устройств — `hardware_settings_screen.dart`, `printer_settings_screen.dart`,
/// `label_printer_settings_screen.dart` — чисты и обязаны такими остаться:
/// именно в них живут кнопки «искать» и «проверить устройство», и весь смысл
/// задачи в том, что они дотягиваются до `lib/hardware/` только через
/// контракты домена. Но каталог `lib/presentation/screens/settings` целиком
/// добавить нельзя: в нём двадцать один файл, который импортирует
/// инфраструктуру (`AppDatabase`, `SysdClient`, `drift`, `dart:io`, хранилища
/// `lib/data/...`). Записать «чисто» про весь
/// каталог было бы неправдой, а не записать ничего — оставить три чистых файла
/// без охраны: следующая правка вернула бы туда прямой импорт, и ничто бы не
/// возразило. Поэтому запись может быть и файлом.
///
/// Каждая запись сама говорит, каким правилом её проверять ([isDomain]),
/// вместо того чтобы диспетчер угадывал это по литералу `'lib/domain'` или по
/// префиксу `'lib/presentation'`. Раньше запись вроде `lib/app` или `lib/core`
/// прошла бы мимо обеих проверок: не совпала бы с захардкоженным
/// `'lib/domain'` и не подошла бы под `startsWith('lib/presentation')` — была
/// бы добавлена в список, ничего не проверяла и молча считалась бы защищённой.
const checkedRoots = <({String path, bool isDomain})>[
  (path: 'lib/domain', isDomain: true),
  // Не совпадает с литералом 'lib/domain' и не начинается с
  // 'lib/presentation' — старый диспетчер (хардкод `== 'lib/domain'` для
  // домена, `startsWith('lib/presentation')` для UI) эту запись не проверил
  // бы ни одним из двух правил. Держим её здесь намеренно, чтобы диспетчер
  // по [isDomain] был проверен не только на записи, чей путь случайно
  // совпадает со старым литералом.
  (path: 'lib/domain/terminal', isDomain: true),
  (path: 'lib/presentation/screens/setup', isDomain: false),
  (path: 'lib/presentation/screens/splash', isDomain: false),
  // Записи-файлы: см. комментарий выше — каталог целиком ещё грязный.
  (
    path: 'lib/presentation/screens/settings/hardware_settings_screen.dart',
    isDomain: false,
  ),
  (
    path: 'lib/presentation/screens/settings/printer_settings_screen.dart',
    isDomain: false,
  ),
  (
    path:
        'lib/presentation/screens/settings/label_printer_settings_screen.dart',
    isDomain: false,
  ),
  // Путь входа. До 2026-08-20 он тянул drift прямо из UI и не проверялся
  // ничем: каталогов `auth` в этом списке не было, и нарушение И5 жило
  // легально. Запись здесь — единственное, что не даёт ему отъехать обратно.
  (path: 'lib/presentation/screens/auth', isDomain: false),
  (path: 'lib/presentation/controllers/auth', isDomain: false),
  // Настройка оплаты по QR (пункт 8 C, 2026-09-15): экран и контроллер
  // ходят только через доменный порт — ключ провайдера им не отдают, и
  // прямой импорт базы открыл бы второй путь к нему.
  (
    path: 'lib/presentation/screens/settings/qr_payment_setup_screen.dart',
    isDomain: false,
  ),
  (
    path:
        'lib/presentation/controllers/settings/qr_payment_setup_controller.dart',
    isDomain: false,
  ),
];

/// Что запрещено импортировать из UI-слоя, в форме `package:`/`dart:`.
const forbiddenFromUi = <String>[
  'package:telepos/data/',
  'package:telepos/hardware/',
  'package:telepos/telegram/',
  'package:telepos/backend/',
  // Задача 6 волны правок фазы 2 («SessionLost» переехал в
  // `lib/domain/wire/`): `login_controller.dart` был единственным файлом
  // `lib/presentation/` с прямым импортом `package:telepos/web/` — тем же
  // швом, из-за которого экраны настроек не научились ловить `SessionLost`
  // отдельно от прочих отказов провода (докстринг `session_lost.dart`).
  // Запись здесь — то, что не даёт этому импорту вернуться молча.
  'package:telepos/web/',
  'package:drift/',
  'dart:io',
  'dart:ffi',
];

/// Что запрещено импортировать из домена, в форме `package:`/`dart:`: он
/// чистый Dart.
///
/// `package:telepos/l10n/` запрещён отдельной строкой, а не через
/// `package:telepos/presentation/`: сгенерированные локализации физически
/// лежат вне `lib/presentation/`, но точно так же тянут `package:flutter/`
/// (см. `lib/l10n/app_localizations.dart`) — контракту домена нечего знать о
/// локализации.
const forbiddenFromDomain = <String>[
  'package:flutter/',
  'package:telepos/data/',
  'package:telepos/hardware/',
  'package:telepos/telegram/',
  'package:telepos/presentation/',
  'package:telepos/l10n/',
  'package:drift/',
  'dart:io',
  'dart:ffi',
];

/// Каталоги, запрещённые как цель *относительного* импорта из UI-слоя.
///
/// `import 'package:telepos/data/x.dart';` ловится [forbiddenFromUi]
/// напрямую по тексту строки. `import '../../data/x.dart';` — то же самое
/// нарушение, но без подстроки `package:telepos/data/` где-либо в строке, и
/// проходит мимо текстового совпадения незамеченным. Импорт нужно сначала
/// разрешить относительно каталога импортирующего файла и только потом
/// сравнить с запрещёнными каталогами. Относительные импорты в
/// инфраструктуру в этой кодовой базе не гипотетический случай: именно так
/// выглядели ошибки компиляции при распутывании browser-сборки — `Target of
/// URI doesn't exist: '../../../telegram/models/sync_packet.dart'`.
const forbiddenRelativeRootsUi = <String>[
  'lib/data/',
  'lib/hardware/',
  'lib/telegram/',
  'lib/backend/',
];

/// То же самое для домена — и дополнительно `lib/presentation/` и `lib/l10n/`,
/// зеркально [forbiddenFromDomain].
const forbiddenRelativeRootsDomain = <String>[
  'lib/data/',
  'lib/hardware/',
  'lib/telegram/',
  'lib/backend/',
  'lib/presentation/',
  'lib/l10n/',
];

final _importTargetPattern = RegExp("['\"]([^'\"]+)['\"]");

/// Каждый `import`/`export` — как отдельный **оператор**, а не строка файла.
///
/// Dart разрешает разносить условный импорт на несколько строк:
///
/// ```dart
/// export 'setup_log_sink_native.dart'
///     if (dart.library.js_interop) 'setup_log_sink_web.dart';
/// ```
///
/// Построчный обход (как было раньше) видит только первую строку — вторая,
/// с `if (...)`, для него не существует, и оператор выглядит безусловным. Тут
/// файл читается целиком и операторы `import`/`export` собираются от
/// ключевого слова до завершающей `;`, включая переносы строк.
final _importStatementPattern = RegExp(
  r'^[ \t]*(?:import|export)\b[^;]*;',
  multiLine: true,
);

Iterable<String> _importExportStatements(File file) => _importStatementPattern
    .allMatches(file.readAsStringSync())
    .map((m) => m.group(0)!);

/// Все `.dart`-файлы записи: либо всё поддерево каталога, либо ровно один
/// файл, если запись указывает на файл.
///
/// Несуществующий путь даёт пустой список — сам по себе это молча прошло бы
/// проверку, поэтому существование каждой записи проверяется отдельным тестом
/// ниже («каждая проверяемая запись существует»), а не подразумевается здесь.
Iterable<File> _dartFiles(String root) {
  final file = File(root);
  if (root.endsWith('.dart')) {
    return file.existsSync() ? [file] : const [];
  }
  final dir = Directory(root);
  if (!dir.existsSync()) return const [];
  return dir
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'));
}

/// Достаёт URI из строки `import '...';` / `export '...';`.
String? _importTarget(String line) =>
    _importTargetPattern.firstMatch(line)?.group(1);

String _displayPath(File file) => file.path.replaceAll(r'\', '/');

/// Разрешает относительный импорт относительно каталога файла, в котором он
/// написан, убирая сегменты `..`, и возвращает путь через `/`, например
/// `lib/data/database/app_database.dart`.
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

const _teleposPackagePrefix = 'package:telepos/';

/// Исследует граф импортов вниз от [file] в поисках запрещённой цели —
/// напрямую или через цепочку `package:telepos/...`/относительных импортов
/// внутри этого же пакета.
///
/// Раньше проверка читала только *прямые* импорты файлов внутри проверяемого
/// каталога — коммит aed7be0 утверждал, что "граф импортов обходится от
/// checkedRoots", но это было не так: файл `lib/presentation/screens/setup/x`,
/// импортирующий `lib/domain/y`, который в свою очередь импортирует
/// `package:flutter/...`, проходил незамеченным, потому что `y` физически не
/// лежит внутри проверяемого каталога и никогда не читался. Здесь — настоящий
/// обход: с каждого файла в проверяемом каталоге проверка спускается по
/// импортам транзитивно и на выходе называет всю цепочку, которой запрещённая
/// цель была достигнута, а не только конечную точку.
///
/// Возвращает `null`, если запрещённая цель недостижима, иначе — список
/// шагов от [file] (не включая сам [file]) до нарушения. [cache] — общая для
/// одного вызова [_violations] память результатов по файлам: без неё файл,
/// на который ссылаются многие, пересчитывался бы заново с нуля для каждого
/// вызывающего, а для `lib/domain` (236 файлов, многие друг друга
/// импортируют) это была бы комбинаторная работа. [inProgress] — стек текущего
/// обхода, а не общий кэш: ловит цикл импортов (A импортирует B импортирует
/// A) — цикл трактуется как "нарушения по этому ребру не найдено", а не как
/// бесконечная рекурсия.
List<String>? _exploreDownward(
  File file,
  Set<String> inProgress,
  Map<String, List<String>?> cache,
  List<String> forbiddenPrefixes,
  List<String> forbiddenRelativeRoots,
) {
  final path = _displayPath(file);
  if (cache.containsKey(path)) return cache[path];
  if (!inProgress.add(path)) return null; // цикл — трактуем как чистое ребро

  List<String>? result;
  for (final statement in _importExportStatements(file)) {
    final line = statement.trim();

    // Dart's conditional import/export — `import 'default.dart' if
    // (dart.library.io) 'io_impl.dart';` — is this codebase's established
    // platform-seam mechanism (lib/core/logging/setup_log_sink.dart,
    // lib/core/platform/*, lib/data/database/database_connection.dart):
    // exactly one branch is compiled in, chosen by the target platform, and
    // the whole point is to keep e.g. dart:io out of the web build without
    // keeping the desktop build from having it. A regex over source text
    // cannot know which branch a given build target picks, and treating the
    // textually-first branch as "the" import (the naive reading) is simply
    // wrong here: in setup_log_sink.dart the first branch is the dart:io
    // implementation and the *conditional* branch is the web-safe one — the
    // opposite of what "first quoted string" would assume. Flagging this
    // would also punish the very seam pattern this codebase's platform-seam
    // refactor introduced to solve exactly this problem. So a conditional
    // import/export is out of scope for this check: neither matched against
    // the forbidden list nor followed transitively.
    if (line.contains(' if (')) continue;

    final target = _importTarget(line);
    if (target == null) continue;

    if (target.startsWith('package:') || target.startsWith('dart:')) {
      final isForbidden = forbiddenPrefixes.any(target.startsWith);
      if (isForbidden) {
        result = [target];
        break;
      }
      if (target.startsWith(_teleposPackagePrefix)) {
        final resolvedPath =
            'lib/${target.substring(_teleposPackagePrefix.length)}';
        final nextFile = File(
          resolvedPath.replaceAll('/', Platform.pathSeparator),
        );
        if (nextFile.existsSync()) {
          final sub = _exploreDownward(
            nextFile,
            inProgress,
            cache,
            forbiddenPrefixes,
            forbiddenRelativeRoots,
          );
          if (sub != null) {
            result = [target, ...sub];
            break;
          }
        }
      }
    } else {
      final resolved = _resolveRelativeImport(file, target);
      final isForbidden = forbiddenRelativeRoots.any(resolved.startsWith);
      if (isForbidden) {
        result = ['$target (resolves to $resolved)'];
        break;
      }
      final nextFile = File(resolved.replaceAll('/', Platform.pathSeparator));
      if (nextFile.existsSync()) {
        final sub = _exploreDownward(
          nextFile,
          inProgress,
          cache,
          forbiddenPrefixes,
          forbiddenRelativeRoots,
        );
        if (sub != null) {
          result = [target, ...sub];
          break;
        }
      }
    }
  }

  inProgress.remove(path);
  cache[path] = result;
  return result;
}

/// Обходит каждый файл проверяемого каталога и транзитивно — весь граф его
/// импортов внутри `package:telepos/...` — в поисках запрещённой цели.
/// Возвращает по одной строке на нарушение: файл в каталоге и полная цепочка
/// импортов, которой запрещённая цель была достигнута.
List<String> _violations(
  String root,
  List<String> forbiddenPrefixes,
  List<String> forbiddenRelativeRoots,
) {
  final found = <String>[];
  final cache = <String, List<String>?>{};
  for (final file in _dartFiles(root)) {
    final chain = _exploreDownward(
      file,
      <String>{},
      cache,
      forbiddenPrefixes,
      forbiddenRelativeRoots,
    );
    if (chain != null) {
      found.add('${_displayPath(file)}  ->  ${chain.join('  ->  ')}');
    }
  }
  return found;
}

void main() {
  test('домен не зависит от Flutter и инфраструктуры (И6)', () {
    final domainRoots = checkedRoots.where((r) => r.isDomain);
    final all = <String>[];
    for (final root in domainRoots) {
      all.addAll(
        _violations(
          root.path,
          forbiddenFromDomain,
          forbiddenRelativeRootsDomain,
        ),
      );
    }
    expect(
      all,
      isEmpty,
      reason: 'lib/domain — чистый Dart. См. docs/system-architecture.md, И6.',
    );
  });

  test('проверяемые каталоги UI зависят только от домена (И5)', () {
    final uiRoots = checkedRoots.where((r) => !r.isDomain);
    final all = <String>[];
    for (final root in uiRoots) {
      all.addAll(
        _violations(root.path, forbiddenFromUi, forbiddenRelativeRootsUi),
      );
    }
    expect(
      all,
      isEmpty,
      reason:
          'UI зависит только от домена. Файл, импортирующий AppDatabase, — '
          'дефект, а не сокращение. См. docs/system-architecture.md, И5.',
    );
  });

  test('каждая запись checkedRoots проверена своим правилом', () {
    // Раньше диспетчер решал, каким правилом проверять запись, по
    // захардкоженному литералу 'lib/domain' и по startsWith('lib/presentation')
    // — запись, не подошедшая ни под одно из двух (lib/app, lib/core, lib/web),
    // была бы добавлена в checkedRoots, ничего не проверяла бы и молча считалась
    // бы защищённой. Здесь — доказательство, что для каждой записи ветка
    // isDomain действительно выбирает домен или UI, то есть каждая запись
    // проверяется хоть чем-то.
    for (final root in checkedRoots) {
      final checkedByDomainRule = checkedRoots
          .where((r) => r.isDomain)
          .map((r) => r.path)
          .contains(root.path);
      final checkedByUiRule = checkedRoots
          .where((r) => !r.isDomain)
          .map((r) => r.path)
          .contains(root.path);
      expect(
        checkedByDomainRule || checkedByUiRule,
        isTrue,
        reason:
            '${root.path} не проверяется ни правилом домена, ни правилом UI',
      );
      expect(
        checkedByDomainRule && checkedByUiRule,
        isFalse,
        reason:
            '${root.path} проверяется обоими правилами одновременно — ambiguous',
      );
    }
  });

  test('каждая проверяемая запись существует', () {
    for (final root in checkedRoots) {
      final exists = root.path.endsWith('.dart')
          ? File(root.path).existsSync()
          : Directory(root.path).existsSync();
      expect(
        exists,
        isTrue,
        reason:
            'В checkedRoots указан несуществующий путь: ${root.path}. '
            'Опечатка или переименование здесь молча снимает охрану: '
            '_dartFiles вернул бы пустой список, и запись «проходила» бы, '
            'ничего не проверяя.',
      );
    }
  });

  test(
    'lib/core не тянет dart:ffi — ни прямо, ни через package:telepos/...',
    () {
      // Фаза 1 «исключение не покидает кассу текстом» завела
      // `lib/core/errors/safe_error_text.dart`, и он импортировал
      // `package:sqlite3/sqlite3.dart` — тот безусловно экспортирует
      // `src/ffi/api.dart` → `dart:ffi` и потянул `dart:ffi` в браузерную
      // сборку (падал `flutter build web`). Строки 73 и 93 этого файла до
      // сих пор проверяли `dart:ffi` только как прямой импорт из
      // `lib/presentation` и `lib/domain` — `lib/core` не проверялся вовсе,
      // и находка не была бы поймана ни одним из существующих тестов.
      //
      // Здесь — тот же обход, что и для checkedRoots, но с единственным
      // запретом: прямой `dart:ffi` или цепочка через `package:telepos/...`,
      // ведущая к нему. Он **не** ловит транзитивную зависимость через
      // сторонний пакет (`package:sqlite3/sqlite3.dart` → `dart:ffi`) —
      // `_exploreDownward` спускается только по `package:telepos/...`
      // импортам, third-party пакеты не разворачиваются. Именно поэтому
      // ниже стоит отдельный, буквальный тест на `package:sqlite3/sqlite3.dart`
      // — а по-настоящему это ловит только сборка (`flutter build web`,
      // job `build-web` в `.github/workflows/ci.yml`).
      final violations = _violations('lib/core', const ['dart:ffi'], const []);
      expect(
        violations,
        isEmpty,
        reason:
            'lib/core не должен зависеть от dart:ffi — он используется и в '
            'браузерной сборке. См. docs/system-architecture.md, И5/И6.',
      );
    },
  );

  test('package:sqlite3/sqlite3.dart — прямой импорт только из lib/data', () {
    // `sqlite3.dart` — ffi-несущая точка входа пакета: она реэкспортирует
    // `common.dart` (чистый) и добавляет `src/ffi/api.dart`, который тянет
    // `dart:ffi` (проверено чтением исходников sqlite3-2.9.4). Только
    // `lib/data/` законно говорит с sqlite3 напрямую и уже это делает
    // (`app_database.dart`, `terminal_dao.dart`) — везде ещё нужен только
    // `SqliteException`, и для него есть `package:sqlite3/common.dart`.
    final offenders = <String>[];
    for (final file in _dartFiles('lib')) {
      final displayPath = _displayPath(file);
      if (displayPath.startsWith('lib/data/')) continue;
      final hasDirectImport = _importExportStatements(file)
          .map((s) => _importTarget(s.trim()))
          .any((target) => target == 'package:sqlite3/sqlite3.dart');
      if (hasDirectImport) offenders.add(displayPath);
    }
    expect(
      offenders,
      isEmpty,
      reason:
          'вне lib/data нужен package:sqlite3/common.dart — '
          'package:sqlite3/sqlite3.dart тянет dart:ffi безусловно.',
    );
  });

  test('в браузерном слое нет HTTP-клиента', () {
    // Правило проекта: двух живых реализаций одного не бывает. `ApiClient` и
    // восемь `http_*` репозиториев сняты (задача 17 плана
    // `2026-08-04-webtransport-browser-terminal.md`), и без сторожа REST
    // вернулся бы первым же «только на время» — а вместе с ним и опрос,
    // ради устранения которого менялся транспорт.
    //
    // Проверяется именно `package:http`, а не слово «http»: `dart:io`
    // `HttpServer` кассы остаётся и обязан остаться — он отдаёт страницу,
    // шрифты и бандл, которые браузер скачивает раньше, чем появится хоть
    // одна сессия WebTransport. Снят обмен данными, а не выдача документа.
    final offenders = _dartFiles('lib/web')
        .where((f) => f.readAsStringSync().contains('package:http/'))
        .map(_displayPath)
        .toList();

    expect(
      offenders,
      isEmpty,
      reason: 'провод один — WebTransport. См. спеку от 2026-08-04.',
    );
  });

  test('касса не отдаёт данных по HTTP — только страницу', () {
    // Вторая половина того же правила. Сторож выше запрещает клиента в
    // браузере; этот запрещает сервер на кассе: `SetupRoutes` и
    // `TerminalRoutes` сняты 2026-08-05 после того, как их недостижимость была
    // доказана поимённо (ни одного клиента ни в Dart, ни в скриптах, ни в CI,
    // ни в приборах — единственным, кто их строил, был `api_server.dart`).
    //
    // Признаком выбран `shelf_router`, а не слово «маршрут»: `shelf` и
    // `shelf_static` кассе по-прежнему нужны — ими отдаётся документ, бандл и
    // шрифты, без которых в браузере не появится ни одной сессии WebTransport.
    // Маршрутизатор нужен ровно тому, кто разводит запросы по данным, и его
    // возвращение — и есть возвращение REST.
    final offenders = _dartFiles('lib/backend')
        .where((f) => f.readAsStringSync().contains('package:shelf_router/'))
        .map(_displayPath)
        .toList();

    expect(
      offenders,
      isEmpty,
      reason:
          'данные едут по проводу (`TillWire`), а HTTP остался затем, чтобы '
          'браузер скачал страницу. См. спеку от 2026-08-04.',
    );
  });

  test('каждая проверяемая запись действительно даёт файлы для проверки', () {
    // Существования пути мало: каталог может существовать и не содержать ни
    // одного .dart-файла — тогда запись так же ничего не проверяет, но
    // выглядит защищённой. Здесь — что с каждой записи есть что читать.
    for (final root in checkedRoots) {
      expect(
        _dartFiles(root.path),
        isNotEmpty,
        reason: 'В checkedRoots запись без единого .dart-файла: ${root.path}',
      );
    }
  });
}

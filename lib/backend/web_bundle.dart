import 'dart:io';

/// Файлы, по которым каталог опознаётся как собранный бандл.
///
/// Двух мало по отдельности и достаточно вместе: `index.html` есть в любом
/// каталоге, куда кто-то однажды положил страницу, а `main.dart.js` порождает
/// только `flutter build web`. Проверять существование самого каталога, как
/// делалось раньше, недостаточно: `build/web` остаётся на диске после `flutter
/// clean` не всегда, но пустым — сколько угодно, и тогда касса рапортовала
/// «бандл найден», а браузер получал 404 на каждый файл.
///
/// Тот же список назван в `tools/build_windows_installer.ps1`: сборка
/// установщика отказывается паковать кассу, если этих двух файлов нет. Список
/// обязан оставаться одним и тем же — иначе установщик соберёт то, что касса
/// не признает бандлом.
const kWebBundleMarkers = <String>['index.html', 'main.dart.js'];

/// Проверяет каталог на признаки собранного бандла.
///
/// [fileExists] впрыскивается ради проверок: решение о том, где лежит бандл,
/// обязано проверяться без настоящих каталогов на диске — иначе единственным
/// способом проверить поиск остаётся установленная касса, а это как раз то, что
/// в этом проекте дважды расходилось с «работает у нас».
bool isWebBundle(String directory, {bool Function(String path)? fileExists}) {
  final exists = fileExists ?? _fileExistsOnDisk;
  return kWebBundleMarkers.every((marker) => exists(_join(directory, marker)));
}

/// Откуда взялся путь к бандлу. В журнал уезжает именно это, а не только путь:
/// «касса взяла бандл рядом с собой» и «касса взяла бандл из рабочего каталога»
/// — разные состояния, и чинят их по-разному.
enum WebBundleOrigin {
  /// `--web-dir=<путь>` в командной строке.
  argument,

  /// Определение сборки `TELEPOS_WEB_DIR`.
  define,

  /// Каталог `web` рядом с исполняемым файлом — так лежит у установленной кассы.
  besideExecutable,

  /// `build/web` относительно рабочего каталога — так лежит у разработчика,
  /// запускающего кассу из корня дерева.
  workingDirectory,
}

String _originText(WebBundleOrigin origin) => switch (origin) {
  WebBundleOrigin.argument => 'указан аргументом --web-dir',
  WebBundleOrigin.define => 'указан определением сборки TELEPOS_WEB_DIR',
  WebBundleOrigin.besideExecutable => 'найден рядом с исполняемым файлом',
  WebBundleOrigin.workingDirectory => 'найден относительно рабочего каталога',
};

/// Где лежит собранный браузерный бандл — или почему его нигде нет.
///
/// # Отказ приходит значением (И144)
///
/// Отсутствующий бандл — состояние, которое надо назвать. Молчание здесь уже
/// стоило заказчику браузерного терминала целиком: сервер поднимался, отвечал
/// `Frontend bundle not found at build/web`, и строка называла каталог, которого
/// на установленной кассе нет и быть не может, — то есть отправляла искать не
/// туда. Поэтому [WebBundleMissing] несёт весь список просмотренных мест.
sealed class WebBundle {
  const WebBundle();

  /// Одна строка для журнала и для страницы отказа.
  String get describe;
}

/// Бандл найден: [directory] — то, что отдаётся браузеру.
final class WebBundleFound extends WebBundle {
  const WebBundleFound(this.directory, this.origin);

  final String directory;
  final WebBundleOrigin origin;

  @override
  String get describe => '$directory (${_originText(origin)})';

  @override
  String toString() => describe;
}

/// Бандла нет ни в одном из мест, где его положено искать.
final class WebBundleMissing extends WebBundle {
  const WebBundleMissing(this.searched, {this.explicit});

  /// Все просмотренные каталоги, по порядку просмотра.
  final List<String> searched;

  /// Путь, названный человеком явно (аргументом или определением сборки), если
  /// он был назван. Тогда поиск на нём и заканчивается — см. [resolveWebBundle].
  final String? explicit;

  @override
  String get describe {
    final where = searched.isEmpty ? '(искать негде)' : searched.join(', ');
    return explicit == null
        ? 'бандл браузера не найден; просмотрено: $where. '
              'Соберите его: flutter build web -t lib/web/main_web.dart'
        : 'бандл браузера не найден по указанному пути $explicit; '
              'ожидались файлы ${kWebBundleMarkers.join(' и ')}';
  }

  @override
  String toString() => describe;
}

/// Решает, откуда касса отдаёт страницу терминалу.
///
/// # Почему поиск, а не один путь
///
/// Установленная касса и касса разработчика лежат по-разному, и ни один
/// единственный путь не годится обеим. Раньше путь был один — `build/web`
/// относительно **рабочего каталога**, — и он годился только разработчику: у
/// установленной кассы рабочий каталог `C:\Program Files\TelePOS`, никакого
/// `build` там нет, страницы взять неоткуда. Требовать от заказчика запускать
/// кассу с аргументом нельзя: ярлык из меню «Пуск» аргументов не несёт.
///
/// Порядок таков, что явное всегда бьёт найденное:
///
/// 1. `--web-dir=<путь>` — аргумент командной строки;
/// 2. `TELEPOS_WEB_DIR` — определение сборки;
/// 3. `<каталог telepos.exe>\web` — так кладёт установщик;
/// 4. `build/web` относительно рабочего каталога — дерево разработчика.
///
/// # Почему названный путь не откатывается на поиск
///
/// Если путь назвали явно и бандла там нет, поиск прекращается отказом. Иначе
/// опечатка в `--web-dir=` привела бы к тому, что касса молча отдала бы
/// **установленный** бандл вместо того, который отлаживают, — а это ровно та
/// разновидность отказа, которую ищут часами и не там.
WebBundle resolveWebBundle({
  String? argument,
  String define = '',
  String? executableDirectory,
  String workingDirectory = '.',
  bool Function(String path)? fileExists,
}) {
  final exists = fileExists ?? _fileExistsOnDisk;

  // Пустая строка — это «не задано»: `String.fromEnvironment` без определения
  // возвращает именно её, а не null.
  final explicit = <(String, WebBundleOrigin)>[
    if (argument != null && argument.isNotEmpty)
      (argument, WebBundleOrigin.argument),
    if (define.isNotEmpty) (define, WebBundleOrigin.define),
  ].firstOrNull;

  if (explicit != null) {
    final (path, origin) = explicit;
    return isWebBundle(path, fileExists: exists)
        ? WebBundleFound(path, origin)
        : WebBundleMissing([path], explicit: path);
  }

  final candidates = <(String, WebBundleOrigin)>[
    if (executableDirectory != null && executableDirectory.isNotEmpty)
      (_join(executableDirectory, 'web'), WebBundleOrigin.besideExecutable),
    (
      _join(_join(workingDirectory, 'build'), 'web'),
      WebBundleOrigin.workingDirectory,
    ),
  ];

  for (final (path, origin) in candidates) {
    if (isWebBundle(path, fileExists: exists)) {
      return WebBundleFound(path, origin);
    }
  }
  return WebBundleMissing([for (final (path, _) in candidates) path]);
}

bool _fileExistsOnDisk(String path) => File(path).existsSync();

/// Склейка пути без `package:path`.
///
/// Разделитель берётся у платформы, но существующий в строке не трогается:
/// Windows понимает и `/`, и `\`, а вот подменять то, что человек написал в
/// `--web-dir=`, — значит расходиться с тем, что он видит в журнале.
String _join(String directory, String name) {
  if (directory.isEmpty || directory == '.') return name;
  final separator = directory.contains('/') && !directory.contains(r'\')
      ? '/'
      : Platform.pathSeparator;
  return directory.endsWith('/') || directory.endsWith(r'\')
      ? '$directory$name'
      : '$directory$separator$name';
}

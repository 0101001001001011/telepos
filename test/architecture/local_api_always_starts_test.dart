@Tags(['architecture'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Сторож одной строки, которая стоила заказчику всего браузерного терминала.
///
/// # Что было
///
/// ```dart
/// if (const bool.fromEnvironment('TELEPOS_API') || _headless) {
///   await _startLocalApi();
/// }
/// ```
///
/// `TELEPOS_API` не задавалась **нигде**: ни в сборке кассы, ни в CI, ни в
/// установщике; `--headless` обычная касса не получает. То есть у каждого
/// заказчика локальный сервер не поднимался, а вместе с ним не выписывался и
/// корень магазина — он создаётся при первом открытии хранилища сертификатов.
/// Установщик, умеющий поставить корень в доверенные пользователя, находил
/// пустой каталог; это записано в `docs/internal/windows-installer.md`, раздел «Чего
/// ещё нет».
///
/// # Почему сторож по исходному тексту, а не по поведению
///
/// Проверить это поведением нечем: `main()` открывает окно, поднимает граф DI и
/// занимает настоящие сокеты — под `flutter test` он не запускается вовсе.
/// Именно поэтому дефект и прожил столько времени при полностью зелёном наборе:
/// набор до этого файла не имел ни одной проверки, касающейся точки входа.
///
/// Что проверяется поведением — проверяется там, где это возможно:
/// `test/unit/core/settings/terminal_service_settings_test.dart` держит правило
/// «выключено → петля», а `test/backend/api_server_listen_scope_test.dart`
/// поднимает настоящие сокеты и убеждается, что касса на петле недостижима с
/// сетевого адреса.
/// Тот же текст без строчных комментариев.
///
/// Достаточно строчных: в этом проекте и `///`, и `//` — единственные виды
/// комментария, которыми пишут пояснения; блочные `/* */` в `lib/` не
/// встречаются. Разбирать Dart целиком ради одного вопроса значило бы завести
/// второй анализатор.
String _withoutComments(List<String> lines) => [
  for (final line in lines)
    if (!line.trimLeft().startsWith('//')) line,
].join('\n');

void main() {
  final main = File('lib/main.dart');

  test('точка входа существует там, где её ищет сторож', () {
    // Иначе переименование `lib/main.dart` превратило бы каждую проверку ниже
    // в зелёную проверку пустоты.
    expect(
      main.existsSync(),
      isTrue,
      reason: 'сторож читает lib/main.dart — без него он ничего не сторожит',
    );
  });

  test('подъём сервера не зависит от определения сборки TELEPOS_API', () {
    final sources = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'));

    // Ищется само выражение, и только вне комментариев. Имя `TELEPOS_API`
    // остаётся в доке — там, где объяснено, почему его больше нет; проверка,
    // краснеющая от объяснения собственной причины, заставила бы стереть это
    // объяснение первым.
    final offenders = <String>[
      for (final file in sources)
        if (_withoutComments(
          file.readAsLinesSync(),
        ).contains("fromEnvironment('TELEPOS_API')"))
          file.path.replaceAll(r'\', '/'),
    ];

    expect(
      offenders,
      isEmpty,
      reason:
          'TELEPOS_API — определение сборки, которого нет ни в одной сборке. '
          'Пока подъём локального сервера стоял за ним, у заказчика не '
          'поднимался сервер и не выписывался корень магазина. Решение о том, '
          'кого обслуживает касса, принимает оператор, и живёт оно в '
          'TerminalServiceChoice, а не в аргументах компилятора',
    );
  });

  test('_startLocalApi зовётся безусловно', () {
    final lines = main.readAsLinesSync();
    final callSites = <int>[
      for (var i = 0; i < lines.length; i++)
        if (lines[i].contains('_startLocalApi(') &&
            !lines[i].contains('Future<void> _startLocalApi('))
          i,
    ];

    expect(
      callSites,
      hasLength(1),
      reason:
          'вызов один — второй означал бы две точки подъёма сервера, и одна '
          'из них подчинялась бы условию, о котором эта проверка не знает',
    );

    final call = callSites.single;
    expect(
      lines[call].trim(),
      startsWith('await _startLocalApi('),
      reason:
          'строка вызова обязана состоять из самого вызова: `if (…) await '
          '_startLocalApi(…)` вернул бы условный подъём в одну строку',
    );

    // Предыдущая значащая строка — не начало условия. Именно так выглядел
    // дефект: `if (…) {` строкой выше и вызов внутри.
    var previous = call - 1;
    while (previous >= 0) {
      final text = lines[previous].trim();
      if (text.isEmpty || text.startsWith('//')) {
        previous--;
        continue;
      }
      break;
    }
    expect(
      previous >= 0 ? lines[previous].trim() : '',
      isNot(startsWith('if (')),
      reason:
          'подъём сервера снова стал условным. Корень магазина обязан '
          'выписываться всегда либо никогда — установщику нужно предсказуемое '
          'поведение. Решение о безопасности принимается областью '
          'прослушивания (ListenScope), а не отказом подниматься',
    );
  });

  test('область прослушивания приходит из решения оператора', () {
    final source = main.readAsStringSync();

    expect(
      source,
      contains('TerminalServiceChoice.resolve('),
      reason: 'иначе решение оператора никто не читает',
    );
    // Ни один из двух слушателей не имеет права получать область литералом:
    // именно так `everywhere` и оказалось прошито у обоих, и касса без
    // терминалов открывала порт в сеть без всякого решения оператора. Пара
    // важна — сначала починили QUIC, и только тогда обнаружилось, что страница
    // не открывается вовсе, потому что её сокет слушал так же узко.
    for (final literal in const [
      'scope: ListenScope.everywhere',
      'scope: ListenScope.loopback',
    ]) {
      expect(
        source,
        isNot(contains(literal)),
        reason:
            '«$literal» в main.dart означает слушателя, чья область не зависит '
            'от того, поручал ли оператор этой кассе обслуживать терминалы',
      );
    }
    expect(
      source,
      contains('scope: scope'),
      reason: 'сервер страницы обязан получать ту же область, что и QUIC',
    );
  });
}

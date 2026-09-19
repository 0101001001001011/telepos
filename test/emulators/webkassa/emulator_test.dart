@Tags(['architecture'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'faults.dart';
import 'state.dart';

/// Сторож при эмуляторе WebKassa.
///
/// # Что он проверяет и, главное, чего он НЕ проверяет
///
/// Он **не проверяет эмулятор сам по себе** — это была бы проверка проверки, и
/// она зелена по построению: эмулятор всегда согласуется с эмулятором. Он
/// читает **исходник продукта** и требует, чтобы эмулятор за ним поспевал.
///
/// Приём взят у `test/architecture/stand_matches_till_test.dart`, где он в
/// этом дереве уже отработал трижды. Оттуда же взято и обязательное условие:
/// **сама выемка обязана что-то найти**. Пустое множество проходит любую
/// проверку молча, и именно так ломаются сторожа, читающие исходник.
///
/// Он не доказывает:
///
/// * что настоящая WebKassa отвечает этими кодами на эти случаи — коды сняты
///   с нашей карты разбора, а не с чужого протокола;
/// * что каждый заведённый код действительно **достижим** прогоном. Это
///   доказывает `probe.dart`, и никакое чтение исходника этого не заменит:
///   код, записанный в [kEmulatedFaults] и не производимый ни одной веткой
///   эмулятора, здесь пройдёт. Разделение намеренное — сторож дешёвый и
///   ежедневный, проба дорогая и полная.
void main() {
  group('карта кодов эмулятора против карты продукта', () {
    test('каждый числовой case из _mapError эмулятор умеет произвести', () {
      final cases = _mapErrorCases();

      // Выемка обязана что-то найти: пустое множество прошло бы молча.
      expect(
        cases.length,
        greaterThanOrEqualTo(13),
        reason:
            'из webkassa_provider.dart._mapError вынуто ${cases.length} '
            'числовых case; их там было тринадцать. Либо карта усохла, либо '
            'сломалась выемка — оба случая требуют человека.',
      );

      final missing = cases
          .difference(kEmulatedCodes)
          .difference(kCodesNotProducibleBySocket.keys.toSet());
      expect(
        missing,
        isEmpty,
        reason:
            'продукт разбирает коды $missing, а эмулятор их не производит. '
            'Ветка _mapError для каждого из них недостижима ни одной живой '
            'проверкой. Завести отказ в lib/emulators/webkassa/faults.dart.',
      );
    });

    test('код, которого сокет не производит, доказан названной пробой', () {
      // Исключение из сторожа выше — не лазейка: у каждого такого кода
      // назван файл, и файл обязан существовать и **звать эту ветку**.
      final cases = _mapErrorCases();
      for (final entry in kCodesNotProducibleBySocket.entries) {
        expect(
          cases,
          contains(entry.key),
          reason:
              'код ${entry.key} объявлен непроизводимым сокетом, но в '
              '_mapError его нет — исключение устарело, убери его',
        );
        expect(
          kEmulatedCodes,
          isNot(contains(entry.key)),
          reason: 'код ${entry.key} заявлен и производимым, и нет',
        );
        final probe = File(entry.value);
        expect(probe.existsSync(), isTrue, reason: 'нет пробы ${entry.value}');
        expect(
          probe.readAsStringSync(),
          contains('send:'),
          reason: '${entry.value} не подменяет транспорт — чем она зовёт ветку?',
        );
      }
    });

    test(
      'эмулятор умеет произвести код ВНЕ карты — иначе default недостижим',
      () {
        final cases = _mapErrorCases();
        final beyond = kEmulatedCodes.difference(cases);
        expect(
          beyond,
          isNotEmpty,
          reason:
              'у _mapError есть ветка `default: return unknown`. Она проходится '
              'только кодом, которого в карте нет. Убери такой код из '
              'kEmulatedFaults — и четырнадцатая ветка станет недостижимой, '
              'оставшись при этом зелёной.',
        );
      },
    );

    test('обе транзиентные ветки _isTransient вызываемы', () {
      // network, operatorUnavailable и tokenExpired — ради них существует
      // очередь. Коды, отображаемые в них: -1/-2/-3, -5 и 2/3.
      for (final code in [-1, -2, -3, -5, 2, 3]) {
        expect(
          kEmulatedCodes,
          contains(code),
          reason:
              'код $code отображается в транзиентный FiscalErrorCode. Без него '
              'ветка _isTransient и вся машина очереди не проходятся.',
        );
      }
    });

    test('у каждого отказа назван вход и то, что он открывает', () {
      for (final fault in kEmulatedFaults) {
        expect(
          fault.how.trim(),
          isNotEmpty,
          reason: 'у отказа ${fault.code} не сказано, как его вызвать',
        );
        expect(
          fault.opens.trim(),
          isNotEmpty,
          reason:
              'у отказа ${fault.code} не сказано, что он открывает в нашем '
              'коде. Отказ, про который это не написано, через полгода никто '
              'не отличит от украшения.',
        );
      }
    });
  });

  group('поверхность эмулятора против клиента продукта', () {
    test('девять путей эмулятора — ровно те, что зовёт WebKassaApiClient', () {
      final fromClient = _clientPaths();
      expect(
        fromClient.length,
        9,
        reason:
            'из webkassa_api_client.dart вынуто ${fromClient.length} путей '
            "post('/api/v4/…'); их там девять. Выемка или клиент изменились.",
      );
      expect(
        fromClient,
        equals(_emulatorApiPaths()),
        reason:
            'путь, который зовёт клиент, а эмулятор не знает, отвечает 404 и '
            'разбирается как -3/network — то есть тихо уезжает в очередь. '
            'Обратное тоже дефект: путь, которого у клиента нет, — выдумка.',
      );
    });

    test('пути пульта не пересекаются с боевыми', () {
      final api = _emulatorApiPaths();
      final console = _emulatorConsolePaths();
      expect(console, isNotEmpty);
      expect(
        console.intersection(api),
        isEmpty,
        reason:
            'пульт обязан стоять там, где настоящая WebKassa ответит 404 — '
            'иначе проба, случайно нацеленная на боевой сервер, пройдёт молча.',
      );
      for (final path in console) {
        expect(
          path.startsWith('/_emul/'),
          isTrue,
          reason: 'путь пульта $path вне префикса /_emul/',
        );
      }
    });

    test('объявленный список пульта совпадает с тем, что пульт разбирает', () {
      // Список kConsolePaths читают сторож и README; ветки разбирает switch в
      // `_console`. Разойтись они могут молча в обе стороны: новая ветка без
      // строки в списке — пульт, о котором никто не знает; строка без ветки —
      // обещание, которое отвечает 404.
      final declared = _emulatorConsolePaths();
      final handled = RegExp(r"case\s+'(/_emul/[a-z]+)'")
          .allMatches(
            File('lib/emulators/webkassa/emulator.dart').readAsStringSync(),
          )
          .map((m) => m.group(1)!)
          .toSet();
      expect(
        handled,
        isNotEmpty,
        reason: 'выемка веток пульта ничего не нашла',
      );
      expect(handled, equals(declared));
    });
  });

  group('деньги эмулятора считаются в Decimal, а не в double', () {
    test('пересчёт не разваливается там, где развалился бы double', () {
      // 0.1 + 0.1 + 0.1 в double даёт 0.30000000000000004 и не равно 0.3.
      // Пересчёт обязан сойтись. Это поведенческий сторож: он краснеет от
      // перехода на double, а не от переименования переменной.
      final recount = recountCheck({
        'Positions': [
          for (var i = 0; i < 3; i++)
            {'Count': 1, 'Price': 0.1, 'TaxType': 0, 'PositionName': 'x'},
        ],
        'Payments': [
          {'Sum': 0.3, 'PaymentType': 0},
        ],
      }, VatMode.off);
      expect(
        recount.agreed,
        isTrue,
        reason:
            'пересчёт отказал на верном чеке: ${recount.complaint}. Это худший '
            'исход, какой у измерительного прибора бывает — прибор внёс свою '
            'ошибку и покрасил исправный код.',
      );
      expect(recount.positionsTotal.toString(), '0.3');
    });

    test('и всё-таки краснеет там, где обязан', () {
      // Три строки по 100 со скидкой 33.33 на каждой: 200.01 против 200.00 —
      // та самая измеренная копейка, которую теряет раскладка скидки по
      // позициям.
      final recount = recountCheck({
        'Positions': [
          for (var i = 0; i < 3; i++)
            {'Count': 1, 'Price': 100, 'Discount': 33.33, 'TaxType': 0},
        ],
        'Payments': [
          {'Sum': 200, 'PaymentType': 0},
        ],
      }, VatMode.off);
      expect(recount.agreed, isFalse);
      expect(recount.complaint, contains('200.01'));
      expect(
        recount.complaint,
        contains('0.01'),
        reason: 'отказ обязан называть разность, а не только факт расхождения',
      );
    });

    test('в денежном пути state.dart нет ни одной операции над double', () {
      // Комментарии срезаются намеренно: этот же файл в докстринге объясняет,
      // почему double запрещён, и упоминает его несколько раз. Сторож,
      // спотыкающийся о собственный довод, — это сторож, который заставит
      // убрать довод.
      final source = _codeOnly(
        File('lib/emulators/webkassa/state.dart').readAsStringSync(),
      );
      for (final forbidden in ['toDouble(', 'as double', 'double.parse']) {
        expect(
          source.contains(forbidden),
          isFalse,
          reason:
              '«$forbidden» в lib/emulators/webkassa/state.dart. WebKassaProvider._money отдаёт num, '
              'и при нецелом значении это double; сложение таких значений '
              'вносит ошибку самого прибора.',
        );
      }
    });
  });

  group('эмулятор обязан запускаться под dart run', () {
    test('под test/emulators/ нет ни одного package:flutter вне сторожей', () {
      final offenders = <String>[];
      for (final file
          in Directory('test/emulators')
              .listSync(recursive: true)
              .whereType<File>()
              .where((f) => f.path.endsWith('.dart'))) {
        if (file.path.endsWith('_test.dart')) continue;
        if (_codeOnly(file.readAsStringSync()).contains('package:flutter')) {
          offenders.add(file.path);
        }
      }
      expect(
        offenders,
        isEmpty,
        reason:
            'эти файлы запускаются `dart run`, а не под flutter_tester. '
            'package:flutter (и всё, что тянет dart:ui) их не соберёт — и '
            'узнается это на живой проверке, которой из-за этого не будет. '
            'bin/telepos_backend.dart уже так сломался через LocalProperties.',
      );
    });
  });
}

// ------------------------------------------------------------------ выемка

/// Исходник без комментариев.
///
/// Нужен потому, что оба здешних сторожа ищут в тексте то, о чём этот же
/// текст рассуждает в докстрингах: `double` и `package:flutter`. Сторож,
/// который краснеет от объяснения запрета, вынуждает объяснение стереть — а
/// объяснение и есть половина сторожа.
String _codeOnly(String source) {
  final withoutBlocks = source.replaceAll(
    RegExp(r'/\*.*?\*/', dotAll: true),
    '',
  );
  return const LineSplitter()
      .convert(withoutBlocks)
      .where((line) => !line.trimLeft().startsWith('//'))
      .join('\n');
}

/// Числовые `case` из `WebKassaProvider._mapError` — из исходника, а не по
/// памяти.
Set<int> _mapErrorCases() {
  final body = _functionBody(
    'lib/data/fiscal/webkassa_provider.dart',
    'FiscalErrorCode _mapError(int? code) {',
  );
  return RegExp(
    r'case\s+(-?\d+)\s*:',
  ).allMatches(body).map((m) => int.parse(m.group(1)!)).toSet();
}

/// Пути `/api/v4/…`, которые зовёт `WebKassaApiClient`.
Set<String> _clientPaths() {
  final source = File(
    'lib/data/datasources/remote/webkassa_api_client.dart',
  ).readAsStringSync();
  return RegExp(
    r"post\(\s*'(/api/v4/[A-Za-z]+)'",
  ).allMatches(source).map((m) => m.group(1)!).toSet();
}

/// `kApiPaths` из `emulator.dart` — читается из исходника, а не импортируется.
///
/// Импорт связал бы сторожа с `dart:io`-сервером и потащил его под
/// `flutter_tester`; чтение текста даёт то же и ничем не рискует.
Set<String> _emulatorApiPaths() =>
    _listLiteral('lib/emulators/webkassa/emulator.dart', 'kApiPaths');

Set<String> _emulatorConsolePaths() =>
    _listLiteral('lib/emulators/webkassa/emulator.dart', 'kConsolePaths');

Set<String> _listLiteral(String path, String name) {
  final source = File(path).readAsStringSync();
  final start = source.indexOf('$name = [');
  expect(start, isNot(-1), reason: 'в $path нет списка $name');
  final end = source.indexOf('];', start);
  expect(end, isNot(-1), reason: 'список $name в $path не закрыт');
  final literal = source.substring(start, end);
  final items = RegExp(
    r"'([^']+)'",
  ).allMatches(literal).map((m) => m.group(1)!).toSet();
  expect(items, isNotEmpty, reason: 'список $name в $path пуст');
  return items;
}

/// Тело функции по её сигнатуре, по балансу скобок.
String _functionBody(String path, String signature) {
  final source = File(path).readAsStringSync();
  final start = source.indexOf(signature);
  expect(start, isNot(-1), reason: 'в $path нет «$signature»');
  var depth = 0;
  var i = start + signature.length - 1;
  final from = i;
  for (; i < source.length; i++) {
    final ch = source[i];
    if (ch == '{') depth++;
    if (ch == '}') {
      depth--;
      if (depth == 0) return source.substring(from, i + 1);
    }
  }
  fail('скобки «$signature» в $path не закрылись');
}

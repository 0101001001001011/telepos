/// Сторожа самих эмуляторов — читают **исходник продукта**, а не свои
/// представления о нём.
///
/// Сторож, читающий только эмулятор, доказывает, что эмулятор согласен сам с
/// собой. Ценность здесь ровно в обратном: эмулятор обязан разойтись с
/// продуктом громко в тот день, когда продукт изменится.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'escpos/faults.dart';
import 'kaspi/emulator.dart';

/// Процессы эмуляторов — те, что запускаются `dart run`, а не под
/// `flutter_tester`.
///
/// ESC/POS переехал в `lib/` (встроенный эмулятор), но запускается по-прежнему
/// `dart run` из тонкой обёртки — значит и запрет на `package:flutter` с него
/// не снимается: под `flutter_tester` его никто не поднимает.
const List<String> _emulatorProcesses = [
  'lib/emulators/escpos/emulator.dart',
  'lib/emulators/escpos/faults.dart',
  'lib/emulators/escpos/render.dart',
  'lib/emulators/labels/zpl.dart',
  'test/emulators/escpos/emulator.dart',
  'test/emulators/kaspi/emulator.dart',
  'lib/emulators/serial/emulator.dart',
  'test/emulators/serial/emulator.dart',
  // WebKassa переехала в `lib/` тем же приёмом 2026-09-19. В список её
  // внесли тогда же, а не раньше: пока она жила целиком под `test/`, запрет
  // на `package:flutter` держался соседним сторожем, который обходит весь
  // каталог. В `lib/` этот сторож её больше не видит, а `dart run` из обёртки
  // по-прежнему сломается о первый же `dart:ui`.
  'lib/emulators/webkassa/emulator.dart',
  'lib/emulators/webkassa/faults.dart',
  'lib/emulators/webkassa/state.dart',
  'test/emulators/webkassa/emulator.dart',
  'lib/emulators/sbp/emulator.dart',
  'test/emulators/sbp/emulator.dart',
];

void main() {
  final root = _repoRoot();

  group('Ограничения процессов-эмуляторов', () {
    test('ни один не тянет package:flutter', () {
      for (final path in _emulatorProcesses) {
        final source = File('$root/$path').readAsStringSync();
        expect(
          source,
          isNot(contains("import 'package:flutter")),
          reason:
              '$path запускается `dart run`, а не под flutter_tester. '
              '`bin/telepos_backend.dart` уже перестал собираться ровно так — '
              'через LocalProperties притянул dart:ui',
        );
      }
    });

    test('у каждого есть дверь остановки', () {
      for (final path in _emulatorProcesses) {
        final source = File('$root/$path').readAsStringSync();
        if (!source.contains('HttpServer.bind') &&
            !source.contains('ServerSocket.bind') &&
            !source.contains('.open(mode:')) {
          continue; // чистый разборщик, поднимать нечего
        }
        expect(
          source,
          contains('/_emul/stop'),
          reason:
              '$path что-то поднимает и не умеет это погасить. У стенда двери '
              'не было, и за сутки это дало три висящих процесса',
        );
      }
    });

    test('каждый называет, чего он НЕ доказывает', () {
      for (final path in _emulatorProcesses) {
        final source = File('$root/$path').readAsStringSync();
        expect(
          source,
          contains('НЕ доказыва'),
          reason:
              '$path: эмулятор без списка того, чего он не доказывает, '
              'читается как доказательство всего',
        );
      }
    });

    test('lib/ не ЗАВИСИТ от test/emulators ни одной строкой кода', () {
      // Сторож про зависимость, а не про упоминание. Ссылка из докстринга —
      // приём этого дерева (три файла вокруг фискализации ссылаются на
      // эмулятор WebKassa ровно так же), и она ничего не тянет за собой.
      // Тянет импорт — и вот его быть не должно: сборка обязана рухнуть в
      // тот день, когда кто-то сошлётся на стенд из продукта.
      final hits = <String>[];
      for (final file in Directory('$root/lib').listSync(recursive: true)) {
        if (file is! File || !file.path.endsWith('.dart')) continue;
        for (final line in file.readAsLinesSync()) {
          final code = line.trimLeft();
          if (code.startsWith('//')) continue;
          if (code.contains('test/emulators') || code.contains('../../test/')) {
            hits.add('${file.path}: $line');
          }
        }
      }
      expect(hits, isEmpty, reason: 'продукт не имеет права зависеть от стенда');
    });
  });

  group('Сторожа против исходника продукта', () {
    test('разбор ответа Kaspi не сверяется ни с одним кодом отказа', () {
      // Карты кодов Kaspi у нас нет, значит коды эмулятора выдуманы. Если
      // продукт когда-нибудь начнёт сверяться со СПИСКОМ кодов, он начнёт
      // сверяться с нашей выдумкой — и настоящий терминал с кодом не из
      // списка получит «неизвестная ошибка» вместо причины.
      final source = File(
        '$root/lib/hardware/kaspi_pos/kaspi_pos_service.dart',
      ).readAsStringSync();
      final parse = source.substring(
        source.indexOf('_parsePurchaseResponse(Uint8List response)'),
      );
      final body = parse.substring(0, parse.indexOf('\n  bool _isSuccess'));

      final comparisons = RegExp(
        r'resultCode\s*==\s*(0x[0-9a-fA-F]+|\d+)',
      ).allMatches(body).map((m) => m.group(1)!).toList();

      expect(
        comparisons,
        ['0x30'],
        reason:
            'единственное допустимое сравнение — с кодом УСПЕХА. Всё '
            'остальное обязано быть отказом по умолчанию: $comparisons',
      );
    });

    test('коды отказа эмулятора не пересекаются с кодом успеха', () {
      expect(kInventedRefusalCodes.values, isNot(contains(kApproved)));
      expect(
        kInventedRefusalCodes.values.toSet(),
        hasLength(kInventedRefusalCodes.length),
        reason: 'два отказа с одним кодом — это отказ без диагноза',
      );
    });

    test('биты ответа DLE EOT сверены с маркером, который читает продукт', () {
      // `_isRealTimeStatusByte`: (b & 0x93) == 0x12. Сторож читает это из
      // ИСХОДНИКА продукта: если продукт поменяет маркер, эмулятор обязан
      // покраснеть в тот же день, а не отвечать байтом, который продукт
      // молча выбросит как чужой.
      final source = File(
        '$root/lib/hardware/printer/wifi_printer.dart',
      ).readAsStringSync();
      expect(
        source,
        contains('(b & 0x93) == 0x12'),
        reason:
            'маркер ответа DLE EOT изменился — почини `_statusByte` эмулятора '
            'в escpos/emulator.dart, иначе он отвечает мусором',
      );
      expect(
        source,
        contains('(reply[1] & 0x60) != 0x60'),
        reason: 'биты «бумага кончилась» изменились — почини эмулятор',
      );
      expect(
        source,
        contains('(reply.first & 0x08) == 0'),
        reason: 'бит «не в сети» изменился — почини эмулятор',
      );
    });

    test('кадр Kaspi сверен с тем, что собирает продукт', () {
      final source = File(
        '$root/lib/hardware/kaspi_pos/kaspi_pos_service.dart',
      ).readAsStringSync();
      expect(source, contains('[0x02, ...payload.codeUnits, 0x03]'));
      expect(source, contains("padLeft(12, '0')"));
      expect(source, contains("padLeft(6, '0')"));
    });
  });

  group('Каждый эмулятор умеет отказать', () {
    test('у ESC/POS отказов не меньше семи, и каждый расходуется', () {
      final faults = EmulatorFaults();
      faults.apply({
        'offline': true,
        'outOfPaper': true,
        'coverOpen': true,
        'reject': 1,
        'kill': 1,
        'silence': 1,
        'garbage': 1,
        'latencyMs': 5,
      });
      expect(faults.describe().length, greaterThanOrEqualTo(8));

      // Счётчик расходуется, а не залипает: залипший отказ красит все
      // следующие случаи и выглядит как поломка продукта.
      expect(faults.takeKill(), isTrue);
      expect(faults.takeKill(), isFalse);
      expect(faults.takeReject(), isTrue);
      expect(faults.takeReject(), isFalse);

      faults.reset();
      expect(faults.offline, isFalse);
      expect(faults.latency, Duration.zero);
      expect(faults.describeState(), 'исправен');
    });

    test('журнал пишет ДОВОД, а не факт вызова', () {
      final faults = EmulatorFaults()..outOfPaper = true;
      expect(faults.describeState(), contains('бумага'));
      faults.coverOpen = true;
      expect(faults.describeState(), contains('крышка'));
    });
  });
}

String _repoRoot() {
  var dir = Directory.current;
  while (!File('${dir.path}/pubspec.yaml').existsSync()) {
    final parent = dir.parent;
    if (parent.path == dir.path) {
      throw StateError('Корень репозитория не найден от ${Directory.current}');
    }
    dir = parent;
  }
  return dir.path.replaceAll('\\', '/');
}

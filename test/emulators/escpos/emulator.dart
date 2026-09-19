/// Запуск эмулятора ESC/POS **из командной строки**.
///
/// # Почему сам эмулятор живёт в `lib/`, а запуск — здесь
///
/// Решение заказчика 2026-09-19: эмулятор обязан быть встроен в приложение,
/// чтобы для проверки шаблона чека и диагностики ничего не доставляли. Класс
/// [EscPosEmulator] поэтому переехал в
/// `lib/emulators/escpos/emulator.dart` — он часть продукта.
///
/// **Правило раздела при этом не нарушено.** Оно требует, чтобы точка
/// подстановки была самой дальней — **сетью**, а не интерфейсом над
/// драйвером; отдельный процесс был способом этого добиться, а не целью.
/// Эмулятор внутри приложения открывает настоящий серверный сокет, и касса
/// идёт к нему своим `WifiPrinterManager`, своими кадрами, своим опросом
/// `DLE EOT`, своей очередью. Проверяется то же самое, до последнего байта.
///
/// Этот файл остаётся затем, что запуск отдельным процессом никуда не делся:
/// им пользуются живые прогоны и ручные проверки, и ни один из них не
/// изменился ни строкой. **Одна реализация, два вызывающих** — тот же приём,
/// которым в проекте уже живёт разборщик потока.
///
/// # Чего этот запуск НЕ доказывает
///
/// Оговорки самого эмулятора перечислены там, где он живёт
/// (`lib/emulators/escpos/emulator.dart`), и они здесь в силе целиком. К ним
/// эта дверь добавляет свою: **успешный запуск отсюда ничего не говорит о
/// встроенном выключателе**. Командная строка поднимает сокет сама, минуя и
/// настройки кассы, и запись адреса в привязку прибора, — то есть ровно тот
/// путь, которым эмулятором будет пользоваться кассир. Он проверяется своими
/// пробами, не этим файлом.
///
/// # Запуск
///
/// ```
/// dart run test/emulators/escpos/emulator.dart --port 9100 --control 9110
/// dart run test/emulators/escpos/emulator.dart --labels --port 9101 --control 9111
/// dart run test/emulators/escpos/emulator.dart --render /tmp/telepos/spool.bin
/// dart run test/emulators/escpos/emulator.dart --stop --control 9110
/// ```
///
/// `package:flutter` здесь и во всём, что отсюда импортируется, запрещён:
/// файл запускается `dart run`, а не под `flutter_tester`. Сторож —
/// `emulator_guards_test.dart`.
library;

import 'dart:io';

import 'package:telepos/emulators/escpos/emulator.dart';
import 'package:telepos/emulators/escpos/faults.dart';
import 'package:telepos/emulators/escpos/render.dart';
import 'package:telepos/emulators/labels/zpl.dart';

// Прежние читатели просили класс отсюда — пересылка оставлена, чтобы живые
// прогоны и стенд печати не менялись ни строкой.
export 'package:telepos/emulators/escpos/emulator.dart';

Future<void> main(List<String> argv) async {
  final args = parseArgs(argv);
  if (args.containsKey('help')) {
    stdout.write(_usage);
    return;
  }

  final host = args['host'] ?? '127.0.0.1';
  final port = int.tryParse(args['port'] ?? '') ?? 9100;
  final control = int.tryParse(args['control'] ?? '') ?? (port + 10);
  final labels = args.containsKey('labels');

  if (args.containsKey('render')) {
    final file = File(args['render']!);
    if (!await file.exists()) {
      stderr.writeln('Файла «${file.path}» нет.');
      exitCode = 2;
      return;
    }
    final bytes = await file.readAsBytes();
    stdout.write(
      labels
          ? renderLabels(bytes)
          : renderReceipt(bytes, width: int.tryParse(args['width'] ?? '') ?? 42),
    );
    return;
  }

  if (args.containsKey('stop')) {
    await stopRemote(host, control);
    return;
  }

  final emulator = EscPosEmulator(
    faults: EmulatorFaults(),
    labels: labels,
    width: int.tryParse(args['width'] ?? '') ?? 42,
  );
  await emulator.start(host, port);
  await emulator.startControl(host, control);

  stdout
    ..writeln(
      labels
          ? 'Эмулятор принтера этикеток (ZPL/EPL) поднят.'
          : 'Эмулятор чекового принтера (ESC/POS) поднят.',
    )
    ..writeln('')
    ..writeln('  Адрес прибора (вписать на экране настроек оборудования):')
    ..writeln('      IP $host, порт $port')
    ..writeln('  Пульт:  http://$host:$control/_emul/state')
    ..writeln('  Журнал: http://$host:$control/_emul/journal')
    ..writeln('  Стоп:   curl -X POST http://$host:$control/_emul/stop')
    ..writeln('')
    ..writeln('  Денежный ящик — здесь же: команда ESC p приходит тем же')
    ..writeln('  сокетом, отдельного прибора у него нет.')
    ..writeln('');

  ProcessSignal.sigint.watch().listen((_) async {
    stdout.writeln(
      '\nЭмулятор остановлен. Заданий: ${emulator.jobs.length}, '
      'открытий ящика: ${emulator.drawerKicks}.',
    );
    await emulator.stop();
    exit(0);
  });
}

/// Стук в чужую дверь остановки.
Future<void> stopRemote(String host, int control) async {
  final client = HttpClient();
  try {
    final request = await client.postUrl(
      Uri.parse('http://$host:$control/_emul/stop'),
    );
    final response = await request.close();
    await response.drain<void>();
    stdout.writeln('Эмулятор на $host:$control остановлен.');
  } catch (e) {
    stderr.writeln('Эмулятор на $host:$control не ответил: $e');
    exitCode = 1;
  } finally {
    client.close(force: true);
  }
}

Map<String, String> parseArgs(List<String> argv) {
  final out = <String, String>{};
  for (var i = 0; i < argv.length; i++) {
    final a = argv[i];
    if (!a.startsWith('--')) continue;
    final name = a.substring(2);
    if (i + 1 < argv.length && !argv[i + 1].startsWith('--')) {
      out[name] = argv[i + 1];
      i++;
    } else {
      out[name] = 'true';
    }
  }
  return out;
}

const String _usage = '''
Эмулятор чекового принтера ESC/POS и принтера этикеток ZPL/EPL.

  --host      127.0.0.1 | 0.0.0.0   (умолч. 127.0.0.1)
  --port      9100     порт принтера
  --control   9110     порт пульта (/_emul/*)
  --labels             разбирать поток как ZPL/EPL
  --width     42       ширина показа чека в символах
  --render    <файл>   разобрать файл и выйти (для эмулятора спулера)
  --stop               остановить эмулятор на --control и выйти
  --help

Пульт:
  POST /_emul/fault  {offline,outOfPaper,coverOpen,kill,silence,garbage,
                      reject,latencyMs}
  POST /_emul/reset  |  GET /_emul/state  |  GET /_emul/journal
  GET  /_emul/last   последний разобранный чек
  POST /_emul/stop   ДВЕРЬ ОСТАНОВКИ
''';

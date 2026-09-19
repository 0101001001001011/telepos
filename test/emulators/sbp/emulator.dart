/// Запуск эмулятора провайдера QR/СБП **из командной строки**.
///
/// # Почему сам эмулятор живёт в `lib/`, а запуск — здесь
///
/// Решение заказчика 2026-09-19: эмулятор обязан быть встроен в приложение,
/// чтобы для проверки оплаты и диагностики ничего не доставляли. Класс
/// [SbpEmulator] поэтому переехал в `lib/emulators/sbp/emulator.dart` — он
/// часть продукта.
///
/// **Правило раздела при этом не нарушено.** Оно требует, чтобы точка
/// подстановки была самой дальней — **сетью**, а не интерфейсом над нашим
/// провайдером; отдельный процесс был способом этого добиться, а не целью.
/// Эмулятор внутри приложения открывает настоящий серверный сокет, и касса
/// идёт к нему своим `HttpQrPaymentProvider` — своей сборкой запроса, своим
/// разбором ответа, своим тайм-аутом. Проверяется то же самое.
///
/// Этот файл остаётся затем, что запуск отдельным процессом никуда не делся:
/// им пользуются живые прогоны, стенд и ручные проверки, и ни один из них не
/// изменился ни строкой. **Одна реализация, два вызывающих.**
///
/// # Чего этот запуск НЕ доказывает
///
/// Оговорки самого эмулятора перечислены там, где он живёт
/// (`lib/emulators/sbp/emulator.dart`), и они здесь в силе целиком. К ним эта
/// дверь добавляет свою: **успешный запуск отсюда ничего не говорит о
/// встроенном выключателе**. Командная строка поднимает сокет сама, минуя и
/// настройки кассы, и запись адреса в настройку провайдера QR, — то есть
/// ровно тот путь, которым эмулятором будет пользоваться кассир. Он
/// проверяется своими пробами, не этим файлом.
///
/// # Запуск
///
/// ```
/// dart run test/emulators/sbp/emulator.dart --port 8890 --control 8900
/// dart run test/emulators/sbp/emulator.dart --stop --control 8900
/// ```
library;

import 'dart:io';

import 'package:telepos/emulators/sbp/emulator.dart';

// Прежние читатели просили класс отсюда — пересылка оставлена, чтобы живые
// прогоны и пробы не менялись ни строкой.
export 'package:telepos/emulators/sbp/emulator.dart';

const String _usage = '''
Эмулятор провайдера QR/СБП.

  --host     127.0.0.1 | 0.0.0.0
  --port     8890    порт провайдера (его вписать в настройки QR)
  --control  8900    порт пульта
  --ttl      5m      срок намерения
  --stop             остановить эмулятор на --control и выйти
  --help

ВНИМАНИЕ: форма протокола этого эмулятора ВЫДУМАНА. Договора с провайдером
СБП у нас нет. Настоящее здесь — ВРЕМЯ: подтверждение приходит после
вопроса, может опоздать, не прийти вовсе и прийти дважды.

Провод:
  POST /sbp/v1/qr                  {intentKey, amount, orderNo}
  GET  /sbp/v1/qr/{id}
  POST /sbp/v1/qr/{id}/cancel
  POST /sbp/v1/qr/{id}/refund      {amount}

Пульт:
  POST /_emul/pay      {intentId?, intentKey?, amount?, times?, afterMs?}
  POST /_emul/decline  {intentId?, message?}
  POST /_emul/expire   {intentId?}
  POST /_emul/fault    {refuse, count, refuseConnect, latencyMs}
       refuse: silence | kill | refuseConnect | garbage | busy |
               unknownIntent | rejected | reverseUnsupported | http500
  POST /_emul/reset  |  GET /_emul/state  |  GET /_emul/journal
  GET  /_emul/faults   список отказов и предупреждение о выдуманной форме
  POST /_emul/stop     ДВЕРЬ ОСТАНОВКИ

Молчание покупателя — это НЕ команда пульта, а её отсутствие: не звать
/_emul/pay. Терпение кассы кончится само, и это самый обычный исход.
''';

Future<void> main(List<String> argv) async {
  final args = <String, String>{};
  for (var i = 0; i < argv.length; i++) {
    final a = argv[i];
    if (!a.startsWith('--')) continue;
    final name = a.substring(2);
    if (i + 1 < argv.length && !argv[i + 1].startsWith('--')) {
      args[name] = argv[i + 1];
      i++;
    } else {
      args[name] = 'true';
    }
  }

  if (args.containsKey('help')) {
    stdout.write(_usage);
    return;
  }

  final host = args['host'] ?? '127.0.0.1';
  final port = int.tryParse(args['port'] ?? '') ?? 8890;
  final control = int.tryParse(args['control'] ?? '') ?? (port + 10);

  if (args.containsKey('stop')) {
    final client = HttpClient();
    try {
      final request = await client.postUrl(
        Uri.parse('http://$host:$control/_emul/stop'),
      );
      await (await request.close()).drain<void>();
      stdout.writeln('Эмулятор СБП на $host:$control остановлен.');
    } catch (e) {
      stderr.writeln('Эмулятор на $host:$control не ответил: $e');
      exitCode = 1;
    } finally {
      client.close(force: true);
    }
    return;
  }

  final ttlRaw = args['ttl'] ?? '5m';
  final ttl = ttlRaw.endsWith('s')
      ? Duration(
          seconds: int.tryParse(ttlRaw.substring(0, ttlRaw.length - 1)) ?? 300,
        )
      : Duration(minutes: int.tryParse(ttlRaw.replaceAll('m', '')) ?? 5);

  final emulator = SbpEmulator(ttl: ttl);
  await emulator.start(host, port);
  await emulator.startControl(host, control);

  // Порты — **настоящие**, а не из доводов: `--port 0` отдаёт выбор
  // системе, и напечатанный ноль никуда не ведёт.
  stdout
    ..writeln('Эмулятор провайдера QR/СБП поднят.')
    ..writeln('')
    ..writeln('  Адрес провайдера (вписать в настройки QR кассы):')
    ..writeln('      http://$host:${emulator.port}')
    ..writeln('  Пульт:  http://$host:${emulator.controlPort}/_emul/state')
    ..writeln(
      '  Стоп:   curl -X POST http://$host:${emulator.controlPort}/_emul/stop',
    )
    ..writeln('')
    ..writeln('  ВНИМАНИЕ. Форма протокола ВЫДУМАНА: договора с провайдером')
    ..writeln('  у нас нет. Настоящее здесь — время, а не имена полей.')
    ..writeln('');

  final sigint = ProcessSignal.sigint.watch().listen((_) async {
    stdout.writeln(
      '\nЭмулятор СБП остановлен. Записей в журнале: '
      '${emulator.journal.length}.',
    );
    await emulator.stop();
    exit(0);
  });

  // **Дверь остановки обязана кончать процесс.** Подписка на сигнал
  // держит процесс живым сама по себе; прежде её не снимал никто, и после
  // `POST /_emul/stop` сокеты закрывались, а `dart.exe` оставался висеть.
  // Сторож — `emulator_stop_door_test.dart`, отдельным процессом.
  await emulator.stopped;
  await sigint.cancel();
  stdout.writeln(
    'Эмулятор СБП остановлен дверью. Записей в журнале: '
    '${emulator.journal.length}.',
  );
}

/// Запуск эмулятора весов и дисплея **из командной строки**.
///
/// Сам эмулятор живёт в `lib/emulators/serial/emulator.dart` — по тому же
/// решению заказчика, что и ESC/POS: эмулятор в комплекте с кассой. Здесь
/// остаётся только запуск отдельным процессом, которым пользуются живые
/// прогоны; ни один из них не изменился ни строкой.
///
/// # Чего этот запуск НЕ доказывает
///
/// Оговорки самого эмулятора перечислены там, где он живёт, и здесь в силе
/// целиком. Своя добавляется одна: запуск отсюда ничего не говорит о
/// встроенном выключателе — командная строка поднимает порт сама, минуя и
/// настройки кассы, и запись адреса в привязку прибора.
library;

import 'dart:io';

import 'package:telepos/emulators/serial/emulator.dart';

export 'package:telepos/emulators/serial/emulator.dart';

const String _usage = '''
Эмулятор весов и дисплея покупателя через петлю операционной системы.

  --port     COM9 | /dev/pts/4   ВТОРОЙ конец пары; кассе достаётся первый
  --role     scale | display
  --dialect  generic | cas | massaK   (для роли scale)
  --control  8899   порт пульта
  --stop     остановить эмулятор на --control и выйти
  --help

Пара портов — средство ОС, не наше:
  Windows        com0com, пара COM8 ↔ COM9
  Linux/macOS    socat -d -d pty,raw,echo=0 pty,raw,echo=0

Пульт:
  POST /_emul/weight {weight:"1.250", stable:true, overload:false}
  POST /_emul/fault  {refuse: silent|neverSettles|overload|garbage}
  POST /_emul/reset  |  GET /_emul/state  |  GET /_emul/journal
  POST /_emul/stop   ДВЕРЬ ОСТАНОВКИ
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
  final control = int.tryParse(args['control'] ?? '') ?? 8899;

  if (args.containsKey('stop')) {
    final client = HttpClient();
    try {
      final request = await client.postUrl(
        Uri.parse('http://$host:$control/_emul/stop'),
      );
      await (await request.close()).drain<void>();
      stdout.writeln('Эмулятор порта на $host:$control остановлен.');
    } catch (e) {
      stderr.writeln('Эмулятор на $host:$control не ответил: $e');
      exitCode = 1;
    } finally {
      client.close(force: true);
    }
    return;
  }

  final portPath = args['port'];
  if (portPath == null) {
    stderr.writeln('Не назван --port. $_usage');
    exitCode = 2;
    return;
  }

  final emulator = SerialEmulator(
    portPath: portPath,
    role: args['role'] ?? 'scale',
    dialect: args['dialect'] ?? 'cas',
  );
  final refusal = await emulator.open();
  if (refusal != null) {
    stderr.writeln(refusal);
    exitCode = 3;
    return;
  }
  await emulator.startControl(host, control);

  stdout
    ..writeln('Эмулятор «${emulator.role}» поднят на $portPath.')
    ..writeln('')
    ..writeln('  Кассе вписать ВТОРОЙ порт пары, не этот.')
    ..writeln('  Пульт: http://$host:$control/_emul/state')
    ..writeln('  Стоп:  curl -X POST http://$host:$control/_emul/stop')
    ..writeln('');

  ProcessSignal.sigint.watch().listen((_) async {
    stdout.writeln('\nЭмулятор остановлен. Записей: ${emulator.journal.length}.');
    await emulator.stop();
    exit(0);
  });
}

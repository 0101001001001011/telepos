/// Дверь остановки эмулятора СБП **кончает процесс**, а не только сокеты.
///
/// # Что случилось
///
/// Живая проверка входа в QR (2026-09-13) позвала `POST /_emul/stop`,
/// получила `{"stopping":true}`, порты закрылись — а процесс остался жить:
/// подписка на Ctrl-C (`ProcessSignal.sigint.watch()`) держала его, и
/// никто её не снимал. Порты свободны, `netstat` пуст, в диспетчере задач
/// висят `dart.exe` и `dartvm.exe`. Ровно тот класс, ради которого дверь
/// заводилась: «у стенда её нет, и это уже стоило дереву трёх висящих
/// процессов».
///
/// # Почему отдельным процессом
///
/// Проба внутри той же памяти (`SbpEmulator.stop()`) зелена при любой
/// подписке на сигнал: процесс набора живёт своей жизнью и не кончается
/// вовсе. Вопрос «кончился ли процесс» задаётся только процессу.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// `dart` из того же SDK, что запустил набор. `FLUTTER_ROOT` набор кладёт
/// в окружение; без него — `dart` из PATH.
String _dart() {
  final root = Platform.environment['FLUTTER_ROOT'];
  if (root != null) {
    final exe = File(
      '$root/bin/cache/dart-sdk/bin/dart${Platform.isWindows ? '.exe' : ''}',
    );
    if (exe.existsSync()) return exe.path;
  }
  return 'dart';
}

void main() {
  test('POST /_emul/stop — процесс эмулятора кончается сам', () async {
    final process = await Process.start(_dart(), [
      'run',
      'test/emulators/sbp/emulator.dart',
      '--port',
      '0',
      '--control',
      '0',
    ]);
    final out = StringBuffer();
    final control = Completer<Uri>();
    process.stdout.transform(utf8.decoder).listen((chunk) {
      out.write(chunk);
      final m = RegExp(
        r'Пульт:\s+(http://127\.0\.0\.1:\d+)',
      ).firstMatch(out.toString());
      if (m != null && !control.isCompleted) control.complete(Uri.parse(m[1]!));
    });
    process.stderr.transform(utf8.decoder).listen(out.write);

    var exited = false;
    unawaited(process.exitCode.then((_) => exited = true));
    addTearDown(() {
      // Красная ветвь не имеет права оставить процесс после себя.
      if (!exited) process.kill(ProcessSignal.sigkill);
    });

    final base = await control.future.timeout(
      const Duration(seconds: 60),
      onTimeout: () => fail('эмулятор не назвал адрес пульта:\n$out'),
    );
    expect(base.port, isNot(0), reason: 'печатается настоящий порт, а не 0');

    final client = HttpClient();
    try {
      final request = await client.postUrl(base.replace(path: '/_emul/stop'));
      final response = await request.close();
      expect(
        await utf8.decoder.bind(response).join(),
        contains('stopping'),
      );
    } finally {
      client.close(force: true);
    }

    final code = await process.exitCode.timeout(
      const Duration(seconds: 10),
      onTimeout: () => fail(
        'дверь остановки ответила, а процесс жив через 10 с — '
        'его держит что-то, кроме сокетов (подписка на сигнал?):\n$out',
      ),
    );
    expect(code, 0);
  });
}

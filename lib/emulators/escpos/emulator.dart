/// Эмулятор чекового принтера ESC/POS, денежного ящика и принтера этикеток —
/// измерительный прибор, а не заглушка.
///
/// # Механизм подстановки: **адресом**
///
/// Правок в `lib/` — ноль. У сетевого принтера уже есть поля `ipAddress` и
/// `port` на экране настроек оборудования; вписать туда `127.0.0.1` и `9100`
/// — весь способ подстановки. Значит проверяются `WifiPrinterManager`,
/// сборка кадров ESC/POS, опрос `DLE EOT`, обнаружение полуоткрытого сокета,
/// очередь печати и разбор результата — то есть то, что вероятнее всего
/// сломано. Подстановка своего `PrinterManager` сняла бы с проверки всё это
/// разом.
///
/// # Чего этот эмулятор НЕ доказывает
///
/// * **Что чек напечатан физически.** Бумаги нет. «Напечатано» здесь
///   означает «байты пришли в сокет и разобрались».
/// * **Что настоящий принтер ведёт себя так же.** Своего верного числа нет
///   ни одного: команды, ответы `DLE EOT` и их биты сняты с **нашего**
///   `WifiPrinterManager`, то есть с нашего понимания чужого протокола.
/// * **Что кодовая страница верна для конкретной модели.** `ESC t 17` — это
///   CP866 у большинства, но не у всех.
/// * **Что ящик действительно открылся.** Соленоида нет; видна команда.
/// * **Что этикетка встала по месту.** ZPL/EPL разбираются до полей, растр
///   не считается.
///
/// # Дверь остановки
///
/// `POST /_emul/stop` на управляющем порту, `Ctrl-C`, и — если ни то ни
/// другое не сработало — `--stop`, который стучится в чужой управляющий порт
/// и глушит его. У стенда двери не было, и за сутки это дало три висящих
/// процесса.
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
/// # Ограничение, а не пожелание
///
/// Файл запускается `dart run`, а не под `flutter_tester`, поэтому
/// **`package:flutter` здесь запрещён**. Сторож — в `emulator_test.dart`.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'faults.dart';
import 'render.dart';
import 'package:telepos/emulators/labels/zpl.dart';

/// Сетевой принтер: чековый (ESC/POS) или этикеточный (ZPL/EPL).
///
/// Один класс на два прибора не из экономии: транспорт у них **буквально**
/// один и тот же — TCP 9100, и `LabelPrinterService` открывает такой же
/// сокет, как `WifiPrinterManager`. Разница только в разборщике потока, и
/// она объявлена полем [labels].
class EscPosEmulator {
  EscPosEmulator({
    required this.faults,
    this.labels = false,
    this.echo = true,
    this.width = 42,
  });

  final EmulatorFaults faults;

  /// Разбирать поток как ZPL/EPL, а не как ESC/POS.
  final bool labels;

  final bool echo;

  final int width;

  ServerSocket? _server;
  HttpServer? _control;
  final List<Socket> _clients = [];

  /// Журнал: что пришло, как разобралось и с каким доводом отвечено.
  final List<Map<String, Object?>> journal = [];

  /// Сколько раз открывался денежный ящик (`ESC p`).
  int drawerKicks = 0;

  /// Байты, пришедшие с начала работы, по заданиям.
  final List<List<int>> jobs = [];

  int get port => _server?.port ?? 0;
  int get controlPort => _control?.port ?? 0;

  Future<void> start(String host, int port) async {
    _server = await ServerSocket.bind(host, port);
    _server!.listen(_onClient);
  }

  Future<void> startControl(String host, int port) async {
    _control = await HttpServer.bind(host, port);
    unawaited(_serveControl());
  }

  void _onClient(Socket socket) {
    _clients.add(socket);
    final buffer = <int>[];
    Timer? idle;

    void settle() {
      if (buffer.isEmpty) return;
      final job = List<int>.from(buffer);
      buffer.clear();
      _acceptJob(job);
    }

    socket.listen(
      (data) async {
        // Отказ «kill» — закрыть сокет без ответа. Единственный вход в
        // ветку полуоткрытого сокета `WifiPrinterManager`.
        if (faults.takeKill()) {
          _log('kill', 'сокет закрыт без ответа: отказ «kill»');
          _clients.remove(socket);
          socket.destroy();
          return;
        }

        // Опрос состояния идёт вперёд задания: настоящий принтер отвечает на
        // `DLE EOT` немедленно, даже посреди печати — на то он и «в реальном
        // времени».
        final answered = await _answerStatusQueries(socket, data);
        final rest = data.where((b) => !answered.contains(b)).toList();
        if (answered.isEmpty) {
          buffer.addAll(data);
        } else if (rest.isNotEmpty) {
          buffer.addAll(_stripStatusQueries(data));
        }

        idle?.cancel();
        idle = Timer(const Duration(milliseconds: 150), settle);
      },
      onError: (_) {
        _clients.remove(socket);
      },
      onDone: () {
        idle?.cancel();
        settle();
        _clients.remove(socket);
      },
      cancelOnError: true,
    );
  }

  /// Байты `DLE EOT n`, найденные в потоке, и ответ на каждый.
  ///
  /// Возвращает множество байтов, которые были частью опроса, — не для
  /// красоты: без этого опрос попал бы в задание печати и напечатался бы
  /// как текст.
  Future<Set<int>> _answerStatusQueries(Socket socket, List<int> data) async {
    final seen = <int>{};
    for (var i = 0; i + 2 < data.length + 1; i++) {
      if (i + 2 >= data.length) break;
      if (data[i] != 0x10 || data[i + 1] != 0x04) continue;
      final n = data[i + 2];
      seen.addAll([0x10, 0x04, n]);

      final latency = faults.latency;
      if (latency > Duration.zero) {
        _log('latency', 'задержка ${latency.inMilliseconds} мс перед ответом');
        await Future<void>.delayed(latency);
      }
      if (faults.takeSilence()) {
        _log(
          'silence',
          'опрос DLE EOT $n оставлен без ответа: отказ «silence»',
        );
        continue;
      }
      if (faults.takeGarbage()) {
        // Не-ответ при живом сокете: байт, у которого не сходятся биты
        // маркера. Единственный вход в ветку «мусор вместо байта состояния».
        socket.add([0xFF]);
        await socket.flush();
        _log('garbage', 'на DLE EOT $n отвечено мусором 0xFF');
        continue;
      }

      final byte = _statusByte(n);
      socket.add([byte]);
      await socket.flush();
      _log(
        'status',
        'DLE EOT $n → 0x${byte.toRadixString(16).padLeft(2, '0')} '
            '(${faults.describeState()})',
      );
    }
    return seen;
  }

  List<int> _stripStatusQueries(List<int> data) {
    final out = <int>[];
    var i = 0;
    while (i < data.length) {
      if (i + 2 < data.length && data[i] == 0x10 && data[i + 1] == 0x04) {
        i += 3;
        continue;
      }
      out.add(data[i]);
      i++;
    }
    return out;
  }

  /// Ответ на `DLE EOT n`, по битам, которые читает продукт.
  ///
  /// Маркер ответа: биты 0 и 7 сброшены, биты 1 и 4 установлены —
  /// `(b & 0x93) == 0x12`. Всё остальное продукт обязан отвергнуть как мусор,
  /// и отвергает (`WifiPrinterManager._isRealTimeStatusByte`).
  /// **Крышка и бумага разведены намеренно, и это допущение эмулятора.**
  /// Настоящий принтер с кончившейся бумагой чаще всего объявляет себя
  /// «не в сети» — то есть один и тот же бит. Эмулятор так не делает: тогда
  /// ветка «В принтере закончилась бумага» (`wifi_printer.dart`, разбор
  /// `DLE EOT 4`) стала бы недостижима, и её сторож был бы зелен впустую.
  /// Крышка отвечает битом «не в сети», потому что отдельного бита крышки
  /// продукт не читает вовсе.
  int _statusByte(int n) {
    var b = 0x12;
    switch (n) {
      case 1: // состояние принтера: бит 3 — не в сети
        if (faults.offline || faults.coverOpen) b |= 0x08;
      case 4: // состояние бумаги: биты 5 и 6 — рулон кончился
        if (faults.outOfPaper) b |= 0x60;
      default:
        break;
    }
    return b;
  }

  void _acceptJob(List<int> job) {
    jobs.add(job);
    if (faults.takeReject()) {
      _log('reject', 'задание ${job.length} байт отвергнуто: отказ «reject»');
      return;
    }
    final kicks = _countDrawerKicks(job);
    drawerKicks += kicks;
    final rendered = labels
        ? renderLabels(job)
        : renderReceipt(job, width: width);
    _log(
      'job',
      'задание ${job.length} байт принято'
          '${kicks > 0 ? ', открытий ящика: $kicks' : ''}',
      rendered: rendered,
    );
  }

  int _countDrawerKicks(List<int> job) {
    var n = 0;
    for (var i = 0; i + 1 < job.length; i++) {
      if (job[i] == 0x1B && job[i + 1] == 0x70) n++;
    }
    return n;
  }

  void _log(String kind, String why, {String? rendered}) {
    final entry = <String, Object?>{
      'at': DateTime.now().toIso8601String(),
      'kind': kind,
      'why': why,
      if (rendered != null) 'rendered': rendered,
    };
    journal.add(entry);
    if (echo) {
      stdout.writeln('[$kind] $why');
      if (rendered != null) stdout.write(rendered);
    }
  }

  Future<void> _serveControl() async {
    final server = _control;
    if (server == null) return;
    await for (final request in server) {
      final path = request.uri.path;
      Map<String, Object?> body = const {};
      if (request.method == 'POST') {
        final raw = await utf8.decoder.bind(request).join();
        if (raw.trim().isNotEmpty) {
          try {
            body = (jsonDecode(raw) as Map).cast<String, Object?>();
          } catch (_) {
            body = const {};
          }
        }
      }

      Object? answer;
      switch (path) {
        case '/_emul/fault':
          faults.apply(body);
          answer = faults.describe();
        case '/_emul/reset':
          faults.reset();
          journal.clear();
          jobs.clear();
          drawerKicks = 0;
          answer = faults.describe();
        case '/_emul/state':
          answer = {
            'faults': faults.describe(),
            'jobs': jobs.length,
            'drawerKicks': drawerKicks,
            'journal': journal.length,
          };
        case '/_emul/journal':
          answer = journal;
        case '/_emul/last':
          answer = {
            'rendered': journal.reversed.firstWhere(
              (e) => e['rendered'] != null,
              orElse: () => const {'rendered': ''},
            )['rendered'],
          };
        case '/_emul/stop':
          request.response
            ..statusCode = 200
            ..headers.contentType = ContentType.json
            ..write(jsonEncode({'stopping': true}));
          await request.response.close();
          await stop();
          return;
        default:
          request.response.statusCode = HttpStatus.notFound;
          await request.response.close();
          continue;
      }

      request.response
        ..statusCode = 200
        ..headers.contentType = ContentType.json
        ..write(jsonEncode(answer));
      await request.response.close();
    }
  }

  /// Дверь остановки. Закрывает **всё**, включая уже принятых клиентов:
  /// сервер, закрытый без них, оставляет порт занятым.
  Future<void> stop() async {
    for (final c in List<Socket>.from(_clients)) {
      try {
        c.destroy();
      } catch (_) {}
    }
    _clients.clear();
    await _server?.close();
    _server = null;
    await _control?.close(force: true);
    _control = null;
  }
}

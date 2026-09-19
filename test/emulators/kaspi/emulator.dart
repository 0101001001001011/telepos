/// Эмулятор эквайрингового терминала Kaspi POS — измерительный прибор, а не
/// заглушка.
///
/// # Механизм подстановки: **адресом**
///
/// Правок в `lib/` — ноль. У терминала оплаты уже есть `ipAddress`/`port` в
/// настройках (`KaspiPosConfig`), и вписать туда `127.0.0.1:8888` — весь
/// способ. Значит проверяется `KaspiPosService` целиком: кадрирование
/// `[0x02, payload, 0x03]`, сборка покупки `'1' + amount(12) + receipt(6)`,
/// сторно `'3'`, разбор ответа, тайм-ауты и разрыв связи.
///
/// # ГЛАВНОЕ, ЧТО НАДО ЗНАТЬ ОБ ЭТОМ ЭМУЛЯТОРЕ
///
/// **Карты кодов отказа у нас нет.** Ни в дереве, ни в документации: продукт
/// разбирает ответ как «первый байт `0x30` — успех, всё остальное — отказ, а
/// текст ошибки — хвост». Поэтому **коды отказа этого эмулятора наши и
/// выдуманные**, и ни одно число здесь не является утверждением о поведении
/// настоящего терминала Kaspi.
///
/// Следствие для продукта прямое и обязательное: разбор обязан обрабатывать
/// **любой** первый байт, отличный от `0x30`, а не наш список. Сторож на это
/// — `emulator_test.dart`: он читает `_parsePurchaseResponse` из исходника
/// продукта и требует, чтобы там не было ни одного сравнения с конкретным
/// кодом отказа.
///
/// # Чего этот эмулятор НЕ доказывает
///
/// * **Что деньги списаны.** Банка здесь нет.
/// * **Что настоящий терминал ведёт себя так же** — ни одного верного числа.
/// * **Что чек эквайринга напечатан.** Принтера здесь нет.
/// * **Что сторно возвращает именно ту операцию.** Наш `_buildReversalCommand`
///   шлёт голое `'3'` без номера операции — эмулятор сторнирует последнюю, и
///   это **допущение эмулятора**, а не факт протокола.
///
/// # Дверь остановки
///
/// `POST /_emul/stop` на управляющем порту, `Ctrl-C`, `--stop`.
///
/// # Запуск
///
/// ```
/// dart run test/emulators/kaspi/emulator.dart --port 8888 --control 8898
/// dart run test/emulators/kaspi/emulator.dart --stop --control 8898
/// ```
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

const int kStx = 0x02;
const int kEtx = 0x03;

/// Первый байт успешного ответа. Единственное число в этом файле, снятое с
/// продукта, а не выдуманное.
const int kApproved = 0x30;

/// Вызываемые отказы. **Все выдуманы**: карты кодов у нас нет.
///
/// | Пульт | Первый байт | Что открывает в продукте |
/// | --- | --- | --- |
/// | `declined` | `0x31` | ветку отказа с текстом |
/// | `insufficientFunds` | `0x32` | ту же ветку, другой текст |
/// | `cardRemoved` | `0x33` | ту же ветку |
/// | `terminalBusy` | `0x34` | ту же ветку |
/// | `cyrillic` | `0x37` | отказ русским текстом в UTF-8 — разбор хвоста продукта |
/// | `framesOnly` | `[0x02,0x03]` | пустая нагрузка → «Некорректный ответ» |
/// | `silence` | — | тайм-аут 60 с → `TimeoutException` |
/// | `kill` | — | разрыв связи → `SocketException` |
/// | `latencyMs` | — | медленный, но живой терминал |
/// | `refuseConnect` | — | сокет не принимается вовсе |
const Map<String, int> kInventedRefusalCodes = {
  'declined': 0x31,
  'insufficientFunds': 0x32,
  'cardRemoved': 0x33,
  'terminalBusy': 0x34,
};

class KaspiEmulator {
  KaspiEmulator({this.echo = true});

  final bool echo;

  ServerSocket? _server;
  HttpServer? _control;
  final List<Socket> _clients = [];

  final List<Map<String, Object?>> journal = [];

  /// Проведённые покупки: номер чека → сумма в тиынах.
  final Map<String, int> approved = {};

  /// Последняя проведённая покупка — её и сторнирует голое `'3'`.
  String? lastReceipt;

  /// Проведённые операции: номер операции → чек, сумма и сколько по ней
  /// уже возвращено (тиыны). Читает возврат `'4'` — задача 26.
  final Map<String, ({String receipt, int amount, int refunded})>
  transactions = {};

  /// Ответы на возвраты по ключу возврата кассы: повтор с тем же ключом
  /// получает прежний ответ, а деньги второй раз не возвращаются.
  final Map<String, List<int>> refundsByKey = {};

  String refuse = '';
  int refusesLeft = 0;
  Duration latency = Duration.zero;
  bool refuseConnect = false;
  int _counter = 0;

  int get port => _server?.port ?? 0;
  int get controlPort => _control?.port ?? 0;

  Future<void> start(String host, int port) async {
    _server = await ServerSocket.bind(host, port);
    _server!.listen((socket) {
      if (refuseConnect) {
        _log('refuseConnect', 'соединение отвергнуто: отказ «refuseConnect»');
        socket.destroy();
        return;
      }
      _clients.add(socket);
      socket.listen(
        (data) => unawaited(_onFrame(socket, data)),
        onError: (_) => _clients.remove(socket),
        onDone: () => _clients.remove(socket),
        cancelOnError: true,
      );
    });
  }

  Future<void> startControl(String host, int port) async {
    _control = await HttpServer.bind(host, port);
    unawaited(_serveControl());
  }

  Future<void> _onFrame(Socket socket, List<int> data) async {
    if (data.isEmpty) return;
    if (data.first != kStx || data.last != kEtx) {
      _log(
        'frame',
        'кадр без STX/ETX — отвечено отказом: настоящий терминал такой кадр '
        'не поймёт, и продукт обязан это пережить',
      );
      await _answer(socket, [0x39, ...'KADR NE RASPOZNAN'.codeUnits]);
      return;
    }

    final payload = String.fromCharCodes(data.sublist(1, data.length - 1));
    if (payload.isEmpty) {
      await _answer(socket, [0x39, ...'PUSTAYA NAGRUZKA'.codeUnits]);
      return;
    }

    final op = payload[0];
    switch (op) {
      case '1':
        await _purchase(socket, payload);
      case '3':
        await _reversal(socket);
      case '4':
        await _refund(socket, payload);
      default:
        _log('op', 'неизвестная операция «$op»');
        await _answer(socket, [0x39, ...'NEIZVESTNAYA OPERACIYA'.codeUnits]);
    }
  }

  Future<void> _purchase(Socket socket, String payload) async {
    // '1' + amount(12) + receipt(6) — ровно то, что собирает
    // `KaspiPosService._buildPurchaseCommand`.
    if (payload.length < 19) {
      _log(
        'purchase',
        'нагрузка ${payload.length} символов, ожидалось 19 — отказ',
      );
      await _answer(socket, [0x39, ...'KOROTKAYA NAGRUZKA'.codeUnits]);
      return;
    }
    final amountRaw = payload.substring(1, 13);
    final receipt = payload.substring(13, 19);
    final amount = int.tryParse(amountRaw);
    if (amount == null) {
      await _answer(socket, [0x39, ...'SUMMA NE CHISLO'.codeUnits]);
      return;
    }
    if (amount <= 0) {
      // Сам собой, из состояния, без пульта: продажа на ноль — это дефект
      // кассы, а не выбор оператора эмулятора.
      _log('purchase', 'сумма $amount ≤ 0 — отказ без пульта');
      await _answer(socket, [0x35, ...'SUMMA DOLZHNA BYT BOLSHE NULYA'.codeUnits]);
      return;
    }

    final named = _takeRefusal();
    if (named != null) {
      final code = kInventedRefusalCodes[named];
      if (code != null) {
        _log('purchase', 'чек $receipt на $amount тиын — отказ «$named»');
        await _answer(socket, [code, ..._refusalText(named).codeUnits]);
        return;
      }
      switch (named) {
        case 'cyrillic':
          // Ответ по-русски, байтами UTF-8. Прежде здесь стояло
          // `'ОТКАЗ'.codeUnits` — коды UTF-16, которые сокет обрезал до
          // байта: эмулятор сам слал мусор, и проверить разбор продукта
          // было нечем.
          _log('purchase', 'ответ кириллицей (UTF-8): отказ «cyrillic»');
          await _answer(socket, [0x37, ...utf8.encode('ОТКАЗ')]);
          return;
        case 'framesOnly':
          _log('purchase', 'только кадр без нагрузки: отказ «framesOnly»');
          await _raw(socket, const [kStx, kEtx]);
          return;
        case 'silence':
          _log('purchase', 'ответа не будет: отказ «silence»');
          return;
        case 'kill':
          _log('purchase', 'связь разорвана: отказ «kill»');
          _clients.remove(socket);
          socket.destroy();
          return;
      }
    }

    // Повтор того же номера чека — не «ещё одна продажа». Настоящий терминал
    // здесь бы задумался, и продукт обязан пережить оба исхода; эмулятор
    // отвечает тем же результатом, а не проводит деньги дважды.
    if (approved.containsKey(receipt)) {
      _log(
        'purchase',
        'чек $receipt уже проведён на ${approved[receipt]} тиын — повтор, '
        'деньги второй раз не берутся',
      );
    } else {
      approved[receipt] = amount;
    }
    lastReceipt = receipt;
    _counter++;

    final txn = 'KP${_counter.toString().padLeft(10, '0')}';
    final approval = _counter.toString().padLeft(6, '0');
    const cardMask = '440043******1234';
    transactions[txn] = (receipt: receipt, amount: amount, refunded: 0);
    _log('purchase', 'чек $receipt на $amount тиын одобрен, операция $txn');
    await _answer(socket, [
      kApproved,
      ...txn.codeUnits,
      ...approval.codeUnits,
      ...cardMask.codeUnits,
    ]);
  }

  Future<void> _reversal(Socket socket) async {
    final named = _takeRefusal();
    if (named == 'kill') {
      _clients.remove(socket);
      socket.destroy();
      return;
    }
    if (named == 'silence') return;
    final code = named == null ? null : kInventedRefusalCodes[named];
    if (code != null) {
      _log('reversal', 'сторно отказано: «$named»');
      await _answer(socket, [code, ..._refusalText(named!).codeUnits]);
      return;
    }

    final receipt = lastReceipt;
    if (receipt == null || !approved.containsKey(receipt)) {
      // Сам собой, из состояния: сторнировать нечего.
      _log('reversal', 'сторнировать нечего — отказ без пульта');
      await _answer(socket, [0x36, ...'NET OPERACII DLYA STORNO'.codeUnits]);
      return;
    }
    approved.remove(receipt);
    lastReceipt = null;
    _log('reversal', 'операция по чеку $receipt сторнирована');
    await _answer(socket, [kApproved, ...'STORNO VYPOLNENO'.codeUnits]);
  }

  /// Возврат по операции — **кадр нашего изобретения** (задача 26):
  /// `'4' + сумма(12) + операция + '|' + ключ возврата`. Протокола возврата
  /// Kaspi POS у нас нет; настоящее здесь — три правила денег, одинаковые у
  /// любого эквайринга:
  ///
  /// * вернуть можно только **проведённую** операцию;
  /// * вернуть больше, чем по ней заплачено, **с учётом прежних возвратов**,
  ///   нельзя — ни разом, ни частями;
  /// * повтор с тем же ключом получает прежний ответ и **не возвращает
  ///   деньги второй раз**.
  Future<void> _refund(Socket socket, String payload) async {
    final bar = payload.indexOf('|');
    if (payload.length < 14 || bar < 14) {
      _log('refund', 'нагрузка возврата без операции или ключа — отказ');
      await _answer(socket, [0x39, ...'KOROTKAYA NAGRUZKA'.codeUnits]);
      return;
    }
    final amount = int.tryParse(payload.substring(1, 13));
    final txn = payload.substring(13, bar);
    final key = payload.substring(bar + 1);

    final named = _takeRefusal();
    if (named == 'kill') {
      _clients.remove(socket);
      socket.destroy();
      return;
    }
    if (named == 'silence') return;
    final code = named == null ? null : kInventedRefusalCodes[named];
    if (code != null) {
      _log('refund', 'возврат по $txn отказан: «$named»');
      await _answer(socket, [code, ..._refusalText(named!).codeUnits]);
      return;
    }

    final seen = refundsByKey[key];
    if (seen != null) {
      _log(
        'refund',
        'ключ $key уже известен — отдан прежний ответ, деньги второй раз '
        'не возвращаются',
      );
      await _answer(socket, seen);
      return;
    }
    final original = transactions[txn];
    if (original == null) {
      _log('refund', 'операции $txn нет — возвращать нечего, отказ без пульта');
      await _answer(socket, [0x36, ...'NET OPERACII DLYA VOZVRATA'.codeUnits]);
      return;
    }
    if (amount == null || amount <= 0) {
      await _answer(socket, [0x35, ...'SUMMA DOLZHNA BYT BOLSHE NULYA'.codeUnits]);
      return;
    }
    if (original.refunded + amount > original.amount) {
      _log(
        'refund',
        'по $txn оплачено ${original.amount}, уже возвращено '
        '${original.refunded}, просят $amount — больше оплаченного, отказ',
      );
      await _answer(socket, [0x38, ...'SUMMA VOZVRATA BOLSHE OPLATY'.codeUnits]);
      return;
    }

    transactions[txn] = (
      receipt: original.receipt,
      amount: original.amount,
      refunded: original.refunded + amount,
    );
    _counter++;
    final refundTxn = 'KR${_counter.toString().padLeft(10, '0')}';
    final approval = _counter.toString().padLeft(6, '0');
    final answer = [kApproved, ...refundTxn.codeUnits, ...approval.codeUnits];
    refundsByKey[key] = answer;
    _log(
      'refund',
      'по $txn возвращено $amount тиын (всего ${original.refunded + amount} из '
      '${original.amount}), операция возврата $refundTxn, ключ $key',
    );
    await _answer(socket, answer);
  }

  String? _takeRefusal() {
    if (refuse.isEmpty) return null;
    if (refusesLeft <= 0) return null;
    refusesLeft--;
    final named = refuse;
    if (refusesLeft == 0) refuse = '';
    return named;
  }

  /// Тексты отказа — латиницей; русский отказ — отдельный пульт `cyrillic`.
  ///
  /// До дорожки D `KaspiPosService._parsePurchaseResponse` разбирал хвост
  /// через `String.fromCharCodes` (побайтно, как latin1), и русский текст
  /// доезжал крокозябрами. Теперь хвост — UTF-8; проба «кириллица в ответе
  /// терминала доезжает до кассира» (`hardware_test.dart`) это требует.
  /// Кодировка **настоящего** терминала не измерена — вопрос наружу.
  String _refusalText(String named) => switch (named) {
    'declined' => 'OTKAZ BANKA',
    'insufficientFunds' => 'NEDOSTATOCHNO SREDSTV',
    'cardRemoved' => 'KARTA IZVLECHENA',
    'terminalBusy' => 'TERMINAL ZANYAT',
    _ => 'OTKAZ',
  };

  Future<void> _answer(Socket socket, List<int> payload) =>
      _raw(socket, [kStx, ...payload, kEtx]);

  Future<void> _raw(Socket socket, List<int> bytes) async {
    if (latency > Duration.zero) {
      await Future<void>.delayed(latency);
    }
    socket.add(bytes);
    await socket.flush();
  }

  void _log(String kind, String why) {
    journal.add({
      'at': DateTime.now().toIso8601String(),
      'kind': kind,
      'why': why,
    });
    if (echo) stdout.writeln('[$kind] $why');
  }

  Future<void> _serveControl() async {
    final server = _control;
    if (server == null) return;
    await for (final request in server) {
      Map<String, Object?> body = const {};
      if (request.method == 'POST') {
        final raw = await utf8.decoder.bind(request).join();
        if (raw.trim().isNotEmpty) {
          try {
            body = (jsonDecode(raw) as Map).cast<String, Object?>();
          } catch (_) {}
        }
      }

      Object? answer;
      switch (request.uri.path) {
        case '/_emul/fault':
          refuse = (body['refuse'] as String?) ?? '';
          refusesLeft = (body['count'] as num?)?.toInt() ?? (refuse.isEmpty ? 0 : 1);
          refuseConnect = (body['refuseConnect'] as bool?) ?? refuseConnect;
          final ms = body['latencyMs'];
          if (ms is num) latency = Duration(milliseconds: ms.toInt());
          answer = _state();
        case '/_emul/reset':
          refuse = '';
          refusesLeft = 0;
          refuseConnect = false;
          latency = Duration.zero;
          approved.clear();
          lastReceipt = null;
          transactions.clear();
          refundsByKey.clear();
          journal.clear();
          answer = _state();
        case '/_emul/state':
          answer = _state();
        case '/_emul/journal':
          answer = journal;
        case '/_emul/codes':
          answer = {
            'approved': kApproved,
            'invented': kInventedRefusalCodes,
            'внимание':
                'коды отказа выдуманы: карты кодов Kaspi у нас нет. Продукт '
                'обязан обрабатывать ЛЮБОЙ первый байт, отличный от 0x30',
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

  Map<String, Object?> _state() => {
    'refuse': refuse,
    'refusesLeft': refusesLeft,
    'refuseConnect': refuseConnect,
    'latencyMs': latency.inMilliseconds,
    'approved': approved,
    'lastReceipt': lastReceipt,
    'transactions': {
      for (final e in transactions.entries)
        e.key: {
          'receipt': e.value.receipt,
          'amount': e.value.amount,
          'refunded': e.value.refunded,
        },
    },
    'journal': journal.length,
  };

  /// Дверь остановки.
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

const String _usage = '''
Эмулятор эквайрингового терминала Kaspi POS.

  --host     127.0.0.1 | 0.0.0.0
  --port     8888    порт терминала
  --control  8898    порт пульта
  --stop             остановить эмулятор на --control и выйти
  --help

ВНИМАНИЕ: коды отказа этого эмулятора ВЫДУМАНЫ. Карты кодов Kaspi у нас
нет — продукт обязан обрабатывать любой первый байт, отличный от 0x30.

Пульт:
  POST /_emul/fault {refuse, count, refuseConnect, latencyMs}
       refuse: declined | insufficientFunds | cardRemoved | terminalBusy |
               cyrillic | framesOnly | silence | kill
  POST /_emul/reset  |  GET /_emul/state  |  GET /_emul/journal
  GET  /_emul/codes  коды и предупреждение о том, что они выдуманы
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
  final port = int.tryParse(args['port'] ?? '') ?? 8888;
  final control = int.tryParse(args['control'] ?? '') ?? (port + 10);

  if (args.containsKey('stop')) {
    final client = HttpClient();
    try {
      final request = await client.postUrl(
        Uri.parse('http://$host:$control/_emul/stop'),
      );
      await (await request.close()).drain<void>();
      stdout.writeln('Эмулятор Kaspi на $host:$control остановлен.');
    } catch (e) {
      stderr.writeln('Эмулятор на $host:$control не ответил: $e');
      exitCode = 1;
    } finally {
      client.close(force: true);
    }
    return;
  }

  final emulator = KaspiEmulator();
  await emulator.start(host, port);
  await emulator.startControl(host, control);

  stdout
    ..writeln('Эмулятор терминала Kaspi POS поднят.')
    ..writeln('')
    ..writeln('  Адрес прибора (вписать в настройки Kaspi POS):')
    ..writeln('      IP $host, порт $port')
    ..writeln('  Пульт:  http://$host:$control/_emul/state')
    ..writeln('  Стоп:   curl -X POST http://$host:$control/_emul/stop')
    ..writeln('')
    ..writeln('  ВНИМАНИЕ. Коды отказа ВЫДУМАНЫ: карты кодов Kaspi у нас нет.')
    ..writeln('  Продукт обязан обрабатывать любой первый байт ≠ 0x30.')
    ..writeln('');

  ProcessSignal.sigint.watch().listen((_) async {
    stdout.writeln(
      '\nЭмулятор Kaspi остановлен. Записей в журнале: '
      '${emulator.journal.length}.',
    );
    await emulator.stop();
    exit(0);
  });
}

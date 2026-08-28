import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:telepos/hardware/printer/receipt_builder.dart';
import 'package:telepos/hardware/printer/wifi_printer.dart';

/// Транспорт сетевого принтера: повтор соединения и записи, честный `getStatus`.
///
/// Проверяется исход, который видит вызывающий, и байты, дошедшие до приёмника,
/// а не число вызовов: «повтор случился трижды» не доказывает, что вернувшийся
/// принтер получил чек.
void main() {
  /// Чек, который система действительно умеет произвести: те же байты ESC/POS и
  /// та же кодировка CP866, что уходят в принтер на живом пути.
  Uint8List receiptBytes() {
    return (ReceiptBuilder(charWidth: 32)
          ..init()
          ..addCentered('ТОО «Дүкен №2»', bold: true)
          ..addLeft('Кассаүй: Ысык-Көл')
          ..addLeft('Kassir: Toshkent')
          ..addRow('Сумма', '1 234.005')
          ..addLine()
          ..addRow('ИТОГО', '1 234.005', bold: true)
          ..addNewLines(2)
          ..cut())
        .build();
  }

  int indexOfSublist(List<int> haystack, List<int> needle) {
    if (needle.isEmpty || needle.length > haystack.length) return -1;
    for (var i = 0; i + needle.length <= haystack.length; i++) {
      var hit = true;
      for (var j = 0; j < needle.length; j++) {
        if (haystack[i + j] != needle[j]) {
          hit = false;
          break;
        }
      }
      if (hit) return i;
    }
    return -1;
  }

  int countSublist(List<int> haystack, List<int> needle) {
    var found = 0;
    var from = 0;
    while (from + needle.length <= haystack.length) {
      final at = indexOfSublist(haystack.sublist(from), needle);
      if (at < 0) break;
      found++;
      from += at + needle.length;
    }
    return found;
  }

  WifiPrinterManager managerFor(
    _FakeEndpoint endpoint, {
    Duration retryBudget = const Duration(milliseconds: 600),
    Duration timeout = const Duration(milliseconds: 100),
    Duration statusReplyTimeout = const Duration(milliseconds: 60),
  }) {
    return WifiPrinterManager(
      host: '10.0.0.7',
      connector: endpoint.connect,
      retryBackoff: const Duration(milliseconds: 10),
      retryBudget: retryBudget,
      timeout: timeout,
      statusReplyTimeout: statusReplyTimeout,
    );
  }

  group('Соединение', () {
    test('принтер, вернувшийся после двух отказов, получает чек целиком', () async {
      final endpoint = _FakeEndpoint(refuseFirst: 2);
      final printer = managerFor(endpoint);
      addTearDown(printer.disconnect);

      final connected = await printer.connect();

      expect(connected.success, isTrue, reason: 'отказ должен повторяться');
      expect(endpoint.connectAttempts, 3);

      final payload = receiptBytes();
      final printed = await printer.printReceipt(payload);

      expect(printed.success, isTrue);
      expect(endpoint.sockets.single.received, payload);
    });

    test('когда принтер не вернулся, результат называет причину, а попытки ограничены', () async {
      final endpoint = _FakeEndpoint(refuseAlways: true);
      final printer = managerFor(endpoint);
      addTearDown(printer.disconnect);

      final started = DateTime.now();
      final result = await printer.connect();
      final elapsed = DateTime.now().difference(started);

      expect(result.success, isFalse);
      expect(result.errorMessage, contains('Соединение отклонено'));
      expect(result.errorMessage, contains('10.0.0.7:9100'));
      expect(
        endpoint.connectAttempts,
        WifiPrinterManager.defaultMaxConnectAttempts,
        reason: 'число попыток ограничено и не крутится',
      );
      expect(elapsed, lessThan(const Duration(seconds: 2)));
    });

    test('сокет, который никогда не отвечает, не задерживает дольше бюджета', () async {
      final endpoint = _FakeEndpoint(neverAnswers: true);
      final printer = managerFor(
        endpoint,
        retryBudget: const Duration(milliseconds: 300),
        timeout: const Duration(milliseconds: 100),
      );
      addTearDown(printer.disconnect);

      final started = DateTime.now();
      final result = await printer.connect();
      final elapsed = DateTime.now().difference(started);

      expect(result.success, isFalse);
      expect(result.errorMessage, contains('таймаут'));
      expect(
        elapsed,
        lessThan(const Duration(milliseconds: 900)),
        reason: 'И30: повтор ограничен временем, а не только числом попыток',
      );
      expect(printer.connectAttemptsMade, lessThanOrEqualTo(3));
    });

    test('соединение, пришедшее после отказа ждать, закрывается, а не течёт', () async {
      final endpoint = _FakeEndpoint(lateBy: const Duration(milliseconds: 120));
      final printer = WifiPrinterManager(
        host: '10.0.0.7',
        connector: endpoint.connect,
        retryBackoff: const Duration(milliseconds: 5),
        retryBudget: const Duration(milliseconds: 120),
        timeout: const Duration(milliseconds: 20),
      );
      addTearDown(printer.disconnect);

      final result = await printer.connect();
      expect(result.success, isFalse);

      await Future<void>.delayed(const Duration(milliseconds: 250));

      expect(endpoint.sockets, isNotEmpty);
      for (final socket in endpoint.sockets) {
        expect(
          socket.closed,
          isTrue,
          reason: 'опоздавший сокет никому не принадлежит и должен быть закрыт',
        );
      }
    });

    test('нечисловой адрес отвергается до первой попытки соединения', () async {
      final endpoint = _FakeEndpoint();
      final printer = WifiPrinterManager(
        host: 'printer.local',
        connector: endpoint.connect,
      );
      addTearDown(printer.disconnect);

      final result = await printer.connect();

      expect(result.success, isFalse);
      expect(result.errorMessage, contains('Неверный IP адрес'));
      expect(endpoint.connectAttempts, 0);
    });

    test('нечисловой адрес отвергается и на пути повтора внутри записи', () async {
      final endpoint = _FakeEndpoint();
      final printer = WifiPrinterManager(
        host: 'printer.local',
        connector: endpoint.connect,
        retryBackoff: const Duration(milliseconds: 10),
        retryBudget: const Duration(milliseconds: 300),
      );
      addTearDown(printer.disconnect);

      final result = await printer.printReceipt(receiptBytes());

      expect(result.success, isFalse);
      expect(result.errorMessage, contains('Неверный IP адрес'));
      expect(
        endpoint.connectAttempts,
        0,
        reason: 'повтор не должен обходить проверку адреса',
      );
    });
  });

  group('Запись', () {
    test('запись в полуоткрытый сокет не выглядит успешной', () async {
      final endpoint = _FakeEndpoint(halfOpenAlways: true);
      final printer = managerFor(endpoint);
      addTearDown(printer.disconnect);

      final payload = receiptBytes();
      final started = DateTime.now();
      final result = await printer.printReceipt(payload);
      final elapsed = DateTime.now().difference(started);

      expect(
        result.success,
        isFalse,
        reason: 'принтер закрыл соединение — байты не напечатаны',
      );
      expect(result.bytesSent, isNull);
      expect(result.errorMessage, contains('10.0.0.7:9100'));
      expect(result.errorMessage, contains('ничего не отправлено'));
      for (final socket in endpoint.sockets) {
        expect(
          socket.received,
          isEmpty,
          reason: 'полуоткрытый сокет ничего не доставил',
        );
      }
      expect(
        endpoint.sockets.length,
        lessThanOrEqualTo(WifiPrinterManager.defaultMaxConnectAttempts),
        reason: 'число переподключений ограничено',
      );
      expect(elapsed, lessThan(const Duration(seconds: 2)));
    });

    test('принтер, оборвавший соединение до отправки, получает чек ровно один раз', () async {
      final endpoint = _FakeEndpoint(halfOpenFirst: 1);
      final printer = managerFor(endpoint);
      addTearDown(printer.disconnect);

      final payload = receiptBytes();
      final result = await printer.printReceipt(payload);

      expect(result.success, isTrue);
      expect(result.bytesSent, payload.length);
      expect(endpoint.sockets, hasLength(2));
      expect(endpoint.sockets.first.received, isEmpty);
      expect(endpoint.sockets.last.received, payload);

      final everything = <int>[
        for (final socket in endpoint.sockets) ...socket.received,
      ];
      expect(
        countSublist(everything, payload),
        1,
        reason: 'повтор не должен напечатать второй чек',
      );
    });

    test('оборванная на записи печать не отправляется второй раз (И29)', () async {
      final endpoint = _FakeEndpoint(
        closeDuringFlush: true,
        flushDelay: const Duration(milliseconds: 20),
      );
      final printer = managerFor(endpoint);
      addTearDown(printer.disconnect);

      final payload = receiptBytes();
      final result = await printer.printReceipt(payload);

      expect(result.success, isFalse);
      expect(
        result.errorMessage,
        contains('не подтверждена'),
        reason: 'неподтверждённая печать — не отказ и не успех, а неизвестность',
      );
      expect(
        endpoint.sockets,
        hasLength(1),
        reason:
            'байты уже отданы сокету — переподключаться и слать их снова '
            'значит напечатать хвост чека и следом целый',
      );

      final everything = <int>[
        for (final socket in endpoint.sockets) ...socket.received,
      ];
      expect(countSublist(everything, payload), 0);
    });

    test('печать не отдаёт сокет опросу состояния посреди чека', () async {
      // Реально достижимо сегодня: печать отправляется без ожидания
      // (payment_screen.dart:149), а кассир в это время жмёт «проверить принтер»
      // в настройках.
      final endpoint = _FakeEndpoint(
        flushDelay: const Duration(milliseconds: 150),
        throwOnStatusFlush: true,
      );
      final printer = managerFor(
        endpoint,
        statusReplyTimeout: const Duration(milliseconds: 400),
      );
      addTearDown(printer.disconnect);
      await printer.connect();

      final payload = receiptBytes();
      final printing = printer.printReceipt(payload);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      final status = await printer.getStatus();
      final printed = await printing;

      expect(
        printed.success,
        isTrue,
        reason: 'опрос состояния не имеет права рвать чек посередине',
      );
      expect(
        endpoint.sockets.single.received,
        payload,
        reason: 'чек дошёл целиком, а не обрывком',
      );
      expect(status.isReady, isFalse);
    });

    test('отключение принтера не рвёт чек посередине', () async {
      // Тот же путь, что и у опроса состояния, только кнопка другая: «отключить
      // принтер» в настройках (additional_screen.dart:274) нажата, пока летит
      // печать, отправленная без ожидания (payment_screen.dart:148-154).
      final endpoint = _FakeEndpoint(
        flushDelay: const Duration(milliseconds: 150),
      );
      final printer = managerFor(endpoint);
      await printer.connect();

      final payload = receiptBytes();
      final printing = printer.printReceipt(payload);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      final disconnecting = printer.disconnect();
      final printed = await printing;
      await disconnecting;

      expect(
        printed.success,
        isTrue,
        reason: 'кнопка «отключить» не имеет права рвать чек посередине',
      );
      expect(
        endpoint.sockets.single.received,
        payload,
        reason: 'чек дошёл целиком, а не обрывком',
      );
      expect(
        printer.isConnected,
        isFalse,
        reason: 'отключение всё-таки произошло, просто дождавшись своей очереди',
      );
      expect(endpoint.sockets.single.closed, isTrue);
    });

    test('вся запись укладывается в бюджет, а не в таймаут соединения', () async {
      final endpoint = _FakeEndpoint(flushNeverCompletes: true);
      final printer = WifiPrinterManager(
        host: '10.0.0.7',
        connector: endpoint.connect,
        retryBackoff: const Duration(milliseconds: 10),
        retryBudget: const Duration(milliseconds: 300),
        timeout: const Duration(milliseconds: 1500),
      );
      addTearDown(printer.disconnect);
      await printer.connect();

      final started = DateTime.now();
      final result = await printer.printReceipt(receiptBytes());
      final elapsed = DateTime.now().difference(started);

      expect(result.success, isFalse);
      expect(
        elapsed,
        lessThan(const Duration(milliseconds: 800)),
        reason:
            'И30: срок записи — бюджет (300 мс), а не таймаут соединения '
            '(1500 мс)',
      );
    });

    test('два чека подряд доходят целиком и в порядке отправки', () async {
      final endpoint = _FakeEndpoint();
      final printer = managerFor(endpoint);
      addTearDown(printer.disconnect);

      final first = receiptBytes();
      final second = (ReceiptBuilder(charWidth: 32)
            ..init()
            ..addCentered('ВОЗВРАТ')
            ..addRow('ИТОГО', '-0.005')
            ..cut())
          .build();

      expect((await printer.printReceipt(first)).success, isTrue);
      expect((await printer.printReceipt(second)).success, isTrue);

      final received = endpoint.sockets.single.received;
      expect(received, [...first, ...second]);
      expect(
        indexOfSublist(received, second),
        greaterThan(indexOfSublist(received, first)),
      );
    });
  });

  group('getStatus', () {
    test('без соединения — offline, а не ok', () async {
      final endpoint = _FakeEndpoint();
      final printer = managerFor(endpoint);
      addTearDown(printer.disconnect);

      final status = await printer.getStatus();

      expect(status.isReady, isFalse);
      expect(status.isOnline, isFalse);
      expect(endpoint.connectAttempts, 0);
    });

    test('принтер ответил «online, бумага есть» — только тогда ok', () async {
      final endpoint = _FakeEndpoint(statusReply: [0x12, 0x12]);
      final printer = managerFor(endpoint);
      addTearDown(printer.disconnect);
      await printer.connect();

      final status = await printer.getStatus();

      expect(status.isOnline, isTrue);
      expect(status.isPaperPresent, isTrue);
      expect(status.isCoverClosed, isTrue);
      expect(status.isReady, isTrue);
      expect(
        endpoint.sockets.single.received,
        [
          ...WifiPrinterManager.statusQueryPrinter,
          ...WifiPrinterManager.statusQueryPaper,
        ],
        reason: 'состояние спрашивается у принтера, а не у своего флага',
      );
    });

    test('принтер ответил «offline» — состояние не ok', () async {
      final endpoint = _FakeEndpoint(statusReply: [0x1A, 0x12]);
      final printer = managerFor(endpoint);
      addTearDown(printer.disconnect);
      await printer.connect();

      final status = await printer.getStatus();

      expect(status.isOnline, isFalse);
      expect(status.isReady, isFalse);
      expect(status.errorMessage, isNotNull);
    });

    test('принтер ответил «бумага кончилась» — не ok и сказано про бумагу', () async {
      final endpoint = _FakeEndpoint(statusReply: [0x12, 0x72]);
      final printer = managerFor(endpoint);
      addTearDown(printer.disconnect);
      await printer.connect();

      final status = await printer.getStatus();

      expect(status.isOnline, isTrue);
      expect(status.isPaperPresent, isFalse);
      expect(status.isReady, isFalse);
      expect(status.errorMessage, contains('бумага'));
    });

    test('молчащий принтер — состояние неизвестно, а не ok', () async {
      final endpoint = _FakeEndpoint();
      final printer = managerFor(endpoint);
      addTearDown(printer.disconnect);
      await printer.connect();

      final started = DateTime.now();
      final status = await printer.getStatus();
      final elapsed = DateTime.now().difference(started);

      expect(status.isReady, isFalse);
      expect(status.errorMessage, contains('неизвестно'));
      expect(
        elapsed,
        lessThan(const Duration(milliseconds: 800)),
        reason: 'опрос состояния ограничен по времени',
      );
    });

    test('незапрошенные ASB-пакеты не мешают прочитать ответ', () async {
      // Принтер с включённым ASB шлёт пакеты сам, когда ему вздумается. Их
      // первый байт отличается от ответа DLE EOT битом 1. Здесь ASB-пакет
      // сообщает «был offline» (бит 3) — принять его за ответ значит объявить
      // исправный принтер неисправным.
      final endpoint = _FakeEndpoint(
        statusReply: [0x12, 0x12],
        noiseBeforeReply: [0x18, 0x00, 0x00, 0x00],
      );
      final printer = managerFor(endpoint);
      addTearDown(printer.disconnect);
      await printer.connect();

      final status = await printer.getStatus();

      expect(
        status.isReady,
        isTrue,
        reason: 'ответ принтера пришёл, просто не первым',
      );
    });

    test('опрос состояния во время печати честно говорит, что не спрашивал', () async {
      final endpoint = _FakeEndpoint(
        statusReply: [0x12, 0x12],
        flushDelay: const Duration(milliseconds: 200),
      );
      final printer = managerFor(
        endpoint,
        statusReplyTimeout: const Duration(milliseconds: 40),
      );
      addTearDown(printer.disconnect);
      await printer.connect();

      final printing = printer.printReceipt(receiptBytes());
      await Future<void>.delayed(const Duration(milliseconds: 10));
      final status = await printer.getStatus();

      expect(status.isReady, isFalse);
      expect(status.errorCode, WifiPrinterManager.statusUnknownErrorCode);
      expect(status.errorMessage, contains('занят печатью'));
      expect((await printing).success, isTrue);
    });

    test('неизвестное состояние отличимо от поломки по errorCode', () async {
      final endpoint = _FakeEndpoint(statusReply: [0x1A, 0x12]);
      final printer = managerFor(endpoint);
      addTearDown(printer.disconnect);
      await printer.connect();

      final faulty = await printer.getStatus();

      expect(faulty.isReady, isFalse);
      expect(
        faulty.errorCode,
        isNot(WifiPrinterManager.statusUnknownErrorCode),
        reason: 'принтер ответил «offline» — это поломка, а не неизвестность',
      );

      final silent = managerFor(_FakeEndpoint());
      addTearDown(silent.disconnect);
      await silent.connect();

      final unknown = await silent.getStatus();

      expect(unknown.isReady, isFalse);
      expect(
        unknown.errorCode,
        WifiPrinterManager.statusUnknownErrorCode,
        reason: 'исправный принтер, который молчит, не должен читаться как '
            'сломанный',
      );
    });

    test('мусор вместо байта состояния не принимается за состояние', () async {
      final endpoint = _FakeEndpoint(statusReply: [0x00, 0x00]);
      final printer = managerFor(endpoint);
      addTearDown(printer.disconnect);
      await printer.connect();

      final status = await printer.getStatus();

      expect(status.isReady, isFalse);
      expect(status.errorMessage, contains('неизвестно'));
    });

    test('полуоткрытый сокет не отвечает ok', () async {
      final endpoint = _FakeEndpoint(statusReply: [0x12, 0x12]);
      final printer = managerFor(endpoint);
      addTearDown(printer.disconnect);
      await printer.connect();

      endpoint.sockets.single.dropPeer();
      await Future<void>.delayed(Duration.zero);

      final status = await printer.getStatus();

      expect(
        status.isReady,
        isFalse,
        reason: 'сокет, который больше нельзя использовать, не бывает ok',
      );
      expect(status.isOnline, isFalse);
    });
  });

  group('Ресурсы', () {
    test('disconnect закрывает сокет и снимает подписку', () async {
      final endpoint = _FakeEndpoint();
      final printer = managerFor(endpoint);
      await printer.connect();

      await printer.disconnect();

      final socket = endpoint.sockets.single;
      expect(socket.closed, isTrue);
      expect(socket.listenerCancelled, isTrue);
      expect(printer.isConnected, isFalse);
    });

    test('повторный connect не открывает второй сокет', () async {
      final endpoint = _FakeEndpoint();
      final printer = managerFor(endpoint);
      addTearDown(printer.disconnect);

      await printer.connect();
      await printer.connect();

      expect(endpoint.sockets, hasLength(1));
    });
  });
}

/// Приёмник вместо принтера: считает попытки соединения и хранит то, что до
/// него дошло. Отказ, полуоткрытый сокет и молчание задаются сценарием.
class _FakeEndpoint {
  _FakeEndpoint({
    this.refuseFirst = 0,
    this.refuseAlways = false,
    this.neverAnswers = false,
    this.halfOpenFirst = 0,
    this.halfOpenAlways = false,
    this.statusReply,
    this.noiseBeforeReply,
    this.lateBy,
    this.flushDelay,
    this.closeDuringFlush = false,
    this.flushNeverCompletes = false,
    this.throwOnStatusFlush = false,
  });

  final int refuseFirst;
  final bool refuseAlways;
  final bool neverAnswers;
  final int halfOpenFirst;
  final bool halfOpenAlways;
  final List<int>? statusReply;
  final List<int>? noiseBeforeReply;
  final Duration? flushDelay;
  final bool closeDuringFlush;
  final bool flushNeverCompletes;
  final bool throwOnStatusFlush;

  /// Соединение, которое устанавливается позже, чем его согласились ждать.
  final Duration? lateBy;

  int connectAttempts = 0;
  final List<_FakeSocket> sockets = [];

  Future<PrinterSocket> connect(
    String host,
    int port, {
    required Duration timeout,
  }) async {
    connectAttempts++;

    if (neverAnswers) {
      return Completer<PrinterSocket>().future;
    }
    if (refuseAlways || connectAttempts <= refuseFirst) {
      throw const SocketException('Соединение отклонено');
    }

    final halfOpen = halfOpenAlways || sockets.length < halfOpenFirst;
    final socket = _FakeSocket(
      halfOpen: halfOpen,
      statusReply: statusReply,
      noiseBeforeReply: noiseBeforeReply,
      flushDelay: flushDelay,
      closeDuringFlush: closeDuringFlush,
      flushNeverCompletes: flushNeverCompletes,
      throwOnStatusFlush: throwOnStatusFlush,
    );
    sockets.add(socket);

    final late = lateBy;
    if (late != null) {
      return Future<PrinterSocket>.delayed(late, () => socket);
    }
    return socket;
  }
}

/// Сокет с настоящей разницей между `close` и `destroy`: то, что отдано в
/// `add`, лежит в буфере и доходит до приёмника только на `flush`. Уничтоженный
/// сокет свой буфер теряет — ровно так рвётся чек, если кто-то закрыл сокет
/// посреди чужой записи.
class _FakeSocket implements PrinterSocket {
  _FakeSocket({
    required this.halfOpen,
    this.statusReply,
    this.noiseBeforeReply,
    this.flushDelay,
    this.closeDuringFlush = false,
    this.flushNeverCompletes = false,
    this.throwOnStatusFlush = false,
  }) {
    _controller = StreamController<Uint8List>(
      onCancel: () => listenerCancelled = true,
    );
    if (halfOpen) {
      // Принтер ушёл: соединение установлено, но его сторона уже закрыта.
      // Байты, отданные в такой сокет, исчезают, и это не видно из `add`.
      _controller.close();
    }
  }

  final bool halfOpen;
  final List<int>? statusReply;
  final List<int>? noiseBeforeReply;
  final Duration? flushDelay;
  final bool closeDuringFlush;
  final bool flushNeverCompletes;
  final bool throwOnStatusFlush;

  late final StreamController<Uint8List> _controller;

  final List<int> _pending = [];
  final List<int> received = [];
  bool destroyed = false;
  bool closed = false;
  bool listenerCancelled = false;
  bool _lastWriteWasStatusQuery = false;

  void dropPeer() {
    if (!_controller.isClosed) _controller.close();
  }

  bool _isStatusQuery(List<int> data) {
    return data.length == 6 && data[0] == 0x10 && data[1] == 0x04;
  }

  @override
  void add(List<int> data) {
    if (halfOpen || destroyed || _controller.isClosed) return;
    _lastWriteWasStatusQuery = _isStatusQuery(data);
    _pending.addAll(data);
    final reply = statusReply;
    if (reply != null && _lastWriteWasStatusQuery) {
      scheduleMicrotask(() {
        if (_controller.isClosed) return;
        final noise = noiseBeforeReply;
        if (noise != null) _controller.add(Uint8List.fromList(noise));
        _controller.add(Uint8List.fromList(reply));
      });
    }
  }

  @override
  Future<void> flush() async {
    if (throwOnStatusFlush && _lastWriteWasStatusQuery) {
      _pending.clear();
      throw const SocketException('Разрыв на опросе состояния');
    }
    if (flushNeverCompletes) return Completer<void>().future;

    final delay = flushDelay;
    if (delay != null) await Future<void>.delayed(delay);

    if (closeDuringFlush) {
      // Принтер закрыл свою сторону, пока байты были в пути: они пропали.
      _pending.clear();
      if (!_controller.isClosed) await _controller.close();
      return;
    }
    if (destroyed) {
      _pending.clear();
      return;
    }
    received.addAll(_pending);
    _pending.clear();
  }

  @override
  Future<void> close() async {
    // `_TcpPrinterSocket.close()` вызывает `destroy()`, а тот выбрасывает всё,
    // что не успело уйти.
    destroyed = true;
    closed = true;
    _pending.clear();
    if (!_controller.isClosed) await _controller.close();
  }

  @override
  Stream<Uint8List> get inbound => _controller.stream;
}

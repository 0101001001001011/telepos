import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:telepos/hardware/printer/printer_manager.dart';

/// Narrow view of the TCP connection to a network printer.
///
/// The transport needs four things from a socket: push bytes, wait until they
/// have left, notice that the peer went away, and read the printer's answer to
/// a real-time status query. Talking to `dart:io`'s [Socket] directly makes all
/// four untestable, so the seam is here and [_TcpPrinterSocket] is the only
/// implementation that touches the network.
abstract class PrinterSocket {
  void add(List<int> data);

  Future<void> flush();

  Future<void> close();

  /// Bytes coming back from the printer.
  ///
  /// `done` on this stream means the peer closed its side — the half-open case
  /// that used to be invisible until the next write silently vanished.
  Stream<Uint8List> get inbound;
}

typedef PrinterSocketConnector =
    Future<PrinterSocket> Function(
      String host,
      int port, {
      required Duration timeout,
    });

class _TcpPrinterSocket implements PrinterSocket {
  _TcpPrinterSocket(this._socket);

  final Socket _socket;

  @override
  void add(List<int> data) => _socket.add(data);

  @override
  Future<void> flush() => _socket.flush();

  @override
  Future<void> close() async {
    try {
      await _socket.close();
    } catch (_) {}
    try {
      _socket.destroy();
    } catch (_) {}
  }

  @override
  Stream<Uint8List> get inbound => _socket;
}

Future<PrinterSocket> connectTcpPrinterSocket(
  String host,
  int port, {
  required Duration timeout,
}) async {
  return _TcpPrinterSocket(await Socket.connect(host, port, timeout: timeout));
}

class WifiPrinterManager extends BufferedPrinterManager {
  WifiPrinterManager({
    required this.host,
    int? port,
    this.timeout = const Duration(seconds: 5),
    PrinterSocketConnector? connector,
    int? maxConnectAttempts,
    Duration? retryBackoff,
    Duration? retryBudget,
    Duration? statusReplyTimeout,
  }) : port = port ?? defaultPort,
       _connector = connector ?? connectTcpPrinterSocket,
       maxConnectAttempts = maxConnectAttempts ?? defaultMaxConnectAttempts,
       retryBackoff =
           retryBackoff ?? const Duration(milliseconds: retryBackoffMs),
       retryBudget = retryBudget ?? const Duration(milliseconds: retryBudgetMs),
       statusReplyTimeout =
           statusReplyTimeout ??
           const Duration(milliseconds: statusReplyTimeoutMs);

  static const int defaultPort = 9100;

  static const List<int> alternativePorts = [9100, 9200, 9300, 515];

  /// Connection attempts, and the delay between them.
  ///
  /// **Only the connection is retried.** A connect that failed has printed
  /// nothing, so trying it again cannot produce paper twice. A write that failed
  /// after the bytes were handed to the socket is a different animal: TCP cannot
  /// say how much of it reached the printer, so re-sending it is how a torn
  /// receipt gets a whole one printed after it. Job-level retry belongs to the
  /// queue, where the idempotency key lives (И29) — see [writeRaw].
  ///
  /// The shape follows the raw-USB path (`linux_printer.dart:284-317`): a
  /// bounded number of reconnect attempts with a fixed 400 ms pause. The pause
  /// is kept identical on purpose — a printer that is rebooting comes back on
  /// the same scale whatever the wire is. (That path allows `attempt <= 6`
  /// starting from `0`, i.e. seven attempts, not six.)
  ///
  /// The attempt *count* differs, deliberately: a serial reopen fails in
  /// microseconds, so seven of them cost nothing, while one TCP connect can sit
  /// on [timeout] (5 s by default) before it fails.
  static const int defaultMaxConnectAttempts = 3;

  static const int retryBackoffMs = 400;

  /// Wall-clock deadline for one public call — [connect] or [writeRaw] — that
  /// covers every attempt and every pause inside it.
  ///
  /// The number is chosen against the worst caller rather than by taste.
  /// `cash_operation_screen.dart:357` **awaits** printing after the money is
  /// already recorded, and `ReceiptPrintServiceImpl._print`
  /// (`receipt_print_service_impl.dart:968-978`) calls `connect()` and then
  /// `printReceipt()`, so that screen can wait two budgets. At 2.5 s that worst
  /// case is 5 s — no worse than the single 5 s connect this replaced. Raising
  /// the budget would quietly make an already-waiting screen wait longer.
  ///
  /// Consequence, named rather than hidden: against an address that swallows
  /// packets (no RST, no ICMP) one attempt fills the budget and there is no
  /// second try. Retries pay off where they were meant to — a printer that
  /// refuses fast because it is restarting — and there all attempts are used.
  static const int retryBudgetMs = 2500;

  /// How long the printer gets to answer a real-time status query.
  ///
  /// One second, not the 300 ms of the first round: a busy Wi-Fi link or a
  /// printer chewing through a long receipt can take that long to answer, and
  /// «unknown» arriving fast is worth nothing if it is wrong. A whole
  /// [getStatus] is bounded by twice this — once waiting for the socket to be
  /// free, once for the probe itself.
  static const int statusReplyTimeoutMs = 1000;

  /// [PrinterStatus.errorCode] on every answer that means «I do not know», as
  /// opposed to «the printer is broken».
  ///
  /// `PrinterStatus` has three booleans and no fourth state, and it lives in
  /// `printer_manager.dart`, which this task does not own. Until it grows one,
  /// this code is the machine-readable difference between «asked, got a fault»
  /// and «asked, got nothing» — so a screen can say «состояние неизвестно»
  /// instead of telling the operator a healthy printer is broken.
  static const int statusUnknownErrorCode = 1;

  /// ESC/POS real-time status queries (DLE EOT n). The printer answers these
  /// immediately, out of its print buffer, which is why they are safe to send
  /// on a connection that also carries receipts.
  ///
  /// `n = 1` — printer status: bit 3 set means offline.
  /// `n = 4` — paper roll sensor: bits 5 and 6 both set mean the paper ran out.
  static const List<int> statusQueryPrinter = [0x10, 0x04, 0x01];

  static const List<int> statusQueryPaper = [0x10, 0x04, 0x04];

  final String host;

  final int port;

  final Duration timeout;

  final int maxConnectAttempts;

  final Duration retryBackoff;

  final Duration retryBudget;

  final Duration statusReplyTimeout;

  final PrinterSocketConnector _connector;

  bool _isConnected = false;
  PrinterInfo? _printerInfo;
  PrinterSocket? _socket;
  StreamSubscription<Uint8List>? _inboundSubscription;
  bool _peerClosed = false;

  final List<int> _inbound = [];
  Completer<void>? _inboundWaiter;

  /// Held for the whole of [connect], [writeRaw] and [getStatus].
  ///
  /// Without it `getStatus` could `_dropSocket()` — which destroys the socket —
  /// while `writeRaw` was awaiting `flush()` on the very same socket, tearing a
  /// receipt in half. That is reachable today: printing is dispatched unawaited
  /// (`payment_screen.dart:149`) while the operator can press the check button
  /// in settings. The queue's single-writer rule (task 3) does not cover it,
  /// because `getStatus` never goes through the queue.
  ///
  /// It is a lock, not a queue: [getStatus] waits only briefly and then answers
  /// «busy, did not ask» rather than blocking. Printing never yields to a status
  /// probe (И30).
  Completer<void>? _socketLock;

  int _connectAttemptsMade = 0;

  /// How many connect attempts the last [connect] made. Diagnostics only — the
  /// transport never branches on it.
  int get connectAttemptsMade => _connectAttemptsMade;

  @override
  bool get isConnected => _isConnected && !_peerClosed;

  Duration _remaining(DateTime deadline) => deadline.difference(DateTime.now());

  Future<bool> _acquireSocket(Duration within) async {
    if (within <= Duration.zero) return false;
    final deadline = DateTime.now().add(within);
    while (_socketLock != null) {
      final left = _remaining(deadline);
      if (left <= Duration.zero) return false;
      try {
        await _socketLock!.future.timeout(left);
      } on TimeoutException {
        return false;
      }
    }
    _socketLock = Completer<void>();
    return true;
  }

  void _releaseSocket() {
    final lock = _socketLock;
    _socketLock = null;
    if (lock != null && !lock.isCompleted) lock.complete();

    if (_dropWhenFree) {
      _dropWhenFree = false;
      unawaited(disconnect());
    }
  }

  @override
  Future<PrinterConnectionResult> connect() async {
    final info = _printerInfo;
    if (isConnected && _socket != null && info != null) {
      return PrinterConnectionResult.ok(info);
    }

    final deadline = DateTime.now().add(retryBudget);
    if (!await _acquireSocket(retryBudget)) {
      return PrinterConnectionResult.error(
        'Принтер $host:$port занят другой операцией',
      );
    }

    try {
      // Someone may have connected while we waited for the socket.
      final ready = _printerInfo;
      if (isConnected && _socket != null && ready != null) {
        return PrinterConnectionResult.ok(ready);
      }
      return await _connectWithin(deadline);
    } finally {
      _releaseSocket();
    }
  }

  Future<PrinterConnectionResult> _connectWithin(DateTime deadline) async {
    // Checked here and not only in [connect] so that the reconnect inside
    // [writeRaw] obeys the same rule: an address the transport refuses to dial
    // must be refused on every path into it, retries included.
    if (!_isValidIp(host)) {
      return PrinterConnectionResult.error('Неверный IP адрес: $host');
    }

    await _dropSocket();
    _connectAttemptsMade = 0;

    Object? lastError = 'причина неизвестна';

    for (var attempt = 1; attempt <= maxConnectAttempts; attempt++) {
      final left = deadline.difference(DateTime.now());
      if (left <= Duration.zero) break;

      _connectAttemptsMade = attempt;
      final attemptTimeout = left < timeout ? left : timeout;

      // The deadline is enforced here rather than left to the connector: a
      // connector that never completes must not be able to hold the caller,
      // whatever it promises about its own timeout.
      final pending = _connector(host, port, timeout: attemptTimeout);

      try {
        final socket = await pending.timeout(attemptTimeout);
        _attach(socket);
        _printerInfo = PrinterInfo(
          name: 'Wi-Fi Printer',
          address: '$host:$port',
          model: 'Network ESC/POS',
          paperWidth: 58,
        );
        return PrinterConnectionResult.ok(_printerInfo!);
      } on SocketException catch (e) {
        lastError = e.message.isEmpty ? e : e.message;
      } on TimeoutException {
        lastError = 'таймаут ${attemptTimeout.inMilliseconds} мс';
        // The connect can still land after we stopped waiting for it; close the
        // late socket instead of leaking a connection nobody owns.
        pending
            .then<void>((late) => late.close(), onError: (Object _) {})
            .ignore();
      } catch (e) {
        lastError = e;
      }

      if (attempt >= maxConnectAttempts) break;
      if (!await _pauseBefore(deadline)) break;
    }

    _isConnected = false;
    return PrinterConnectionResult.error(
      'Не удалось подключиться к $host:$port '
      '(попыток: $_connectAttemptsMade из $maxConnectAttempts) - $lastError',
    );
  }

  /// Waits [retryBackoff], or the rest of the budget if that is shorter.
  /// Returns `false` when the budget is spent and the loop must stop.
  Future<bool> _pauseBefore(DateTime deadline) async {
    final left = deadline.difference(DateTime.now());
    if (left <= Duration.zero) return false;
    await Future<void>.delayed(left < retryBackoff ? left : retryBackoff);
    return deadline.difference(DateTime.now()) > Duration.zero;
  }

  void _attach(PrinterSocket socket) {
    _socket = socket;
    _peerClosed = false;
    _isConnected = true;
    _inbound.clear();
    _inboundSubscription = socket.inbound.listen(
      (chunk) {
        _inbound.addAll(chunk);
        _wakeInboundWaiter();
      },
      onError: (Object _) => _markPeerGone(),
      onDone: _markPeerGone,
      cancelOnError: false,
    );
  }

  void _markPeerGone() {
    _peerClosed = true;
    _isConnected = false;
    _wakeInboundWaiter();
  }

  void _wakeInboundWaiter() {
    final waiter = _inboundWaiter;
    if (waiter != null && !waiter.isCompleted) waiter.complete();
  }

  /// Detaches and destroys the current socket. **Only the holder of
  /// [_socketLock] may call this** — destroying a socket that another call is
  /// writing to is exactly the torn receipt the lock exists to prevent.
  Future<void> _dropSocket() async {
    final socket = _socket;
    final subscription = _inboundSubscription;
    _socket = null;
    _inboundSubscription = null;
    _isConnected = false;
    _peerClosed = false;
    _inbound.clear();
    _wakeInboundWaiter();
    try {
      await subscription?.cancel();
    } catch (_) {}
    // The close is not awaited: the socket is already detached, nothing depends
    // on it finishing, and a close that hangs would otherwise hold the lock and
    // with it the printer.
    socket?.close().then<void>((_) {}, onError: (Object _) {}).ignore();
  }

  /// How long a caller must be prepared to wait for the socket to come free.
  ///
  /// Every holder bounds itself: [writeRaw] and [connect] by [retryBudget],
  /// [getStatus] by twice [statusReplyTimeout]. This is the sum, so a wait of
  /// this length always ends in acquiring the lock rather than giving up.
  Duration get _socketWaitCeiling => retryBudget + statusReplyTimeout * 2;

  /// Set when [disconnect] could not take the socket. The holder performs the
  /// drop when it releases; nobody ever destroys a socket they do not own.
  bool _dropWhenFree = false;

  @override
  Future<void> disconnect() async {
    // Waiting is not optional here. The button is pressed while a print
    // dispatched unawaited (`payment_screen.dart:148-154`) may be in flight, and
    // destroying that socket tears the receipt in half — the same mechanism the
    // lock was added for. The wait is the ceiling above, so under any holder
    // that respects its own deadline this acquires rather than gives up.
    if (!await _acquireSocket(_socketWaitCeiling)) {
      // Defence in depth for a holder that overran its own deadline: hand the
      // drop to whoever holds the socket instead of shredding a half-printed
      // receipt to honour a button.
      _dropWhenFree = true;
      return;
    }

    try {
      await _dropSocket();
      _printerInfo = null;
    } finally {
      _releaseSocket();
    }
  }

  @override
  Future<PrinterStatus> getStatus() async {
    if (!_isConnected || _socket == null || _peerClosed) {
      return PrinterStatus.offline;
    }

    // Never take the socket away from a receipt that is being written: wait
    // briefly, and if the printer is busy say so instead of interfering.
    if (!await _acquireSocket(statusReplyTimeout)) {
      return _unknown(
        'принтер $host:$port занят печатью — состояние не спрашивали',
      );
    }

    try {
      return await _probeStatus();
    } finally {
      _releaseSocket();
    }
  }

  Future<PrinterStatus> _probeStatus() async {
    final socket = _socket;
    if (!_isConnected || socket == null || _peerClosed) {
      return PrinterStatus.offline;
    }

    final deadline = DateTime.now().add(statusReplyTimeout);
    _inbound.clear();

    try {
      socket.add([...statusQueryPrinter, ...statusQueryPaper]);
      await socket.flush().timeout(_remaining(deadline));
    } on TimeoutException {
      return _unknown(
        'принтер $host:$port не принял запрос состояния за '
        '${statusReplyTimeout.inMilliseconds} мс',
      );
    } catch (e) {
      await _dropSocket();
      return PrinterStatus(
        isOnline: false,
        isPaperPresent: false,
        isCoverClosed: false,
        errorMessage: 'Принтер $host:$port недоступен: $e',
      );
    }

    if (_peerClosed) {
      await _dropSocket();
      return const PrinterStatus(
        isOnline: false,
        isPaperPresent: false,
        isCoverClosed: false,
        errorMessage: 'Соединение с принтером закрыто с той стороны',
      );
    }

    final (reply, sawOtherBytes) = await _readStatusBytes(2, deadline);

    if (reply.isEmpty) {
      return _unknown(
        sawOtherBytes
            ? 'принтер $host:$port прислал байты, но ни один из них не является '
                  'ответом DLE EOT'
            : 'принтер $host:$port не ответил на запрос состояния за '
                  '${statusReplyTimeout.inMilliseconds} мс',
      );
    }

    // DLE EOT 1, bit 3: set means the printer is offline. A printer whose cover
    // is open, whose paper ran out or which hit an error reports itself offline,
    // so «online» is what licenses the claim that the cover is closed; the cover
    // is never asserted on the strength of nothing.
    final online = (reply.first & 0x08) == 0;

    if (reply.length < 2 || !_isRealTimeStatusByte(reply[1])) {
      return PrinterStatus(
        isOnline: online,
        isPaperPresent: false,
        isCoverClosed: online,
        errorMessage:
            'Принтер $host:$port сообщил состояние, но не ответил про бумагу — '
            'наличие бумаги неизвестно',
      );
    }

    // DLE EOT 4, bits 5 and 6: both set means the paper roll has ended.
    final paperPresent = (reply[1] & 0x60) != 0x60;

    return PrinterStatus(
      isOnline: online,
      isPaperPresent: paperPresent,
      isCoverClosed: online,
      errorMessage: online
          ? (paperPresent ? null : 'В принтере закончилась бумага')
          : 'Принтер сообщает, что он offline (крышка, бумага или ошибка)',
    );
  }

  /// The honest answer when the connection is alive but the printer said
  /// nothing: not `ok`, and the message says the state is unknown rather than
  /// naming a fault that was never observed.
  PrinterStatus _unknown(String why) {
    return PrinterStatus(
      isOnline: false,
      isPaperPresent: false,
      isCoverClosed: false,
      errorCode: statusUnknownErrorCode,
      errorMessage: 'Состояние принтера неизвестно: $why',
    );
  }

  /// A `DLE EOT` answer has bits 0 and 7 clear and bits 1 and 4 set.
  ///
  /// This is also what separates it from an unsolicited ASB packet, whose first
  /// byte has bit 1 clear: a printer with ASB switched on can push status
  /// packets at any moment, and taking the first byte that arrives as the answer
  /// would report a healthy printer as unknown.
  static bool _isRealTimeStatusByte(int b) => (b & 0x93) == 0x12;

  /// Collects up to [wanted] real answers, dropping anything that is not one.
  /// The second element of the result says whether other bytes did arrive —
  /// «the printer said nothing» and «the printer said something we cannot read»
  /// are different diagnoses and must not share a message.
  Future<(List<int>, bool)> _readStatusBytes(
    int wanted,
    DateTime deadline,
  ) async {
    final found = <int>[];
    var sawOtherBytes = false;

    while (found.length < wanted && !_peerClosed) {
      for (final byte in _inbound) {
        if (_isRealTimeStatusByte(byte)) {
          if (found.length < wanted) found.add(byte);
        } else {
          sawOtherBytes = true;
        }
      }
      _inbound.clear();
      if (found.length >= wanted) break;

      final left = _remaining(deadline);
      if (left <= Duration.zero) break;
      final waiter = Completer<void>();
      _inboundWaiter = waiter;
      try {
        await waiter.future.timeout(left);
      } on TimeoutException {
        break;
      } finally {
        _inboundWaiter = null;
      }
    }

    return (found, sawOtherBytes);
  }

  /// Hands [data] to the printer **at most once**.
  ///
  /// The connection may be retried as often as the budget allows, because a
  /// connection that failed has printed nothing. The payload may not: once
  /// `add` has been called, TCP cannot tell how many of those bytes reached the
  /// paper, and re-sending them prints the tail of a receipt and then a whole
  /// one. So a write that failed after the bytes went out is reported, not
  /// repeated — repeating whole jobs is the queue's business, because that is
  /// where the idempotency key lives (И29).
  ///
  /// «Before any byte was committed» is decided by a fail-fast check, not by a
  /// promise the network can keep; see the comment on it below.
  ///
  /// Every path returns inside [retryBudget]: the socket wait, the connect
  /// attempts and the flush all share one deadline, and when nothing is left the
  /// call ends without sending rather than falling back to [timeout].
  @override
  Future<PrintResult> writeRaw(Uint8List data) async {
    final deadline = DateTime.now().add(retryBudget);

    if (!await _acquireSocket(retryBudget)) {
      return PrintResult.error(
        'Не удалось напечатать на $host:$port - принтер занят другой '
        'операцией; ничего не отправлено',
      );
    }

    try {
      // Nothing has been handed to a socket yet, so re-connecting here is free
      // of the duplicate-print risk: this retries the *connection*.
      for (var attempt = 1; ; attempt++) {
        if (!_isConnected || _socket == null || _peerClosed) {
          final connection = await _connectWithin(deadline);
          if (!connection.success) {
            return PrintResult.error(
              'Не удалось напечатать на $host:$port - '
              '${connection.errorMessage}',
            );
          }
        }

        // One turn of the event loop, so that a FIN which has *already arrived*
        // is seen before the bytes are committed.
        //
        // This is fail-fast detection, not a guarantee, and the difference
        // matters to whoever reads this next: a real peer's FIN travels at
        // network speed, so a printer that dies a millisecond later will not be
        // caught here and the bytes will go out. Nothing is lost by that — the
        // post-flush check below reports the write unconfirmed, and since the
        // payload is never re-sent the outcome is the same either way. What this
        // buys is the common case: a socket that was already dead when we picked
        // it up costs nothing and gets no bytes.
        await Future<void>.delayed(Duration.zero);
        if (!_peerClosed) break;

        await _dropSocket();
        if (attempt >= maxConnectAttempts ||
            _remaining(deadline) <= Duration.zero) {
          return PrintResult.error(
            'Не удалось напечатать на $host:$port - принтер закрывает '
            'соединение сразу после подключения; ничего не отправлено',
          );
        }
      }

      final socket = _socket;
      if (socket == null) {
        return PrintResult.error(
          'Не удалось напечатать на $host:$port - соединения нет',
        );
      }

      final left = _remaining(deadline);
      if (left <= Duration.zero) {
        return PrintResult.error(
          'Не удалось напечатать на $host:$port - срок '
          '${retryBudget.inMilliseconds} мс истёк на подключении; '
          'ничего не отправлено',
        );
      }

      try {
        socket.add(data);
        await socket.flush().timeout(left);

        // A peer that closed its side takes the bytes into a socket buffer and
        // drops them: `add` and `flush` both succeed and nothing is printed.
        // Awaiting the flush gives a FIN that is already in flight a turn to
        // arrive, so this check is what keeps a half-open socket from being
        // reported as a successful print.
        if (_peerClosed) {
          await _dropSocket();
          return PrintResult.error(
            'Печать на $host:$port не подтверждена - соединение закрыто '
            'принтером во время записи. Повторяет задание очередь, транспорт '
            'второй раз тот же чек не отправляет',
          );
        }
        return PrintResult.ok(bytesSent: data.length);
      } on SocketException catch (e) {
        await _dropSocket();
        return PrintResult.error(
          'Печать на $host:$port не подтверждена - ошибка сети: ${e.message}',
        );
      } on TimeoutException {
        await _dropSocket();
        return PrintResult.error(
          'Печать на $host:$port не подтверждена - принтер не принял данные за '
          '${left.inMilliseconds} мс',
        );
      } catch (e) {
        await _dropSocket();
        return PrintResult.error(
          'Печать на $host:$port не подтверждена - $e',
        );
      }
    } finally {
      _releaseSocket();
    }
  }

  bool _isValidIp(String ip) {
    try {
      InternetAddress(ip);
      return true;
    } catch (_) {
      return false;
    }
  }
}

class WifiPrinterScanner {
  WifiPrinterScanner._();

  static const int hostTimeoutMs = 100;

  static Stream<WifiPrinterInfo> scan({
    required String subnet,
    int startIp = 1,
    int endIp = 254,
    int port = WifiPrinterManager.defaultPort,
  }) async* {
    for (var i = startIp; i <= endIp; i++) {
      final host = '$subnet.$i';

      try {
        final socket = await Socket.connect(
          host,
          port,
          timeout: Duration(milliseconds: hostTimeoutMs),
        );

        await socket.close();

        yield WifiPrinterInfo(host: host, port: port);
      } on SocketException {
      } catch (_) {}
    }
  }

  static Future<bool> checkAvailability(String host, {int? port}) async {
    try {
      final socket = await Socket.connect(
        host,
        port ?? WifiPrinterManager.defaultPort,
        timeout: Duration(milliseconds: hostTimeoutMs * 3),
      );
      await socket.close();
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<String?> getDeviceSubnet() async {
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
      );

      for (final interface in interfaces) {
        for (final addr in interface.addresses) {
          final ip = addr.address;
          if (ip.startsWith('127.')) continue;

          final parts = ip.split('.');
          if (parts.length == 4) {
            return '${parts[0]}.${parts[1]}.${parts[2]}';
          }
        }
      }
    } catch (_) {}
    return null;
  }
}

class WifiPrinterInfo {
  const WifiPrinterInfo({
    required this.host,
    required this.port,
    this.name,
    this.model,
  });

  final String host;

  final int port;

  final String? name;

  final String? model;

  String get address => '$host:$port';

  @override
  String toString() => 'WifiPrinterInfo($address)';
}

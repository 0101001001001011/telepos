import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'kaspi_pos_config.dart';
import 'payment_terminal_journal.dart';

class KaspiPosService {
  KaspiPosService({KaspiPosConfig? config, PaymentTerminalJournal? journal})
    : _config = config ?? const KaspiPosConfig(),
      _journal = journal ?? PaymentTerminalJournal.shared;

  KaspiPosConfig _config;

  /// Куда пишутся обмены для экрана диагностики.
  ///
  /// Умолчание — общий на процесс журнал, и это не недосмотр: служба
  /// создаётся заново на каждую операцию тремя разными местами, ни одно из
  /// которых не достаёт сотрудников из контейнера. Довод целиком — на
  /// [PaymentTerminalJournal].
  final PaymentTerminalJournal _journal;

  final _statusController = StreamController<KaspiPosStatus>.broadcast();

  KaspiPosStatus _status = KaspiPosStatus.disconnected;
  Socket? _socket;
  StreamSubscription<Uint8List>? _socketSubscription;

  final _responseBuffer = <int>[];

  Completer<Uint8List>? _pendingResponse;

  KaspiPosConfig get config => _config;

  KaspiPosStatus get status => _status;

  Stream<KaspiPosStatus> get statusStream => _statusController.stream;

  bool get isConnected => _status == KaspiPosStatus.connected;

  void updateConfig(KaspiPosConfig config) {
    _config = config;
  }

  Future<KaspiPosTestResult> testConnection() async {
    if (!_config.isValid) {
      return KaspiPosTestResult.failure('Invalid configuration');
    }

    _updateStatus(KaspiPosStatus.connecting);

    try {
      final stopwatch = Stopwatch()..start();

      final socket = await Socket.connect(
        _config.host,
        _config.port,
        timeout: Duration(milliseconds: _config.timeoutMs),
      );
      await socket.close();

      stopwatch.stop();

      _updateStatus(KaspiPosStatus.connected);
      return KaspiPosTestResult.success(
        latencyMs: stopwatch.elapsedMilliseconds,
        terminalInfo: 'Kaspi POS @ ${_config.address}',
      );
    } on SocketException catch (e) {
      _updateStatus(KaspiPosStatus.error);
      return KaspiPosTestResult.failure(
        'Не удалось подключиться: ${e.message}',
      );
    } on TimeoutException {
      _updateStatus(KaspiPosStatus.error);
      return KaspiPosTestResult.failure(
        'Таймаут подключения (${_config.timeoutMs}ms)',
      );
    } catch (e) {
      _updateStatus(KaspiPosStatus.error);
      return KaspiPosTestResult.failure('Ошибка: $e');
    }
  }

  Future<bool> connect() async {
    if (!_config.enabled || !_config.isValid) {
      return false;
    }

    if (_socket != null && isConnected) return true;

    _updateStatus(KaspiPosStatus.connecting);

    try {
      _socket = await Socket.connect(
        _config.host,
        _config.port,
        timeout: Duration(milliseconds: _config.timeoutMs),
      );

      _socketSubscription = _socket!.listen(
        _onDataReceived,
        onError: _onSocketError,
        onDone: _onSocketDone,
      );

      _updateStatus(KaspiPosStatus.connected);
      return true;
    } on SocketException catch (e) {
      _updateStatus(KaspiPosStatus.error);
      _socket = null;
      throw Exception('Kaspi POS connection failed: ${e.message}');
    } catch (e) {
      _updateStatus(KaspiPosStatus.error);
      _socket = null;
      return false;
    }
  }

  Future<void> disconnect() async {
    await _socketSubscription?.cancel();
    _socketSubscription = null;
    await _socket?.close();
    _socket = null;
    _responseBuffer.clear();
    _failPending(const SocketException('Disconnected'));
    _updateStatus(KaspiPosStatus.disconnected);
  }

  /// Отказать ждущему ответу — **только если он ещё ждёт**.
  ///
  /// Задача 26, найдено живой пробой возврата на эмуляторе: `_onDataReceived`
  /// исполняет обещание и не обнуляет его, так что после **любого удачного**
  /// обмена `disconnect` бросал `Bad state: Future already completed`.
  /// Разговор, закрываемый в `finally`, падал после того, как терминал уже
  /// провёл деньги.
  void _failPending(Object error) {
    final pending = _pendingResponse;
    _pendingResponse = null;
    if (pending != null && !pending.isCompleted) pending.completeError(error);
  }

  /// Один разговор с терминалом — и **единственное место, где он
  /// записывается**.
  ///
  /// Через него проходит каждый кадр: покупка, сторно, возврат, — и каждый
  /// исход: ответ, тайм-аут, обрыв, отказ соединения. Запись выше по течению
  /// (в `requestPayment` и `requestRefund` порознь) пропустила бы сторно и
  /// разошлась бы по веткам отказа; запись ниже по течению невозможна —
  /// ниже только сокет.
  ///
  /// Разбор ответа для журнала делается **тем же** `_parsePurchaseResponse`,
  /// которым продукт принимает решение о деньгах: функция чистая, второй
  /// вызов ничего не меняет, а второй раскладки не появляется. Именно на
  /// второй раскладке в этом проекте однажды разошлись предпросмотр чека и
  /// бумага.
  Future<Uint8List> _sendAndReceive(
    List<int> data, {
    Duration timeout = const Duration(seconds: 30),
  }) async {
    if (_socket == null || !isConnected) {
      _note(data, null, 'к терминалу нет соединения');
      throw const SocketException('Not connected to Kaspi POS');
    }

    _responseBuffer.clear();
    _pendingResponse = Completer<Uint8List>();

    _socket!.add(data);
    await _socket!.flush();

    try {
      final reply = await _pendingResponse!.future.timeout(
        timeout,
        onTimeout: () {
          _pendingResponse = null;
          throw TimeoutException('No response from terminal', timeout);
        },
      );
      _note(data, reply, null);
      return reply;
    } on TimeoutException {
      _note(data, null, 'терминал не ответил за ${timeout.inSeconds} с');
      rethrow;
    } on Object catch (e) {
      // Текст исключения в журнал диагностики идёт намеренно: его читает
      // наладчик, а не покупатель, и «связь оборвана» без причины —
      // ровно то, ради чего эту вкладку и просили.
      _note(data, null, 'обмен не состоялся: $e');
      rethrow;
    }
  }

  /// Записать обмен. Кадр разбирается так же, как его разбирает продукт.
  void _note(List<int> request, Uint8List? response, String? failure) {
    final frame = _frameText(request);
    KaspiPaymentResult? parsed;
    if (response != null) parsed = _parsePurchaseResponse(response);
    _journal.record(
      PaymentTerminalExchange(
        at: DateTime.now(),
        operation: PaymentTerminalOperation.ofFrame(frame),
        request: frame,
        address: _config.address,
        response: response == null ? null : _frameText(response),
        approved: parsed?.success ?? false,
        approvalCode: parsed?.approvalCode,
        transactionId: parsed?.transactionId,
        refusal:
            failure ??
            (parsed?.success == false
                ? (parsed?.errorMessage ?? 'терминал отказал без причины')
                : null),
      ),
    );
  }

  /// Текст кадра между `STX` и `ETX` — **UTF-8 с допуском на порчу**, тем же
  /// способом, что [_tail]: русский текст отказа, прочитанный побайтно,
  /// доезжает до глаз как `ÐÐ¢ÐÐÐ` (измерено эмулятором).
  static String _frameText(List<int> frame) => utf8.decode(
    // 0x02 STX, 0x03 ETX — те же числа, что собирает `_buildPurchaseCommand`.
    frame.where((b) => b != 0x02 && b != 0x03).toList(),
    allowMalformed: true,
  );

  void _onDataReceived(Uint8List data) {
    _responseBuffer.addAll(data);

    if (_pendingResponse != null && !_pendingResponse!.isCompleted) {
      _pendingResponse!.complete(Uint8List.fromList(_responseBuffer));
      _responseBuffer.clear();
    }
  }

  void _onSocketError(Object error) {
    _updateStatus(KaspiPosStatus.error);
    _failPending(error);
  }

  void _onSocketDone() {
    _socket = null;
    _socketSubscription = null;
    _updateStatus(KaspiPosStatus.disconnected);
    _failPending(const SocketException('Connection closed by terminal'));
  }

  Future<KaspiPaymentResult> requestPayment({
    required int amountKopeiki,
    required String receiptNo,
  }) async {
    if (!isConnected) {
      final connected = await connect();
      if (!connected) {
        return KaspiPaymentResult.failure(
          'Не удалось подключиться к терминалу',
        );
      }
    }

    try {
      final command = _buildPurchaseCommand(amountKopeiki, receiptNo);

      final response = await _sendAndReceive(
        command,
        timeout: const Duration(seconds: 60),
      );

      return _parsePurchaseResponse(response);
    } on TimeoutException {
      return KaspiPaymentResult.failure('Таймаут ожидания ответа от терминала');
    } on SocketException catch (e) {
      _updateStatus(KaspiPosStatus.error);
      return KaspiPaymentResult.failure('Ошибка связи: ${e.message}');
    } catch (e) {
      return KaspiPaymentResult.failure('Ошибка: $e');
    }
  }

  /// Возврат покупки по транзакции — задача 26.
  ///
  /// **Кадр нашего изобретения**, как и коды отказа эмулятора: протокола
  /// возврата Kaspi POS у нас нет. Форма —
  /// `'4' + сумма(12) + транзакция + '|' + ключ возврата`. Ключ повторяется
  /// при повторе того же возврата: терминал по нему отдаёт прежний ответ, а
  /// не возвращает деньги второй раз. Разбор ответа — тот же, что у покупки:
  /// первый байт `0x30` — успех, всё остальное — отказ с текстом.
  ///
  /// Не бросает: обрыв связи и тайм-аут — отказ значением.
  Future<KaspiPaymentResult> requestRefund({
    required int amountKopeiki,
    required String transactionId,
    required String refundKey,
  }) async {
    try {
      if (!isConnected && !await connect()) {
        return KaspiPaymentResult.failure(
          'Не удалось подключиться к терминалу',
        );
      }
      final amountStr = amountKopeiki.toString().padLeft(12, '0');
      final payload = '4$amountStr$transactionId|$refundKey';
      final response = await _sendAndReceive([
        0x02,
        ...utf8.encode(payload),
        0x03,
      ], timeout: const Duration(seconds: 60));
      return _parsePurchaseResponse(response);
    } on TimeoutException {
      return KaspiPaymentResult.failure('Таймаут ожидания ответа от терминала');
    } on SocketException catch (e) {
      _updateStatus(KaspiPosStatus.error);
      return KaspiPaymentResult.failure('Ошибка связи: ${e.message}');
    } catch (e) {
      return KaspiPaymentResult.failure('Ошибка: $e');
    }
  }

  Future<bool> cancelTransaction() async {
    if (!isConnected) return false;

    try {
      final command = _buildReversalCommand();
      final response = await _sendAndReceive(
        command,
        timeout: const Duration(seconds: 30),
      );
      return _isSuccessResponse(response);
    } catch (_) {
      return false;
    }
  }

  List<int> _buildPurchaseCommand(int amountKopeiki, String receiptNo) {
    final amountStr = amountKopeiki.toString().padLeft(12, '0');
    final receiptStr = receiptNo.padLeft(6, '0');
    final payload = '1$amountStr$receiptStr';
    return [0x02, ...payload.codeUnits, 0x03];
  }

  List<int> _buildReversalCommand() {
    return [0x02, ...('3').codeUnits, 0x03];
  }

  KaspiPaymentResult _parsePurchaseResponse(Uint8List response) {
    if (response.isEmpty) {
      return KaspiPaymentResult.failure('Пустой ответ от терминала');
    }

    final payload = response.where((b) => b != 0x02 && b != 0x03).toList();
    if (payload.isEmpty) {
      return KaspiPaymentResult.failure('Некорректный ответ');
    }

    final resultCode = payload[0];
    if (resultCode == 0x30) {
      final dataStr = _tail(payload);
      final transactionId = dataStr.length >= 12
          ? dataStr.substring(0, 12).trim()
          : '';
      final approvalCode = dataStr.length >= 18
          ? dataStr.substring(12, 18).trim()
          : '';

      return KaspiPaymentResult.success(
        transactionId: transactionId.isNotEmpty
            ? transactionId
            : 'KP${DateTime.now().millisecondsSinceEpoch}',
        approvalCode: approvalCode.isNotEmpty ? approvalCode : '000000',
        cardMask: dataStr.length >= 34
            ? dataStr.substring(18, 34).trim()
            : null,
      );
    } else {
      final errorMsg = _tail(payload).trim();
      return KaspiPaymentResult.failure(
        errorMsg.isNotEmpty ? errorMsg : 'Отказ терминала (код: $resultCode)',
        errorCode: resultCode.toString(),
      );
    }
  }

  /// Хвост ответа после кода результата — **UTF-8**, а не побайтно.
  ///
  /// Было `String.fromCharCodes(payload.skip(1))`: каждый байт — отдельный
  /// символ latin1, и русский текст отказа доезжал до кассира как
  /// `ÐÐ¢ÐÐÐ` (измерено эмулятором). ASCII-поля ответа (номер транзакции,
  /// код авторизации, маска карты) UTF-8 читает без изменений, поэтому
  /// смещения 12/18/34 остаются верными. Кодировку настоящего терминала мы
  /// не измеряли — вопрос наружу; битые байты не бросают, а видны `�`.
  static String _tail(List<int> payload) =>
      utf8.decode(payload.sublist(1), allowMalformed: true);

  bool _isSuccessResponse(Uint8List response) {
    final payload = response.where((b) => b != 0x02 && b != 0x03).toList();
    return payload.isNotEmpty && payload[0] == 0x30;
  }

  void _updateStatus(KaspiPosStatus newStatus) {
    _status = newStatus;
    if (!_statusController.isClosed) {
      _statusController.add(newStatus);
    }
  }

  void dispose() {
    disconnect();
    _statusController.close();
  }
}

class KaspiPaymentResult {
  const KaspiPaymentResult({
    required this.success,
    this.transactionId,
    this.approvalCode,
    this.cardMask,
    this.errorCode,
    this.errorMessage,
  });

  final bool success;
  final String? transactionId;
  final String? approvalCode;
  final String? cardMask;
  final String? errorCode;
  final String? errorMessage;

  factory KaspiPaymentResult.success({
    required String transactionId,
    required String approvalCode,
    String? cardMask,
  }) {
    return KaspiPaymentResult(
      success: true,
      transactionId: transactionId,
      approvalCode: approvalCode,
      cardMask: cardMask,
    );
  }

  factory KaspiPaymentResult.failure(String errorMessage, {String? errorCode}) {
    return KaspiPaymentResult(
      success: false,
      errorCode: errorCode,
      errorMessage: errorMessage,
    );
  }
}

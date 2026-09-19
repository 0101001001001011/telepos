import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:talker/talker.dart';

typedef WebKassaHttpSend =
    Future<WebKassaRawResponse> Function(
      Uri uri,
      Map<String, String> headers,
      String body,
    );

class WebKassaRawResponse {
  const WebKassaRawResponse({required this.statusCode, required this.body});

  final int statusCode;
  final String body;
}

class WebKassaApiClient {
  WebKassaApiClient({
    required this.baseUrl,
    required this.apiKey,
    required Talker logger,
    this.timeout = const Duration(seconds: 30),
    WebKassaHttpSend? send,
  }) : _logger = logger,
       _send = send;

  final String baseUrl;

  final String? apiKey;

  final Duration timeout;
  final Talker _logger;

  final WebKassaHttpSend? _send;

  HttpClient? _client;

  HttpClient get _httpClient {
    _client ??= HttpClient()..connectionTimeout = timeout;
    return _client!;
  }

  Future<WebKassaResponse> authorize({
    required String login,
    required String password,
  }) {
    return post('/api/v4/Authorize', {'Login': login, 'Password': password});
  }

  Future<WebKassaResponse> check(Map<String, dynamic> body) {
    return post('/api/v4/check', body);
  }

  Future<WebKassaResponse> moneyOperation(Map<String, dynamic> body) {
    return post('/api/v4/MoneyOperation', body);
  }

  Future<WebKassaResponse> zReport(Map<String, dynamic> body) {
    return post('/api/v4/ZReport', body);
  }

  Future<WebKassaResponse> xReport(Map<String, dynamic> body) {
    return post('/api/v4/XReport', body);
  }

  Future<WebKassaResponse> cashboxes(Map<String, dynamic> body) {
    return post('/api/v4/Cashboxes', body);
  }

  Future<WebKassaResponse> esf(Map<String, dynamic> body) {
    return post('/api/v4/Esf', body);
  }

  Future<WebKassaResponse> snt(Map<String, dynamic> body) {
    return post('/api/v4/Snt', body);
  }

  Future<WebKassaResponse> verifyMark(Map<String, dynamic> body) {
    return post('/api/v4/MarkCheck', body);
  }

  /// Код отказа «касса не смогла собрать запрос» — адрес без узла, схема не
  /// `http`/`https`, неразборный адрес или тело, которое не кодируется в
  /// JSON.
  ///
  /// # Почему отдельный код, а не `-3`
  ///
  /// `-3` отображается в `network`, а `network` — транзиентный отказ:
  /// очередь кладёт чек в `pending` и докладывает `success: true`. Для
  /// обрыва связи это верно. Для запроса, который **не собирается**, повтор
  /// детерминированно повторит отказ: очередь остановится на нём при каждом
  /// повторе (`replay` на `network` прекращает обход целиком и попыток не
  /// считает), загородит всех, кто за ним, а кассир и отчёт смены увидят
  /// «в очереди» вместо «документ не выдан». Лечит это человек, исправив
  /// настройки, — значит строка обязана попасть на экран нефискализованных
  /// чеков с названной причиной.
  static const int requestNotBuiltCode = -4;

  /// Коды отказа, которые производит **транспорт**, а не тело ответа.
  ///
  /// | Код | Откуда | Разбор провайдера | Повторимо |
  /// | ---: | --- | --- | :---: |
  /// | −1 | `IOException` по дороге: `SocketException`, `HttpException` (сокет закрыт без ответа) | `network` | да |
  /// | −2 | `TimeoutException` | `network` | да |
  /// | −3 | ответ 1xx–3xx, не JSON — ответ потерян, документ мог лечь | `network` | да |
  /// | −4 | [requestNotBuiltCode] | `requestNotBuilt` | нет |
  /// | −5 | [operatorUnavailableCode] | `operatorUnavailable` | да |
  /// | −6 | [tlsRejectedCode] | `tlsRejected` | нет |
  /// | −7 | [clientFaultCode] | `clientFault` | нет |
  ///
  /// Повторимость решает не этот файл, а `FiscalErrorCode.isTransient`;
  /// здесь — только различение причин, которых после строки уже не различить.
  static const int connectionLostCode = -1;
  static const int timeoutCode = -2;
  static const int unreadableResponseCode = -3;

  /// HTTP 5xx, 408 или 429 **без кода оператора в теле**.
  ///
  /// Раньше такой ответ шёл как `errorCode = статус` → `_mapError` default →
  /// `unknown`: нетранзиентно, мимо очереди. 503 от балансировщика перед
  /// оператором — самый обычный вид «оператор недоступен», и чек с ним
  /// ложился на экран нефискализованных чеков, как отвергнутый по существу
  /// (измерено пробой `webkassa_failure_classification_test.dart`: `unknown`,
  /// raw 503). Сам статус сохраняется в [WebKassaResponse.statusCode].
  static const int operatorUnavailableCode = -5;

  /// `TlsException` (и `HandshakeException`): TLS не сошёлся.
  ///
  /// До этой правки падал в общий `catch` → −3 → `network` → **в очередь**:
  /// `https` к порту без TLS давал `success: true, queued: true` (измерено).
  /// Чужая схема, сертификат, часы кассы от времени не лечатся, а строка в
  /// `pending` не видна ни одному экрану.
  static const int tlsRejectedCode = -6;

  /// Исключение, **не являющееся вводом-выводом** (`StateError`, `TypeError`
  /// …) — сбой кода кассы. Раньше тоже −3 → `network` → очередь навсегда.
  static const int clientFaultCode = -7;

  static bool _operatorUnavailableStatus(int status) =>
      status >= 500 || status == 408 || status == 429;

  Future<WebKassaResponse> post(String path, Map<String, dynamic> body) async {
    final headers = <String, String>{
      // `charset` назван явно: тело уходит байтами UTF-8 (см. `_defaultSend`),
      // и тип обязан говорить то же самое.
      'Content-Type': 'application/json; charset=utf-8',
      'Accept': 'application/json',
      if (apiKey != null && apiKey!.isNotEmpty) 'X-API-Key': apiKey!,
    };

    // Адрес и тело собираются ВНУТРИ try: их отказ — это отказ запроса, и он
    // обязан вернуться значением, а не броском мимо очереди.
    try {
      final uri = Uri.parse('$baseUrl$path');
      final encoded = jsonEncode(body);
      _logger.debug('WebKassa POST: $uri');
      final raw = await (_send ?? _defaultSend)(uri, headers, encoded);
      _logger.debug('WebKassa response: ${raw.statusCode}');
      return WebKassaResponse.parse(raw.statusCode, raw.body);
    } on SocketException catch (e) {
      _logger.error('WebKassa connection error', e);
      return WebKassaResponse.transport(
        code: connectionLostCode,
        message: 'Нет соединения с сервером WebKassa',
      );
    } on TimeoutException catch (e) {
      _logger.error('WebKassa timeout', e);
      return WebKassaResponse.transport(
        code: timeoutCode,
        message: 'Таймаут соединения с WebKassa',
      );
    } on TlsException catch (e) {
      // Раньше `IOException`: `TlsException` его реализует, и общая ветка
      // ввода-вывода проглотила бы его как обрыв.
      _logger.error('WebKassa TLS rejected on $path: ${e.runtimeType}');
      return WebKassaResponse.transport(
        code: tlsRejectedCode,
        message:
            'TLS с сервером WebKassa не сошёлся (${e.runtimeType}): проверьте '
            'схему адреса, сертификат и часы кассы',
      );
    } on IOException catch (e) {
      // `HttpException` — сокет закрыт до заголовков ответа (`/_emul/kill`
      // производит именно его, а не `SocketException`). Документ мог лечь у
      // оператора; повтор тем же ключом безопасен.
      _logger.error('WebKassa I/O error on $path: ${e.runtimeType}');
      return WebKassaResponse.transport(
        code: connectionLostCode,
        message: 'Связь с WebKassa прервана (${e.runtimeType})',
      );
    } on ArgumentError catch (e) {
      return _notBuilt(path, e);
    } on FormatException catch (e) {
      return _notBuilt(path, e);
    } on JsonUnsupportedObjectError catch (e) {
      return _notBuilt(path, e);
    } catch (e) {
      // Текст исключения в отказ не идёт: у `ArgumentError` из `write` в нём
      // лежало всё тело — токен, названия, ИИН покупателя, — и он уезжал в
      // журнал и в `lastError` строки очереди.
      _logger.error('WebKassa client fault on $path: ${e.runtimeType}');
      return WebKassaResponse.transport(
        code: clientFaultCode,
        message: 'Сбой кассы при обмене с WebKassa: ${e.runtimeType}',
      );
    }
  }

  WebKassaResponse _notBuilt(String path, Object e) {
    _logger.error(
      'WebKassa: запрос $path не собран кассой (${e.runtimeType}) — '
      'повтор без исправления настроек не поможет',
    );
    return WebKassaResponse.transport(
      code: requestNotBuiltCode,
      message:
          'Запрос к WebKassa не собран кассой (${e.runtimeType}): проверьте '
          'адрес сервера в фискальных настройках и повторите чек',
    );
  }

  /// Единственное место, где тело попадает в сокет.
  ///
  /// Тело пишется **байтами UTF-8** с `contentLength`, а не
  /// `request.write(body)`: `HttpClientRequest.write` кодирует строку
  /// кодировкой из `charset` типа, а без него — latin1, и первая русская
  /// буква бросала `Contains invalid characters` до сокета. Так касса не
  /// отправила оператору ни одного чека с кириллицей. Запрет `write`
  /// строкой сторожится `test/architecture/http_body_is_bytes_test.dart`.
  ///
  /// Ответ читается декодером с `allowMalformed`: битые байты в ответе —
  /// это отказ **после** отправки (документ у оператора мог появиться), и
  /// он должен дойти до разбора как «неразборный ответ» (`-3`), а не
  /// выглядеть как `FormatException` несобранного запроса.
  Future<WebKassaRawResponse> _defaultSend(
    Uri uri,
    Map<String, String> headers,
    String body,
  ) async {
    final bytes = utf8.encode(body);
    final request = await _httpClient.postUrl(uri);
    headers.forEach(request.headers.set);
    request.contentLength = bytes.length;
    request.add(bytes);
    final response = await request.close().timeout(timeout);
    final responseBody = await response
        .transform(const Utf8Decoder(allowMalformed: true))
        .join();
    return WebKassaRawResponse(
      statusCode: response.statusCode,
      body: responseBody,
    );
  }

  void dispose() {
    _client?.close();
    _client = null;
  }
}

class WebKassaResponse {
  const WebKassaResponse({
    required this.success,
    this.data,
    this.errorCode,
    this.errorMessage,
    this.statusCode,
  });

  final bool success;

  final Map<String, dynamic>? data;

  final int? errorCode;

  final String? errorMessage;

  final int? statusCode;

  factory WebKassaResponse.parse(int statusCode, String rawBody) {
    Map<String, dynamic>? json;
    try {
      final decoded = jsonDecode(rawBody);
      if (decoded is Map<String, dynamic>) {
        json = decoded;
      }
    } catch (_) {}

    if (json == null) {
      return WebKassaResponse(
        success: false,
        errorCode: WebKassaApiClient._operatorUnavailableStatus(statusCode)
            ? WebKassaApiClient.operatorUnavailableCode
            : (statusCode >= 400
                  ? statusCode
                  : WebKassaApiClient.unreadableResponseCode),
        errorMessage: 'Некорректный ответ WebKassa (HTTP $statusCode)',
        statusCode: statusCode,
      );
    }

    final errors = json['Errors'];
    if (errors is List && errors.isNotEmpty) {
      final first = (errors.first as Map).cast<String, dynamic>();
      return WebKassaResponse(
        success: false,
        errorCode: (first['Code'] as num?)?.toInt(),
        errorMessage: first['Text'] as String?,
        statusCode: statusCode,
      );
    }

    final data = json['Data'];
    if (data is Map) {
      return WebKassaResponse(
        success: true,
        data: data.cast<String, dynamic>(),
        statusCode: statusCode,
      );
    }

    return WebKassaResponse(
      success: statusCode >= 200 && statusCode < 300,
      data: json,
      statusCode: statusCode,
      errorCode: WebKassaApiClient._operatorUnavailableStatus(statusCode)
          ? WebKassaApiClient.operatorUnavailableCode
          : (statusCode >= 400 ? statusCode : null),
      errorMessage: statusCode >= 400 ? 'HTTP $statusCode' : null,
    );
  }

  factory WebKassaResponse.transport({
    required int code,
    required String message,
  }) {
    return WebKassaResponse(
      success: false,
      errorCode: code,
      errorMessage: message,
    );
  }

  String? get token => data?['Token'] as String?;
}

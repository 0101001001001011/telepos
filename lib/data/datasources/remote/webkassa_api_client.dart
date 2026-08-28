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

  Future<WebKassaResponse> post(String path, Map<String, dynamic> body) async {
    final uri = Uri.parse('$baseUrl$path');
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (apiKey != null && apiKey!.isNotEmpty) 'X-API-Key': apiKey!,
    };
    final encoded = jsonEncode(body);

    _logger.debug('WebKassa POST: $uri');

    try {
      final raw = await (_send ?? _defaultSend)(uri, headers, encoded);
      _logger.debug('WebKassa response: ${raw.statusCode}');
      return WebKassaResponse.parse(raw.statusCode, raw.body);
    } on SocketException catch (e) {
      _logger.error('WebKassa connection error', e);
      return WebKassaResponse.transport(
        code: -1,
        message: 'Нет соединения с сервером WebKassa',
      );
    } on TimeoutException catch (e) {
      _logger.error('WebKassa timeout', e);
      return WebKassaResponse.transport(
        code: -2,
        message: 'Таймаут соединения с WebKassa',
      );
    } catch (e) {
      _logger.error('WebKassa error', e);
      return WebKassaResponse.transport(
        code: -3,
        message: 'Ошибка WebKassa: $e',
      );
    }
  }

  Future<WebKassaRawResponse> _defaultSend(
    Uri uri,
    Map<String, String> headers,
    String body,
  ) async {
    final request = await _httpClient.postUrl(uri);
    headers.forEach(request.headers.set);
    request.write(body);
    final response = await request.close().timeout(timeout);
    final responseBody = await response.transform(utf8.decoder).join();
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
        errorCode: statusCode >= 400 ? statusCode : -3,
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
      errorCode: statusCode >= 400 ? statusCode : null,
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

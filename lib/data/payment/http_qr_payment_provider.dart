import 'dart:async';
import 'dart:convert';

import 'package:decimal/decimal.dart';
import 'package:http/http.dart' as http;

import 'package:telepos/domain/payment/payment_intent.dart';
import 'package:telepos/domain/payment/qr_payment_provider.dart';

/// Провайдер QR/СБП поверх HTTP — **единственная реализация, и она
/// настраивается адресом**.
///
/// # Почему адресом, и почему это важно именно здесь
///
/// Подобие провайдера, поднятое в наборе, отличается от настоящего
/// **только адресом**. Ни одной ветки «если тест», ни одного флага, ни
/// одного `if (kDebugMode)`: в этом файле нет ни имени подобия, ни пути к
/// нему, и это сторожится пробой.
///
/// Это не удобство, а условие правдивости проверки. Провайдер, у которого
/// точка подстановки — наш собственный интерфейс, проверяет наш
/// собственный интерфейс. Провайдер, у которого точка подстановки —
/// **сеть**, проверяет сборку запроса, разбор ответа, тайм-аут и обрыв
/// связи, то есть ровно то, что ломается в магазине.
///
/// # Отказ приходит значением
///
/// Наружу не выходит ни одного исключения: сеть отказывает **обычно**, и
/// каждое место вызова, обязанное помнить про `try`, — это место, где
/// однажды забудут. Разбор кода отказа — в [_refusalOf].
///
/// # Чего этот класс НЕ делает
///
/// **Не ждёт и не повторяет.** Терпение — решение кассы, и оно в
/// `QrPaymentCoordinator`. Здесь только один круг сети: спросил, ответил
/// или не ответил.
class HttpQrPaymentProvider implements QrPaymentProvider {
  HttpQrPaymentProvider({
    required this.baseUrl,
    required this.code,
    http.Client? client,
    this.apiKey,
    this.timeout = const Duration(seconds: 10),
  }) : _client = client ?? http.Client();

  /// Адрес провайдера. Тот же способ подстановки, что у эмулятора
  /// WebKassa и эмулятора Kaspi.
  final String baseUrl;

  @override
  final String code;

  final String? apiKey;
  final Duration timeout;
  final http.Client _client;

  Uri _uri(String path) => Uri.parse('$baseUrl$path');

  Map<String, String> get _headers => {
    'content-type': 'application/json',
    if (apiKey != null) 'authorization': 'Bearer $apiKey',
  };

  @override
  Future<QrProviderReply<QrIntentCreation>> create({
    required String intentKey,
    required Decimal amount,
    String? orderNo,
  }) async {
    final reply = await _post('/sbp/v1/qr', {
      'intentKey': intentKey,
      // **Деньги строкой** (I159). `amount.toString()` над `Decimal`, а не
      // `toDouble()`: один `double` в денежном пути — и 1000.005 уезжает
      // как 1000.0049999999999.
      'amount': amount.toString(),
      if (orderNo != null) 'orderNo': orderNo,
    });
    if (!reply.isOk) return QrProviderReply.refused(reply.refusal!);
    final body = reply.value!;
    final id = body['intentId'];
    if (id is! String || id.isEmpty) {
      return const QrProviderReply.refused(
        QrRefusal(qrMalformedCode, 'провайдер не назвал ид намерения'),
      );
    }
    final status = QrIntentStatus.byCode(body['status'] as String?);
    if (status == null) {
      return QrProviderReply.refused(
        QrRefusal(
          qrMalformedCode,
          'незнакомое состояние намерения «${body['status']}»',
        ),
      );
    }
    return QrProviderReply.ok(
      QrIntentCreation(
        providerIntentId: id,
        status: status,
        qrPayload: body['payload'] as String?,
        expiresAt: _time(body['expiresAt']),
        alreadyExisted: body['existed'] == true,
      ),
    );
  }

  @override
  Future<QrProviderReply<QrIntentState>> poll(String providerIntentId) async {
    final reply = await _get('/sbp/v1/qr/$providerIntentId');
    if (!reply.isOk) return QrProviderReply.refused(reply.refusal!);
    return _stateOf(providerIntentId, reply.value!);
  }

  @override
  Future<QrProviderReply<QrIntentState>> cancel(String providerIntentId) async {
    final reply = await _post('/sbp/v1/qr/$providerIntentId/cancel', const {});
    if (!reply.isOk) return QrProviderReply.refused(reply.refusal!);
    return _stateOf(providerIntentId, reply.value!);
  }

  @override
  Future<QrProviderReply<QrIntentState>> reverse(
    String providerIntentId,
    Decimal amount, {
    String? refundKey,
  }) async {
    final reply = await _post('/sbp/v1/qr/$providerIntentId/refund', {
      'amount': amount.toString(),
      'refundKey': ?refundKey,
    });
    if (!reply.isOk) return QrProviderReply.refused(reply.refusal!);
    return _stateOf(providerIntentId, reply.value!);
  }

  QrProviderReply<QrIntentState> _stateOf(
    String id,
    Map<String, Object?> body,
  ) {
    final status = QrIntentStatus.byCode(body['status'] as String?);
    if (status == null) {
      return QrProviderReply.refused(
        QrRefusal(
          qrMalformedCode,
          'незнакомое состояние намерения «${body['status']}»',
        ),
      );
    }
    final paid = body['paidAmount'];
    return QrProviderReply.ok(
      QrIntentState(
        providerIntentId: body['intentId'] as String? ?? id,
        status: status,
        paidAmount: paid is String ? Decimal.tryParse(paid) : null,
        confirmedAt: _time(body['confirmedAt']),
        message: body['message'] as String?,
      ),
    );
  }

  static DateTime? _time(Object? raw) =>
      raw is String ? DateTime.tryParse(raw) : null;

  Future<QrProviderReply<Map<String, Object?>>> _get(String path) =>
      _send(() => _client.get(_uri(path), headers: _headers));

  Future<QrProviderReply<Map<String, Object?>>> _post(
    String path,
    Map<String, Object?> body,
  ) => _send(
    () => _client.post(_uri(path), headers: _headers, body: jsonEncode(body)),
  );

  /// Один круг сети и разбор ответа — **всё, что может пойти не так,
  /// названо кодом**.
  ///
  /// Три вида беды, и они разные по лечению, поэтому и коды разные:
  /// не ответил вовремя ([qrTimeoutCode]), не ответил вовсе
  /// ([qrNetworkCode]), ответил непонятным ([qrMalformedCode]). Первые два
  /// транзиентны — деньги могли уйти, и объявлять намерение провалившимся
  /// по ним **нельзя**; третий лечится человеком.
  Future<QrProviderReply<Map<String, Object?>>> _send(
    Future<http.Response> Function() call,
  ) async {
    http.Response response;
    try {
      response = await call().timeout(timeout);
    } on TimeoutException {
      return const QrProviderReply.refused(
        QrRefusal(qrTimeoutCode, 'провайдер не ответил за отведённое время'),
      );
    } catch (e) {
      // Текст исключения наружу не идёт (I144) — только названная причина.
      return const QrProviderReply.refused(
        QrRefusal(qrNetworkCode, 'связи с провайдером нет'),
      );
    }

    if (response.statusCode == 404) {
      return const QrProviderReply.refused(
        QrRefusal(qrUnknownIntentCode, 'провайдер не знает такого намерения'),
      );
    }
    if (response.statusCode == 501 || response.statusCode == 405) {
      return const QrProviderReply.refused(
        QrRefusal(
          qrReverseUnsupportedCode,
          'провайдер не умеет возвращать деньги по этому каналу',
        ),
      );
    }
    if (response.statusCode == 503 || response.statusCode == 429) {
      return const QrProviderReply.refused(
        QrRefusal(qrProviderBusyCode, 'провайдер занят, спросите позже'),
      );
    }
    if (response.statusCode >= 400) {
      final parsed = _tryDecode(response.body);
      final message = parsed?['message'];
      return QrProviderReply.refused(
        QrRefusal(
          qrRejectedCode,
          message is String
              ? message
              : 'провайдер отверг запрос (${response.statusCode})',
        ),
      );
    }

    final parsed = _tryDecode(response.body);
    if (parsed == null) {
      return const QrProviderReply.refused(
        QrRefusal(qrMalformedCode, 'ответ провайдера не разбирается'),
      );
    }
    return QrProviderReply.ok(parsed);
  }

  static Map<String, Object?>? _tryDecode(String raw) {
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map ? decoded.cast<String, Object?>() : null;
    } catch (_) {
      return null;
    }
  }

  void close() => _client.close();
}

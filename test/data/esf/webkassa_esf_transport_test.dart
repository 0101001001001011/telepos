import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talker/talker.dart';
import 'package:telepos/data/datasources/remote/webkassa_api_client.dart';
import 'package:telepos/data/esf/webkassa_esf_transport.dart';
import 'package:telepos/domain/esf/esf_models.dart';
import 'package:telepos/domain/esf/esf_settings.dart';
import 'package:telepos/domain/fiscal/fiscal_settings.dart';

FiscalSettings _wkSettings() => FiscalSettings(
  operatorType: FiscalOperatorType.webkassa,
  testMode: false,
  apiKey: 'WKD-KEY-123',
  login: 'kassir@shop.kz',
  password: 'secret',
  cashboxUniqueNumber: 'SWK00001',
);

EsfInvoice _sampleInvoice({String? regNumber}) {
  final vat = EsfTax(
    mode: EsfTaxMode.vat,
    ratePercent: Decimal.fromInt(12),
    amount: Decimal.parse('120'),
  );
  return EsfInvoice(
    idempotencyKey: 'idem-001',
    accountingNumber: 'ACC-7',
    direction: EsfDirection.outgoing,
    documentType: EsfDocumentType.basic,
    supplier: const EsfParty(binIin: '123456789012', name: 'ТОО Продавец'),
    buyer: const EsfParty(binIin: '210987654321', name: 'ТОО Покупатель'),
    lines: [
      EsfLine(
        lineNumber: 1,
        name: 'Товар №1',
        quantity: Decimal.fromInt(2),
        unitPrice: Decimal.parse('500'),
        lineTotal: Decimal.parse('1000'),
        tax: vat,
      ),
    ],
    vatBuckets: [
      EsfVatBucket(
        ratePercent: Decimal.fromInt(12),
        taxableAmount: Decimal.parse('1000'),
        vatAmount: Decimal.parse('120'),
      ),
    ],
    turnoverDate: DateTime.utc(2026, 6, 20),
    issueDate: DateTime.utc(2026, 6, 20),
    registrationNumber: regNumber,
  );
}

class _FakeSend {
  _FakeSend(this._bodies);
  final List<String> _bodies;
  int _i = 0;
  final List<Uri> uris = [];
  final List<Map<String, String>> headers = [];
  final List<Map<String, dynamic>> jsonBodies = [];

  WebKassaHttpSend get fn => (uri, hdrs, body) async {
    uris.add(uri);
    headers.add(hdrs);
    jsonBodies.add(jsonDecode(body) as Map<String, dynamic>);
    final reply = _bodies[_i < _bodies.length ? _i : _bodies.length - 1];
    _i++;
    return WebKassaRawResponse(statusCode: 200, body: reply);
  };
}

WebKassaApiClient _client(_FakeSend fake, FiscalSettings s) =>
    WebKassaApiClient(
      baseUrl: s.resolvedBaseUrl ?? '',
      apiKey: s.apiKey,
      logger: Talker(),
      send: fake.fn,
    );

void main() {
  group('WebKassaEsfTransport', () {
    test('canSign is true (WebKassa signs server-side)', () {
      final fake = _FakeSend(['{}']);
      final t = WebKassaEsfTransport(
        fiscalSettings: _wkSettings(),
        logger: Talker(),
        client: _client(fake, _wkSettings()),
      );
      expect(t.canSign, isTrue);
    });

    test('importInvoice authorizes then POSTs /api/v4/Esf with Token + '
        'X-API-Key, parses Data → delivered', () async {
      final fake = _FakeSend([
        '{"Data":{"Token":"TKN-1"}}',
        '{"Data":{"RegistrationNumber":"ESF-2026-777","Status":"delivered"}}',
      ]);
      final s = _wkSettings();
      final t = WebKassaEsfTransport(
        fiscalSettings: s,
        logger: Talker(),
        client: _client(fake, s),
      );

      final result = await t.importInvoice(
        _sampleInvoice(),
        EsfSettings.disabled(),
      );

      expect(
        fake.uris[0].toString(),
        'https://api.webkassa.kz/api/v4/Authorize',
      );
      expect(fake.uris[1].toString(), 'https://api.webkassa.kz/api/v4/Esf');

      expect(fake.headers[1]['X-API-Key'], 'WKD-KEY-123');

      expect(fake.jsonBodies[1]['Token'], 'TKN-1');
      expect(fake.jsonBodies[1]['SellerBin'], '123456789012');
      expect(fake.jsonBodies[1]['BuyerBin'], '210987654321');

      expect(result.success, isTrue);
      expect(result.status, EsfStatus.delivered);
      expect(result.registrationNumber, 'ESF-2026-777');
    });

    test('Errors envelope → failure (rejected, no faked reg number)', () async {
      final fake = _FakeSend([
        '{"Data":{"Token":"TKN-1"}}',
        '{"Errors":[{"Code":9,"Text":"Неверный БИН"}]}',
      ]);
      final s = _wkSettings();
      final t = WebKassaEsfTransport(
        fiscalSettings: s,
        logger: Talker(),
        client: _client(fake, s),
      );

      final result = await t.importInvoice(
        _sampleInvoice(),
        EsfSettings.disabled(),
      );

      expect(result.success, isFalse);
      expect(result.registrationNumber, isNull);
      expect(result.errorCode, EsfErrorCode.validation);
      expect(result.errorMessage, 'Неверный БИН');
    });

    test(
      'socket fault → transient network error (re-queue, not success)',
      () async {
        final s = _wkSettings();
        var calls = 0;
        final client = WebKassaApiClient(
          baseUrl: s.resolvedBaseUrl ?? '',
          apiKey: s.apiKey,
          logger: Talker(),
          send: (uri, headers, body) async {
            calls++;
            if (calls == 1) {
              return const WebKassaRawResponse(
                statusCode: 200,
                body: '{"Data":{"Token":"TKN-1"}}',
              );
            }
            throw const SocketException('connection refused');
          },
        );
        final t = WebKassaEsfTransport(
          fiscalSettings: s,
          logger: Talker(),
          client: client,
        );

        final result = await t.importInvoice(
          _sampleInvoice(),
          EsfSettings.disabled(),
        );

        expect(result.success, isFalse);
        expect(result.errorCode, EsfErrorCode.network);
      },
    );

    test('timeout → transient network error', () async {
      final s = _wkSettings();
      var calls = 0;
      final client = WebKassaApiClient(
        baseUrl: s.resolvedBaseUrl ?? '',
        apiKey: s.apiKey,
        logger: Talker(),
        send: (uri, headers, body) async {
          calls++;
          if (calls == 1) {
            return const WebKassaRawResponse(
              statusCode: 200,
              body: '{"Data":{"Token":"TKN-1"}}',
            );
          }
          throw TimeoutException('slow');
        },
      );
      final t = WebKassaEsfTransport(
        fiscalSettings: s,
        logger: Talker(),
        client: client,
      );

      final result = await t.importInvoice(
        _sampleInvoice(),
        EsfSettings.disabled(),
      );

      expect(result.success, isFalse);
      expect(result.errorCode, EsfErrorCode.network);
    });
  });
}

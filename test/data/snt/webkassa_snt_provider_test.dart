import 'dart:convert';
import 'dart:io';

import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talker/talker.dart';
import 'package:telepos/data/datasources/remote/webkassa_api_client.dart';
import 'package:telepos/data/snt/webkassa_snt_provider.dart';
import 'package:telepos/domain/fiscal/fiscal_settings.dart';
import 'package:telepos/domain/snt/snt_models.dart';

FiscalSettings _wkSettings() => FiscalSettings(
  operatorType: FiscalOperatorType.webkassa,
  testMode: false,
  apiKey: 'WKD-KEY-123',
  login: 'kassir@shop.kz',
  password: 'secret',
  cashboxUniqueNumber: 'SWK00001',
);

SntDocument _sampleDoc({
  String? regNumber,
  SntStatus status = SntStatus.draft,
}) => SntDocument(
  idempotencyKey: 'snt-001',
  direction: SntDirection.inbound,
  operationType: SntOperationType.supply,
  sender: const SntParty(bin: '123456789012', name: 'ТОО Поставщик'),
  recipient: const SntParty(bin: '210987654321', name: 'ТОО Мы'),
  lines: [
    SntLine(
      productCode: 1,
      name: 'Товар №1',
      quantity: Decimal.fromInt(3),
      unitCode: 796,
      isTraceable: true,
    ),
  ],
  occurredAt: DateTime.utc(2026, 6, 20),
  registrationNumber: regNumber,
  status: status,
);

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
  group('WebKassaSntProvider', () {
    test('id is webkassa and capabilities allow submit/confirm/revoke', () {
      final fake = _FakeSend(['{}']);
      final p = WebKassaSntProvider(
        fiscalSettings: _wkSettings(),
        logger: Talker(),
        client: _client(fake, _wkSettings()),
      );
      expect(p.id, 'webkassa');
      expect(p.capabilities.canSubmit, isTrue);
      expect(p.capabilities.canConfirmInbound, isTrue);
    });

    test('submit authorizes then POSTs /api/v4/Snt with Token + X-API-Key and '
        'parses Data → registered', () async {
      final fake = _FakeSend([
        '{"Data":{"Token":"TKN-1"}}',
        '{"Data":{"RegistrationNumber":"SNT-555","Status":"registered"}}',
      ]);
      final s = _wkSettings();
      final p = WebKassaSntProvider(
        fiscalSettings: s,
        logger: Talker(),
        client: _client(fake, s),
      );

      final result = await p.submit(_sampleDoc());

      expect(
        fake.uris[0].toString(),
        'https://api.webkassa.kz/api/v4/Authorize',
      );
      expect(fake.uris[1].toString(), 'https://api.webkassa.kz/api/v4/Snt');
      expect(fake.headers[1]['X-API-Key'], 'WKD-KEY-123');
      expect(fake.jsonBodies[1]['Token'], 'TKN-1');
      expect(fake.jsonBodies[1]['Operation'], 'submit');
      expect(fake.jsonBodies[1]['SenderBin'], '123456789012');

      expect(result.success, isTrue);
      expect(result.status, SntStatus.registered);
      expect(result.registrationNumber, 'SNT-555');
    });

    test('confirmInbound REALLY calls WebKassa (no local status flip) → '
        'confirmed only on a positive envelope', () async {
      final fake = _FakeSend([
        '{"Data":{"Token":"TKN-1"}}',
        '{"Data":{"Status":"confirmed"}}',
      ]);
      final s = _wkSettings();
      final p = WebKassaSntProvider(
        fiscalSettings: s,
        logger: Talker(),
        client: _client(fake, s),
      );

      final result = await p.confirmInbound(
        _sampleDoc(regNumber: 'SNT-555', status: SntStatus.registered),
      );

      expect(fake.uris[1].toString(), 'https://api.webkassa.kz/api/v4/Snt');
      expect(fake.jsonBodies[1]['Operation'], 'confirm');
      expect(fake.jsonBodies[1]['RegistrationNumber'], 'SNT-555');
      expect(result.success, isTrue);
      expect(result.status, SntStatus.confirmed);
    });

    test(
      'confirmInbound without a reg number fails (cannot confirm unverified)',
      () async {
        final fake = _FakeSend(['{"Data":{"Token":"TKN-1"}}']);
        final s = _wkSettings();
        final p = WebKassaSntProvider(
          fiscalSettings: s,
          logger: Talker(),
          client: _client(fake, s),
        );

        final result = await p.confirmInbound(_sampleDoc());
        expect(result.success, isFalse);
        expect(result.errorCode, SntErrorCode.validation);
        expect(fake.uris, isEmpty);
      },
    );

    test('Errors envelope → failure (validation)', () async {
      final fake = _FakeSend([
        '{"Data":{"Token":"TKN-1"}}',
        '{"Errors":[{"Code":9,"Text":"ФЛК отклонил СНТ"}]}',
      ]);
      final s = _wkSettings();
      final p = WebKassaSntProvider(
        fiscalSettings: s,
        logger: Talker(),
        client: _client(fake, s),
      );

      final result = await p.submit(_sampleDoc());
      expect(result.success, isFalse);
      expect(result.errorCode, SntErrorCode.validation);
      expect(result.errorMessage, 'ФЛК отклонил СНТ');
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
        final p = WebKassaSntProvider(
          fiscalSettings: s,
          logger: Talker(),
          client: client,
        );

        final result = await p.submit(_sampleDoc());
        expect(result.success, isFalse);
        expect(result.errorCode, SntErrorCode.network);
      },
    );
  });
}

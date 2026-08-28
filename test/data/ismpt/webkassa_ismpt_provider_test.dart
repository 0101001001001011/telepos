import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:talker/talker.dart';
import 'package:telepos/data/datasources/remote/webkassa_api_client.dart';
import 'package:telepos/data/ismpt/webkassa_ismpt_provider.dart';
import 'package:telepos/domain/fiscal/fiscal_settings.dart';
import 'package:telepos/domain/ismpt/ismpt_models.dart';

FiscalSettings _wkSettings() => FiscalSettings(
  operatorType: FiscalOperatorType.webkassa,
  testMode: false,
  apiKey: 'WKD-KEY-123',
  login: 'kassir@shop.kz',
  password: 'secret',
  cashboxUniqueNumber: 'SWK00001',
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
  group('WebKassaIsMptProvider', () {
    test('validateConfig returns null when WebKassa settings present', () {
      final fake = _FakeSend(['{}']);
      final p = WebKassaIsMptProvider(
        fiscalSettings: _wkSettings(),
        logger: Talker(),
        client: _client(fake, _wkSettings()),
      );
      expect(p.validateConfig(), isNull);
      expect(p.capabilities.supportsVerify, isTrue);
    });

    test('verifyCodes authorizes then POSTs /api/v4/MarkCheck with Token + '
        'X-API-Key and maps Results → in circulation', () async {
      final fake = _FakeSend([
        '{"Data":{"Token":"TKN-1"}}',
        '{"Data":{"Results":[{"Code":"0104607...","Status":"INTRODUCED",'
            '"Valid":true,"OwnerBin":"123456789012"}]}}',
      ]);
      final s = _wkSettings();
      final p = WebKassaIsMptProvider(
        fiscalSettings: s,
        logger: Talker(),
        client: _client(fake, s),
      );

      final result = await p.verifyCodes(['0104607...'], productGroup: 'shoes');

      expect(
        fake.uris[0].toString(),
        'https://api.webkassa.kz/api/v4/Authorize',
      );
      expect(
        fake.uris[1].toString(),
        'https://api.webkassa.kz/api/v4/MarkCheck',
      );
      expect(fake.headers[1]['X-API-Key'], 'WKD-KEY-123');
      expect(fake.jsonBodies[1]['Token'], 'TKN-1');
      expect(fake.jsonBodies[1]['Codes'], ['0104607...']);
      expect(fake.jsonBodies[1]['ProductGroup'], 'shoes');

      expect(result.success, isTrue);
      expect(result.verifications, hasLength(1));
      expect(result.verifications.first.status, MarkCisStatus.inCirculation);
      expect(result.verifications.first.valid, isTrue);
      expect(result.verifications.first.isInCirculation, isTrue);
    });

    test(
      'Errors envelope → failure (rejected, no faked valid status)',
      () async {
        final fake = _FakeSend([
          '{"Data":{"Token":"TKN-1"}}',
          '{"Errors":[{"Code":100,"Text":"КМ не найден"}]}',
        ]);
        final s = _wkSettings();
        final p = WebKassaIsMptProvider(
          fiscalSettings: s,
          logger: Talker(),
          client: _client(fake, s),
        );

        final result = await p.verifyCodes(['bad-code']);
        expect(result.success, isFalse);
        expect(result.errorCode, IsMptErrorCode.rejected);
        expect(result.errorMessage, 'КМ не найден');
      },
    );

    test('socket fault on verify → transient network error', () async {
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
      final p = WebKassaIsMptProvider(
        fiscalSettings: s,
        logger: Talker(),
        client: client,
      );

      final result = await p.verifyCodes(['x']);
      expect(result.success, isFalse);
      expect(result.errorCode, IsMptErrorCode.network);
    });

    test('submitDocument withdrawal is handled by the fiscal receipt — '
        'success, NOT a double-withdrawal', () async {
      final fake = _FakeSend(['{}']);
      final s = _wkSettings();
      final p = WebKassaIsMptProvider(
        fiscalSettings: s,
        logger: Talker(),
        client: _client(fake, s),
      );

      final result = await p.submitDocument(
        const IsMptDocRequest(
          idempotencyKey: 'd-1',
          type: IsMptDocType.withdrawal,
          codes: ['code-1'],
        ),
      );

      expect(result.success, isTrue);
      expect(fake.uris, isEmpty);
    });

    test(
      'submitDocument non-withdrawal is queued honestly (no faked UUID)',
      () async {
        final fake = _FakeSend(['{}']);
        final s = _wkSettings();
        final p = WebKassaIsMptProvider(
          fiscalSettings: s,
          logger: Talker(),
          client: _client(fake, s),
        );

        final result = await p.submitDocument(
          const IsMptDocRequest(
            idempotencyKey: 'd-2',
            type: IsMptDocType.acceptance,
            codes: ['code-1'],
          ),
        );

        expect(result.success, isTrue);
        expect(result.queued, isTrue);
        expect(result.documentId, isNull);
      },
    );

    test('getStatus is online once authorized', () async {
      final fake = _FakeSend(['{"Data":{"Token":"TKN-1"}}']);
      final s = _wkSettings();
      final p = WebKassaIsMptProvider(
        fiscalSettings: s,
        logger: Talker(),
        client: _client(fake, s),
      );

      final status = await p.getStatus();
      expect(status.configured, isTrue);
      expect(status.online, isTrue);
    });
  });
}

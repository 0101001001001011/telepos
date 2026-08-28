library;

import 'dart:convert';

import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talker/talker.dart';

import 'package:telepos/data/datasources/remote/webkassa_api_client.dart';
import 'package:telepos/data/fiscal/webkassa_provider.dart';
import 'package:telepos/domain/fiscal/fiscal_models.dart';
import 'package:telepos/domain/fiscal/fiscal_provider_registry.dart';
import 'package:telepos/domain/fiscal/fiscal_settings.dart';

class _Captured {
  _Captured(this.uri, this.headers, this.body);
  final Uri uri;
  final Map<String, String> headers;
  final Map<String, dynamic> body;
}

class _FakeTransport {
  _FakeTransport(this._responses);

  final List<WebKassaRawResponse> _responses;
  final List<_Captured> calls = [];
  int _i = 0;

  WebKassaHttpSend get send => (uri, headers, body) async {
    calls.add(
      _Captured(uri, headers, jsonDecode(body) as Map<String, dynamic>),
    );
    final resp = _i < _responses.length ? _responses[_i] : _responses.last;
    _i++;
    return resp;
  };

  _Captured callTo(String pathEnds) =>
      calls.firstWhere((c) => c.uri.path.endsWith(pathEnds));
}

WebKassaRawResponse _ok(Map<String, dynamic> data) =>
    WebKassaRawResponse(statusCode: 200, body: jsonEncode({'Data': data}));

WebKassaRawResponse _err(int code, String text) => WebKassaRawResponse(
  statusCode: 200,
  body: jsonEncode({
    'Errors': [
      {'Code': code, 'Text': text},
    ],
  }),
);

FiscalSettings _settings() => FiscalSettings(
  operatorType: FiscalOperatorType.webkassa,
  testMode: true,
  apiKey: 'WKD-XXXX-XXXX',
  login: 'cashier@example.com',
  password: 'Asdzxc1!',
  cashboxUniqueNumber: 'SWK00033717',
  registrationNumber: '032600010253',
  isVatPayer: true,
  vatRatePercent: Decimal.fromInt(12),
);

FiscalSaleRequest _mixedSale() => FiscalSaleRequest(
  idempotencyKey: 'GUID-7A3F',
  localOperationId: 101,
  positions: [
    FiscalPosition(
      name: 'Marlboro',
      quantity: Decimal.fromInt(1),
      unitPrice: Decimal.fromInt(500),
      lineTotal: Decimal.fromInt(500),
      tax: FiscalTax(
        mode: FiscalTaxMode.vat,
        ratePercent: Decimal.fromInt(12),
        amount: Decimal.parse('53.57'),
      ),
      ntin: '0200000000001',
      barcode: '4870249811936',
      unitCode: 796,
      markCodes: const ['0104603276013765213A8B06OMH52K291KZ'],
    ),
    FiscalPosition(
      name: 'Хлеб',
      quantity: Decimal.fromInt(2),
      unitPrice: Decimal.fromInt(150),
      lineTotal: Decimal.fromInt(300),
      tax: FiscalTax.none(),
      unitCode: 796,
    ),
  ],
  payments: [
    FiscalPayment(kind: FiscalPaymentKind.card, amount: Decimal.fromInt(600)),
    FiscalPayment(kind: FiscalPaymentKind.cash, amount: Decimal.fromInt(200)),
  ],
  totalDiscount: Decimal.zero,
  totalMarkup: Decimal.zero,
  occurredAt: DateTime(2026, 6, 1, 12),
);

WebKassaProvider _provider(_FakeTransport t) {
  final client = WebKassaApiClient(
    baseUrl: 'https://devkkm.webkassa.kz',
    apiKey: _settings().apiKey,
    logger: Talker(),
    send: t.send,
  );
  return WebKassaProvider(
    settings: _settings(),
    logger: Talker(),
    client: client,
  );
}

void main() {
  group('WebKassaProvider — real v4 /check payload mapping', () {
    test('sale maps mixed VAT + marking onto the v4 /check payload', () async {
      final t = _FakeTransport([
        _ok({'Token': 'TKN-abc'}),
        _ok({
          'CheckNumber': '321520655220',
          'TicketUrl': 'http://cabinet.wofd.kz/consumer?i=1&f=2&s=3&t=4',
          'ShiftNumber': 12,
          'CheckOrderNumber': 5,
          'OfflineMode': false,
          'DateTime': '01.06.2026 12:00:00',
          'Cashbox': {'RegistrationNumber': '032600010253'},
        }),
      ]);

      final result = await _provider(t).fiscalizeSale(_mixedSale());

      expect(result.success, isTrue);
      expect(result.fiscalSign, '321520655220');
      expect(result.ticketUrl, contains('cabinet.wofd.kz'));
      expect(result.shiftNumber, 12);
      expect(result.documentNumber, 5);
      expect(result.registrationNumber, '032600010253');

      final auth = t.callTo('/api/v4/Authorize');
      expect(auth.headers['X-API-Key'], 'WKD-XXXX-XXXX');
      expect(auth.body['Login'], 'cashier@example.com');
      expect(auth.body['Password'], 'Asdzxc1!');

      final check = t.callTo('/api/v4/check');
      expect(check.headers['X-API-Key'], 'WKD-XXXX-XXXX');
      expect(check.body['Token'], 'TKN-abc');
      expect(check.body['CashboxUniqueNumber'], 'SWK00033717');
      expect(check.body['OperationType'], 2);
      expect(check.body['ExternalCheckNumber'], 'GUID-7A3F');
      expect(check.body['RoundType'], 2);

      final positions = (check.body['Positions'] as List).cast<Map>();
      expect(positions, hasLength(2));

      final vatLine = positions[0];
      expect(vatLine['PositionName'], 'Marlboro');
      expect(vatLine['Count'], 1);
      expect(vatLine['Price'], 500);
      expect(vatLine['TaxType'], 100);
      expect(vatLine['TaxPercent'], 12);
      expect(vatLine['Tax'], 53.57);
      expect(vatLine['NTIN'], '0200000000001');
      expect(vatLine['GTIN'], '4870249811936');
      expect(vatLine['UnitCode'], 796);
      expect(vatLine['Mark'], '0104603276013765213A8B06OMH52K291KZ');
      expect(vatLine.containsKey('MarkList'), isFalse);

      final noVatLine = positions[1];
      expect(noVatLine['PositionName'], 'Хлеб');
      expect(noVatLine['TaxType'], 0);
      expect(noVatLine.containsKey('TaxPercent'), isFalse);
      expect(noVatLine.containsKey('Tax'), isFalse);
      expect(noVatLine.containsKey('Mark'), isFalse);

      final payments = (check.body['Payments'] as List).cast<Map>();
      final byType = {for (final p in payments) p['PaymentType']: p['Sum']};
      expect(byType[1], 600);
      expect(byType[0], 200);
    });

    test('multiple marking codes map to MarkList', () async {
      final t = _FakeTransport([
        _ok({'Token': 'TKN'}),
        _ok({'CheckNumber': 'C1'}),
      ]);
      final req = FiscalSaleRequest(
        idempotencyKey: 'G1',
        localOperationId: 1,
        positions: [
          FiscalPosition(
            name: 'Сигареты x2',
            quantity: Decimal.fromInt(2),
            unitPrice: Decimal.fromInt(500),
            lineTotal: Decimal.fromInt(1000),
            tax: FiscalTax(
              mode: FiscalTaxMode.vat,
              ratePercent: Decimal.fromInt(12),
              amount: Decimal.parse('107.14'),
            ),
            markCodes: const ['MARK-A', 'MARK-B'],
          ),
        ],
        payments: [
          FiscalPayment(
            kind: FiscalPaymentKind.cash,
            amount: Decimal.fromInt(1000),
          ),
        ],
        totalDiscount: Decimal.zero,
        totalMarkup: Decimal.zero,
        occurredAt: DateTime(2026, 6, 1),
      );

      await _provider(t).fiscalizeSale(req);
      final pos = (t.callTo('/api/v4/check').body['Positions'] as List)
          .cast<Map>()
          .first;
      expect(pos['MarkList'], ['MARK-A', 'MARK-B']);
      expect(pos.containsKey('Mark'), isFalse);
    });

    test('refund builds OperationType=3 + ReturnBasisDetails', () async {
      final t = _FakeTransport([
        _ok({'Token': 'TKN'}),
        _ok({'CheckNumber': 'R1', 'OfflineMode': false}),
      ]);
      final refund = FiscalRefundRequest(
        sale: _mixedSale(),
        basis: FiscalRefundBasis(
          originalFiscalSign: '321520655220',
          originalDateTime: DateTime.utc(2025, 9, 10, 6, 22, 21),
          originalRegistrationNumber: '032600010253',
          originalTotal: Decimal.fromInt(800),
          originalWasOffline: false,
        ),
      );

      final res = await _provider(t).fiscalizeRefund(refund);
      expect(res.success, isTrue);

      final check = t.callTo('/api/v4/check');
      expect(check.body['OperationType'], 3);
      final basis = check.body['ReturnBasisDetails'] as Map;
      expect(basis['CheckNumber'], '321520655220');
      expect(basis['RegistrationNumber'], '032600010253');
      expect(basis['Total'], 800);
      expect(basis['IsOffline'], false);
      expect(basis['DateTime'], contains('2025-09-10'));
    });

    test('money in/out hit /api/v4/MoneyOperation with direction', () async {
      final t = _FakeTransport([
        _ok({'Token': 'TKN'}),
        _ok({'CheckNumber': 'M1'}),
      ]);
      await _provider(t).moneyIn(
        FiscalMoneyRequest(
          idempotencyKey: 'MK1',
          amount: Decimal.fromInt(5000),
          occurredAt: DateTime(2026, 6, 1),
        ),
      );
      final money = t.callTo('/api/v4/MoneyOperation');
      expect(money.body['OperationType'], 0);
      expect(money.body['Sum'], 5000);
      expect(money.body['ExternalCheckNumber'], 'MK1');
      expect(money.body['CashboxUniqueNumber'], 'SWK00033717');
    });
  });

  group('WebKassaProvider — error envelope parsing & normalization', () {
    test('business error {Errors:[{Code,Text}]} → normalized code', () async {
      final t = _FakeTransport([
        _ok({'Token': 'TKN'}),
        _err(6, 'Касса не зарегистрирована или недоступна'),
      ]);
      final res = await _provider(t).fiscalizeSale(_mixedSale());
      expect(res.success, isFalse);
      expect(res.errorCode, FiscalErrorCode.cashboxNotFound);
      expect(res.rawErrorCode, 6);
      expect(res.errorMessage, contains('Касса'));
    });

    test('token-expired (Code 2) → re-auth + retry once → success', () async {
      final t = _FakeTransport([
        _ok({'Token': 'TKN-1'}),
        _err(2, 'TokenExpired'),
        _ok({'Token': 'TKN-2'}),
        _ok({'CheckNumber': 'C-RETRY'}),
      ]);
      final res = await _provider(t).fiscalizeSale(_mixedSale());
      expect(res.success, isTrue);
      expect(res.fiscalSign, 'C-RETRY');
      expect(t.calls.where((c) => c.uri.path.endsWith('/check')).length, 2);
      expect(t.calls.where((c) => c.uri.path.endsWith('/Authorize')).length, 2);
      final retried = t.calls.where((c) => c.uri.path.endsWith('/check')).last;
      expect(retried.body['Token'], 'TKN-2');
    });

    test('duplicate (Code 14) → idempotent success', () async {
      final t = _FakeTransport([
        _ok({'Token': 'TKN'}),
        _err(14, 'DuplicateExternalCode'),
      ]);
      final res = await _provider(t).fiscalizeSale(_mixedSale());
      expect(res.success, isTrue);
    });

    test(
      'bad credentials (Code 1) on authorize → notConfigured/failure',
      () async {
        final t = _FakeTransport([_err(1, 'Неверный логин и/или пароль')]);
        final res = await _provider(t).fiscalizeSale(_mixedSale());
        expect(res.success, isFalse);
        expect(res.errorCode, FiscalErrorCode.badCredentials);
      },
    );
  });

  group('WebKassaProvider — offline-first / operator-agnostic surface', () {
    test(
      'unconfigured settings → notConfigured (no network, never blocks)',
      () async {
        final t = _FakeTransport([
          _ok({'Token': 'x'}),
        ]);
        final client = WebKassaApiClient(
          baseUrl: 'https://devkkm.webkassa.kz',
          apiKey: null,
          logger: Talker(),
          send: t.send,
        );
        final provider = WebKassaProvider(
          settings: FiscalSettings(operatorType: FiscalOperatorType.webkassa),
          logger: Talker(),
          client: client,
        );
        final res = await provider.fiscalizeSale(_mixedSale());
        expect(res.success, isFalse);
        expect(res.errorCode, FiscalErrorCode.notConfigured);
        expect(t.calls, isEmpty);
      },
    );

    test('registry resolves webkassa builder when registered', () {
      final registry = FiscalProviderRegistry();
      registry.register(
        FiscalOperatorType.webkassa,
        (s) => WebKassaProvider(settings: s, logger: Talker()),
      );
      final provider = registry.resolve(_settings());
      expect(provider, isA<WebKassaProvider>());
      expect(provider.id, 'webkassa');
      expect(provider.capabilities.implicitShift, isTrue);
      expect(provider.capabilities.supportsMarking, isTrue);
      expect(provider.capabilities.supportsLocalModule, isTrue);
    });

    test('local module URL is preferred as base when set', () async {
      final t = _FakeTransport([
        _ok({'Token': 'TKN'}),
        _ok({'CheckNumber': 'L1', 'OfflineMode': true}),
      ]);
      final settings = _settings().copyWith(
        localModuleUrl: FiscalDefaults.localModuleUrl,
      );
      final client = WebKassaApiClient(
        baseUrl: settings.localModuleUrl!,
        apiKey: settings.apiKey,
        logger: Talker(),
        send: t.send,
      );
      final provider = WebKassaProvider(
        settings: settings,
        logger: Talker(),
        client: client,
      );
      final res = await provider.fiscalizeSale(_mixedSale());
      expect(res.success, isTrue);
      expect(res.offlineMode, isTrue);
      expect(
        t.callTo('/api/v4/check').uri.toString(),
        startsWith('http://localhost:1332'),
      );
    });
  });

  group('WebKassaProvider — Z/X reports', () {
    test('closeShift maps ZReport response', () async {
      final t = _FakeTransport([
        _ok({'Token': 'TKN'}),
        _ok({
          'ReportNumber': '77',
          'ShiftNumber': 12,
          'DocumentCount': 9,
          'PutMoneySum': 1000,
          'TakeMoneySum': 500,
          'SumInCashbox': 12500,
          'ControlSum': 'CS-1',
          'StartOn': '01.06.2026 09:00:00',
          'CloseOn': '01.06.2026 21:00:00',
        }),
      ]);
      final report = await _provider(t).closeShift(const FiscalShiftRequest());
      expect(report.success, isTrue);
      expect(report.shiftNumber, 12);
      expect(report.documentCount, 9);
      expect(report.cashInDrawer, Decimal.fromInt(12500));
      expect(report.controlSum, 'CS-1');
      expect(
        t.calls.any((c) => c.uri.path.endsWith('/api/v4/ZReport')),
        isTrue,
      );
    });
  });
}

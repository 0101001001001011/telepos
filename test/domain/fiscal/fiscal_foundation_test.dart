import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telepos/domain/fiscal/fiscal_models.dart';
import 'package:telepos/domain/fiscal/fiscal_provider.dart';
import 'package:telepos/domain/fiscal/fiscal_provider_registry.dart';
import 'package:telepos/domain/fiscal/fiscal_settings.dart';
import 'package:telepos/domain/fiscal/refusing_fiscal_provider.dart';

class _FakeProvider implements FiscalProvider {
  _FakeProvider(this.settings);

  final FiscalSettings settings;
  final List<String> calls = [];

  @override
  String get id => 'fake';

  @override
  FiscalCapabilities get capabilities => const FiscalCapabilities(
    implicitShift: true,
    supportsMarking: true,
    supportsLocalModule: true,
    supportsPurchase: true,
  );

  @override
  Future<FiscalAuthResult> authorize(FiscalSettings config) async {
    calls.add('authorize');
    return FiscalAuthResult.ok(token: 'tok');
  }

  @override
  String? validateConfig(FiscalSettings config) => null;

  @override
  Future<FiscalResult> fiscalizeSale(FiscalSaleRequest req) async {
    calls.add('sale:${req.idempotencyKey}');
    return FiscalResult.ok(fiscalSign: 'SIGN-${req.localOperationId}');
  }

  @override
  Future<FiscalResult> fiscalizeRefund(FiscalRefundRequest req) async {
    calls.add('refund:${req.basis.originalFiscalSign}');
    return FiscalResult.ok(fiscalSign: 'RSIGN');
  }

  @override
  Future<FiscalResult> fiscalizePurchase(FiscalSaleRequest req) async {
    calls.add('purchase');
    return FiscalResult.ok(fiscalSign: 'PSIGN');
  }

  @override
  Future<FiscalResult> fiscalizePurchaseReturn(FiscalRefundRequest req) async {
    calls.add('purchaseReturn');
    return FiscalResult.ok(fiscalSign: 'PRSIGN');
  }

  @override
  Future<FiscalResult> moneyIn(FiscalMoneyRequest req) async {
    calls.add('moneyIn');
    return FiscalResult.ok(fiscalSign: 'MIN');
  }

  @override
  Future<FiscalResult> moneyOut(FiscalMoneyRequest req) async {
    calls.add('moneyOut');
    return FiscalResult.ok(fiscalSign: 'MOUT');
  }

  @override
  Future<FiscalResult> openShift(FiscalShiftRequest req) async =>
      const FiscalResult(success: true);

  @override
  Future<FiscalReportResult> closeShift(FiscalShiftRequest req) async =>
      const FiscalReportResult(result: FiscalResult(success: true));

  @override
  Future<FiscalReportResult> xReport(FiscalShiftRequest req) async =>
      const FiscalReportResult(result: FiscalResult(success: true));

  @override
  Future<FiscalResult> correctionReceipt(FiscalCorrectionRequest req) async =>
      FiscalResult.unsupported('correctionReceipt');

  @override
  Future<FiscalStatus> getStatus() async =>
      const FiscalStatus(configured: true, active: true, online: true);
}

FiscalSaleRequest _sampleSale({int id = 7, String key = 'GUID-1'}) {
  return FiscalSaleRequest(
    idempotencyKey: key,
    localOperationId: id,
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
        markCodes: const ['0104603276013765213A8B06OMH52K291KZ'],
        unitCode: 796,
      ),
    ],
    payments: [
      FiscalPayment(kind: FiscalPaymentKind.card, amount: Decimal.fromInt(500)),
    ],
    totalDiscount: Decimal.zero,
    totalMarkup: Decimal.zero,
    occurredAt: DateTime(2026, 6, 1, 12),
  );
}

void main() {
  group('FiscalProviderRegistry — operator selection from settings', () {
    test('operatorType none resolves to RefusingFiscalProvider', () {
      final registry = FiscalProviderRegistry();
      final provider = registry.resolve(FiscalSettings.disabled());
      expect(provider, isA<RefusingFiscalProvider>());
      expect(provider.id, 'refusing');
    });

    test('unregistered operator falls back to Refusing (never crashes)', () {
      final registry = FiscalProviderRegistry();
      final provider = registry.resolve(
        FiscalSettings(operatorType: FiscalOperatorType.webkassa),
      );
      expect(provider, isA<RefusingFiscalProvider>());
    });

    test('registered operator is selected and receives settings', () {
      final registry = FiscalProviderRegistry();
      registry.register(FiscalOperatorType.webkassa, (s) => _FakeProvider(s));
      final settings = FiscalSettings(
        operatorType: FiscalOperatorType.webkassa,
        apiKey: 'WKD-XXXX',
        login: 'cashier@example.com',
        cashboxUniqueNumber: 'SWK00033717',
      );
      final provider = registry.resolve(settings);
      expect(provider, isA<_FakeProvider>());
      expect((provider as _FakeProvider).settings.apiKey, 'WKD-XXXX');
      expect(registry.isRegistered(FiscalOperatorType.webkassa), isTrue);
      expect(registry.isRegistered(FiscalOperatorType.kassa24), isFalse);
    });
  });

  group('Sale/refund route through the abstraction', () {
    test('sale and refund hit the resolved provider', () async {
      final registry = FiscalProviderRegistry();
      registry.register(FiscalOperatorType.kassa24, (s) => _FakeProvider(s));
      final provider =
          registry.resolve(
                FiscalSettings(operatorType: FiscalOperatorType.kassa24),
              )
              as _FakeProvider;

      final saleRes = await provider.fiscalizeSale(_sampleSale());
      expect(saleRes.success, isTrue);
      expect(saleRes.fiscalSign, 'SIGN-7');

      final refundRes = await provider.fiscalizeRefund(
        FiscalRefundRequest(
          sale: _sampleSale(id: 8, key: 'GUID-2'),
          basis: FiscalRefundBasis(
            originalFiscalSign: 'SIGN-7',
            originalDateTime: DateTime(2026, 6, 1, 12),
            originalRegistrationNumber: '032600010253',
            originalTotal: Decimal.fromInt(500),
          ),
        ),
      );
      expect(refundRes.success, isTrue);
      expect(provider.calls, contains('sale:GUID-1'));
      expect(provider.calls, contains('refund:SIGN-7'));
    });
  });

  // Прежде эта группа называлась «NoOp provider — offline-first, never
  // blocks» и **закрепляла ложь**: она требовала, чтобы заглушка отвечала
  // `queued` — то есть «чек встал в очередь и уедет сам». Очереди за ней не
  // было ни одной: очередь даёт `OfflineQueueingProvider`, и он оборачивает
  // настоящих провайдеров, а заглушка подставлялась реестром **вместо**
  // обёртки, а не под неё. Ожидания ниже переписаны по поведению, а не
  // подогнаны: то, что они требуют теперь, — названный отказ.
  group('Refusing provider — отказывает названно, ничего не обещает', () {
    const refusing = RefusingFiscalProvider();

    test('продажа отказана как «не настроено», а не поставлена в очередь', () async {
      final r = await refusing.fiscalizeSale(_sampleSale());
      expect(r.success, isFalse);
      expect(r.errorCode, FiscalErrorCode.notConfigured);
      // Главное отличие от прежнего поведения: обещания очереди больше нет.
      expect(r.queued, isFalse, reason: 'очереди за этим провайдером нет');
      expect(r.hasFiscalSign, isFalse);
    });

    test('возврат / приход / расход — тоже отказ, не очередь', () async {
      final refund = await refusing.fiscalizeRefund(
        FiscalRefundRequest(
          sale: _sampleSale(),
          basis: FiscalRefundBasis(
            originalFiscalSign: 'X',
            originalDateTime: DateTime(2026),
            originalRegistrationNumber: 'R',
            originalTotal: Decimal.zero,
          ),
        ),
      );
      final mIn = await refusing.moneyIn(
        FiscalMoneyRequest(
          idempotencyKey: 'k',
          amount: Decimal.fromInt(1000),
          occurredAt: DateTime(2026),
        ),
      );
      final mOut = await refusing.moneyOut(
        FiscalMoneyRequest(
          idempotencyKey: 'k2',
          amount: Decimal.fromInt(500),
          occurredAt: DateTime(2026),
        ),
      );
      for (final r in [refund, mIn, mOut]) {
        expect(r.success, isFalse);
        expect(r.queued, isFalse);
        expect(r.errorCode, FiscalErrorCode.notConfigured);
      }
    });

    test('коррекция отказана названно', () async {
      final r = await refusing.correctionReceipt(
        FiscalCorrectionRequest(
          idempotencyKey: 'k',
          positions: const [],
          payments: const [],
        ),
      );
      expect(r.success, isFalse);
      expect(r.errorCode, FiscalErrorCode.notConfigured);
    });

    test('отчёты не «удаются благополучно» — они отказывают', () async {
      final close = await refusing.closeShift(const FiscalShiftRequest());
      final x = await refusing.xReport(const FiscalShiftRequest());
      expect(close.success, isFalse);
      expect(x.success, isFalse);
      expect(close.result.errorCode, FiscalErrorCode.notConfigured);
      expect(x.result.errorCode, FiscalErrorCode.notConfigured);
    });

    test('настройки заглушки не «годны» — validateConfig называет причину', () {
      expect(refusing.validateConfig(FiscalSettings()), isNotNull);
    });
  });

  group('DTO mapping & Decimal-exact serialization', () {
    test('FiscalPosition round-trips НДС / НКТ / marking exactly', () {
      final original = _sampleSale().positions.first;
      final restored = FiscalPosition.fromJson(original.toJson());

      expect(restored.name, 'Marlboro');
      expect(restored.ntin, '0200000000001');
      expect(restored.barcode, '4870249811936');
      expect(restored.unitCode, 796);
      expect(restored.isMarked, isTrue);
      expect(restored.markCodes.length, 1);
      expect(restored.tax.amount, Decimal.parse('53.57'));
      expect(restored.tax.ratePercent, Decimal.fromInt(12));
      expect(restored.tax.mode, FiscalTaxMode.vat);
      expect(restored.unitPrice, Decimal.fromInt(500));
    });

    test('per-rate НДС: vat vs none positions preserved', () {
      final none = FiscalTax.none();
      final restored = FiscalTax.fromJson(none.toJson());
      expect(restored.mode, FiscalTaxMode.none);
      expect(restored.amount, Decimal.zero);
    });

    test('FiscalSaleRequest round-trips positions/payments/idempotency', () {
      final req = _sampleSale(id: 42, key: 'GUID-42');
      final restored = FiscalSaleRequest.fromJson(req.toJson());
      expect(restored.idempotencyKey, 'GUID-42');
      expect(restored.localOperationId, 42);
      expect(restored.positions.length, 1);
      expect(restored.payments.first.kind, FiscalPaymentKind.card);
      expect(restored.payments.first.amount, Decimal.fromInt(500));
    });

    test('FiscalSettings round-trips with Decimal VAT rate', () {
      final settings = FiscalSettings(
        operatorType: FiscalOperatorType.webkassa,
        apiKey: 'WKD-1',
        login: 'a@b.kz',
        cashboxUniqueNumber: 'SWK1',
        vatRatePercent: Decimal.fromInt(12),
        localModuleUrl: FiscalDefaults.localModuleUrl,
      );
      final restored = FiscalSettings.fromJson(settings.toJson());
      expect(restored.operatorType, FiscalOperatorType.webkassa);
      expect(restored.apiKey, 'WKD-1');
      expect(restored.vatRatePercent, Decimal.fromInt(12));
      expect(restored.hasLocalModule, isTrue);
      expect(restored.isEnabled, isTrue);
    });

    test('resolvedBaseUrl swaps test/prod per operator', () {
      final test = FiscalSettings(
        operatorType: FiscalOperatorType.webkassa,
        testMode: true,
      );
      final prod = test.copyWith(testMode: false);
      expect(test.resolvedBaseUrl, 'https://devkkm.webkassa.kz');
      expect(prod.resolvedBaseUrl, 'https://api.webkassa.kz');
    });
  });
}

library;

import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:telepos/data/fiscal/direct_ofd_provider.dart';
import 'package:telepos/data/fiscal/kassa24_provider.dart';
import 'package:telepos/data/fiscal/offline_queueing_provider.dart';
import 'package:telepos/domain/fiscal/fiscal_models.dart';
import 'package:telepos/domain/fiscal/fiscal_provider.dart';
import 'package:telepos/domain/fiscal/fiscal_provider_registry.dart';
import 'package:telepos/domain/fiscal/fiscal_settings.dart';

class _ControllableProvider implements FiscalProvider {
  bool online = true;

  final List<String> saleCalls = [];
  final List<String> refundCalls = [];
  final List<String> moneyCalls = [];

  FiscalResult? nextSaleResult;

  bool throwOnSale = false;

  final Map<String, FiscalResult> scripted = {};

  @override
  String get id => 'controllable';

  @override
  FiscalCapabilities get capabilities =>
      const FiscalCapabilities(supportsMarking: true, supportsPurchase: true);

  @override
  Future<FiscalAuthResult> authorize(FiscalSettings config) async =>
      FiscalAuthResult.ok(token: 't');

  @override
  String? validateConfig(FiscalSettings config) => null;

  @override
  Future<FiscalResult> fiscalizeSale(FiscalSaleRequest req) async {
    saleCalls.add(req.idempotencyKey);
    if (throwOnSale) throw Exception('socket closed');
    final scriptedResult = scripted.remove(req.idempotencyKey);
    if (scriptedResult != null) return scriptedResult;
    if (nextSaleResult != null) {
      final r = nextSaleResult!;
      nextSaleResult = null;
      return r;
    }
    return FiscalResult.ok(fiscalSign: 'SIGN-${req.idempotencyKey}');
  }

  @override
  Future<FiscalResult> fiscalizeRefund(FiscalRefundRequest req) async {
    refundCalls.add(req.sale.idempotencyKey);
    final scriptedResult = scripted.remove(req.sale.idempotencyKey);
    if (scriptedResult != null) return scriptedResult;
    return FiscalResult.ok(fiscalSign: 'RSIGN-${req.sale.idempotencyKey}');
  }

  @override
  Future<FiscalResult> fiscalizePurchase(FiscalSaleRequest req) async =>
      FiscalResult.ok(fiscalSign: 'PSIGN');

  @override
  Future<FiscalResult> fiscalizePurchaseReturn(FiscalRefundRequest req) async =>
      FiscalResult.ok(fiscalSign: 'PRSIGN');

  @override
  Future<FiscalResult> moneyIn(FiscalMoneyRequest req) async {
    moneyCalls.add('in:${req.idempotencyKey}');
    return FiscalResult.ok(fiscalSign: 'MIN');
  }

  @override
  Future<FiscalResult> moneyOut(FiscalMoneyRequest req) async {
    moneyCalls.add('out:${req.idempotencyKey}');
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
      FiscalStatus(configured: true, active: true, online: online);
}

OfflineQueueingProvider _wrap(
  _ControllableProvider inner,
  FiscalQueueStore store, {
  Duration window = kOfflineFiscalWindow,
  DateTime Function()? now,
}) {
  return OfflineQueueingProvider(
    inner: inner,
    store: store,
    isReachable: () async => inner.online,
    offlineWindow: window,
    now: now ?? () => DateTime(2026, 6, 1, 13),
  );
}

FiscalSaleRequest _sale({String key = 'GUID-1', int id = 1, DateTime? at}) {
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
    occurredAt: at ?? DateTime(2026, 6, 1, 12),
  );
}

void main() {
  group('OfflineQueueingProvider — offline-first, never blocks', () {
    test(
      'offline sale is enqueued and returns queued-success (no throw)',
      () async {
        final inner = _ControllableProvider()..online = false;
        final store = InMemoryFiscalQueueStore();
        final provider = _wrap(inner, store);

        final r = await provider.fiscalizeSale(_sale());

        expect(r.success, isTrue);
        expect(r.queued, isTrue);
        expect(r.hasFiscalSign, isFalse);
        expect(inner.saleCalls, isEmpty);
        expect(await store.pendingCount(), 1);
      },
    );

    test(
      're-enqueue with the same GUID is idempotent (no duplicate)',
      () async {
        final inner = _ControllableProvider()..online = false;
        final store = InMemoryFiscalQueueStore();
        final provider = _wrap(inner, store);

        await provider.fiscalizeSale(_sale(key: 'G-DUP'));
        await provider.fiscalizeSale(_sale(key: 'G-DUP'));

        expect(await store.pendingCount(), 1);
      },
    );

    test('a thrown transport error queues instead of propagating', () async {
      final inner = _ControllableProvider()
        ..online = true
        ..throwOnSale = true;
      final store = InMemoryFiscalQueueStore();
      final provider = _wrap(inner, store);

      final r = await provider.fiscalizeSale(_sale(key: 'G-THROW'));

      expect(r.queued, isTrue);
      expect(await store.pendingCount(), 1);
    });

    test(
      'transient network error result queues; hard error surfaces',
      () async {
        final inner = _ControllableProvider()..online = true;
        final store = InMemoryFiscalQueueStore();
        final provider = _wrap(inner, store);

        inner.nextSaleResult = FiscalResult.failure(
          'net',
          code: FiscalErrorCode.network,
        );
        final transient = await provider.fiscalizeSale(_sale(key: 'G-NET'));
        expect(transient.queued, isTrue);
        expect(await store.pendingCount(), 1);

        inner.nextSaleResult = FiscalResult.failure(
          'bad qty',
          code: FiscalErrorCode.validation,
        );
        final hard = await provider.fiscalizeSale(_sale(key: 'G-VAL'));
        expect(hard.success, isFalse);
        expect(hard.queued, isFalse);
        expect(hard.errorCode, FiscalErrorCode.validation);
        expect(await store.pendingCount(), 1);
      },
    );

    test('online sale fiscalizes immediately (no queue)', () async {
      final inner = _ControllableProvider()..online = true;
      final store = InMemoryFiscalQueueStore();
      final provider = _wrap(inner, store);

      final r = await provider.fiscalizeSale(_sale(key: 'G-ONLINE'));

      expect(r.success, isTrue);
      expect(r.queued, isFalse);
      expect(r.fiscalSign, 'SIGN-G-ONLINE');
      expect(await store.pendingCount(), 0);
    });
  });

  group('OfflineQueueingProvider — reconnect replay', () {
    test('replay dequeues FIFO with the ORIGINAL idempotency key', () async {
      final inner = _ControllableProvider()..online = false;
      final store = InMemoryFiscalQueueStore();
      final provider = _wrap(inner, store);

      await provider.fiscalizeSale(
        _sale(key: 'G-B', at: DateTime(2026, 6, 1, 12, 2)),
      );
      await provider.fiscalizeSale(
        _sale(key: 'G-A', at: DateTime(2026, 6, 1, 12, 1)),
      );
      await provider.fiscalizeSale(
        _sale(key: 'G-C', at: DateTime(2026, 6, 1, 12, 3)),
      );
      expect(await store.pendingCount(), 3);

      inner.online = true;
      final report = await provider.replay();

      expect(report.fiscalized, 3);
      expect(report.remaining, 0);
      expect(inner.saleCalls, ['G-A', 'G-B', 'G-C']);
      expect(await store.pendingCount(), 0);
    });

    test(
      'duplicate on replay goes to a human, not to the bin '
      '(no double fiscalization either)',
      () async {
        final inner = _ControllableProvider()..online = false;
        final store = InMemoryFiscalQueueStore();
        final provider = _wrap(inner, store);

        await provider.fiscalizeSale(_sale(key: 'G-DEDUP'));
        inner.online = true;
        inner.scripted['G-DEDUP'] = FiscalResult.failure(
          'dup',
          code: FiscalErrorCode.duplicate,
        );

        final report = await provider.replay();

        expect(report.duplicates, 1);
        expect(report.fiscalized, 0);
        expect(await store.pendingCount(), 0);
        // Правка 2026-09-19: строка остаётся следом для человека. Документ
        // у оператора есть, фискального признака у кассы нет, и удалить
        // строку значило бы стереть единственную запись об этом.
        final left = await store.failed();
        expect(left.map((e) => e.idempotencyKey), ['G-DEDUP']);
        expect(left.single.lastError, 'fiscal(duplicate)');
      },
    );

    test(
      'replay stops on network error and preserves the queue (FIFO)',
      () async {
        final inner = _ControllableProvider()..online = false;
        final store = InMemoryFiscalQueueStore();
        final provider = _wrap(inner, store);

        await provider.fiscalizeSale(
          _sale(key: 'G-1', at: DateTime(2026, 6, 1, 12, 1)),
        );
        await provider.fiscalizeSale(
          _sale(key: 'G-2', at: DateTime(2026, 6, 1, 12, 2)),
        );

        inner.online = true;
        inner.scripted['G-2'] = FiscalResult.failure(
          'net',
          code: FiscalErrorCode.network,
        );

        final report = await provider.replay();

        expect(report.fiscalized, 1);
        expect(report.stoppedOnNetwork, isTrue);
        expect(report.remaining, 1);
        expect(await store.pendingCount(), 1);
      },
    );

    test(
      'replay while offline is a no-op that keeps the queue intact',
      () async {
        final inner = _ControllableProvider()..online = false;
        final store = InMemoryFiscalQueueStore();
        final provider = _wrap(inner, store);

        await provider.fiscalizeSale(_sale(key: 'G-OFF'));
        final report = await provider.replay();

        expect(report.stoppedOnNetwork, isTrue);
        expect(report.remaining, 1);
        expect(inner.saleCalls, isEmpty);
      },
    );

    test(
      'queued op older than the 72h window is marked FAILED on replay',
      () async {
        final inner = _ControllableProvider()..online = false;
        final store = InMemoryFiscalQueueStore();
        final saleTime = DateTime(2026, 6, 1, 12);
        final replayNow = saleTime.add(const Duration(hours: 80));
        final provider = _wrap(inner, store, now: () => replayNow);

        await provider.fiscalizeSale(_sale(key: 'G-STALE', at: saleTime));
        inner.online = true;

        final report = await provider.replay();

        expect(report.failed, 1);
        expect(report.fiscalized, 0);
        expect(inner.saleCalls, isEmpty);
        final pending = await store.pending();
        expect(pending, isEmpty);
      },
    );

    test(
      'refund and money ops also queue + replay through the decorator',
      () async {
        final inner = _ControllableProvider()..online = false;
        final store = InMemoryFiscalQueueStore();
        final provider = _wrap(inner, store);

        final refundReq = FiscalRefundRequest(
          sale: _sale(key: 'G-REF', id: 9),
          basis: FiscalRefundBasis(
            originalFiscalSign: 'SIGN-X',
            originalDateTime: DateTime(2026, 6, 1, 11),
            originalRegistrationNumber: '032600010253',
            originalTotal: Decimal.fromInt(500),
          ),
        );
        final refundRes = await provider.fiscalizeRefund(refundReq);
        final moneyRes = await provider.moneyIn(
          FiscalMoneyRequest(
            idempotencyKey: 'G-MIN',
            amount: Decimal.fromInt(1000),
            occurredAt: DateTime(2026, 6, 1, 12),
          ),
        );
        expect(refundRes.queued, isTrue);
        expect(moneyRes.queued, isTrue);
        expect(await store.pendingCount(), 2);

        inner.online = true;
        final report = await provider.replay();
        expect(report.fiscalized, 2);
        expect(inner.refundCalls, contains('G-REF'));
        expect(inner.moneyCalls, contains('in:G-MIN'));
      },
    );
  });

  group('Decimal / НДС / НКТ / marking survive enqueue → replay', () {
    test(
      'the inner provider receives the exact Decimal/НДС/НКТ on replay',
      () async {
        final inner = _ControllableProvider()..online = false;
        final store = InMemoryFiscalQueueStore();
        final provider = _wrap(inner, store);

        await provider.fiscalizeSale(_sale(key: 'G-DTO'));

        final entry = (await store.pending()).single;
        final restored = FiscalSaleRequest.fromJson(entry.payload);
        final pos = restored.positions.single;

        expect(restored.idempotencyKey, 'G-DTO');
        expect(pos.tax.amount, Decimal.parse('53.57'));
        expect(pos.tax.ratePercent, Decimal.fromInt(12));
        expect(pos.tax.mode, FiscalTaxMode.vat);
        expect(pos.ntin, '0200000000001');
        expect(pos.isMarked, isTrue);
        expect(pos.markCodes.single, '0104603276013765213A8B06OMH52K291KZ');
        expect(pos.unitCode, 796);
        expect(pos.unitPrice, Decimal.fromInt(500));
      },
    );
  });

  group(
    'Sale routes through the abstraction without blocking when offline',
    () {
      test(
        'registry resolves operator → decorator; offline sale still completes',
        () async {
          final inner = _ControllableProvider()..online = false;
          final store = InMemoryFiscalQueueStore();
          final registry = FiscalProviderRegistry();
          registry.register(
            FiscalOperatorType.kassa24,
            (s) => _wrap(inner, store),
          );

          final provider = registry.resolve(
            FiscalSettings(operatorType: FiscalOperatorType.kassa24),
          );
          expect(provider, isA<OfflineQueueingProvider>());
          expect(provider.id, 'controllable');

          final r = await provider.fiscalizeSale(_sale(key: 'G-ROUTE'));
          expect(r.success, isTrue);
          expect(r.queued, isTrue);
          expect(await store.pendingCount(), 1);
        },
      );
    },
  );

  group('DirectOfd & Kassa24 skeletons are honest (no fake success)', () {
    test(
      'DirectOfdProvider: correct caps, validation, unsupported ops',
      () async {
        final settings = FiscalSettings(
          operatorType: FiscalOperatorType.directOfd,
        );
        final p = DirectOfdProvider(settings);

        expect(p.id, 'direct_ofd');
        expect(p.capabilities.implicitShift, isFalse);
        expect(p.capabilities.supportsLocalModule, isTrue);
        expect(p.capabilities.supportsMarking, isTrue);
        expect(p.validateConfig(settings), isNotNull);
        final sale = await p.fiscalizeSale(_sale());
        expect(sale.success, isFalse);
        expect(sale.errorCode, FiscalErrorCode.unsupported);
        expect(sale.hasFiscalSign, isFalse);
        final auth = await p.authorize(settings);
        expect(auth.success, isFalse);
      },
    );

    test(
      'Kassa24Provider: correct caps, validation, unsupported ops',
      () async {
        final settings = FiscalSettings(
          operatorType: FiscalOperatorType.kassa24,
        );
        final p = Kassa24Provider(settings);

        expect(p.id, 'kassa24');
        expect(p.capabilities.implicitShift, isFalse);
        expect(p.capabilities.supportsLocalModule, isFalse);
        expect(p.capabilities.supportsPurchase, isTrue);
        expect(p.validateConfig(settings), isNotNull);
        final sale = await p.fiscalizeSale(_sale());
        expect(sale.success, isFalse);
        expect(sale.errorCode, FiscalErrorCode.unsupported);
        expect(sale.hasFiscalSign, isFalse);
        final z = await p.closeShift(const FiscalShiftRequest());
        expect(z.success, isFalse);
      },
    );

    test(
      'a skeleton wrapped in the offline decorator still never blocks',
      () async {
        final store = InMemoryFiscalQueueStore();
        final skeleton = Kassa24Provider(
          FiscalSettings(operatorType: FiscalOperatorType.kassa24),
        );
        final provider = OfflineQueueingProvider(
          inner: skeleton,
          store: store,
          isReachable: () async => false,
        );

        final r = await provider.fiscalizeSale(_sale(key: 'G-SKEL'));
        expect(r.queued, isTrue);
        expect(await store.pendingCount(), 1);
      },
    );
  });
}

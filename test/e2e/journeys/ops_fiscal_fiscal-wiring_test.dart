library;

import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:talker/talker.dart';

import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/usecases/fiscal/fiscal_service_impl.dart';
import 'package:telepos/data/usecases/fiscal/this_pos_fiscal_settings_source.dart';
import 'package:telepos/domain/fiscal/fiscal_models.dart';
import 'package:telepos/domain/fiscal/fiscal_provider.dart';
import 'package:telepos/domain/fiscal/fiscal_provider_registry.dart';
import 'package:telepos/domain/fiscal/fiscal_settings.dart';
import 'package:telepos/domain/services/shift_service.dart';
import 'package:telepos/domain/usecases/fiscal/fiscal_service.dart';

import '../support/harness.dart';

class _CapturingProvider implements FiscalProvider {
  _CapturingProvider(this.settings, {this.offline = false});

  final FiscalSettings settings;
  final bool offline;

  FiscalSaleRequest? lastSale;
  FiscalRefundRequest? lastRefund;
  final List<String> calls = [];

  @override
  String get id => 'capturing';

  @override
  FiscalCapabilities get capabilities => const FiscalCapabilities(
    implicitShift: true,
    supportsMarking: true,
    supportsLocalModule: true,
    supportsPurchase: true,
  );

  @override
  Future<FiscalAuthResult> authorize(FiscalSettings config) async =>
      FiscalAuthResult.ok(token: 'tok');

  @override
  String? validateConfig(FiscalSettings config) => null;

  @override
  Future<FiscalResult> fiscalizeSale(FiscalSaleRequest req) async {
    calls.add('sale');
    lastSale = req;
    if (offline) throw Exception('offline: no network');
    return FiscalResult.ok(
      fiscalSign: 'SIGN-${req.localOperationId}',
      registrationNumber: '032600010253',
      ticketUrl: 'https://consumer.kz/?i=1',
      documentNumber: 5,
      shiftNumber: 3,
    );
  }

  @override
  Future<FiscalResult> fiscalizeRefund(FiscalRefundRequest req) async {
    calls.add('refund');
    lastRefund = req;
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
    calls.add('moneyIn:${req.amount}');
    return FiscalResult.ok(fiscalSign: 'MIN');
  }

  @override
  Future<FiscalResult> moneyOut(FiscalMoneyRequest req) async {
    calls.add('moneyOut:${req.amount}');
    return FiscalResult.ok(fiscalSign: 'MOUT');
  }

  @override
  Future<FiscalResult> openShift(FiscalShiftRequest req) async {
    calls.add('openShift');
    return const FiscalResult(success: true);
  }

  @override
  Future<FiscalReportResult> closeShift(FiscalShiftRequest req) async {
    calls.add('closeShift');
    return const FiscalReportResult(
      result: FiscalResult(success: true, fiscalSign: 'ZREP'),
      shiftNumber: 3,
      documentCount: 7,
    );
  }

  @override
  Future<FiscalReportResult> xReport(FiscalShiftRequest req) async {
    calls.add('xReport');
    return const FiscalReportResult(result: FiscalResult(success: true));
  }

  @override
  Future<FiscalResult> correctionReceipt(FiscalCorrectionRequest req) async {
    calls.add('correction');
    return FiscalResult.unsupported('correctionReceipt');
  }

  @override
  Future<FiscalStatus> getStatus() async =>
      const FiscalStatus(configured: true, active: true, online: true);
}

void main() {
  final h = E2eHarness();

  setUp(() => h.setUp());
  tearDown(() => h.tearDown());

  Future<void> enableOfd(AppDatabase db) async {
    await (db.update(
      db.thisPosEntries,
    )..where((tp) => tp.rId.equals(true))).write(
      const ThisPosEntriesCompanion(
        sendToOfd: Value(true),
        webkassaToken: Value('TEST-TOKEN'),
        webkassaHost: Value('https://api.webkassa.kz'),
        isVatPayer: Value(true),
      ),
    );
  }

  ({FiscalService service, FiscalProviderRegistry registry}) wire(
    AppDatabase db,
    FiscalProvider Function(FiscalSettings) builder,
  ) {
    final registry = FiscalProviderRegistry();
    registry.register(FiscalOperatorType.webkassa, builder);
    final service = FiscalServiceImpl(
      db: db,
      registry: registry,
      settingsSource: ThisPosFiscalSettingsSource(db: db),
      logger: Talker(),
    );
    return (service: service, registry: registry);
  }

  Future<int> seedFiscalSale(
    AppDatabase db, {
    required int receiptNo,
    required int ucode,
    required int? vatRate,
    required String? ntin,
    required bool markable,
    String? mark,
    String price = '500',
  }) async {
    await db
        .into(db.productInfos)
        .insert(
          ProductInfosCompanion(
            ucode: Value(ucode),
            barcode: Value(4870001),
            name: Value('Сигареты Marlboro'),
            type: const Value(0),
            measure: const Value(0),
            quantity: Value(d('100')),
            vatRate: Value(vatRate),
            ntin: Value(ntin),
            isMarkable: Value(markable),
          ),
        );
    await db
        .into(db.sales)
        .insert(
          SalesCompanion(
            receiptNo: Value(receiptNo),
            posId: const Value(1),
            userId: const Value(1),
            amount: Value(d(price)),
            time: Value(DateTime.now().millisecondsSinceEpoch ~/ 1000),
            isOfd: const Value(true),
            state: const Value(1),
          ),
        );
    final spId = await db
        .into(db.saleProducts)
        .insert(
          SaleProductsCompanion(
            receiptNo: Value(receiptNo),
            posId: const Value(1),
            ucode: Value(ucode),
            barcode: const Value(4870001),
            quantity: Value(d('1')),
            price: Value(d(price)),
            priceBefore: Value(d(price)),
          ),
        );
    if (mark != null) {
      await db
          .into(db.saleProductMarks)
          .insert(
            SaleProductMarksCompanion(
              mark: Value(mark),
              saleProductId: Value(spId),
            ),
          );
    }
    return receiptNo;
  }

  test(
    'fiscalization routes through the operator-agnostic provider '
    '(per-rate НДС / НКТ / marking, refund basis, shift Z-report, offline)',
    () async {
      final db = h.db;
      GetIt.I.registerSingleton<AppDatabase>(db);

      {
        final registry = FiscalProviderRegistry();
        final service = FiscalServiceImpl(
          db: db,
          registry: registry,
          settingsSource: ThisPosFiscalSettingsSource(db: db),
          logger: Talker(),
        );
        await seedFiscalSale(
          db,
          receiptNo: 7005,
          ucode: 9005,
          vatRate: 12,
          ntin: null,
          markable: false,
        );

        expect(await service.isEnabled(), isFalse);
        final res = await service.fiscalizeSale(
          saleReceiptNo: 7005,
          salePosId: 1,
          amount: d('500'),
          cashAmount: d('500'),
          cardAmount: Decimal.zero,
        );
        expect(res.success, isTrue, reason: 'NoOp never blocks the sale');
        expect(res.queued, isTrue);
        expect(res.hasFiscalSign, isFalse);
      }

      {
        await (db.update(
          db.thisPosEntries,
        )..where((tp) => tp.rId.equals(true))).write(
          const ThisPosEntriesCompanion(
            sendToOfd: Value(true),
            webkassaToken: Value('TEST-TOKEN'),
            isVatPayer: Value(false),
          ),
        );
        late _CapturingProvider provider;
        final w = wire(db, (s) => provider = _CapturingProvider(s));

        await seedFiscalSale(
          db,
          receiptNo: 7002,
          ucode: 9002,
          vatRate: null,
          ntin: null,
          markable: false,
        );
        await w.service.fiscalizeSale(
          saleReceiptNo: 7002,
          salePosId: 1,
          amount: d('500'),
          cashAmount: d('500'),
          cardAmount: Decimal.zero,
        );

        final pos = provider.lastSale!.positions.first;
        expect(pos.tax.mode, FiscalTaxMode.none);
        expect(pos.tax.amount, Decimal.zero);
        expect(pos.isMarked, isFalse);
      }

      await enableOfd(db);

      {
        late _CapturingProvider provider;
        final w = wire(db, (s) => provider = _CapturingProvider(s));

        await seedFiscalSale(
          db,
          receiptNo: 7001,
          ucode: 9001,
          vatRate: 12,
          ntin: '0200000000001',
          markable: true,
          mark: '0104603276013765213A8B06OMH52K291KZ',
        );

        final res = await w.service.fiscalizeSale(
          saleReceiptNo: 7001,
          salePosId: 1,
          amount: d('500'),
          cashAmount: Decimal.zero,
          cardAmount: d('500'),
        );

        expect(res.success, isTrue);
        expect(res.fiscalSign, 'SIGN-7001');

        final sent = provider.lastSale!;
        expect(sent.localOperationId, 7001);
        expect(sent.idempotencyKey, 'sale-7001-1');
        expect(sent.positions.length, 1);

        final pos = sent.positions.first;
        expect(pos.name, 'Сигареты Marlboro');
        expect(pos.ntin, '0200000000001');
        expect(pos.isMarked, isTrue);
        expect(pos.markCodes.single, '0104603276013765213A8B06OMH52K291KZ');
        expect(pos.tax.mode, FiscalTaxMode.vat);
        expect(pos.tax.ratePercent, Decimal.fromInt(12));
        expect(pos.tax.amount, Decimal.parse('53.57'));
        expect(sent.payments.single.kind, FiscalPaymentKind.card);
        expect(sent.payments.single.amount, d('500'));

        final receipt = await db.webkassaReceiptDao.findByIsSaleAndOperationId(
          true,
          7001,
        );
        expect(receipt, isNotNull);
        expect(receipt!.fiscalNo, 'SIGN-7001');
      }

      {
        late _CapturingProvider provider;
        final w = wire(db, (s) => provider = _CapturingProvider(s));

        await seedFiscalSale(
          db,
          receiptNo: 7003,
          ucode: 9003,
          vatRate: 12,
          ntin: null,
          markable: false,
        );
        await (db.update(db.sales)
              ..where((s) => s.receiptNo.equals(7003) & s.posId.equals(1)))
            .write(const SalesCompanion(saleId: Value(7003)));
        await db.webkassaReceiptDao.insertReceipt(
          WebkassaReceiptsCompanion(
            operationId: const Value(7003),
            receiptNo: const Value(7003),
            fiscalNo: const Value('ORIG-SIGN-7003'),
            wkTime: Value(DateTime.now().millisecondsSinceEpoch ~/ 1000),
            isSale: const Value(true),
          ),
        );
        await db
            .into(db.refunds)
            .insert(
              RefundsCompanion(
                localId: const Value(8003),
                userId: const Value(1),
                amount: Value(d('500')),
                time: Value(DateTime.now().millisecondsSinceEpoch ~/ 1000),
              ),
            );
        await db
            .into(db.refundProducts)
            .insert(
              RefundProductsCompanion(
                refundLocalId: const Value(8003),
                ucode: const Value(9003),
                quantity: Value(d('1')),
                price: Value(d('500')),
              ),
            );

        final res = await w.service.fiscalizeRefund(
          refundLocalId: 8003,
          originalSaleReceiptNo: 7003,
          amount: d('500'),
        );

        expect(res.success, isTrue);
        expect(provider.calls, contains('refund'));
        final basis = provider.lastRefund!.basis;
        expect(basis.originalFiscalSign, 'ORIG-SIGN-7003');
        expect(basis.originalTotal, d('500'));
        expect(provider.lastRefund!.sale.kind, FiscalOperationKind.saleReturn);
        expect(
          provider.lastRefund!.sale.positions.single.tax.ratePercent,
          Decimal.fromInt(12),
        );
      }

      {
        late _CapturingProvider provider;
        final w = wire(db, (s) => provider = _CapturingProvider(s));
        GetIt.I.registerSingleton<FiscalService>(w.service);

        final shift = GetIt.I<ShiftService>();
        await shift.onOpenShift(1, openingCash: d('10000'));
        expect(provider.calls, contains('openShift'));

        await shift.onCloseShift(d('25000'));
        expect(
          provider.calls,
          contains('closeShift'),
          reason: 'shift close must trigger a fiscal Z-report',
        );

        final closed = await db.shiftDao.findOpenedShift();
        expect(closed, isNull);
      }

      {
        _CapturingProvider? provider;
        final w = wire(db, (s) => provider ??= _CapturingProvider(s));

        final inRes = await w.service.moneyIn(
          amount: d('10000'),
          comment: 'фонд',
        );
        final outRes = await w.service.moneyOut(
          amount: d('5000'),
          comment: 'инкассация',
        );

        expect(inRes.success, isTrue);
        expect(outRes.success, isTrue);
        expect(provider!.calls, contains('moneyIn:10000'));
        expect(provider!.calls, contains('moneyOut:5000'));
      }

      {
        final w = wire(db, (s) => _CapturingProvider(s, offline: true));
        await seedFiscalSale(
          db,
          receiptNo: 7004,
          ucode: 9004,
          vatRate: 12,
          ntin: null,
          markable: false,
        );

        final res = await w.service.fiscalizeSale(
          saleReceiptNo: 7004,
          salePosId: 1,
          amount: d('500'),
          cashAmount: d('500'),
          cardAmount: Decimal.zero,
        );
        expect(res.success, isFalse, reason: 'offline → not fiscalized');
        final receipt = await db.webkassaReceiptDao.findByIsSaleAndOperationId(
          true,
          7004,
        );
        expect(receipt, isNull);
      }
    },
  );
}

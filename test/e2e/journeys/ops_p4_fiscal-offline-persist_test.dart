library;

import 'package:decimal/decimal.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:telepos/data/database/app_database.dart' hide FiscalQueueEntry;
import 'package:telepos/data/fiscal/drift_fiscal_queue_store.dart';
import 'package:telepos/data/fiscal/offline_queueing_provider.dart';
import 'package:telepos/domain/fiscal/fiscal_models.dart';
import 'package:telepos/domain/fiscal/fiscal_provider.dart';
import 'package:telepos/domain/fiscal/fiscal_settings.dart';

class _RecordingProvider implements FiscalProvider {
  _RecordingProvider();

  bool reachable = true;
  final List<String> fiscalizedKeys = [];

  @override
  String get id => 'recording';

  @override
  FiscalCapabilities get capabilities => FiscalCapabilities.none;

  @override
  Future<FiscalAuthResult> authorize(FiscalSettings config) async =>
      FiscalAuthResult.ok();

  @override
  String? validateConfig(FiscalSettings config) => null;

  @override
  Future<FiscalResult> fiscalizeSale(FiscalSaleRequest req) async {
    fiscalizedKeys.add(req.idempotencyKey);
    return FiscalResult.ok(fiscalSign: 'SIGN-${req.idempotencyKey}');
  }

  @override
  Future<FiscalResult> fiscalizeRefund(FiscalRefundRequest req) async =>
      FiscalResult.ok(fiscalSign: 'r');
  @override
  Future<FiscalResult> fiscalizePurchase(FiscalSaleRequest req) async =>
      FiscalResult.ok(fiscalSign: 'p');
  @override
  Future<FiscalResult> fiscalizePurchaseReturn(FiscalRefundRequest req) async =>
      FiscalResult.ok(fiscalSign: 'pr');
  @override
  Future<FiscalResult> moneyIn(FiscalMoneyRequest req) async =>
      FiscalResult.ok(fiscalSign: 'mi');
  @override
  Future<FiscalResult> moneyOut(FiscalMoneyRequest req) async =>
      FiscalResult.ok(fiscalSign: 'mo');
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

FiscalSaleRequest _saleReq(String guid, DateTime occurredAt) =>
    FiscalSaleRequest(
      idempotencyKey: guid,
      localOperationId: 42,
      positions: const [],
      payments: const [],
      totalDiscount: Decimal.zero,
      totalMarkup: Decimal.zero,
      occurredAt: occurredAt,
    );

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });
  tearDown(() => db.close());

  test(
    'offline-queued fiscal op persists to FiscalQueueEntries, survives a new '
    'store instance (restart), and replays to fiscalized idempotently',
    () async {
      const guid = 'GUID-OFFLINE-0001';
      final occurredAt = DateTime.now().subtract(const Duration(hours: 1));

      final writer = DriftFiscalQueueStore(db);
      await writer.enqueue(
        FiscalQueueEntry(
          idempotencyKey: guid,
          opType: FiscalQueueOp.sale,
          payload: _saleReq(guid, occurredAt).toJson(),
          occurredAt: occurredAt,
        ),
      );

      final rows = await db.select(db.fiscalQueueEntries).get();
      expect(
        rows.length,
        1,
        reason: 'exactly one queued op persisted to the DB',
      );
      expect(rows.first.idempotencyKey, guid);
      expect(
        rows.first.status,
        FiscalQueueStatus.pending.index,
        reason: 'persisted op is pending',
      );
      expect(
        rows.first.payload,
        contains(guid),
        reason: 'neutral DTO JSON is stored verbatim (replayable)',
      );

      await writer.enqueue(
        FiscalQueueEntry(
          idempotencyKey: guid,
          opType: FiscalQueueOp.sale,
          payload: _saleReq(guid, occurredAt).toJson(),
          occurredAt: occurredAt,
        ),
      );
      expect(
        await db.select(db.fiscalQueueEntries).get(),
        hasLength(1),
        reason: 're-enqueue of the same GUID is a no-op',
      );

      final afterRestart = DriftFiscalQueueStore(db);
      final pending = await afterRestart.pending();
      expect(pending, hasLength(1), reason: 'queued op SURVIVED the restart');
      expect(pending.first.idempotencyKey, guid);
      expect(pending.first.opType, FiscalQueueOp.sale);
      expect(
        pending.first.payload['idempotencyKey'],
        guid,
        reason: 'payload re-hydrated from persisted JSON',
      );
      expect(await afterRestart.pendingCount(), 1);

      final operator = _RecordingProvider()..reachable = true;
      final decorator = OfflineQueueingProvider(
        inner: operator,
        store: afterRestart,
        isReachable: () async => operator.reachable,
      );

      final report = await decorator.replay();
      expect(report.fiscalized, 1, reason: 'the survived op was fiscalized');
      expect(report.failed, 0);
      expect(report.remaining, 0, reason: 'queue drained');
      expect(
        operator.fiscalizedKeys,
        [guid],
        reason:
            'replayed with the ORIGINAL GUID → operator dedups (idempotent)',
      );

      expect(
        await db.select(db.fiscalQueueEntries).get(),
        isEmpty,
        reason: 'fiscalized op is removed from the drift queue',
      );
      expect(await afterRestart.pendingCount(), 0);

      final report2 = await decorator.replay();
      expect(report2.fiscalized, 0);
      expect(report2.remaining, 0);
      expect(
        operator.fiscalizedKeys,
        [guid],
        reason: 'no second send — replay is idempotent across restarts',
      );
    },
  );
}

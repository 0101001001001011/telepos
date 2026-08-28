import 'package:telepos/domain/fiscal/fiscal_models.dart';
import 'package:telepos/domain/fiscal/fiscal_provider.dart';
import 'package:telepos/domain/fiscal/fiscal_settings.dart';

class FiscalQueueEntry {
  FiscalQueueEntry({
    required this.idempotencyKey,
    required this.opType,
    required this.payload,
    required this.occurredAt,
    this.status = FiscalQueueStatus.pending,
    this.attempts = 0,
    this.lastError,
  });

  final String idempotencyKey;

  final FiscalQueueOp opType;

  final Map<String, dynamic> payload;

  final DateTime occurredAt;

  FiscalQueueStatus status;
  int attempts;
  String? lastError;

  Map<String, dynamic> toJson() => {
    'idempotencyKey': idempotencyKey,
    'opType': opType.name,
    'payload': payload,
    'occurredAt': occurredAt.toIso8601String(),
    'status': status.name,
    'attempts': attempts,
    if (lastError != null) 'lastError': lastError,
  };

  factory FiscalQueueEntry.fromJson(Map<String, dynamic> json) =>
      FiscalQueueEntry(
        idempotencyKey: json['idempotencyKey'] as String? ?? '',
        opType: FiscalQueueOp.values.byName(
          json['opType'] as String? ?? 'sale',
        ),
        payload: (json['payload'] as Map?)?.cast<String, dynamic>() ?? const {},
        occurredAt:
            DateTime.tryParse(json['occurredAt'] as String? ?? '') ??
            DateTime.now(),
        status: FiscalQueueStatus.values.byName(
          json['status'] as String? ?? 'pending',
        ),
        attempts: json['attempts'] as int? ?? 0,
        lastError: json['lastError'] as String?,
      );
}

enum FiscalQueueOp { sale, refund, purchase, purchaseReturn, moneyIn, moneyOut }

enum FiscalQueueStatus { pending, done, failed }

abstract interface class FiscalQueueStore {
  Future<void> enqueue(FiscalQueueEntry entry);

  Future<List<FiscalQueueEntry>> pending();

  Future<void> update(FiscalQueueEntry entry);

  Future<void> remove(String idempotencyKey);

  Future<int> pendingCount();
}

class InMemoryFiscalQueueStore implements FiscalQueueStore {
  final Map<String, FiscalQueueEntry> _entries = {};

  @override
  Future<void> enqueue(FiscalQueueEntry entry) async {
    _entries.putIfAbsent(entry.idempotencyKey, () => entry);
  }

  @override
  Future<List<FiscalQueueEntry>> pending() async {
    final list =
        _entries.values
            .where((e) => e.status == FiscalQueueStatus.pending)
            .toList()
          ..sort((a, b) => a.occurredAt.compareTo(b.occurredAt));
    return list;
  }

  @override
  Future<void> update(FiscalQueueEntry entry) async {
    _entries[entry.idempotencyKey] = entry;
  }

  @override
  Future<void> remove(String idempotencyKey) async {
    _entries.remove(idempotencyKey);
  }

  @override
  Future<int> pendingCount() async => (await pending()).length;
}

typedef FiscalReachabilityCheck = Future<bool> Function();

class FiscalReplayReport {
  const FiscalReplayReport({
    this.fiscalized = 0,
    this.deduped = 0,
    this.failed = 0,
    this.remaining = 0,
    this.stoppedOnNetwork = false,
  });

  final int fiscalized;

  final int deduped;

  final int failed;

  final int remaining;

  final bool stoppedOnNetwork;
}

const Duration kOfflineFiscalWindow = Duration(hours: 72);

class OfflineQueueingProvider implements FiscalProvider {
  OfflineQueueingProvider({
    required this.inner,
    required this.store,
    required FiscalReachabilityCheck isReachable,
    this.offlineWindow = kOfflineFiscalWindow,
    DateTime Function()? now,
  }) : _isReachable = isReachable,
       _now = now ?? DateTime.now;

  final FiscalProvider inner;

  final FiscalQueueStore store;

  final FiscalReachabilityCheck _isReachable;

  final Duration offlineWindow;

  final DateTime Function() _now;

  @override
  String get id => inner.id;

  @override
  FiscalCapabilities get capabilities => inner.capabilities;

  @override
  String? validateConfig(FiscalSettings config) => inner.validateConfig(config);

  @override
  Future<FiscalAuthResult> authorize(FiscalSettings config) =>
      inner.authorize(config);

  @override
  Future<FiscalResult> fiscalizeSale(FiscalSaleRequest req) => _guard(
    FiscalQueueOp.sale,
    req.idempotencyKey,
    req.occurredAt,
    req.toJson,
    () => inner.fiscalizeSale(req),
  );

  @override
  Future<FiscalResult> fiscalizeRefund(FiscalRefundRequest req) => _guard(
    FiscalQueueOp.refund,
    req.sale.idempotencyKey,
    req.sale.occurredAt,
    req.toJson,
    () => inner.fiscalizeRefund(req),
  );

  @override
  Future<FiscalResult> fiscalizePurchase(FiscalSaleRequest req) => _guard(
    FiscalQueueOp.purchase,
    req.idempotencyKey,
    req.occurredAt,
    req.toJson,
    () => inner.fiscalizePurchase(req),
  );

  @override
  Future<FiscalResult> fiscalizePurchaseReturn(FiscalRefundRequest req) =>
      _guard(
        FiscalQueueOp.purchaseReturn,
        req.sale.idempotencyKey,
        req.sale.occurredAt,
        req.toJson,
        () => inner.fiscalizePurchaseReturn(req),
      );

  @override
  Future<FiscalResult> moneyIn(FiscalMoneyRequest req) => _guard(
    FiscalQueueOp.moneyIn,
    req.idempotencyKey,
    req.occurredAt,
    req.toJson,
    () => inner.moneyIn(req),
  );

  @override
  Future<FiscalResult> moneyOut(FiscalMoneyRequest req) => _guard(
    FiscalQueueOp.moneyOut,
    req.idempotencyKey,
    req.occurredAt,
    req.toJson,
    () => inner.moneyOut(req),
  );

  Future<FiscalResult> _guard(
    FiscalQueueOp op,
    String idempotencyKey,
    DateTime occurredAt,
    Map<String, dynamic> Function() payload,
    Future<FiscalResult> Function() call,
  ) async {
    if (!await _reachableSafe()) {
      return _enqueue(op, idempotencyKey, occurredAt, payload());
    }
    final FiscalResult result;
    try {
      result = await call();
    } catch (_) {
      return _enqueue(op, idempotencyKey, occurredAt, payload());
    }
    if (result.success) return result;
    if (_isTransient(result.errorCode)) {
      return _enqueue(op, idempotencyKey, occurredAt, payload());
    }
    return result;
  }

  Future<FiscalResult> _enqueue(
    FiscalQueueOp op,
    String idempotencyKey,
    DateTime occurredAt,
    Map<String, dynamic> payload,
  ) async {
    await store.enqueue(
      FiscalQueueEntry(
        idempotencyKey: idempotencyKey,
        opType: op,
        payload: payload,
        occurredAt: occurredAt,
      ),
    );
    return FiscalResult.queued();
  }

  Future<bool> _reachableSafe() async {
    try {
      return await _isReachable();
    } catch (_) {
      return false;
    }
  }

  static bool _isTransient(FiscalErrorCode code) {
    switch (code) {
      case FiscalErrorCode.network:
      case FiscalErrorCode.tokenExpired:
        return true;
      case FiscalErrorCode.ok:
      case FiscalErrorCode.badCredentials:
      case FiscalErrorCode.cashboxNotFound:
      case FiscalErrorCode.cashboxBlocked:
      case FiscalErrorCode.offlineLimitExceeded:
      case FiscalErrorCode.offlineNotSupported:
      case FiscalErrorCode.duplicate:
      case FiscalErrorCode.validation:
      case FiscalErrorCode.notEnoughMoney:
      case FiscalErrorCode.shiftError:
      case FiscalErrorCode.unsupported:
      case FiscalErrorCode.notConfigured:
      case FiscalErrorCode.unknown:
        return false;
    }
  }

  Future<FiscalReplayReport> replay() async {
    if (!await _reachableSafe()) {
      final remaining = await store.pendingCount();
      return FiscalReplayReport(remaining: remaining, stoppedOnNetwork: true);
    }

    var fiscalized = 0;
    var deduped = 0;
    var failed = 0;

    final entries = await store.pending();
    for (final entry in entries) {
      if (_now().difference(entry.occurredAt) > offlineWindow) {
        entry
          ..status = FiscalQueueStatus.failed
          ..lastError =
              'Превышено автономное окно 72ч (документ не фискализирован)';
        await store.update(entry);
        failed++;
        continue;
      }

      final FiscalResult result;
      try {
        result = await _dispatch(entry);
      } catch (_) {
        return FiscalReplayReport(
          fiscalized: fiscalized,
          deduped: deduped,
          failed: failed,
          remaining: await store.pendingCount(),
          stoppedOnNetwork: true,
        );
      }

      if (result.success) {
        await store.remove(entry.idempotencyKey);
        fiscalized++;
      } else if (result.errorCode == FiscalErrorCode.duplicate) {
        await store.remove(entry.idempotencyKey);
        deduped++;
      } else if (result.errorCode == FiscalErrorCode.network) {
        return FiscalReplayReport(
          fiscalized: fiscalized,
          deduped: deduped,
          failed: failed,
          remaining: await store.pendingCount(),
          stoppedOnNetwork: true,
        );
      } else {
        entry
          ..status = FiscalQueueStatus.failed
          ..attempts = entry.attempts + 1
          ..lastError = result.errorMessage ?? result.errorCode.name;
        await store.update(entry);
        failed++;
      }
    }

    return FiscalReplayReport(
      fiscalized: fiscalized,
      deduped: deduped,
      failed: failed,
      remaining: await store.pendingCount(),
    );
  }

  Future<FiscalResult> _dispatch(FiscalQueueEntry entry) {
    switch (entry.opType) {
      case FiscalQueueOp.sale:
        return inner.fiscalizeSale(FiscalSaleRequest.fromJson(entry.payload));
      case FiscalQueueOp.refund:
        return inner.fiscalizeRefund(
          FiscalRefundRequest.fromJson(entry.payload),
        );
      case FiscalQueueOp.purchase:
        return inner.fiscalizePurchase(
          FiscalSaleRequest.fromJson(entry.payload),
        );
      case FiscalQueueOp.purchaseReturn:
        return inner.fiscalizePurchaseReturn(
          FiscalRefundRequest.fromJson(entry.payload),
        );
      case FiscalQueueOp.moneyIn:
        return inner.moneyIn(FiscalMoneyRequest.fromJson(entry.payload));
      case FiscalQueueOp.moneyOut:
        return inner.moneyOut(FiscalMoneyRequest.fromJson(entry.payload));
    }
  }

  Future<int> pendingCount() => store.pendingCount();

  @override
  Future<FiscalResult> openShift(FiscalShiftRequest req) =>
      inner.openShift(req);

  @override
  Future<FiscalReportResult> closeShift(FiscalShiftRequest req) =>
      inner.closeShift(req);

  @override
  Future<FiscalReportResult> xReport(FiscalShiftRequest req) =>
      inner.xReport(req);

  @override
  Future<FiscalResult> correctionReceipt(FiscalCorrectionRequest req) =>
      inner.correctionReceipt(req);

  @override
  Future<FiscalStatus> getStatus() => inner.getStatus();
}

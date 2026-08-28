import 'package:decimal/decimal.dart';

import 'package:telepos/domain/snt/snt_models.dart';
import 'package:telepos/domain/snt/snt_provider.dart';
import 'package:telepos/domain/snt/snt_store.dart';

typedef SntReachabilityCheck = Future<bool> Function();

class SntOutboxReport {
  const SntOutboxReport({
    this.submitted = 0,
    this.unsupported = 0,
    this.failed = 0,
    this.remaining = 0,
    this.stoppedOnNetwork = false,
  });

  final int submitted;

  final int unsupported;

  final int failed;

  final int remaining;

  final bool stoppedOnNetwork;
}

class SntService {
  SntService({
    required this.provider,
    required this.store,
    required this.warehouse,
    SntReachabilityCheck? isReachable,
  }) : _isReachable = isReachable ?? (() async => true);

  final SntProvider provider;
  final SntDocumentStore store;
  final VirtualWarehouseStore warehouse;
  final SntReachabilityCheck _isReachable;

  Future<void> saveDraft(SntDocument doc) =>
      store.save(doc.copyWith(status: SntStatus.draft));

  Future<SntResult> register(SntDocument doc) async {
    if (!await _reachableSafe()) {
      await store.save(doc.copyWith(status: SntStatus.queued));
      return SntResult.queued();
    }
    final SntResult result;
    try {
      result = await provider.submit(doc);
    } catch (_) {
      await store.save(doc.copyWith(status: SntStatus.queued));
      return SntResult.queued();
    }
    if (result.success) {
      await store.save(
        doc.copyWith(
          status: result.status ?? SntStatus.registered,
          registrationNumber: result.registrationNumber,
        ),
      );
      return result;
    }
    if (result.errorCode == SntErrorCode.unsupported ||
        result.errorCode == SntErrorCode.notConfigured ||
        result.errorCode == SntErrorCode.network) {
      await store.save(
        doc.copyWith(status: SntStatus.queued, lastError: result.errorMessage),
      );
      return result;
    }
    await store.save(
      doc.copyWith(status: SntStatus.failed, lastError: result.errorMessage),
    );
    return result;
  }

  Future<List<VirtualWarehouseBalance>> confirmInbound(SntDocument doc) async {
    if (doc.direction != SntDirection.inbound) {
      throw ArgumentError('confirmInbound requires an inbound СНТ');
    }
    final result = await provider.confirmInbound(doc);
    if (!result.success) {
      await store.save(
        doc.copyWith(status: SntStatus.failed, lastError: result.errorMessage),
      );
      return const [];
    }
    final balances = await _bookMovement(doc, sign: Decimal.one);
    await store.save(doc.copyWith(status: SntStatus.confirmed));
    return balances;
  }

  Future<SntResult> rejectInbound(SntDocument doc, {String? reason}) async {
    final result = await provider.rejectInbound(doc, reason: reason);
    await store.save(
      doc.copyWith(
        status: result.success ? SntStatus.rejected : SntStatus.failed,
        lastError: result.success ? null : result.errorMessage,
      ),
    );
    return result;
  }

  Future<List<VirtualWarehouseBalance>> confirmOutbound(SntDocument doc) async {
    if (doc.direction != SntDirection.outbound) {
      throw ArgumentError('confirmOutbound requires an outbound СНТ');
    }
    final balances = await _bookMovement(doc, sign: -Decimal.one);
    await store.save(doc.copyWith(status: SntStatus.confirmed));
    return balances;
  }

  Future<SntOutboxReport> drainOutbox() async {
    if (!await _reachableSafe()) {
      final remaining = (await store.outbox()).length;
      return SntOutboxReport(remaining: remaining, stoppedOnNetwork: true);
    }
    var submitted = 0;
    var unsupported = 0;
    var failed = 0;

    final queued = await store.outbox();
    for (final doc in queued) {
      final SntResult result;
      try {
        result = await provider.submit(doc);
      } catch (_) {
        return SntOutboxReport(
          submitted: submitted,
          unsupported: unsupported,
          failed: failed,
          remaining: (await store.outbox()).length,
          stoppedOnNetwork: true,
        );
      }
      if (result.success) {
        await store.save(
          doc.copyWith(
            status: result.status ?? SntStatus.registered,
            registrationNumber: result.registrationNumber,
          ),
        );
        submitted++;
      } else if (result.errorCode == SntErrorCode.unsupported ||
          result.errorCode == SntErrorCode.notConfigured) {
        unsupported++;
      } else if (result.errorCode == SntErrorCode.network) {
        return SntOutboxReport(
          submitted: submitted,
          unsupported: unsupported,
          failed: failed,
          remaining: (await store.outbox()).length,
          stoppedOnNetwork: true,
        );
      } else {
        await store.save(
          doc.copyWith(
            status: SntStatus.failed,
            lastError: result.errorMessage,
          ),
        );
        failed++;
      }
    }
    return SntOutboxReport(
      submitted: submitted,
      unsupported: unsupported,
      failed: failed,
      remaining: (await store.outbox()).length,
    );
  }

  Future<List<VirtualWarehouseBalance>> balances() => warehouse.all();

  Future<List<VirtualWarehouseBalance>> _bookMovement(
    SntDocument doc, {
    required Decimal sign,
  }) async {
    final out = <VirtualWarehouseBalance>[];
    for (final line in doc.lines) {
      final b = await warehouse.applyDelta(
        productCode: line.productCode,
        name: line.name,
        delta: sign * line.quantity,
        unitCode: line.unitCode,
        warehouseCode: doc.direction == SntDirection.inbound
            ? doc.recipient.warehouseCode
            : doc.sender.warehouseCode,
        originCountry: line.originCountry,
      );
      out.add(b);
    }
    return out;
  }

  Future<bool> _reachableSafe() async {
    try {
      return await _isReachable();
    } catch (_) {
      return false;
    }
  }
}

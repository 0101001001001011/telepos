import 'package:telepos/data/esf/esf_outbox_store.dart';
import 'package:telepos/domain/esf/esf_models.dart';
import 'package:telepos/domain/esf/esf_provider.dart';
import 'package:telepos/domain/esf/esf_settings.dart';

typedef EsfReachabilityCheck = Future<bool> Function();

class EsfReplayReport {
  const EsfReplayReport({
    this.delivered = 0,
    this.stillQueued = 0,
    this.failed = 0,
    this.remaining = 0,
    this.stoppedOnNetwork = false,
  });

  final int delivered;

  final int stillQueued;

  final int failed;

  final int remaining;

  final bool stoppedOnNetwork;
}

const Duration kEsfDemandWindow = Duration(days: 15);

class OfflineEsfProvider implements EsfProvider {
  OfflineEsfProvider({
    required this.inner,
    required this.store,
    required EsfReachabilityCheck isReachable,
  }) : _isReachable = isReachable;

  final EsfProvider inner;

  final EsfOutboxStore store;

  final EsfReachabilityCheck _isReachable;

  @override
  String get id => inner.id;

  @override
  EsfCapabilities get capabilities => inner.capabilities;

  @override
  String? validateConfig(EsfSettings config) => inner.validateConfig(config);

  @override
  Future<EsfProviderStatus> providerStatus(EsfSettings config) =>
      inner.providerStatus(config);

  @override
  Future<EsfResult> submit(EsfInvoice invoice) async {
    final entry = await _ensureQueued(invoice);

    if (!await _reachableSafe()) {
      return EsfResult.queued();
    }

    final EsfResult result;
    try {
      result = await inner.submit(invoice);
    } catch (_) {
      return EsfResult.queued();
    }

    return _applyResult(entry, result, queueOnTransient: true);
  }

  Future<EsfReplayReport> replay() async {
    if (!await _reachableSafe()) {
      return EsfReplayReport(
        remaining: await store.pendingCount(),
        stoppedOnNetwork: true,
      );
    }

    var delivered = 0;
    var stillQueued = 0;
    var failed = 0;

    for (final entry in await store.pending()) {
      final EsfResult result;
      try {
        result = await inner.submit(entry.invoice);
      } catch (_) {
        return EsfReplayReport(
          delivered: delivered,
          stillQueued: stillQueued,
          failed: failed,
          remaining: await store.pendingCount(),
          stoppedOnNetwork: true,
        );
      }

      if (result.errorCode == EsfErrorCode.network) {
        return EsfReplayReport(
          delivered: delivered,
          stillQueued: stillQueued,
          failed: failed,
          remaining: await store.pendingCount(),
          stoppedOnNetwork: true,
        );
      }

      final applied = await _applyResult(
        entry,
        result,
        queueOnTransient: false,
      );
      switch (applied.status) {
        case EsfStatus.delivered:
          delivered++;
          break;
        case EsfStatus.queued:
        case EsfStatus.submitted:
          stillQueued++;
          break;
        default:
          failed++;
      }
    }

    return EsfReplayReport(
      delivered: delivered,
      stillQueued: stillQueued,
      failed: failed,
      remaining: await store.pendingCount(),
    );
  }

  @override
  Future<EsfResult> getStatus(String registrationNumber) =>
      inner.getStatus(registrationNumber);

  @override
  Future<EsfResult> revoke(EsfInvoice invoice, {String? reason}) =>
      inner.revoke(invoice, reason: reason);

  Future<int> pendingCount() => store.pendingCount();

  Future<EsfOutboxEntry> _ensureQueued(EsfInvoice invoice) async {
    final existing = await store.find(invoice.idempotencyKey);
    if (existing != null) return existing;
    final entry = EsfOutboxEntry(invoice: invoice, status: EsfStatus.queued);
    await store.enqueue(entry);
    return entry;
  }

  Future<EsfResult> _applyResult(
    EsfOutboxEntry entry,
    EsfResult result, {
    required bool queueOnTransient,
  }) async {
    entry.attempts += 1;

    if (result.success && result.status == EsfStatus.delivered) {
      entry.status = EsfStatus.delivered;
      entry.lastError = null;
      if (result.registrationNumber != null) {
        entry.invoice = entry.invoice.copyWith(
          registrationNumber: result.registrationNumber,
        );
      }
      await store.update(entry);
      return result;
    }

    if (result.errorCode == EsfErrorCode.network) {
      entry.status = EsfStatus.queued;
      entry.lastError = result.errorMessage;
      await store.update(entry);
      return queueOnTransient ? EsfResult.queued() : result;
    }

    entry.status = EsfStatus.error;
    entry.lastError = result.errorMessage ?? result.errorCode.name;
    await store.update(entry);
    return result;
  }

  Future<bool> _reachableSafe() async {
    try {
      return await _isReachable();
    } catch (_) {
      return false;
    }
  }
}

import 'package:telepos/domain/ismpt/ismpt_models.dart';
import 'package:telepos/domain/ismpt/ismpt_service.dart';

class IsMptQueueEntry {
  IsMptQueueEntry({
    required this.idempotencyKey,
    required this.payload,
    required this.occurredAt,
    this.status = IsMptQueueStatus.pending,
    this.attempts = 0,
    this.lastError,
  });

  final String idempotencyKey;

  final Map<String, dynamic> payload;

  final DateTime occurredAt;

  IsMptQueueStatus status;
  int attempts;
  String? lastError;

  Map<String, dynamic> toJson() => {
    'idempotencyKey': idempotencyKey,
    'payload': payload,
    'occurredAt': occurredAt.toIso8601String(),
    'status': status.name,
    'attempts': attempts,
    if (lastError != null) 'lastError': lastError,
  };

  factory IsMptQueueEntry.fromJson(Map<String, dynamic> json) =>
      IsMptQueueEntry(
        idempotencyKey: json['idempotencyKey'] as String? ?? '',
        payload: (json['payload'] as Map?)?.cast<String, dynamic>() ?? const {},
        occurredAt:
            DateTime.tryParse(json['occurredAt'] as String? ?? '') ??
            DateTime.now(),
        status: IsMptQueueStatus.values.byName(
          json['status'] as String? ?? 'pending',
        ),
        attempts: json['attempts'] as int? ?? 0,
        lastError: json['lastError'] as String?,
      );
}

enum IsMptQueueStatus { pending, done, failed }

abstract interface class IsMptQueueStore {
  Future<void> enqueue(IsMptQueueEntry entry);
  Future<List<IsMptQueueEntry>> pending();
  Future<void> update(IsMptQueueEntry entry);
  Future<void> remove(String idempotencyKey);
  Future<int> pendingCount();
}

class InMemoryIsMptQueueStore implements IsMptQueueStore {
  final Map<String, IsMptQueueEntry> _entries = {};

  @override
  Future<void> enqueue(IsMptQueueEntry entry) async {
    _entries.putIfAbsent(entry.idempotencyKey, () => entry);
  }

  @override
  Future<List<IsMptQueueEntry>> pending() async {
    final list =
        _entries.values
            .where((e) => e.status == IsMptQueueStatus.pending)
            .toList()
          ..sort((a, b) => a.occurredAt.compareTo(b.occurredAt));
    return list;
  }

  @override
  Future<void> update(IsMptQueueEntry entry) async {
    _entries[entry.idempotencyKey] = entry;
  }

  @override
  Future<void> remove(String idempotencyKey) async {
    _entries.remove(idempotencyKey);
  }

  @override
  Future<int> pendingCount() async => (await pending()).length;
}

typedef IsMptReachabilityCheck = Future<bool> Function();

class IsMptReplayReport {
  const IsMptReplayReport({
    this.submitted = 0,
    this.deduped = 0,
    this.failed = 0,
    this.remaining = 0,
    this.stoppedOnNetwork = false,
  });

  final int submitted;
  final int deduped;
  final int failed;
  final int remaining;
  final bool stoppedOnNetwork;
}

class IsMptOfflineQueueingProvider implements IsMptService {
  IsMptOfflineQueueingProvider({
    required this.inner,
    required this.store,
    required IsMptReachabilityCheck isReachable,
  }) : _isReachable = isReachable;

  final IsMptService inner;
  final IsMptQueueStore store;
  final IsMptReachabilityCheck _isReachable;

  @override
  String get id => inner.id;

  @override
  IsMptCapabilities get capabilities => inner.capabilities;

  @override
  Future<IsMptResult> authorize() async {
    try {
      return await inner.authorize();
    } catch (e) {
      return IsMptResult.failure('$e', code: IsMptErrorCode.network);
    }
  }

  @override
  Future<IsMptVerifyResult> verifyCodes(
    List<String> codes, {
    String? productGroup,
  }) async {
    if (!await _reachableSafe()) {
      return const IsMptVerifyResult(
        success: false,
        queued: true,
        errorMessage: 'Нет связи с ИС МПТ — проверка статуса отложена',
        errorCode: IsMptErrorCode.network,
      );
    }
    try {
      return await inner.verifyCodes(codes, productGroup: productGroup);
    } catch (e) {
      return IsMptVerifyResult.failure('$e', code: IsMptErrorCode.network);
    }
  }

  @override
  Future<IsMptResult> submitDocument(IsMptDocRequest req) async {
    if (!await _reachableSafe()) return _enqueue(req);
    final IsMptResult result;
    try {
      result = await inner.submitDocument(req);
    } catch (_) {
      return _enqueue(req);
    }
    if (result.success) return result;
    if (result.errorCode == IsMptErrorCode.network) return _enqueue(req);
    return result;
  }

  Future<IsMptResult> _enqueue(IsMptDocRequest req) async {
    await store.enqueue(
      IsMptQueueEntry(
        idempotencyKey: req.idempotencyKey,
        payload: req.toJson(),
        occurredAt: req.occurredAt ?? DateTime.now(),
      ),
    );
    return IsMptResult.queued();
  }

  Future<bool> _reachableSafe() async {
    try {
      return await _isReachable();
    } catch (_) {
      return false;
    }
  }

  Future<IsMptReplayReport> replay() async {
    if (!await _reachableSafe()) {
      return IsMptReplayReport(
        remaining: await store.pendingCount(),
        stoppedOnNetwork: true,
      );
    }

    var submitted = 0;
    var deduped = 0;
    var failed = 0;

    for (final entry in await store.pending()) {
      final IsMptResult result;
      try {
        result = await inner.submitDocument(
          IsMptDocRequest.fromJson(entry.payload),
        );
      } catch (_) {
        return IsMptReplayReport(
          submitted: submitted,
          deduped: deduped,
          failed: failed,
          remaining: await store.pendingCount(),
          stoppedOnNetwork: true,
        );
      }

      if (result.success) {
        await store.remove(entry.idempotencyKey);
        submitted++;
      } else if (result.errorCode == IsMptErrorCode.network) {
        return IsMptReplayReport(
          submitted: submitted,
          deduped: deduped,
          failed: failed,
          remaining: await store.pendingCount(),
          stoppedOnNetwork: true,
        );
      } else {
        entry
          ..status = IsMptQueueStatus.failed
          ..attempts = entry.attempts + 1
          ..lastError = result.errorMessage ?? result.errorCode.name;
        await store.update(entry);
        failed++;
      }
    }

    return IsMptReplayReport(
      submitted: submitted,
      deduped: deduped,
      failed: failed,
      remaining: await store.pendingCount(),
    );
  }

  Future<int> pendingCount() => store.pendingCount();

  @override
  Future<IsMptStatus> getStatus() async {
    try {
      return await inner.getStatus();
    } catch (e) {
      return IsMptStatus(configured: true, online: false, lastError: '$e');
    }
  }
}

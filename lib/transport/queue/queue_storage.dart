import 'queued_operation.dart';

abstract class QueueStorage {
  Future<void> initialize();

  Future<void> add(QueuedOperation operation);

  Future<void> addAll(List<QueuedOperation> operations);

  Future<void> update(QueuedOperation operation);

  Future<void> remove(String operationId);

  Future<void> removeAll(List<String> operationIds);

  Future<QueuedOperation?> get(String operationId);

  Future<List<QueuedOperation>> getAll();

  Future<List<QueuedOperation>> getByStatus(QueuedOperationStatus status);

  Future<List<QueuedOperation>> getPendingOperations();

  Future<List<QueuedOperation>> getByGroup(String groupId);

  Future<int> count();

  Future<int> countByStatus(QueuedOperationStatus status);

  Future<int> clearCompleted({Duration age = const Duration(days: 7)});

  Future<void> clearAll();

  Future<void> dispose();
}

class QueueStatistics {
  final int total;

  final int pending;

  final int inProgress;

  final int retrying;

  final int completed;

  final int failed;

  final int cancelled;

  const QueueStatistics({
    this.total = 0,
    this.pending = 0,
    this.inProgress = 0,
    this.retrying = 0,
    this.completed = 0,
    this.failed = 0,
    this.cancelled = 0,
  });

  bool get hasPending => pending > 0 || retrying > 0;

  double get successRate {
    final processed = completed + failed;
    if (processed == 0) return 0;
    return completed / processed;
  }

  @override
  String toString() =>
      'QueueStats(pending=$pending, '
      'inProgress=$inProgress, completed=$completed, failed=$failed)';
}

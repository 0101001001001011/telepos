import 'dart:async';

import '../interface/transport_interface_exports.dart';
import 'queue_storage.dart';
import 'queued_operation.dart';

sealed class QueueEvent {
  const QueueEvent();
}

class OperationEnqueued extends QueueEvent {
  final QueuedOperation operation;
  const OperationEnqueued(this.operation);
}

class OperationCompleted extends QueueEvent {
  final QueuedOperation operation;
  const OperationCompleted(this.operation);
}

class OperationFailed extends QueueEvent {
  final QueuedOperation operation;
  final String error;
  const OperationFailed(this.operation, this.error);
}

class OperationRetrying extends QueueEvent {
  final QueuedOperation operation;
  final int attemptNumber;
  const OperationRetrying(this.operation, this.attemptNumber);
}

class QueueDrained extends QueueEvent {
  const QueueDrained();
}

class QueuePaused extends QueueEvent {
  final String reason;
  const QueuePaused(this.reason);
}

class QueueResumed extends QueueEvent {
  const QueueResumed();
}

class OfflineQueue {
  final QueueStorage storage;

  final Future<TransportResult<dynamic>> Function(
    TransportOperation operation,
    Map<String, dynamic> data,
  )?
  executor;

  final int maxConcurrency;

  final Duration checkInterval;

  final void Function(String message)? logger;

  Timer? _processTimer;
  bool _isProcessing = false;
  bool _isPaused = false;
  int _runningOperations = 0;

  final _eventController = StreamController<QueueEvent>.broadcast();

  OfflineQueue({
    required this.storage,
    this.executor,
    this.maxConcurrency = 3,
    this.checkInterval = const Duration(seconds: 30),
    this.logger,
  });

  Stream<QueueEvent> get eventStream => _eventController.stream;

  bool get isPaused => _isPaused;

  bool get isProcessing => _isProcessing;

  Future<void> initialize() async {
    await storage.initialize();
    _startPeriodicCheck();
    _log('OfflineQueue initialized');
  }

  Future<String> enqueue({
    required TransportOperation operation,
    required Map<String, dynamic> data,
    TransportType preferredTransport = TransportType.none,
    int? priority,
    String? groupId,
  }) async {
    final id = _generateId();

    final queuedOp = operation.isCritical
        ? QueuedOperation.critical(
            id: id,
            operation: operation,
            data: data,
            preferredTransport: preferredTransport,
            groupId: groupId,
          )
        : QueuedOperation.create(
            id: id,
            operation: operation,
            data: data,
            preferredTransport: preferredTransport,
            priority: priority ?? 0,
            groupId: groupId,
          );

    await storage.add(queuedOp);
    _eventController.add(OperationEnqueued(queuedOp));
    _log('Enqueued: $operation (id=$id)');

    _scheduleProcessing();

    return id;
  }

  Future<List<String>> enqueueBatch({
    required TransportOperation operation,
    required List<Map<String, dynamic>> dataList,
    TransportType preferredTransport = TransportType.none,
  }) async {
    final groupId = _generateId();
    final ids = <String>[];

    final operations = dataList.map((data) {
      final id = _generateId();
      ids.add(id);
      return QueuedOperation.create(
        id: id,
        operation: operation,
        data: data,
        preferredTransport: preferredTransport,
        groupId: groupId,
      );
    }).toList();

    await storage.addAll(operations);
    for (final op in operations) {
      _eventController.add(OperationEnqueued(op));
    }

    _log('Enqueued batch: ${operations.length} operations (group=$groupId)');
    _scheduleProcessing();

    return ids;
  }

  Future<bool> cancel(String operationId) async {
    final operation = await storage.get(operationId);
    if (operation == null) return false;

    if (operation.status == QueuedOperationStatus.inProgress) {
      return false;
    }

    await storage.update(operation.markCancelled());
    _log('Cancelled: $operationId');
    return true;
  }

  Future<int> cancelGroup(String groupId) async {
    final operations = await storage.getByGroup(groupId);
    int cancelled = 0;

    for (final op in operations) {
      if (op.status != QueuedOperationStatus.inProgress) {
        await storage.update(op.markCancelled());
        cancelled++;
      }
    }

    _log('Cancelled group $groupId: $cancelled operations');
    return cancelled;
  }

  Future<bool> retry(String operationId) async {
    final operation = await storage.get(operationId);
    if (operation == null) return false;

    if (operation.status != QueuedOperationStatus.failed) {
      return false;
    }

    await storage.update(operation.reset());
    _log('Retry scheduled: $operationId');
    _scheduleProcessing();
    return true;
  }

  Future<int> retryAllFailed() async {
    final failed = await storage.getByStatus(QueuedOperationStatus.failed);
    for (final op in failed) {
      await storage.update(op.reset());
    }

    _log('Retry scheduled for ${failed.length} failed operations');
    _scheduleProcessing();
    return failed.length;
  }

  void pause([String reason = 'manual']) {
    if (_isPaused) return;
    _isPaused = true;
    _eventController.add(QueuePaused(reason));
    _log('Queue paused: $reason');
  }

  void resume() {
    if (!_isPaused) return;
    _isPaused = false;
    _eventController.add(const QueueResumed());
    _log('Queue resumed');
    _scheduleProcessing();
  }

  Future<void> processQueue() async {
    if (_isPaused) {
      _log('Queue is paused, skipping processing');
      return;
    }

    if (_isProcessing) {
      _log('Already processing');
      return;
    }

    _isProcessing = true;

    try {
      await _processQueueInternal();
    } finally {
      _isProcessing = false;
    }
  }

  Future<QueuedOperation?> getOperationStatus(String operationId) {
    return storage.get(operationId);
  }

  Future<List<QueuedOperation>> getPendingOperations() {
    return storage.getPendingOperations();
  }

  Future<QueueStatistics> getStatistics() async {
    final all = await storage.getAll();

    int pending = 0;
    int inProgress = 0;
    int retrying = 0;
    int completed = 0;
    int failed = 0;
    int cancelled = 0;

    for (final op in all) {
      switch (op.status) {
        case QueuedOperationStatus.pending:
          pending++;
        case QueuedOperationStatus.inProgress:
          inProgress++;
        case QueuedOperationStatus.retrying:
          retrying++;
        case QueuedOperationStatus.completed:
          completed++;
        case QueuedOperationStatus.failed:
          failed++;
        case QueuedOperationStatus.cancelled:
          cancelled++;
      }
    }

    return QueueStatistics(
      total: all.length,
      pending: pending,
      inProgress: inProgress,
      retrying: retrying,
      completed: completed,
      failed: failed,
      cancelled: cancelled,
    );
  }

  Future<int> clearCompleted({Duration age = const Duration(days: 7)}) {
    return storage.clearCompleted(age: age);
  }

  Future<void> dispose() async {
    _processTimer?.cancel();
    await _eventController.close();
    await storage.dispose();
  }

  void _startPeriodicCheck() {
    _processTimer?.cancel();
    _processTimer = Timer.periodic(checkInterval, (_) {
      processQueue();
    });
  }

  void _scheduleProcessing() {
    Future.delayed(const Duration(milliseconds: 100), () {
      processQueue();
    });
  }

  Future<void> _processQueueInternal() async {
    if (executor == null) {
      _log('No executor configured, skipping processing');
      return;
    }

    while (true) {
      if (_isPaused) break;

      final pending = await storage.getPendingOperations();
      if (pending.isEmpty) {
        _eventController.add(const QueueDrained());
        break;
      }

      final toProcess = pending.take(maxConcurrency - _runningOperations);
      if (toProcess.isEmpty) {
        await Future.delayed(const Duration(seconds: 1));
        continue;
      }

      await Future.wait(toProcess.map((op) => _executeOperation(op)));
    }
  }

  Future<void> _executeOperation(QueuedOperation operation) async {
    _runningOperations++;

    try {
      final inProgress = operation.markInProgress();
      await storage.update(inProgress);

      _log('Executing: ${operation.operation} (id=${operation.id})');

      final result = await executor!(operation.operation, operation.data);

      if (result.isSuccess) {
        await storage.update(inProgress.markCompleted());
        _eventController.add(OperationCompleted(inProgress));
        _log('Completed: ${operation.id}');
      } else {
        final error = result.errorOrNull?.message ?? 'Unknown error';

        if (result.errorOrNull?.isRetryable ?? true) {
          final retrying = inProgress.markForRetry(error);
          await storage.update(retrying);
          _eventController.add(
            OperationRetrying(retrying, retrying.attemptCount),
          );
          _log('Retrying: ${operation.id} (attempt ${retrying.attemptCount})');
        } else {
          final failed = inProgress.markFailed(error);
          await storage.update(failed);
          _eventController.add(OperationFailed(failed, error));
          _log('Failed (not retryable): ${operation.id} - $error');
        }
      }
    } catch (e) {
      final error = e.toString();
      final retrying = operation.markForRetry(error);
      await storage.update(retrying);
      _eventController.add(OperationRetrying(retrying, retrying.attemptCount));
      _log('Error executing ${operation.id}: $e');
    } finally {
      _runningOperations--;
    }
  }

  String _generateId() {
    final now = DateTime.now();
    final timestamp = now.millisecondsSinceEpoch;
    final random = now.microsecond;
    return '$timestamp-$random';
  }

  void _log(String message) {
    logger?.call('[OfflineQueue] $message');
  }
}

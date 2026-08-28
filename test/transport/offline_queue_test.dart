import 'package:flutter_test/flutter_test.dart';
import 'package:telepos/transport/transport_exports.dart';

void main() {
  group('QueuedOperationStatus', () {
    test('has all expected values', () {
      expect(QueuedOperationStatus.values.length, 6);
      expect(QueuedOperationStatus.pending, isNotNull);
      expect(QueuedOperationStatus.inProgress, isNotNull);
      expect(QueuedOperationStatus.retrying, isNotNull);
      expect(QueuedOperationStatus.completed, isNotNull);
      expect(QueuedOperationStatus.failed, isNotNull);
      expect(QueuedOperationStatus.cancelled, isNotNull);
    });
  });

  group('QueuedOperation', () {
    test('creates with factory', () {
      final operation = QueuedOperation.create(
        id: 'op-123',
        operation: TransportOperation.uploadSales,
        data: {'sales': []},
      );

      expect(operation.id, 'op-123');
      expect(operation.operation, TransportOperation.uploadSales);
      expect(operation.status, QueuedOperationStatus.pending);
      expect(operation.attemptCount, 0);
    });

    test('creates critical operation with high priority', () {
      final operation = QueuedOperation.critical(
        id: 'op-critical',
        operation: TransportOperation.uploadSales,
        data: {'sales': []},
      );

      expect(operation.priority, 100);
      expect(operation.maxAttempts, 10);
      expect(operation.isCritical, isTrue);
    });

    test('data getter deserializes payload', () {
      final operation = QueuedOperation.create(
        id: 'op-123',
        operation: TransportOperation.uploadSales,
        data: {'key': 'value', 'number': 42},
      );

      expect(operation.data, {'key': 'value', 'number': 42});
    });

    test('markInProgress changes status', () {
      final operation = QueuedOperation.create(
        id: 'op-123',
        operation: TransportOperation.uploadSales,
        data: {},
      );

      final inProgress = operation.markInProgress();

      expect(inProgress.status, QueuedOperationStatus.inProgress);
      expect(inProgress.lastAttemptAt, isNotNull);
      expect(operation.status, QueuedOperationStatus.pending);
    });

    test('markCompleted changes status', () {
      final operation = QueuedOperation.create(
        id: 'op-123',
        operation: TransportOperation.uploadSales,
        data: {},
      ).markInProgress();

      final completed = operation.markCompleted();

      expect(completed.status, QueuedOperationStatus.completed);
    });

    test('markForRetry increments attempt count', () {
      final operation = QueuedOperation.create(
        id: 'op-123',
        operation: TransportOperation.uploadSales,
        data: {},
        maxAttempts: 5,
      );

      final retrying = operation.markForRetry('Test error');

      expect(retrying.status, QueuedOperationStatus.retrying);
      expect(retrying.attemptCount, 1);
      expect(retrying.lastError, 'Test error');
      expect(retrying.nextAttemptAt, isNotNull);
    });

    test('markForRetry becomes failed when max attempts reached', () {
      final operation = QueuedOperation.create(
        id: 'op-123',
        operation: TransportOperation.uploadSales,
        data: {},
        maxAttempts: 1,
      );

      final failed = operation.markForRetry('Final error');

      expect(failed.status, QueuedOperationStatus.failed);
      expect(failed.lastError, 'Final error');
    });

    test('markFailed sets error', () {
      final operation = QueuedOperation.create(
        id: 'op-123',
        operation: TransportOperation.uploadSales,
        data: {},
      );

      final failed = operation.markFailed('Critical failure');

      expect(failed.status, QueuedOperationStatus.failed);
      expect(failed.lastError, 'Critical failure');
    });

    test('markCancelled changes status', () {
      final operation = QueuedOperation.create(
        id: 'op-123',
        operation: TransportOperation.uploadSales,
        data: {},
      );

      final cancelled = operation.markCancelled();

      expect(cancelled.status, QueuedOperationStatus.cancelled);
    });

    test('reset clears attempt count', () {
      final operation = QueuedOperation.create(
        id: 'op-123',
        operation: TransportOperation.uploadSales,
        data: {},
      ).markForRetry('Error 1').markForRetry('Error 2');

      final reset = operation.reset();

      expect(reset.status, QueuedOperationStatus.pending);
      expect(reset.attemptCount, 0);
    });

    test('hasRemainingAttempts returns correct value', () {
      final fresh = QueuedOperation.create(
        id: 'op-123',
        operation: TransportOperation.uploadSales,
        data: {},
        maxAttempts: 3,
      );
      expect(fresh.hasRemainingAttempts, isTrue);

      final exhausted = fresh.copyWith(attemptCount: 3);
      expect(exhausted.hasRemainingAttempts, isFalse);
    });

    test('canExecuteNow respects status', () {
      final pending = QueuedOperation(
        id: 'op-123',
        operation: TransportOperation.uploadSales,
        payload: '{}',
        createdAt: DateTime.now(),
        nextAttemptAt: DateTime.now().subtract(const Duration(seconds: 1)),
      );
      expect(pending.canExecuteNow, isTrue);

      final inProgress = pending.markInProgress();
      expect(inProgress.canExecuteNow, isFalse);

      final completed = inProgress.markCompleted();
      expect(completed.canExecuteNow, isFalse);
    });

    test('toJson and fromJson round-trip', () {
      final original = QueuedOperation.create(
        id: 'op-123',
        operation: TransportOperation.uploadSales,
        data: {'key': 'value'},
        priority: 50,
      );

      final json = original.toJson();
      final restored = QueuedOperation.fromJson(json);

      expect(restored.id, original.id);
      expect(restored.operation, original.operation);
      expect(restored.status, original.status);
      expect(restored.priority, original.priority);
      expect(restored.data, original.data);
    });

    test('copyWith preserves unchanged values', () {
      final original = QueuedOperation.create(
        id: 'op-123',
        operation: TransportOperation.uploadSales,
        data: {},
        priority: 50,
      );

      final modified = original.copyWith(priority: 100);

      expect(modified.priority, 100);
      expect(modified.id, original.id);
      expect(modified.operation, original.operation);
    });

    test('toString returns descriptive string', () {
      final operation = QueuedOperation.create(
        id: 'op-123',
        operation: TransportOperation.uploadSales,
        data: {},
      );

      final str = operation.toString();
      expect(str, contains('op-123'));
      expect(str, contains('uploadSales'));
    });
  });

  group('QueueStatistics', () {
    test('creates with all counts', () {
      const stats = QueueStatistics(
        total: 10,
        pending: 3,
        inProgress: 1,
        retrying: 2,
        completed: 3,
        failed: 1,
        cancelled: 0,
      );

      expect(stats.total, 10);
      expect(stats.pending, 3);
      expect(stats.inProgress, 1);
      expect(stats.retrying, 2);
      expect(stats.completed, 3);
      expect(stats.failed, 1);
      expect(stats.cancelled, 0);
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:telepos/transport/transport_exports.dart';

void main() {
  group('TransportCoordinator Integration', () {
    group('Configuration flow', () {
      test('telegram only config enables telegram-only routing', () {
        final config = TransportConfig.telegramOnly(
          TelegramTransportConfig(apiId: 123, apiHash: 'test_hash'),
        );

        expect(config.mode, TransportMode.telegramOnly);
        expect(config.hasTelegram, isTrue);
        expect(config.hasRest, isFalse);

        final coordinator = TransportCoordinator(
          config: config,
          telegram: null,
          rest: null,
        );

        expect(coordinator.config.mode, TransportMode.telegramOnly);
      });

      test('rest only config enables rest-only routing', () {
        final config = TransportConfig.restOnly(
          RestTransportConfig(baseUrl: 'https://api.example.com'),
        );

        expect(config.mode, TransportMode.restOnly);
        expect(config.hasRest, isTrue);
        expect(config.hasTelegram, isFalse);

        final coordinator = TransportCoordinator(
          config: config,
          telegram: null,
          rest: null,
        );

        expect(coordinator.config.mode, TransportMode.restOnly);
      });

      test('hybrid config enables both transports', () {
        final config = TransportConfig.hybrid(
          telegram: TelegramTransportConfig(apiId: 123, apiHash: 'test'),
          rest: RestTransportConfig(baseUrl: 'https://api.example.com'),
        );

        expect(config.mode, TransportMode.hybrid);
        expect(config.hasTelegram, isTrue);
        expect(config.hasRest, isTrue);

        final coordinator = TransportCoordinator(
          config: config,
          telegram: null,
          rest: null,
        );

        expect(coordinator.config.mode, TransportMode.hybrid);
      });
    });

    group('Routing strategy selection', () {
      test('routing rule selects correct strategy per mode', () {
        const rule = RoutingRule(
          telegramOnlyStrategy: RoutingStrategy.telegramOnly,
          restOnlyStrategy: RoutingStrategy.restOnly,
          hybridStrategy: RoutingStrategy.telegramPriority,
        );

        expect(
          rule.getStrategy(TransportMode.telegramOnly),
          RoutingStrategy.telegramOnly,
        );
        expect(
          rule.getStrategy(TransportMode.telegramOnly).hasFallback,
          isFalse,
        );

        expect(
          rule.getStrategy(TransportMode.restOnly),
          RoutingStrategy.restOnly,
        );
        expect(rule.getStrategy(TransportMode.restOnly).hasFallback, isFalse);

        expect(
          rule.getStrategy(TransportMode.hybrid),
          RoutingStrategy.telegramPriority,
        );
        expect(rule.getStrategy(TransportMode.hybrid).hasFallback, isTrue);
      });

      test('parallel strategy for high-availability operations', () {
        const rule = RoutingRule(
          telegramOnlyStrategy: RoutingStrategy.telegramOnly,
          restOnlyStrategy: RoutingStrategy.restOnly,
          hybridStrategy: RoutingStrategy.parallel,
        );

        final strategy = rule.getStrategy(TransportMode.hybrid);

        expect(strategy, RoutingStrategy.parallel);
        expect(strategy.primaryTransport, isNull);
        expect(strategy.fallbackTransport, isNull);
      });
    });

    group('Queued operation lifecycle', () {
      test('operation goes through complete lifecycle', () {
        final op = QueuedOperation.create(
          id: 'test-op-1',
          operation: TransportOperation.uploadSales,
          data: {'saleId': 123, 'amount': 1000},
        );
        expect(op.status, QueuedOperationStatus.pending);
        expect(op.attemptCount, 0);

        final inProgress = op.markInProgress();
        expect(inProgress.status, QueuedOperationStatus.inProgress);
        expect(inProgress.lastAttemptAt, isNotNull);

        final completed = inProgress.markCompleted();
        expect(completed.status, QueuedOperationStatus.completed);
      });

      test('operation retries on failure with backoff', () {
        final op = QueuedOperation.create(
          id: 'test-op-2',
          operation: TransportOperation.uploadSales,
          data: {'saleId': 456},
          maxAttempts: 3,
        );

        final retry1 = op.markForRetry('Network timeout');
        expect(retry1.status, QueuedOperationStatus.retrying);
        expect(retry1.attemptCount, 1);
        expect(retry1.lastError, 'Network timeout');
        expect(retry1.nextAttemptAt, isNotNull);

        final retry2 = retry1.markForRetry('Connection refused');
        expect(retry2.status, QueuedOperationStatus.retrying);
        expect(retry2.attemptCount, 2);

        final failed = retry2.markForRetry('Final error');
        expect(failed.status, QueuedOperationStatus.failed);
        expect(failed.lastError, 'Final error');
      });

      test('critical operations get higher priority and more attempts', () {
        final normal = QueuedOperation.create(
          id: 'normal-op',
          operation: TransportOperation.uploadSales,
          data: {},
        );

        final critical = QueuedOperation.critical(
          id: 'critical-op',
          operation: TransportOperation.uploadSales,
          data: {},
        );

        expect(critical.priority, greaterThan(normal.priority));
        expect(critical.maxAttempts, greaterThan(normal.maxAttempts));
        expect(critical.isCritical, isTrue);
      });

      test('cancelled operations cannot be retried', () {
        final op = QueuedOperation.create(
          id: 'test-op-3',
          operation: TransportOperation.uploadSales,
          data: {},
        );

        final cancelled = op.markCancelled();
        expect(cancelled.status, QueuedOperationStatus.cancelled);
        expect(cancelled.canExecuteNow, isFalse);
      });
    });

    group('Migration state transitions', () {
      test('migration follows correct state transitions', () {
        final idle = MigrationState.idle(
          fromMode: TransportMode.restOnly,
          toMode: TransportMode.telegramOnly,
        );
        expect(idle.status, MigrationStatus.idle);
        expect(idle.isInProgress, isFalse);
        expect(idle.progress, 0.0);

        final validating = idle.copyWith(
          status: MigrationStatus.validating,
          startTime: DateTime.now(),
        );
        expect(validating.isInProgress, isTrue);

        var migrating = validating.copyWith(
          status: MigrationStatus.migrating,
          currentStep: MigrationStep.checkAvailability,
          completedSteps: 1,
        );
        expect(migrating.progress, closeTo(0.125, 0.01));

        migrating = migrating.copyWith(
          currentStep: MigrationStep.migrateQueue,
          completedSteps: 5,
        );
        expect(migrating.progress, closeTo(0.625, 0.01));

        final completing = migrating.copyWith(
          status: MigrationStatus.completing,
          currentStep: MigrationStep.cleanupOldTransport,
          completedSteps: 7,
        );
        expect(completing.isInProgress, isTrue);

        final completed = completing.copyWith(
          status: MigrationStatus.completed,
          completedSteps: 8,
          endTime: DateTime.now(),
        );
        expect(completed.isCompleted, isTrue);
        expect(completed.isInProgress, isFalse);
        expect(completed.progress, 1.0);
        expect(completed.duration, isNotNull);
      });

      test('migration can fail and track error', () {
        final migrating = MigrationState.idle().copyWith(
          status: MigrationStatus.migrating,
          currentStep: MigrationStep.migrateSettings,
          completedSteps: 2,
        );

        final failed = migrating.copyWith(
          status: MigrationStatus.failed,
          error: 'Failed to connect to Telegram',
          endTime: DateTime.now(),
        );

        expect(failed.hasError, isTrue);
        expect(failed.error, 'Failed to connect to Telegram');
        expect(failed.isInProgress, isFalse);
      });

      test('migration can be rolled back', () {
        final failed = MigrationState.idle().copyWith(
          status: MigrationStatus.failed,
          error: 'Some error',
        );

        final rolledBack = failed.copyWith(status: MigrationStatus.rolledBack);

        expect(rolledBack.hasError, isTrue);
        expect(rolledBack.status, MigrationStatus.rolledBack);
      });
    });

    group('Validation result handling', () {
      test('successful validation allows migration', () {
        final result = MigrationValidationResult.success(
          warnings: ['Telegram connection latency is high'],
          details: {'latencyMs': 500},
        );

        expect(result.canMigrate, isTrue);
        expect(result.warnings, isNotEmpty);
        expect(result.errors, isEmpty);
        expect(result.details['latencyMs'], 500);
      });

      test('failed validation blocks migration', () {
        final result = MigrationValidationResult.failure(
          errors: [
            'Telegram API credentials invalid',
            'Cannot reach Telegram servers',
          ],
          warnings: ['REST API will be unavailable during migration'],
        );

        expect(result.canMigrate, isFalse);
        expect(result.errors.length, 2);
        expect(result.warnings.length, 1);
      });
    });

    group('FallbackHandler lifecycle', () {
      test('creates and disposes cleanly', () async {
        final events = <FallbackEvent>[];

        final handler = FallbackHandler(logger: (msg) {}, onEvent: events.add);

        expect(handler, isNotNull);

        await handler.dispose();
      });
    });

    group('ParallelExecutor usage', () {
      test('creates executor for parallel operations', () {
        final executor = ParallelExecutor();
        expect(executor, isNotNull);
      });
    });

    group('TransportConfig edge cases', () {
      test('telegram config stores credentials', () {
        final telegramConfig = TelegramTransportConfig(
          apiId: 12345,
          apiHash: 'abc123hash',
        );

        expect(telegramConfig.apiId, 12345);
        expect(telegramConfig.apiHash, 'abc123hash');
      });

      test('rest config stores base URL and timeout', () {
        final restConfig = RestTransportConfig(
          baseUrl: 'https://api.telepos.com/v1',
          timeout: const Duration(seconds: 60),
        );

        expect(restConfig.baseUrl, 'https://api.telepos.com/v1');
        expect(restConfig.timeout.inSeconds, 60);
      });
    });

    group('TransportOperation properties', () {
      test('operations have correct isCritical flags', () {
        expect(TransportOperation.uploadSales.isCritical, isTrue);

        expect(TransportOperation.downloadProducts.isCritical, isFalse);
      });
    });
  });
}

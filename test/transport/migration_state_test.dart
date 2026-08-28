import 'package:flutter_test/flutter_test.dart';
import 'package:telepos/transport/transport_exports.dart';

void main() {
  group('MigrationStatus', () {
    test('has all expected values', () {
      expect(MigrationStatus.values.length, 7);
      expect(MigrationStatus.idle, isNotNull);
      expect(MigrationStatus.validating, isNotNull);
      expect(MigrationStatus.migrating, isNotNull);
      expect(MigrationStatus.completing, isNotNull);
      expect(MigrationStatus.completed, isNotNull);
      expect(MigrationStatus.failed, isNotNull);
      expect(MigrationStatus.rolledBack, isNotNull);
    });
  });

  group('MigrationStep', () {
    test('has all 8 migration steps', () {
      expect(MigrationStep.values.length, 8);
      expect(MigrationStep.checkAvailability, isNotNull);
      expect(MigrationStep.syncPendingData, isNotNull);
      expect(MigrationStep.migrateSettings, isNotNull);
      expect(MigrationStep.migrateEncryptionKeys, isNotNull);
      expect(MigrationStep.migrateQueue, isNotNull);
      expect(MigrationStep.switchTransport, isNotNull);
      expect(MigrationStep.verifyNewTransport, isNotNull);
      expect(MigrationStep.cleanupOldTransport, isNotNull);
    });

    test('steps are in correct order', () {
      final steps = MigrationStep.values;
      expect(steps[0], MigrationStep.checkAvailability);
      expect(steps[1], MigrationStep.syncPendingData);
      expect(steps[2], MigrationStep.migrateSettings);
      expect(steps[3], MigrationStep.migrateEncryptionKeys);
      expect(steps[4], MigrationStep.migrateQueue);
      expect(steps[5], MigrationStep.switchTransport);
      expect(steps[6], MigrationStep.verifyNewTransport);
      expect(steps[7], MigrationStep.cleanupOldTransport);
    });
  });

  group('MigrationState', () {
    test('creates with idle factory', () {
      final state = MigrationState.idle();

      expect(state.status, MigrationStatus.idle);
      expect(state.currentStep, isNull);
      expect(state.completedSteps, 0);
      expect(state.error, isNull);
      expect(state.startTime, isNull);
      expect(state.endTime, isNull);
    });

    test('idle factory accepts fromMode and toMode', () {
      final state = MigrationState.idle(
        fromMode: TransportMode.restOnly,
        toMode: TransportMode.telegramOnly,
      );

      expect(state.fromMode, TransportMode.restOnly);
      expect(state.toMode, TransportMode.telegramOnly);
    });

    test('copyWith creates new instance with updated values', () {
      final initial = MigrationState.idle();
      final updated = initial.copyWith(
        status: MigrationStatus.migrating,
        currentStep: MigrationStep.migrateSettings,
        completedSteps: 2,
      );

      expect(updated.status, MigrationStatus.migrating);
      expect(updated.currentStep, MigrationStep.migrateSettings);
      expect(updated.completedSteps, 2);
      expect(initial.status, MigrationStatus.idle);
    });

    test('progress calculates correctly', () {
      final idle = MigrationState.idle();
      expect(idle.progress, 0.0);

      final midway = MigrationState.idle().copyWith(
        status: MigrationStatus.migrating,
        completedSteps: 4,
      );
      expect(midway.progress, 0.5);

      final completed = MigrationState.idle().copyWith(
        status: MigrationStatus.completed,
        completedSteps: 8,
      );
      expect(completed.progress, 1.0);
    });

    test('isInProgress returns correct values', () {
      expect(MigrationState.idle().isInProgress, isFalse);
      expect(
        MigrationState.idle()
            .copyWith(status: MigrationStatus.validating)
            .isInProgress,
        isTrue,
      );
      expect(
        MigrationState.idle()
            .copyWith(status: MigrationStatus.migrating)
            .isInProgress,
        isTrue,
      );
      expect(
        MigrationState.idle()
            .copyWith(status: MigrationStatus.completing)
            .isInProgress,
        isTrue,
      );
      expect(
        MigrationState.idle()
            .copyWith(status: MigrationStatus.completed)
            .isInProgress,
        isFalse,
      );
      expect(
        MigrationState.idle()
            .copyWith(status: MigrationStatus.failed)
            .isInProgress,
        isFalse,
      );
    });

    test('isCompleted returns true only for completed status', () {
      expect(MigrationState.idle().isCompleted, isFalse);
      expect(
        MigrationState.idle()
            .copyWith(status: MigrationStatus.completed)
            .isCompleted,
        isTrue,
      );
    });

    test('hasError returns true for failed or rolledBack', () {
      expect(MigrationState.idle().hasError, isFalse);
      expect(
        MigrationState.idle().copyWith(status: MigrationStatus.failed).hasError,
        isTrue,
      );
      expect(
        MigrationState.idle()
            .copyWith(status: MigrationStatus.rolledBack)
            .hasError,
        isTrue,
      );
    });

    test('duration calculates correctly', () {
      final noStart = MigrationState.idle();
      expect(noStart.duration, isNull);

      final started = MigrationState.idle().copyWith(
        startTime: DateTime.now().subtract(const Duration(seconds: 10)),
      );
      expect(started.duration, isNotNull);
      expect(started.duration!.inSeconds, greaterThanOrEqualTo(10));
    });
  });

  group('MigrationLogEntry', () {
    test('creates info entry', () {
      final entry = MigrationLogEntry.info(
        MigrationStep.checkAvailability,
        'Checking availability',
      );

      expect(entry.step, MigrationStep.checkAvailability);
      expect(entry.message, 'Checking availability');
      expect(entry.isError, isFalse);
      expect(entry.timestamp, isNotNull);
    });

    test('creates error entry', () {
      final entry = MigrationLogEntry.error(
        MigrationStep.migrateSettings,
        'Failed to migrate settings',
      );

      expect(entry.step, MigrationStep.migrateSettings);
      expect(entry.message, 'Failed to migrate settings');
      expect(entry.isError, isTrue);
    });

    test('toString formats correctly', () {
      final info = MigrationLogEntry.info(MigrationStep.migrateQueue, 'Done');
      expect(info.toString(), contains('INFO'));
      expect(info.toString(), contains('Done'));

      final error = MigrationLogEntry.error(MigrationStep.migrateQueue, 'Fail');
      expect(error.toString(), contains('ERROR'));
      expect(error.toString(), contains('Fail'));
    });
  });

  group('MigrationValidationResult', () {
    test('success factory creates valid result', () {
      final result = MigrationValidationResult.success(warnings: ['Warning 1']);

      expect(result.canMigrate, isTrue);
      expect(result.errors, isEmpty);
      expect(result.warnings, hasLength(1));
    });

    test('failure factory creates invalid result', () {
      final result = MigrationValidationResult.failure(
        errors: ['Error 1', 'Error 2'],
      );

      expect(result.canMigrate, isFalse);
      expect(result.errors, hasLength(2));
    });

    test('toString shows status', () {
      final success = MigrationValidationResult.success();
      expect(success.toString(), contains('OK'));

      final failure = MigrationValidationResult.failure(errors: ['e']);
      expect(failure.toString(), contains('FAILED'));
    });
  });
}

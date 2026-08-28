import 'dart:async';

import '../coordinator/coordinator_exports.dart';
import '../interface/transport_interface_exports.dart';
import '../queue/offline_queue.dart';
import '../settings/settings_storage.dart';
import 'migration_state.dart';
import 'migration_validator.dart';

class TransportMigrationService {
  final TransportCoordinator _coordinator;
  final TransportInterface? _telegram;
  final TransportInterface? _rest;
  final OfflineQueue _queue;
  final SettingsManager _settingsManager;
  final void Function(String)? _logger;
  final void Function(MigrationState)? _onStateChange;

  late final MigrationValidator _validator;
  late final RollbackValidator _rollbackValidator;

  MigrationState _state = MigrationState.idle();
  final _stateController = StreamController<MigrationState>.broadcast();
  TransportMode? _originalMode;

  TransportMigrationService({
    required TransportCoordinator coordinator,
    TransportInterface? telegram,
    TransportInterface? rest,
    required OfflineQueue queue,
    required SettingsManager settingsManager,
    void Function(String)? logger,
    void Function(MigrationState)? onStateChange,
  }) : _coordinator = coordinator,
       _telegram = telegram,
       _rest = rest,
       _queue = queue,
       _settingsManager = settingsManager,
       _logger = logger,
       _onStateChange = onStateChange {
    _validator = MigrationValidator(
      telegram: telegram,
      rest: rest,
      queue: queue,
      logger: logger,
    );
    _rollbackValidator = RollbackValidator(
      telegram: telegram,
      rest: rest,
      logger: logger,
    );
  }

  MigrationState get state => _state;

  Stream<MigrationState> get stateStream => _stateController.stream;

  bool get isInProgress => _state.isInProgress;

  Future<MigrationValidationResult> validate({required TransportMode toMode}) {
    return _validator.validate(
      fromMode: _coordinator.config.mode,
      toMode: toMode,
    );
  }

  Future<MigrationResult> migrate({required TransportMode toMode}) async {
    final fromMode = _coordinator.config.mode;

    if (_state.isInProgress) {
      return MigrationResult.failure('Migration already in progress');
    }

    if (fromMode == toMode) {
      return MigrationResult.failure('Already in target mode');
    }

    _log('Starting migration: $fromMode -> $toMode');
    _originalMode = fromMode;

    _updateState(
      MigrationState(
        status: MigrationStatus.validating,
        fromMode: fromMode,
        toMode: toMode,
        currentStep: MigrationStep.checkAvailability,
        startTime: DateTime.now(),
      ),
    );

    try {
      final validation = await _validator.validate(
        fromMode: fromMode,
        toMode: toMode,
      );

      if (!validation.canMigrate) {
        _updateState(
          _state.copyWith(
            status: MigrationStatus.failed,
            error: validation.errors.join('; '),
            endTime: DateTime.now(),
          ),
        );
        return MigrationResult.failure(validation.errors.join('; '));
      }

      _updateState(_state.copyWith(status: MigrationStatus.migrating));

      await _executeStep(MigrationStep.checkAvailability, () async {});

      await _executeStep(MigrationStep.syncPendingData, () async {
        await _syncPendingData();
      });

      await _executeStep(MigrationStep.migrateSettings, () async {
        await _migrateSettings(toMode);
      });

      await _executeStep(MigrationStep.migrateEncryptionKeys, () async {
        await _migrateEncryptionKeys(toMode);
      });

      await _executeStep(MigrationStep.migrateQueue, () async {
        await _migrateQueue(toMode);
      });

      await _executeStep(MigrationStep.switchTransport, () async {
        await _switchTransport(toMode);
      });

      await _executeStep(MigrationStep.verifyNewTransport, () async {
        await _verifyNewTransport(toMode);
      });

      _updateState(
        _state.copyWith(
          status: MigrationStatus.completing,
          currentStep: MigrationStep.cleanupOldTransport,
        ),
      );

      await _executeStep(MigrationStep.cleanupOldTransport, () async {
        await _cleanupOldTransport(fromMode);
      });

      _updateState(
        _state.copyWith(
          status: MigrationStatus.completed,
          currentStep: null,
          endTime: DateTime.now(),
          canRollback: false,
        ),
      );

      _log('Migration completed successfully');
      return MigrationResult.success();
    } catch (e) {
      _log('Migration failed: $e');
      _logEntry(
        _state.currentStep ?? MigrationStep.checkAvailability,
        'Migration failed: $e',
        isError: true,
      );

      _updateState(
        _state.copyWith(
          status: MigrationStatus.failed,
          error: e.toString(),
          endTime: DateTime.now(),
        ),
      );

      if (_state.canRollback && _originalMode != null) {
        await _attemptRollback();
      }

      return MigrationResult.failure(e.toString());
    }
  }

  Future<MigrationResult> rollback() async {
    if (!_state.canRollback || _originalMode == null) {
      return MigrationResult.failure('Rollback not available');
    }

    _log('Starting rollback to $_originalMode');

    try {
      await _switchTransport(_originalMode!);

      _updateState(
        _state.copyWith(
          status: MigrationStatus.rolledBack,
          endTime: DateTime.now(),
          canRollback: false,
        ),
      );

      return MigrationResult.success();
    } catch (e) {
      _log('Rollback failed: $e');
      return MigrationResult.failure('Rollback failed: $e');
    }
  }

  Future<void> _executeStep(
    MigrationStep step,
    Future<void> Function() action,
  ) async {
    _log('Executing step: $step');
    _updateState(_state.copyWith(currentStep: step));
    _logEntry(step, 'Started');

    try {
      await action();
      _logEntry(step, 'Completed');
      _updateState(_state.copyWith(completedSteps: _state.completedSteps + 1));
    } catch (e) {
      _logEntry(step, 'Failed: $e', isError: true);
      rethrow;
    }
  }

  Future<void> _syncPendingData() async {
    final stats = await _queue.getStatistics();
    if (stats.pending == 0) {
      _log('No pending data to sync');
      return;
    }

    _log('Syncing ${stats.pending} pending operations...');

    await _queue.processQueue();

    final timeout = Duration(seconds: 30);
    final startTime = DateTime.now();

    while (true) {
      final currentStats = await _queue.getStatistics();
      if (currentStats.pending == 0) {
        break;
      }

      if (DateTime.now().difference(startTime) > timeout) {
        _log('Sync timeout, ${currentStats.pending} operations remaining');
        break;
      }

      await Future.delayed(const Duration(milliseconds: 500));
    }
  }

  Future<void> _migrateSettings(TransportMode toMode) async {
    _log('Migrating settings to $toMode (no-op: not implemented)');
  }

  Future<void> _migrateEncryptionKeys(TransportMode toMode) async {
    _log('Migrating encryption keys for $toMode (no-op: not implemented)');
  }

  Future<void> _migrateQueue(TransportMode toMode) async {
    final stats = await _queue.getStatistics();
    _log('Queue has ${stats.total} operations');
  }

  Future<void> _switchTransport(TransportMode toMode) async {
    _log('Switching transport to $toMode');

    final settings = _settingsManager.currentSettings;
    final newConfig = TransportConfig(
      mode: toMode,
      telegram: toMode == TransportMode.restOnly
          ? null
          : settings.transportConfig.telegram,
      rest: toMode == TransportMode.telegramOnly
          ? null
          : settings.transportConfig.rest,
    );

    await _settingsManager.updateSettings(
      settings.copyWith(transportConfig: newConfig),
    );
  }

  Future<void> _verifyNewTransport(TransportMode toMode) async {
    _log('Verifying new transport $toMode');

    TransportInterface? transport;
    switch (toMode) {
      case TransportMode.telegramOnly:
        transport = _telegram;
        break;
      case TransportMode.restOnly:
        transport = _rest;
        break;
      case TransportMode.hybrid:
        final telegram = _telegram;
        if (telegram != null) {
          final telegramOk = await telegram.isAvailable();
          _log('Telegram available: $telegramOk');
        }
        final rest = _rest;
        if (rest != null) {
          final restOk = await rest.isAvailable();
          _log('REST available: $restOk');
        }
        return;
    }

    if (transport == null) {
      throw Exception('Transport not configured for $toMode');
    }

    final available = await transport.isAvailable();
    if (!available) {
      throw Exception('New transport is not available');
    }

    _log('New transport verified successfully');
  }

  Future<void> _cleanupOldTransport(TransportMode fromMode) async {
    _log('Cleaning up old transport $fromMode (no-op: not implemented)');
  }

  Future<void> _attemptRollback() async {
    _log('Attempting automatic rollback...');

    final canRollback = await _rollbackValidator.canRollback(
      originalMode: _originalMode!,
    );

    if (canRollback) {
      try {
        await _switchTransport(_originalMode!);
        _log('Automatic rollback successful');
      } catch (e) {
        _log('Automatic rollback failed: $e');
      }
    } else {
      _log('Rollback not possible');
    }
  }

  void _updateState(MigrationState newState) {
    _state = newState;
    _stateController.add(_state);
    _onStateChange?.call(_state);
  }

  void _logEntry(MigrationStep step, String message, {bool isError = false}) {
    final entry = isError
        ? MigrationLogEntry.error(step, message)
        : MigrationLogEntry.info(step, message);

    _updateState(_state.copyWith(log: [..._state.log, entry]));
  }

  void _log(String message) {
    _logger?.call('[TransportMigration] $message');
  }

  void dispose() {
    _stateController.close();
  }
}

class MigrationResult {
  final bool success;
  final String? error;
  final Duration? duration;

  const MigrationResult._({required this.success, this.error, this.duration});

  factory MigrationResult.success({Duration? duration}) {
    return MigrationResult._(success: true, duration: duration);
  }

  factory MigrationResult.failure(String error) {
    return MigrationResult._(success: false, error: error);
  }

  @override
  String toString() =>
      success ? 'MigrationResult: SUCCESS' : 'MigrationResult: FAILED ($error)';
}

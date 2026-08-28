import '../coordinator/coordinator_exports.dart';

enum MigrationStatus {
  idle,

  validating,

  migrating,

  completing,

  completed,

  failed,

  rolledBack,
}

enum MigrationStep {
  checkAvailability,

  syncPendingData,

  migrateSettings,

  migrateEncryptionKeys,

  migrateQueue,

  switchTransport,

  verifyNewTransport,

  cleanupOldTransport,
}

class MigrationState {
  final MigrationStatus status;
  final TransportMode fromMode;
  final TransportMode toMode;
  final MigrationStep? currentStep;
  final int completedSteps;
  final int totalSteps;
  final String? error;
  final List<MigrationLogEntry> log;
  final DateTime? startTime;
  final DateTime? endTime;
  final bool canRollback;

  const MigrationState({
    required this.status,
    required this.fromMode,
    required this.toMode,
    this.currentStep,
    this.completedSteps = 0,
    this.totalSteps = 8,
    this.error,
    this.log = const [],
    this.startTime,
    this.endTime,
    this.canRollback = true,
  });

  factory MigrationState.idle({
    TransportMode fromMode = TransportMode.restOnly,
    TransportMode toMode = TransportMode.restOnly,
  }) {
    return MigrationState(
      status: MigrationStatus.idle,
      fromMode: fromMode,
      toMode: toMode,
    );
  }

  double get progress => totalSteps > 0 ? completedSteps / totalSteps : 0;

  bool get isInProgress =>
      status == MigrationStatus.validating ||
      status == MigrationStatus.migrating ||
      status == MigrationStatus.completing;

  bool get isCompleted => status == MigrationStatus.completed;

  bool get hasError =>
      status == MigrationStatus.failed || status == MigrationStatus.rolledBack;

  Duration? get duration {
    if (startTime == null) return null;
    final end = endTime ?? DateTime.now();
    return end.difference(startTime!);
  }

  MigrationState copyWith({
    MigrationStatus? status,
    TransportMode? fromMode,
    TransportMode? toMode,
    MigrationStep? currentStep,
    int? completedSteps,
    int? totalSteps,
    String? error,
    List<MigrationLogEntry>? log,
    DateTime? startTime,
    DateTime? endTime,
    bool? canRollback,
  }) {
    return MigrationState(
      status: status ?? this.status,
      fromMode: fromMode ?? this.fromMode,
      toMode: toMode ?? this.toMode,
      currentStep: currentStep ?? this.currentStep,
      completedSteps: completedSteps ?? this.completedSteps,
      totalSteps: totalSteps ?? this.totalSteps,
      error: error ?? this.error,
      log: log ?? this.log,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      canRollback: canRollback ?? this.canRollback,
    );
  }

  @override
  String toString() =>
      'MigrationState($status, $fromMode -> $toMode, step $completedSteps/$totalSteps)';
}

class MigrationLogEntry {
  final DateTime timestamp;
  final MigrationStep step;
  final String message;
  final bool isError;

  const MigrationLogEntry({
    required this.timestamp,
    required this.step,
    required this.message,
    this.isError = false,
  });

  factory MigrationLogEntry.info(MigrationStep step, String message) {
    return MigrationLogEntry(
      timestamp: DateTime.now(),
      step: step,
      message: message,
    );
  }

  factory MigrationLogEntry.error(MigrationStep step, String message) {
    return MigrationLogEntry(
      timestamp: DateTime.now(),
      step: step,
      message: message,
      isError: true,
    );
  }

  @override
  String toString() =>
      '[${timestamp.toIso8601String()}] ${isError ? "ERROR" : "INFO"}: $message';
}

class MigrationValidationResult {
  final bool canMigrate;
  final List<String> warnings;
  final List<String> errors;
  final Map<String, dynamic> details;

  const MigrationValidationResult({
    required this.canMigrate,
    this.warnings = const [],
    this.errors = const [],
    this.details = const {},
  });

  factory MigrationValidationResult.success({
    List<String> warnings = const [],
    Map<String, dynamic> details = const {},
  }) {
    return MigrationValidationResult(
      canMigrate: true,
      warnings: warnings,
      details: details,
    );
  }

  factory MigrationValidationResult.failure({
    required List<String> errors,
    List<String> warnings = const [],
    Map<String, dynamic> details = const {},
  }) {
    return MigrationValidationResult(
      canMigrate: false,
      errors: errors,
      warnings: warnings,
      details: details,
    );
  }

  @override
  String toString() => canMigrate
      ? 'ValidationResult: OK (${warnings.length} warnings)'
      : 'ValidationResult: FAILED (${errors.length} errors)';
}

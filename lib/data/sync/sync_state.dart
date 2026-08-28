import 'sync_config.dart';

enum SyncStatus {
  idle,

  starting,

  downloading,

  uploading,

  finalizing,

  completed,

  failed,

  cancelled,

  waitingForNetwork,
}

class SyncState {
  const SyncState({
    required this.status,
    this.syncType = SyncType.incremental,
    this.currentStep,
    this.currentStepProgress = 0.0,
    this.overallProgress = 0.0,
    this.itemsProcessed = 0,
    this.totalItems,
    this.errorMessage,
    this.lastSyncTime,
    this.cycleCount = 0,
    this.pendingUploads = 0,
  });

  final SyncStatus status;

  final SyncType syncType;

  final SyncStep? currentStep;

  final double currentStepProgress;

  final double overallProgress;

  final int itemsProcessed;

  final int? totalItems;

  final String? errorMessage;

  final DateTime? lastSyncTime;

  final int cycleCount;

  final int pendingUploads;

  bool get isInProgress =>
      status == SyncStatus.starting ||
      status == SyncStatus.downloading ||
      status == SyncStatus.uploading ||
      status == SyncStatus.finalizing;

  bool get isCompleted => status == SyncStatus.completed;

  bool get isFailed => status == SyncStatus.failed;

  bool get isIdle => status == SyncStatus.idle;

  String? get currentStepName {
    if (currentStep == null) return null;
    return SyncStepInfo.getInfo(currentStep!)?.displayName;
  }

  SyncState copyWith({
    SyncStatus? status,
    SyncType? syncType,
    SyncStep? currentStep,
    double? currentStepProgress,
    double? overallProgress,
    int? itemsProcessed,
    int? totalItems,
    String? errorMessage,
    DateTime? lastSyncTime,
    int? cycleCount,
    int? pendingUploads,
    bool clearError = false,
    bool clearStep = false,
  }) {
    return SyncState(
      status: status ?? this.status,
      syncType: syncType ?? this.syncType,
      currentStep: clearStep ? null : (currentStep ?? this.currentStep),
      currentStepProgress: currentStepProgress ?? this.currentStepProgress,
      overallProgress: overallProgress ?? this.overallProgress,
      itemsProcessed: itemsProcessed ?? this.itemsProcessed,
      totalItems: totalItems ?? this.totalItems,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      lastSyncTime: lastSyncTime ?? this.lastSyncTime,
      cycleCount: cycleCount ?? this.cycleCount,
      pendingUploads: pendingUploads ?? this.pendingUploads,
    );
  }

  factory SyncState.idle() {
    return const SyncState(status: SyncStatus.idle);
  }

  factory SyncState.starting(SyncType type) {
    return SyncState(
      status: SyncStatus.starting,
      syncType: type,
      overallProgress: 0.0,
    );
  }

  factory SyncState.downloading({
    required SyncType syncType,
    required SyncStep step,
    double progress = 0.0,
    int itemsProcessed = 0,
    int? totalItems,
  }) {
    return SyncState(
      status: SyncStatus.downloading,
      syncType: syncType,
      currentStep: step,
      currentStepProgress: progress,
      itemsProcessed: itemsProcessed,
      totalItems: totalItems,
    );
  }

  factory SyncState.uploading({
    required SyncType syncType,
    required SyncStep step,
    double progress = 0.0,
    int itemsProcessed = 0,
    int? totalItems,
  }) {
    return SyncState(
      status: SyncStatus.uploading,
      syncType: syncType,
      currentStep: step,
      currentStepProgress: progress,
      itemsProcessed: itemsProcessed,
      totalItems: totalItems,
    );
  }

  factory SyncState.completed({
    required SyncType syncType,
    required int cycleCount,
    int pendingUploads = 0,
  }) {
    return SyncState(
      status: SyncStatus.completed,
      syncType: syncType,
      overallProgress: 1.0,
      lastSyncTime: DateTime.now(),
      cycleCount: cycleCount,
      pendingUploads: pendingUploads,
    );
  }

  factory SyncState.failed(String errorMessage) {
    return SyncState(status: SyncStatus.failed, errorMessage: errorMessage);
  }

  factory SyncState.cancelled() {
    return const SyncState(status: SyncStatus.cancelled);
  }

  @override
  String toString() {
    return 'SyncState('
        'status: $status, '
        'type: $syncType, '
        'step: ${currentStepName ?? "none"}, '
        'progress: ${(overallProgress * 100).toStringAsFixed(1)}%'
        ')';
  }
}

class SyncResult {
  const SyncResult({
    required this.success,
    required this.syncType,
    this.itemsDownloaded = 0,
    this.itemsUploaded = 0,
    this.duration,
    this.errorMessage,
    this.wasFullSync = false,
    this.newCycleCount = 0,
  });

  final bool success;

  final SyncType syncType;

  final int itemsDownloaded;

  final int itemsUploaded;

  final Duration? duration;

  final String? errorMessage;

  final bool wasFullSync;

  final int newCycleCount;

  int get totalItems => itemsDownloaded + itemsUploaded;

  factory SyncResult.success({
    required SyncType syncType,
    int itemsDownloaded = 0,
    int itemsUploaded = 0,
    Duration? duration,
    bool wasFullSync = false,
    int newCycleCount = 0,
  }) {
    return SyncResult(
      success: true,
      syncType: syncType,
      itemsDownloaded: itemsDownloaded,
      itemsUploaded: itemsUploaded,
      duration: duration,
      wasFullSync: wasFullSync,
      newCycleCount: newCycleCount,
    );
  }

  factory SyncResult.offline() {
    return const SyncResult(
      success: false,
      syncType: SyncType.incremental,
      errorMessage: 'Network unavailable',
    );
  }

  factory SyncResult.error(String message, {SyncType? syncType}) {
    return SyncResult(
      success: false,
      syncType: syncType ?? SyncType.incremental,
      errorMessage: message,
    );
  }

  @override
  String toString() {
    if (success) {
      return 'SyncResult.success('
          'type: $syncType, '
          'downloaded: $itemsDownloaded, '
          'uploaded: $itemsUploaded'
          ')';
    }
    return 'SyncResult.error($errorMessage)';
  }
}

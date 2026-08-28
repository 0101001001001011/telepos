import 'dart:async';

import 'sync_config.dart';
import 'sync_state.dart';

class DataExchangeStateful {
  DataExchangeStateful({this.onStateChanged});

  final void Function(SyncState state)? onStateChanged;

  final _stateController = StreamController<SyncState>.broadcast();

  SyncState _state = SyncState.idle();
  int _cycleCount = 0;
  DateTime? _lastSyncTime;
  bool _isCancelled = false;

  SyncState get state => _state;

  Stream<SyncState> get stateStream => _stateController.stream;

  bool get isSyncInProgress => _state.isInProgress;

  int get cycleCount => _cycleCount;

  DateTime? get lastSyncTime => _lastSyncTime;

  bool get shouldDoFullSync =>
      _cycleCount >= SyncConfig.fullSyncThreshold || _lastSyncTime == null;

  bool get canSync {
    if (_lastSyncTime == null) return true;
    final elapsed = DateTime.now().difference(_lastSyncTime!);
    return elapsed.inSeconds >= SyncConfig.minSyncIntervalSeconds;
  }

  int get pendingUploads => 0;

  double get syncProgress => _state.overallProgress;

  Future<SyncResult> performSync() async {
    if (isSyncInProgress) {
      return SyncResult.error('Sync already in progress');
    }

    final syncType = shouldDoFullSync ? SyncType.full : SyncType.incremental;

    if (syncType == SyncType.full) {
      return performFullSync();
    } else {
      return performIncrementalSync();
    }
  }

  Future<SyncResult> performFullSync() async {
    if (isSyncInProgress) {
      return SyncResult.error('Sync already in progress');
    }

    _isCancelled = false;
    final stopwatch = Stopwatch()..start();

    _updateState(SyncState.starting(SyncType.full));

    final steps = SyncStepInfo.allSteps;

    for (var i = 0; i < steps.length; i++) {
      if (_isCancelled) {
        _updateState(SyncState.cancelled());
        return SyncResult.error('Sync cancelled', syncType: SyncType.full);
      }

      final step = steps[i];
      final progress = (i + 1) / steps.length;

      if (step.direction == SyncDirection.download) {
        _updateState(
          SyncState.downloading(
            syncType: SyncType.full,
            step: step.step,
            progress: progress,
          ),
        );
      } else if (step.direction == SyncDirection.upload) {
        _updateState(
          SyncState.uploading(
            syncType: SyncType.full,
            step: step.step,
            progress: progress,
          ),
        );
      }
    }

    stopwatch.stop();

    _cycleCount = 0;
    _lastSyncTime = DateTime.now();

    _updateState(
      SyncState.completed(syncType: SyncType.full, cycleCount: _cycleCount),
    );

    return SyncResult.success(
      syncType: SyncType.full,
      itemsDownloaded: 0,
      itemsUploaded: 0,
      duration: stopwatch.elapsed,
      wasFullSync: true,
      newCycleCount: _cycleCount,
    );
  }

  Future<SyncResult> performIncrementalSync() async {
    if (isSyncInProgress) {
      return SyncResult.error('Sync already in progress');
    }

    if (_lastSyncTime == null) {
      return performFullSync();
    }

    _isCancelled = false;
    final stopwatch = Stopwatch()..start();

    _updateState(SyncState.starting(SyncType.incremental));

    final steps = [
      SyncStep.downloadProducts,
      SyncStep.downloadPrices,
      SyncStep.uploadSales,
      SyncStep.uploadRefunds,
      SyncStep.finalize,
    ];

    for (var i = 0; i < steps.length; i++) {
      if (_isCancelled) {
        _updateState(SyncState.cancelled());
        return SyncResult.error(
          'Sync cancelled',
          syncType: SyncType.incremental,
        );
      }

      final step = steps[i];
      final stepInfo = SyncStepInfo.getInfo(step);
      final progress = (i + 1) / steps.length;

      if (stepInfo?.direction == SyncDirection.download) {
        _updateState(
          SyncState.downloading(
            syncType: SyncType.incremental,
            step: step,
            progress: progress,
          ),
        );
      } else if (stepInfo?.direction == SyncDirection.upload) {
        _updateState(
          SyncState.uploading(
            syncType: SyncType.incremental,
            step: step,
            progress: progress,
          ),
        );
      }
    }

    stopwatch.stop();

    _cycleCount++;
    _lastSyncTime = DateTime.now();

    _updateState(
      SyncState.completed(
        syncType: SyncType.incremental,
        cycleCount: _cycleCount,
      ),
    );

    return SyncResult.success(
      syncType: SyncType.incremental,
      itemsDownloaded: 0,
      itemsUploaded: 0,
      duration: stopwatch.elapsed,
      wasFullSync: false,
      newCycleCount: _cycleCount,
    );
  }

  Future<SyncResult> performQuickSync() async {
    if (isSyncInProgress) {
      return SyncResult.error('Sync already in progress');
    }

    _isCancelled = false;
    _updateState(SyncState.starting(SyncType.quick));

    _lastSyncTime = DateTime.now();
    _updateState(
      SyncState.completed(syncType: SyncType.quick, cycleCount: _cycleCount),
    );

    return SyncResult.success(
      syncType: SyncType.quick,
      duration: Duration.zero,
    );
  }

  Future<SyncResult> uploadPending() async {
    if (isSyncInProgress) {
      return SyncResult.error('Sync already in progress');
    }

    _isCancelled = false;
    _updateState(SyncState.starting(SyncType.uploadOnly));

    _updateState(
      SyncState.completed(
        syncType: SyncType.uploadOnly,
        cycleCount: _cycleCount,
      ),
    );

    return SyncResult.success(syncType: SyncType.uploadOnly, itemsUploaded: 0);
  }

  void cancelSync() {
    _isCancelled = true;
  }

  void reset() {
    _cycleCount = 0;
    _lastSyncTime = null;
    _updateState(SyncState.idle());
  }

  void requireFullSync() {
    _cycleCount = SyncConfig.fullSyncThreshold;
  }

  SyncStatusSummary getStatusSummary() {
    return SyncStatusSummary(
      isInProgress: isSyncInProgress,
      lastSyncTime: _lastSyncTime,
      cycleCount: _cycleCount,
      pendingUploads: pendingUploads,
      nextSyncWillBeFull: shouldDoFullSync,
    );
  }

  void _updateState(SyncState newState) {
    _state = newState;
    _stateController.add(newState);
    onStateChanged?.call(newState);
  }

  void dispose() {
    cancelSync();
    _stateController.close();
  }
}

class SyncStatusSummary {
  const SyncStatusSummary({
    required this.isInProgress,
    this.lastSyncTime,
    this.cycleCount = 0,
    this.pendingUploads = 0,
    this.nextSyncWillBeFull = false,
  });

  final bool isInProgress;
  final DateTime? lastSyncTime;
  final int cycleCount;
  final int pendingUploads;
  final bool nextSyncWillBeFull;

  String get lastSyncDisplay {
    if (lastSyncTime == null) return 'Никогда';

    final now = DateTime.now();
    final diff = now.difference(lastSyncTime!);

    if (diff.inMinutes < 1) return 'Только что';
    if (diff.inMinutes < 60) return '${diff.inMinutes} мин назад';
    if (diff.inHours < 24) return '${diff.inHours} ч назад';
    return '${diff.inDays} дн назад';
  }

  int get cyclesUntilFullSync {
    final remaining = SyncConfig.fullSyncThreshold - cycleCount;
    return remaining > 0 ? remaining : 0;
  }
}

import 'update_info.dart';

enum UpdateStatus {
  idle,

  checking,

  available,

  skipped,

  downloading,

  ready,

  preUpdateCheck,

  installing,

  complete,

  failed,
}

class UpdateState {
  const UpdateState({
    required this.status,
    this.updateInfo,
    this.downloadProgress,
    this.errorMessage,
    this.canUpdate = false,
    this.pendingSyncItems = const [],
  });

  const UpdateState.idle()
    : status = UpdateStatus.idle,
      updateInfo = null,
      downloadProgress = null,
      errorMessage = null,
      canUpdate = false,
      pendingSyncItems = const [];

  final UpdateStatus status;

  final UpdateInfo? updateInfo;

  final double? downloadProgress;

  final String? errorMessage;

  final bool canUpdate;

  final List<String> pendingSyncItems;

  bool get isLoading =>
      status == UpdateStatus.checking ||
      status == UpdateStatus.downloading ||
      status == UpdateStatus.preUpdateCheck ||
      status == UpdateStatus.installing;

  bool get hasUpdate =>
      status == UpdateStatus.available || status == UpdateStatus.ready;

  UpdateState copyWith({
    UpdateStatus? status,
    UpdateInfo? updateInfo,
    double? downloadProgress,
    String? errorMessage,
    bool? canUpdate,
    List<String>? pendingSyncItems,
  }) {
    return UpdateState(
      status: status ?? this.status,
      updateInfo: updateInfo ?? this.updateInfo,
      downloadProgress: downloadProgress ?? this.downloadProgress,
      errorMessage: errorMessage ?? this.errorMessage,
      canUpdate: canUpdate ?? this.canUpdate,
      pendingSyncItems: pendingSyncItems ?? this.pendingSyncItems,
    );
  }

  @override
  String toString() {
    return 'UpdateState(status: $status, updateInfo: $updateInfo, '
        'progress: $downloadProgress, error: $errorMessage)';
  }
}

enum UpdateBlockReason {
  shiftOpen('Open shift must be closed'),

  shiftsNotSynced('Shifts pending synchronization'),

  agentsNotSynced('Agents pending synchronization'),

  salesNotSynced('Sales pending synchronization'),

  refundsNotSynced('Refunds pending synchronization'),

  cashOperationsNotSynced('Cash operations pending synchronization'),

  noNetwork('No network connection');

  const UpdateBlockReason(this.message);

  final String message;
}

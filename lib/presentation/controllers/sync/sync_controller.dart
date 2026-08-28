import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';
import 'package:telepos/app/config/local_properties.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/sync/couchdb_sync_coordinator.dart';
import 'package:telepos/l10n/app_localizations.dart';

enum SyncDirection { download, upload }

enum SyncDataType {
  products(SyncDirection.download),
  prices(SyncDirection.download),
  categories(SyncDirection.download),
  agents(SyncDirection.download),
  config(SyncDirection.download),

  sales(SyncDirection.upload),
  refunds(SyncDirection.upload),
  cashOps(SyncDirection.upload),
  shifts(SyncDirection.upload),
  supplies(SyncDirection.upload);

  const SyncDataType(this.direction);

  final SyncDirection direction;

  String getLabel(AppLocalizations l10n) {
    return switch (this) {
      SyncDataType.products => l10n.syncTypeProducts,
      SyncDataType.prices => l10n.syncTypePrices,
      SyncDataType.categories => l10n.syncTypeCategories,
      SyncDataType.agents => l10n.syncTypeAgents,
      SyncDataType.config => l10n.syncTypeConfig,
      SyncDataType.sales => l10n.syncTypeSales,
      SyncDataType.refunds => l10n.syncTypeRefunds,
      SyncDataType.cashOps => l10n.syncTypeCashOps,
      SyncDataType.shifts => l10n.syncTypeShifts,
      SyncDataType.supplies => l10n.syncTypeSupplies,
    };
  }
}

enum SyncItemStatus { pending, inProgress, completed, error }

@immutable
class SyncItem {
  const SyncItem({
    required this.type,
    required this.pendingCount,
    required this.status,
    this.errorMessage,
    this.progressPercent = 0,
  });

  final SyncDataType type;
  final int pendingCount;
  final SyncItemStatus status;
  final String? errorMessage;
  final int progressPercent;

  SyncItem copyWith({
    SyncDataType? type,
    int? pendingCount,
    SyncItemStatus? status,
    String? errorMessage,
    int? progressPercent,
  }) {
    return SyncItem(
      type: type ?? this.type,
      pendingCount: pendingCount ?? this.pendingCount,
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
      progressPercent: progressPercent ?? this.progressPercent,
    );
  }
}

enum SyncStatus { idle, syncing, completed, error }

@immutable
class SyncState {
  const SyncState({
    required this.status,
    required this.items,
    this.currentStep,
    this.totalSteps = 0,
    this.overallProgress = 0,
    this.lastSyncTime,
    this.errorMessage,
    this.syncIntervalMinutes = 5,
    this.autoSyncEnabled = true,
  });

  factory SyncState.initial() {
    return SyncState(
      status: SyncStatus.idle,
      items: SyncDataType.values
          .map(
            (type) => SyncItem(
              type: type,
              pendingCount: _getMockPendingCount(type),
              status: SyncItemStatus.pending,
            ),
          )
          .toList(),
    );
  }

  final SyncStatus status;
  final List<SyncItem> items;
  final String? currentStep;
  final int totalSteps;
  final int overallProgress;
  final DateTime? lastSyncTime;
  final String? errorMessage;

  final int syncIntervalMinutes;

  final bool autoSyncEnabled;

  int get totalPendingUploads => items
      .where((item) => item.type.direction == SyncDirection.upload)
      .fold(0, (sum, item) => sum + item.pendingCount);

  int get totalPendingDownloads => items
      .where((item) => item.type.direction == SyncDirection.download)
      .fold(0, (sum, item) => sum + item.pendingCount);

  bool get hasPendingData => totalPendingUploads > 0;

  SyncState copyWith({
    SyncStatus? status,
    List<SyncItem>? items,
    String? currentStep,
    int? totalSteps,
    int? overallProgress,
    DateTime? lastSyncTime,
    String? errorMessage,
    int? syncIntervalMinutes,
    bool? autoSyncEnabled,
  }) {
    return SyncState(
      status: status ?? this.status,
      items: items ?? this.items,
      currentStep: currentStep ?? this.currentStep,
      totalSteps: totalSteps ?? this.totalSteps,
      overallProgress: overallProgress ?? this.overallProgress,
      lastSyncTime: lastSyncTime ?? this.lastSyncTime,
      errorMessage: errorMessage ?? this.errorMessage,
      syncIntervalMinutes: syncIntervalMinutes ?? this.syncIntervalMinutes,
      autoSyncEnabled: autoSyncEnabled ?? this.autoSyncEnabled,
    );
  }

  static int _getMockPendingCount(SyncDataType type) {
    return 0;
  }
}

class SyncNotifier extends Notifier<SyncState> {
  @override
  SyncState build() {
    Future.microtask(_loadInitialState);
    return SyncState.initial();
  }

  AppDatabase get _db => GetIt.I<AppDatabase>();
  LocalProperties? get _prefs => GetIt.I.isRegistered<LocalProperties>()
      ? GetIt.I<LocalProperties>()
      : null;
  CouchDbSyncCoordinator? get _coordinator =>
      GetIt.I.isRegistered<CouchDbSyncCoordinator>()
      ? GetIt.I<CouchDbSyncCoordinator>()
      : null;

  Future<void> _loadInitialState() async {
    await _loadSettings();
    await _loadPendingCounts();
  }

  Future<void> _loadSettings() async {
    final prefs = _prefs;
    if (prefs != null) {
      state = state.copyWith(
        syncIntervalMinutes: prefs.syncIntervalMinutes,
        autoSyncEnabled: prefs.autoSyncEnabled,
      );
    }
  }

  Future<void> _loadPendingCounts() async {
    try {
      final salesCount = await _db.saleDao.countWithState(1);
      final refundsCount = await _db.refundDao.countWithState(1);
      final shiftsCount = await _db.shiftDao.countUnsyncedReports();
      final agentsCount = await _db.agentDao.countUnSyncedCustomers();

      final updatedItems = state.items.map((item) {
        final count = switch (item.type) {
          SyncDataType.sales => salesCount,
          SyncDataType.refunds => refundsCount,
          SyncDataType.shifts => shiftsCount,
          SyncDataType.agents => agentsCount,
          _ => item.pendingCount,
        };
        return item.copyWith(pendingCount: count);
      }).toList();

      state = state.copyWith(items: updatedItems);
    } catch (e) {}
  }

  Future<void> startSync() async {
    if (state.status == SyncStatus.syncing) return;

    final coordinator = _coordinator;
    if (coordinator == null) {
      state = state.copyWith(
        status: SyncStatus.error,
        currentStep: 'offline',
        errorMessage: 'offline / sync not configured',
      );
      await _loadPendingCounts();
      return;
    }

    state = state.copyWith(
      status: SyncStatus.syncing,
      currentStep: 'syncing',
      totalSteps: state.items.length,
      overallProgress: 0,
      errorMessage: null,
    );

    final inProgressItems = state.items
        .map(
          (item) =>
              item.type.direction == SyncDirection.upload &&
                  item.pendingCount > 0
              ? item.copyWith(status: SyncItemStatus.inProgress)
              : item,
        )
        .toList();
    state = state.copyWith(items: inProgressItems);

    final result = await coordinator.syncNow();

    if (state.status != SyncStatus.syncing) {
      return;
    }

    if (!result.ok) {
      final resetItems = state.items
          .map(
            (item) => item.status == SyncItemStatus.inProgress
                ? item.copyWith(status: SyncItemStatus.pending)
                : item,
          )
          .toList();
      state = state.copyWith(
        status: SyncStatus.error,
        items: resetItems,
        currentStep: result.skippedReason ?? 'error',
        overallProgress: 0,
        errorMessage: switch (result.skippedReason) {
          'not_configured' => 'offline / sync not configured',
          'offline' => 'offline / server unreachable',
          'already_running' => 'sync already running',
          _ => 'sync failed',
        },
      );
      await _loadPendingCounts();
      return;
    }

    state = state.copyWith(
      status: SyncStatus.completed,
      currentStep: 'completed',
      lastSyncTime: DateTime.now(),
      overallProgress: 100,
      errorMessage: null,
    );
    await _loadPendingCounts();
  }

  void abortSync() {
    if (state.status != SyncStatus.syncing) return;

    final updatedItems = state.items.map((item) {
      if (item.status == SyncItemStatus.inProgress) {
        return item.copyWith(
          status: SyncItemStatus.pending,
          progressPercent: 0,
        );
      }
      return item;
    }).toList();

    state = state.copyWith(
      status: SyncStatus.idle,
      items: updatedItems,
      currentStep: null,
      overallProgress: 0,
    );
  }

  void reset() {
    state = SyncState.initial();
    _loadPendingCounts();
  }

  Future<void> refresh() async {
    await _loadPendingCounts();
  }

  void setSyncInterval(int minutes) {
    if (![5, 10, 15, 30].contains(minutes)) return;

    _prefs?.syncIntervalMinutes = minutes;
    state = state.copyWith(syncIntervalMinutes: minutes);
  }

  void setAutoSyncEnabled(bool enabled) {
    _prefs?.autoSyncEnabled = enabled;
    state = state.copyWith(autoSyncEnabled: enabled);
  }

  static const List<int> availableIntervals = [5, 10, 15, 30];
}

final syncProvider = NotifierProvider<SyncNotifier, SyncState>(
  SyncNotifier.new,
);

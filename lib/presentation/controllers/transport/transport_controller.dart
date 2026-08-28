import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:talker/talker.dart';

import '../../../data/sync/couchdb_sync_coordinator.dart';
import '../../../telegram/data_exchange/sync_state_tracker.dart';
import '../../../telegram/data_exchange/telegram_sync_engine.dart';
import '../../../transport/transport_exports.dart';

class TransportState {
  final TransportMode mode;

  final TransportStatus primaryStatus;

  final TransportStatus? secondaryStatus;

  final bool isSyncing;

  final DateTime? lastSyncTime;

  final int queuedOperationsCount;

  final int failedOperationsCount;

  final String? error;

  final TransportType activeTransport;

  const TransportState({
    this.mode = TransportMode.restOnly,
    this.primaryStatus = TransportStatus.disconnected,
    this.secondaryStatus,
    this.isSyncing = false,
    this.lastSyncTime,
    this.queuedOperationsCount = 0,
    this.failedOperationsCount = 0,
    this.error,
    this.activeTransport = TransportType.none,
  });

  bool get isConnected => primaryStatus == TransportStatus.connected;

  bool get hasPendingOperations => queuedOperationsCount > 0;

  bool get hasIssues => failedOperationsCount > 0 || error != null;

  TransportDisplayStatus get displayStatus {
    if (isSyncing) return TransportDisplayStatus.syncing;
    if (error != null) return TransportDisplayStatus.error;
    if (failedOperationsCount > 0) return TransportDisplayStatus.warning;
    if (queuedOperationsCount > 0) return TransportDisplayStatus.queued;
    if (isConnected) return TransportDisplayStatus.online;
    return TransportDisplayStatus.offline;
  }

  TransportState copyWith({
    TransportMode? mode,
    TransportStatus? primaryStatus,
    TransportStatus? secondaryStatus,
    bool? isSyncing,
    DateTime? lastSyncTime,
    int? queuedOperationsCount,
    int? failedOperationsCount,
    String? error,
    TransportType? activeTransport,
  }) {
    return TransportState(
      mode: mode ?? this.mode,
      primaryStatus: primaryStatus ?? this.primaryStatus,
      secondaryStatus: secondaryStatus ?? this.secondaryStatus,
      isSyncing: isSyncing ?? this.isSyncing,
      lastSyncTime: lastSyncTime ?? this.lastSyncTime,
      queuedOperationsCount:
          queuedOperationsCount ?? this.queuedOperationsCount,
      failedOperationsCount:
          failedOperationsCount ?? this.failedOperationsCount,
      error: error,
      activeTransport: activeTransport ?? this.activeTransport,
    );
  }
}

enum TransportDisplayStatus { online, offline, syncing, queued, warning, error }

class TransportNotifier extends Notifier<TransportState> {
  TelegramSyncEngine? _syncEngine;
  SyncStateTracker? _stateTracker;
  Talker? _logger;

  @override
  TransportState build() {
    _initServices();

    return const TransportState(
      mode: TransportMode.telegramOnly,
      primaryStatus: TransportStatus.disconnected,
      activeTransport: TransportType.telegram,
    );
  }

  void _initServices() {
    try {
      _logger = GetIt.I<Talker>();

      if (GetIt.I.isRegistered<TelegramSyncEngine>()) {
        _syncEngine = GetIt.I<TelegramSyncEngine>();
        _logger?.debug('TransportNotifier: SyncEngine connected');
      }

      _initStateTracker();
    } catch (e) {
      _logger?.warning('TransportNotifier init failed: $e');
    }
  }

  Future<void> _initStateTracker() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _stateTracker = SyncStateTracker(prefs: prefs);
      _syncEngine?.setStateTracker(_stateTracker!);

      final snapshot = _stateTracker!.getSnapshot();
      if (snapshot.latestSync != null) {
        state = state.copyWith(lastSyncTime: snapshot.latestSync);
      }

      final savedMode = prefs.getString('transport_mode');
      if (savedMode != null) {
        for (final mode in TransportMode.values) {
          if (mode.name == savedMode) {
            state = state.copyWith(mode: mode);
            break;
          }
        }
      }
    } catch (e) {
      _logger?.warning('SyncStateTracker init failed: $e');
    }
  }

  SyncStateSnapshot? getSyncSnapshot() {
    return _stateTracker?.getSnapshot();
  }

  void updateStatus({
    TransportStatus? primaryStatus,
    TransportStatus? secondaryStatus,
    bool? isSyncing,
    String? error,
  }) {
    state = state.copyWith(
      primaryStatus: primaryStatus,
      secondaryStatus: secondaryStatus,
      isSyncing: isSyncing,
      error: error,
    );
  }

  void updateQueueStats({required int queued, required int failed}) {
    state = state.copyWith(
      queuedOperationsCount: queued,
      failedOperationsCount: failed,
    );
  }

  void setLastSyncTime(DateTime time) {
    state = state.copyWith(lastSyncTime: time);
  }

  void clearError() {
    state = state.copyWith(error: null);
  }

  Future<void> changeMode(TransportMode mode) async {
    state = state.copyWith(mode: mode);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('transport_mode', mode.name);
    } catch (e) {
      _logger?.warning('changeMode: failed to persist mode: $e');
    }
  }

  Future<void> forceSync() async {
    state = state.copyWith(isSyncing: true, error: null);
    _logger?.info('Force sync started');

    try {
      if (_syncEngine != null) {
        await _syncEngine!.syncAll();

        state = state.copyWith(
          isSyncing: false,
          lastSyncTime: DateTime.now(),
          primaryStatus: TransportStatus.connected,
        );
        _logger?.info('Force sync completed');
        return;
      }

      final coordinator = _couchCoordinator;
      if (coordinator == null) {
        state = state.copyWith(
          isSyncing: false,
          primaryStatus: TransportStatus.disconnected,
          error: 'offline / sync not configured',
        );
        _logger?.warning(
          'Force sync: no sync engine and no CouchDB coordinator',
        );
        return;
      }

      final result = await coordinator.syncNow();
      if (result.ok) {
        state = state.copyWith(
          isSyncing: false,
          lastSyncTime: DateTime.now(),
          primaryStatus: TransportStatus.connected,
        );
        _logger?.info(
          'Force sync completed (pushed=${result.pushed}, pulled=${result.pulled})',
        );
      } else {
        state = state.copyWith(
          isSyncing: false,
          primaryStatus: TransportStatus.disconnected,
          error: result.skippedReason ?? 'sync unavailable',
        );
        _logger?.warning('Force sync no-op: ${result.skippedReason}');
      }
    } catch (e) {
      _logger?.error('Force sync failed: $e');
      state = state.copyWith(
        isSyncing: false,
        error: e.toString(),
        primaryStatus: TransportStatus.error,
      );
    }
  }

  CouchDbSyncCoordinator? get _couchCoordinator =>
      GetIt.I.isRegistered<CouchDbSyncCoordinator>()
      ? GetIt.I<CouchDbSyncCoordinator>()
      : null;

  Future<void> forceSyncAll() async {
    state = state.copyWith(isSyncing: true, error: null);
    _logger?.info('Force full sync started');

    try {
      if (_syncEngine != null) {
        await _syncEngine!.forceSyncAll();

        state = state.copyWith(
          isSyncing: false,
          lastSyncTime: DateTime.now(),
          primaryStatus: TransportStatus.connected,
        );
        _logger?.info('Force full sync completed');
        return;
      }

      final coordinator = _couchCoordinator;
      if (coordinator == null) {
        state = state.copyWith(
          isSyncing: false,
          primaryStatus: TransportStatus.disconnected,
          error: 'offline / sync not configured',
        );
        _logger?.warning(
          'Force full sync: no sync engine and no CouchDB coordinator',
        );
        return;
      }

      final result = await coordinator.syncNow();
      if (result.ok) {
        state = state.copyWith(
          isSyncing: false,
          lastSyncTime: DateTime.now(),
          primaryStatus: TransportStatus.connected,
        );
        _logger?.info(
          'Force full sync completed (pushed=${result.pushed}, pulled=${result.pulled})',
        );
      } else {
        state = state.copyWith(
          isSyncing: false,
          primaryStatus: TransportStatus.disconnected,
          error: result.skippedReason ?? 'sync unavailable',
        );
        _logger?.warning('Force full sync no-op: ${result.skippedReason}');
      }
    } catch (e) {
      _logger?.error('Force full sync failed: $e');
      state = state.copyWith(isSyncing: false, error: e.toString());
    }
  }

  Future<void> retryFailed() async {
    if (state.failedOperationsCount == 0 && state.queuedOperationsCount == 0) {
      return;
    }

    state = state.copyWith(isSyncing: true, error: null);
    _logger?.info('Retry failed operations started');

    try {
      if (_syncEngine != null) {
        await _syncEngine!.syncAll();
        state = state.copyWith(
          isSyncing: false,
          failedOperationsCount: 0,
          lastSyncTime: DateTime.now(),
          primaryStatus: TransportStatus.connected,
        );
        _logger?.info('Retry failed completed via sync engine');
        return;
      }

      final coordinator = _couchCoordinator;
      if (coordinator == null) {
        state = state.copyWith(
          isSyncing: false,
          primaryStatus: TransportStatus.disconnected,
          error: 'offline / sync not configured',
        );
        _logger?.warning(
          'Retry failed: no sync engine and no CouchDB coordinator',
        );
        return;
      }

      final result = await coordinator.syncNow();
      if (result.ok) {
        state = state.copyWith(
          isSyncing: false,
          failedOperationsCount: 0,
          lastSyncTime: DateTime.now(),
          primaryStatus: TransportStatus.connected,
        );
        _logger?.info(
          'Retry failed completed (pushed=${result.pushed}, pulled=${result.pulled})',
        );
      } else {
        state = state.copyWith(
          isSyncing: false,
          primaryStatus: TransportStatus.disconnected,
          error: result.skippedReason ?? 'retry unavailable',
        );
        _logger?.warning('Retry failed no-op: ${result.skippedReason}');
      }
    } catch (e) {
      _logger?.error('Retry failed errored: $e');
      state = state.copyWith(
        isSyncing: false,
        error: e.toString(),
        primaryStatus: TransportStatus.error,
      );
    }
  }
}

final transportControllerProvider =
    NotifierProvider<TransportNotifier, TransportState>(TransportNotifier.new);

final transportModeProvider = Provider<TransportMode>((ref) {
  return ref.watch(transportControllerProvider).mode;
});

final transportDisplayStatusProvider = Provider<TransportDisplayStatus>((ref) {
  return ref.watch(transportControllerProvider).displayStatus;
});

final queuedOperationsProvider = Provider<int>((ref) {
  return ref.watch(transportControllerProvider).queuedOperationsCount;
});

final failedOperationsProvider = Provider<int>((ref) {
  return ref.watch(transportControllerProvider).failedOperationsCount;
});

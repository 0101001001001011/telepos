import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:telepos/data/sysd/sysd_client.dart';

class SystemManagementState {
  const SystemManagementState({
    this.loading = true,
    this.available = false,
    this.health,
    this.update,
    this.backups = const [],
    this.snapshots = const [],
    this.snapshotSupported = false,
    this.display,
    this.displayControllable = false,
    this.service,
    this.time,
    this.savingTimezone = false,
    this.ntpSyncing = false,
    this.refreshingHealth = false,
    this.checkingUpdate = false,
    this.updating = false,
    this.updateProgress,
    this.busyBackup,
    this.creatingBackup = false,
    this.busySnapshot,
    this.creatingSnapshot = false,
    this.togglingRemote = false,
    this.powerBusy = false,
    this.error,
  });

  final bool loading;

  final bool available;

  final SystemHealth? health;
  final UpdateInfo? update;
  final List<BackupItem> backups;
  final List<SnapshotItem> snapshots;
  final bool snapshotSupported;
  final DisplayInfo? display;

  final bool displayControllable;
  final ServiceStatus? service;

  final SystemTime? time;

  final bool savingTimezone;

  final bool ntpSyncing;

  final bool refreshingHealth;
  final bool checkingUpdate;
  final bool updating;

  final String? updateProgress;

  final String? busyBackup;
  final bool creatingBackup;

  final String? busySnapshot;
  final bool creatingSnapshot;

  final bool togglingRemote;
  final bool powerBusy;

  final String? error;

  SystemManagementState copyWith({
    bool? loading,
    bool? available,
    SystemHealth? health,
    UpdateInfo? update,
    List<BackupItem>? backups,
    List<SnapshotItem>? snapshots,
    bool? snapshotSupported,
    DisplayInfo? display,
    bool? displayControllable,
    ServiceStatus? service,
    SystemTime? time,
    bool? savingTimezone,
    bool? ntpSyncing,
    bool? refreshingHealth,
    bool? checkingUpdate,
    bool? updating,
    String? updateProgress,
    String? busyBackup,
    bool? creatingBackup,
    String? busySnapshot,
    bool? creatingSnapshot,
    bool? togglingRemote,
    bool? powerBusy,
    String? error,
  }) {
    return SystemManagementState(
      loading: loading ?? this.loading,
      available: available ?? this.available,
      health: health ?? this.health,
      update: update ?? this.update,
      backups: backups ?? this.backups,
      snapshots: snapshots ?? this.snapshots,
      snapshotSupported: snapshotSupported ?? this.snapshotSupported,
      display: display ?? this.display,
      displayControllable: displayControllable ?? this.displayControllable,
      service: service ?? this.service,
      time: time ?? this.time,
      savingTimezone: savingTimezone ?? this.savingTimezone,
      ntpSyncing: ntpSyncing ?? this.ntpSyncing,
      refreshingHealth: refreshingHealth ?? this.refreshingHealth,
      checkingUpdate: checkingUpdate ?? this.checkingUpdate,
      updating: updating ?? this.updating,
      updateProgress: updateProgress,
      busyBackup: busyBackup,
      creatingBackup: creatingBackup ?? this.creatingBackup,
      busySnapshot: busySnapshot,
      creatingSnapshot: creatingSnapshot ?? this.creatingSnapshot,
      togglingRemote: togglingRemote ?? this.togglingRemote,
      powerBusy: powerBusy ?? this.powerBusy,
      error: error,
    );
  }
}

class SystemManagementNotifier extends Notifier<SystemManagementState> {
  final SysdClient _sysd = SysdClient();

  @override
  SystemManagementState build() => const SystemManagementState();

  Future<void> load() async {
    state = state.copyWith(loading: true, error: null);
    SystemHealth health;
    try {
      health = await _sysd.systemHealth();
    } catch (_) {
      state = state.copyWith(loading: false, available: false);
      return;
    }
    state = state.copyWith(loading: false, available: true, health: health);
    await Future.wait([
      _loadUpdate(),
      _loadBackups(),
      _loadSnapshots(),
      _loadDisplay(),
      _loadService(),
      _loadTime(),
    ]);
  }

  Future<void> refreshHealth() async {
    if (!state.available) return;
    state = state.copyWith(refreshingHealth: true, error: null);
    try {
      final h = await _sysd.systemHealth();
      state = state.copyWith(refreshingHealth: false, health: h);
    } catch (e) {
      state = state.copyWith(refreshingHealth: false, error: e.toString());
    }
  }

  Future<void> _loadUpdate() async {
    try {
      final u = await _sysd.updateVersion();
      state = state.copyWith(update: u);
    } catch (_) {}
  }

  Future<void> checkUpdate() async {
    if (!state.available) return;
    state = state.copyWith(checkingUpdate: true, error: null);
    try {
      final u = await _sysd.updateCheck();
      state = state.copyWith(checkingUpdate: false, update: u);
    } catch (e) {
      state = state.copyWith(checkingUpdate: false, error: e.toString());
    }
  }

  Future<bool> applyUpdate(String Function(String phase) progress) async {
    final u = state.update;
    if (u == null || !u.updateAvailable) return false;
    state = state.copyWith(updating: true, error: null);
    try {
      state = state.copyWith(updateProgress: progress('download'));
      state = state.copyWith(updateProgress: progress('apply'));
      await _sysd.updateApply();
      state = state.copyWith(updating: false, updateProgress: null);
      return true;
    } catch (e) {
      state = state.copyWith(
        updating: false,
        updateProgress: null,
        error: e.toString(),
      );
      return false;
    }
  }

  Future<bool> rollbackUpdate() async {
    state = state.copyWith(updating: true, error: null);
    try {
      await _sysd.updateRollback();
      state = state.copyWith(updating: false);
      return true;
    } catch (e) {
      state = state.copyWith(updating: false, error: e.toString());
      return false;
    }
  }

  Future<void> _loadBackups() async {
    try {
      final b = await _sysd.backupList();
      state = state.copyWith(backups: b);
    } catch (_) {}
  }

  Future<bool> createBackup() async {
    state = state.copyWith(creatingBackup: true, error: null);
    try {
      await _sysd.backupCreate();
      state = state.copyWith(creatingBackup: false);
      await _loadBackups();
      return true;
    } catch (e) {
      state = state.copyWith(creatingBackup: false, error: e.toString());
      return false;
    }
  }

  Future<bool> restoreBackup(String name) async {
    state = state.copyWith(busyBackup: name, error: null);
    try {
      await _sysd.backupRestore(name);
      state = state.copyWith(busyBackup: null);
      return true;
    } catch (e) {
      state = state.copyWith(busyBackup: null, error: e.toString());
      return false;
    }
  }

  Future<bool> exportBackupUsb(String name) async {
    state = state.copyWith(busyBackup: name, error: null);
    try {
      await _sysd.backupExportUsb(name);
      state = state.copyWith(busyBackup: null);
      return true;
    } catch (e) {
      state = state.copyWith(busyBackup: null, error: e.toString());
      return false;
    }
  }

  Future<bool> importBackupUsb() async {
    state = state.copyWith(creatingBackup: true, error: null);
    try {
      await _sysd.backupImportUsb();
      state = state.copyWith(creatingBackup: false);
      await _loadBackups();
      return true;
    } catch (e) {
      state = state.copyWith(creatingBackup: false, error: e.toString());
      return false;
    }
  }

  Future<void> _loadSnapshots() async {
    try {
      final supported = await _sysd.snapshotAvailable();
      state = state.copyWith(snapshotSupported: supported);
      if (supported) {
        final s = await _sysd.snapshotList();
        state = state.copyWith(snapshots: s);
      }
    } catch (_) {}
  }

  Future<bool> createSnapshot([String? name]) async {
    state = state.copyWith(creatingSnapshot: true, error: null);
    try {
      await _sysd.snapshotCreate(name);
      state = state.copyWith(creatingSnapshot: false);
      await _loadSnapshots();
      return true;
    } catch (e) {
      state = state.copyWith(creatingSnapshot: false, error: e.toString());
      return false;
    }
  }

  Future<bool?> rollbackSnapshot(String name) async {
    state = state.copyWith(busySnapshot: name, error: null);
    try {
      final rebootRequired = await _sysd.snapshotRollback(name);
      state = state.copyWith(busySnapshot: null);
      return rebootRequired;
    } catch (e) {
      state = state.copyWith(busySnapshot: null, error: e.toString());
      return null;
    }
  }

  Future<bool> factoryReset() async {
    state = state.copyWith(powerBusy: true, error: null);
    try {
      await _sysd.factoryReset();
      state = state.copyWith(powerBusy: false);
      return true;
    } catch (e) {
      state = state.copyWith(powerBusy: false, error: e.toString());
      return false;
    }
  }

  Future<void> _loadDisplay() async {
    try {
      final b = await _sysd.displayGetBrightness();
      final prev = state.display;
      state = state.copyWith(
        display: DisplayInfo(brightness: b, rotation: prev?.rotation ?? 0),
        displayControllable: true,
      );
    } catch (_) {
      state = state.copyWith(displayControllable: false);
    }
  }

  Future<void> setBrightness(int value) async {
    final prev = state.display;
    if (prev != null) {
      state = state.copyWith(
        display: DisplayInfo(brightness: value, rotation: prev.rotation),
      );
    }
    try {
      await _sysd.displaySetBrightness(value);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> setRotation(int rotation) async {
    final prev = state.display;
    try {
      await _sysd.displaySetRotation(rotation);
      state = state.copyWith(
        display: DisplayInfo(
          brightness: prev?.brightness ?? 0,
          rotation: rotation,
        ),
      );
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> _loadService() async {
    try {
      final s = await _sysd.serviceStatus();
      state = state.copyWith(service: s);
    } catch (_) {}
  }

  Future<bool> enableRemote({int minutes = 30}) async {
    state = state.copyWith(togglingRemote: true, error: null);
    try {
      await _sysd.serviceRemoteEnable(minutes: minutes);
      state = state.copyWith(togglingRemote: false);
      await _loadService();
      return true;
    } catch (e) {
      state = state.copyWith(togglingRemote: false, error: e.toString());
      return false;
    }
  }

  Future<bool> disableRemote() async {
    state = state.copyWith(togglingRemote: true, error: null);
    try {
      await _sysd.serviceRemoteDisable();
      state = state.copyWith(togglingRemote: false);
      await _loadService();
      return true;
    } catch (e) {
      state = state.copyWith(togglingRemote: false, error: e.toString());
      return false;
    }
  }

  Future<void> _loadTime() async {
    try {
      final t = await _sysd.getTime();
      state = state.copyWith(time: t);
    } catch (_) {}
  }

  Future<void> refreshTime() async {
    if (!state.available) return;
    try {
      final t = await _sysd.getTime();
      state = state.copyWith(time: t);
    } catch (_) {}
  }

  Future<bool> setTimezone(String timezone) async {
    state = state.copyWith(savingTimezone: true, error: null);
    try {
      final r = await _sysd.setTimezone(timezone);
      await _loadTime();
      state = state.copyWith(savingTimezone: false);
      return r.success;
    } catch (e) {
      state = state.copyWith(savingTimezone: false, error: e.toString());
      return false;
    }
  }

  Future<NtpSyncResult?> ntpSync() async {
    state = state.copyWith(ntpSyncing: true, error: null);
    try {
      final r = await _sysd.ntpSync();
      await _loadTime();
      state = state.copyWith(ntpSyncing: false);
      return r;
    } catch (e) {
      state = state.copyWith(ntpSyncing: false, error: e.toString());
      return null;
    }
  }

  Future<ExecResult> exec(String command, {int? timeout, String? cwd}) {
    return _sysd.systemExec(command, timeout: timeout, cwd: cwd);
  }

  Future<bool> reboot() async {
    state = state.copyWith(powerBusy: true, error: null);
    try {
      await _sysd.reboot();
      state = state.copyWith(powerBusy: false);
      return true;
    } catch (e) {
      state = state.copyWith(powerBusy: false, error: e.toString());
      return false;
    }
  }

  Future<bool> shutdown() async {
    state = state.copyWith(powerBusy: true, error: null);
    try {
      await _sysd.shutdown();
      state = state.copyWith(powerBusy: false);
      return true;
    } catch (e) {
      state = state.copyWith(powerBusy: false, error: e.toString());
      return false;
    }
  }
}

final systemManagementControllerProvider =
    NotifierProvider<SystemManagementNotifier, SystemManagementState>(
      SystemManagementNotifier.new,
    );

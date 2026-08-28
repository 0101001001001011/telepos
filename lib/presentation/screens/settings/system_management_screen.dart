import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:telepos/app/router/app_routes.dart';
import 'package:telepos/app/theme/app_colors.dart';
import 'package:telepos/app/theme/app_semantic_colors.dart';
import 'package:telepos/app/theme/app_theme.dart';
import 'package:telepos/app/theme/telepos_icons.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/presentation/controllers/system/system_management_controller.dart';
import 'package:telepos/data/sysd/sysd_client.dart';
import 'package:telepos/core/constants/enums/user_role.dart';
import 'package:telepos/presentation/common/widgets/owner_only_gate.dart';
import 'package:telepos/presentation/controllers/app/app_state_controller.dart';

class SystemManagementScreen extends ConsumerStatefulWidget {
  const SystemManagementScreen({super.key});

  @override
  ConsumerState<SystemManagementScreen> createState() =>
      _SystemManagementScreenState();
}

class _SystemManagementScreenState
    extends ConsumerState<SystemManagementScreen> {
  Timer? _poll;

  String? _selectedTimezone;

  static const List<String> _timezones = [
    'Asia/Almaty',
    'Asia/Aqtau',
    'Asia/Aqtobe',
    'Asia/Atyrau',
    'Asia/Oral',
    'Asia/Qostanay',
    'Asia/Qyzylorda',
    'Asia/Tashkent',
    'Asia/Bishkek',
    'Europe/Moscow',
    'UTC',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await ref.read(systemManagementControllerProvider.notifier).load();
      _poll = Timer.periodic(const Duration(seconds: 10), (_) {
        final n = ref.read(systemManagementControllerProvider.notifier);
        n.refreshHealth();
        n.refreshTime();
      });
    });
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  SystemManagementNotifier get _ctrl =>
      ref.read(systemManagementControllerProvider.notifier);

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: error
            ? Theme.of(context).colorScheme.error
            : AppColors.success,
      ),
    );
  }

  Future<bool> _confirm({
    required String title,
    required String message,
    required String confirmLabel,
    bool destructive = false,
  }) async {
    final l10n = AppLocalizations.of(context)!;
    final res = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.globalCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: destructive
                  ? Theme.of(context).colorScheme.error
                  : AppColors.primary,
            ),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    return res ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final role = ref.watch(appStateProvider.select((s) => s.userRole));
    if (role != null && role != UserRole.owner.index) {
      return ownerOnlyScaffold(context, l10n.sysmTitle);
    }
    final state = ref.watch(systemManagementControllerProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.sysmTitle),
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: state.loading ? null : () => _ctrl.load(),
            icon: const Icon(Icons.refresh),
            tooltip: l10n.networkRefresh,
          ),
        ],
      ),
      body: state.loading
          ? const Center(child: CircularProgressIndicator())
          : !state.available
          ? _buildUnavailable(l10n)
          : _buildBody(l10n, state),
    );
  }

  Widget _buildUnavailable(AppLocalizations l10n) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.dvr_outlined,
              size: 56,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              l10n.networkUnavailableTitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.applianceUnavailableDesc,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(AppLocalizations l10n, SystemManagementState state) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHealthCard(l10n, state),
              const SizedBox(height: 20),
              _buildUpdateCard(l10n, state),
              const SizedBox(height: 20),
              _buildBackupCard(l10n, state),
              const SizedBox(height: 20),
              _buildSnapshotCard(l10n, state),
              const SizedBox(height: 20),
              _buildDisplayCard(l10n, state),
              const SizedBox(height: 20),
              _buildTimeCard(l10n, state),
              const SizedBox(height: 20),
              _buildTerminalCard(l10n, state),
              const SizedBox(height: 20),
              _buildJournalCard(l10n),
              const SizedBox(height: 20),
              _buildRemoteCard(l10n, state),
              const SizedBox(height: 20),
              _buildPowerCard(l10n, state),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHealthCard(AppLocalizations l10n, SystemManagementState state) {
    final h = state.health;
    return _card(
      icon: Icons.monitor_heart_outlined,
      title: l10n.sysmHealthTitle,
      description: l10n.sysmHealthDesc,
      trailing: state.refreshingHealth
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : IconButton(
              icon: const Icon(Icons.refresh, size: 20),
              onPressed: () => _ctrl.refreshHealth(),
              tooltip: l10n.networkRefresh,
            ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        child: h == null
            ? Text(
                l10n.sysmNoData,
                style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              )
            : Column(
                children: [
                  _metric(
                    l10n.sysmCpu,
                    '${h.cpuPercent.toStringAsFixed(0)}% · ${h.cpuCores} ${l10n.sysmCores}',
                    h.cpuPercent / 100,
                  ),
                  _metric(
                    l10n.sysmRam,
                    '${h.memoryUsedMb} / ${h.memoryTotalMb} ${l10n.sysmMb}',
                    h.memoryPercent / 100,
                  ),
                  _metric(
                    l10n.sysmDisk,
                    '${h.diskAvailableGb.toStringAsFixed(1)} ${l10n.sysmGbFree} / ${h.diskTotalGb.toStringAsFixed(1)} ${l10n.sysmGb}',
                    h.diskTotalGb > 0
                        ? 1 - (h.diskAvailableGb / h.diskTotalGb)
                        : 0,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: _kv(
                          l10n.sysmTemperature,
                          h.temperatureC != null
                              ? '${h.temperatureC!.toStringAsFixed(1)} °C'
                              : '—',
                        ),
                      ),
                      Expanded(
                        child: _kv(
                          l10n.sysmUptime,
                          _formatUptime(l10n, h.uptimeSecs),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
      ),
    );
  }

  Widget _metric(String label, String value, double fraction) {
    final f = fraction.clamp(0.0, 1.0);
    final color = f > 0.85
        ? Theme.of(context).colorScheme.error
        : f > 0.65
        ? AppColors.warning
        : AppColors.success;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: f,
              minHeight: 6,
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
        ],
      ),
    );
  }

  String _formatUptime(AppLocalizations l10n, int secs) {
    final d = secs ~/ 86400;
    final hrs = (secs % 86400) ~/ 3600;
    final mins = (secs % 3600) ~/ 60;
    if (d > 0) return '$d${l10n.sysmDaysShort} $hrs${l10n.sysmHoursShort}';
    if (hrs > 0) return '$hrs${l10n.sysmHoursShort} $mins${l10n.sysmMinsShort}';
    return '$mins${l10n.sysmMinsShort}';
  }

  Widget _buildUpdateCard(AppLocalizations l10n, SystemManagementState state) {
    final u = state.update;
    return _card(
      icon: Icons.system_update_alt,
      title: l10n.sysmUpdateTitle,
      description: l10n.sysmUpdateDesc,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _kv(l10n.sysmCurrentVersion, u?.currentVersion ?? '—'),
            if (u?.latestVersion != null)
              _kv(l10n.sysmLatestVersion, u!.latestVersion!),
            if (u?.updateAvailable == true)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Row(
                  children: [
                    const Icon(
                      Icons.new_releases,
                      size: 16,
                      color: AppColors.warningGold,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      l10n.sysmUpdateAvailable,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.warningGold,
                      ),
                    ),
                  ],
                ),
              ),
            if (u?.releaseNotes != null && u!.releaseNotes!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  u.releaseNotes!,
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            if (state.updating && state.updateProgress != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Row(
                  children: [
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      _updatePhaseLabel(l10n, state.updateProgress!),
                      style: TextStyle(
                        fontSize: 13,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: state.checkingUpdate || state.updating
                        ? null
                        : () => _ctrl.checkUpdate(),
                    icon: state.checkingUpdate
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.search, size: 18),
                    label: Text(l10n.sysmCheckUpdate),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: (u?.updateAvailable == true) && !state.updating
                        ? () => _doUpdate(l10n)
                        : null,
                    icon: const Icon(Icons.download, size: 18),
                    label: Text(l10n.sysmUpdateNow),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: state.updating ? null : () => _doRollback(l10n),
                icon: const Icon(Icons.history, size: 16),
                label: Text(l10n.sysmRollback),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _updatePhaseLabel(AppLocalizations l10n, String phase) {
    switch (phase) {
      case 'download':
        return l10n.sysmUpdatePhaseDownload;
      case 'apply':
        return l10n.sysmUpdatePhaseApply;
      default:
        return phase;
    }
  }

  Future<void> _doUpdate(AppLocalizations l10n) async {
    final ok = await _confirm(
      title: l10n.sysmUpdateNow,
      message: l10n.sysmUpdateConfirm,
      confirmLabel: l10n.sysmUpdateNow,
    );
    if (!ok) return;
    final done = await _ctrl.applyUpdate((phase) => phase);
    if (!mounted) return;
    if (done) {
      _snack(l10n.sysmUpdateStarted);
    } else {
      final err = ref.read(systemManagementControllerProvider).error;
      _snack(err ?? l10n.sysmUpdateFailed, error: true);
    }
  }

  Future<void> _doRollback(AppLocalizations l10n) async {
    final ok = await _confirm(
      title: l10n.sysmRollback,
      message: l10n.sysmRollbackConfirm,
      confirmLabel: l10n.sysmRollback,
      destructive: true,
    );
    if (!ok) return;
    final done = await _ctrl.rollbackUpdate();
    if (!mounted) return;
    _snack(done ? l10n.sysmRollbackDone : l10n.sysmUpdateFailed, error: !done);
  }

  Widget _buildBackupCard(AppLocalizations l10n, SystemManagementState state) {
    return _card(
      icon: Icons.backup_outlined,
      title: l10n.sysmBackupTitle,
      description: l10n.sysmBackupDesc,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (state.backups.isEmpty)
              Text(
                l10n.sysmBackupEmpty,
                style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              )
            else
              ...state.backups.map((b) => _backupRow(l10n, state, b)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: state.creatingBackup
                        ? null
                        : () => _createBackup(l10n),
                    icon: state.creatingBackup
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(TeleposIcons.add, size: 18),
                    label: Text(l10n.sysmBackupCreate),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: state.creatingBackup
                        ? null
                        : () => _importBackup(l10n),
                    icon: const Icon(Icons.usb, size: 18),
                    label: Text(l10n.sysmBackupImport),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _backupRow(
    AppLocalizations l10n,
    SystemManagementState state,
    BackupItem b,
  ) {
    final busy = state.busyBackup == b.name;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(
            Icons.archive_outlined,
            size: 20,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  b.name,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                Text(
                  '${_fmtBytes(b.sizeBytes)} · ${b.modified}',
                  style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          if (busy)
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else ...[
            IconButton(
              icon: const Icon(Icons.usb, size: 18),
              tooltip: l10n.sysmBackupExport,
              onPressed: state.busyBackup != null
                  ? null
                  : () => _exportBackup(l10n, b.name),
            ),
            IconButton(
              icon: const Icon(Icons.restore, size: 18),
              tooltip: l10n.sysmBackupRestore,
              onPressed: state.busyBackup != null
                  ? null
                  : () => _restoreBackup(l10n, b.name),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _createBackup(AppLocalizations l10n) async {
    final ok = await _ctrl.createBackup();
    if (!mounted) return;
    _snack(ok ? l10n.sysmBackupCreated : _err(l10n), error: !ok);
  }

  Future<void> _importBackup(AppLocalizations l10n) async {
    final ok = await _ctrl.importBackupUsb();
    if (!mounted) return;
    _snack(ok ? l10n.sysmBackupImported : _err(l10n), error: !ok);
  }

  Future<void> _exportBackup(AppLocalizations l10n, String name) async {
    final ok = await _ctrl.exportBackupUsb(name);
    if (!mounted) return;
    _snack(ok ? l10n.sysmBackupExported : _err(l10n), error: !ok);
  }

  Future<void> _restoreBackup(AppLocalizations l10n, String name) async {
    final ok = await _confirm(
      title: l10n.sysmBackupRestore,
      message: l10n.sysmBackupRestoreConfirm(name),
      confirmLabel: l10n.sysmBackupRestore,
      destructive: true,
    );
    if (!ok) return;
    final done = await _ctrl.restoreBackup(name);
    if (!mounted) return;
    _snack(done ? l10n.sysmBackupRestored : _err(l10n), error: !done);
  }

  Widget _buildSnapshotCard(
    AppLocalizations l10n,
    SystemManagementState state,
  ) {
    return _card(
      icon: Icons.photo_camera_back_outlined,
      title: l10n.sysmSnapshotTitle,
      description: l10n.sysmSnapshotDesc,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!state.snapshotSupported)
              Text(
                l10n.sysmSnapshotUnsupported,
                style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              )
            else ...[
              if (state.snapshots.isEmpty)
                Text(
                  l10n.sysmSnapshotEmpty,
                  style: TextStyle(
                    fontSize: 13,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                )
              else
                ...state.snapshots.map((s) => _snapshotRow(l10n, state, s)),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: state.creatingSnapshot
                      ? null
                      : () => _createSnapshot(l10n),
                  icon: state.creatingSnapshot
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.add_a_photo, size: 18),
                  label: Text(l10n.sysmSnapshotCreate),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                  ),
                ),
              ),
            ],
            const Divider(height: 28),
            Row(
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  size: 18,
                  color: Theme.of(context).colorScheme.error,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    l10n.sysmFactoryResetWarn,
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: state.powerBusy ? null : () => _factoryReset(l10n),
                icon: const Icon(Icons.restore_from_trash, size: 18),
                label: Text(l10n.sysmFactoryReset),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.error,
                  side: BorderSide(color: Theme.of(context).colorScheme.error),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _snapshotRow(
    AppLocalizations l10n,
    SystemManagementState state,
    SnapshotItem s,
  ) {
    final busy = state.busySnapshot == s.name;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(
            Icons.layers_outlined,
            size: 20,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.name,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                Text(
                  s.created,
                  style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          if (busy)
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            TextButton(
              onPressed: state.busySnapshot != null
                  ? null
                  : () => _rollbackSnapshot(l10n, s.name),
              child: Text(l10n.sysmSnapshotRollback),
            ),
        ],
      ),
    );
  }

  Future<void> _createSnapshot(AppLocalizations l10n) async {
    final ok = await _ctrl.createSnapshot();
    if (!mounted) return;
    _snack(ok ? l10n.sysmSnapshotCreated : _err(l10n), error: !ok);
  }

  Future<void> _rollbackSnapshot(AppLocalizations l10n, String name) async {
    final ok = await _confirm(
      title: l10n.sysmSnapshotRollback,
      message: l10n.sysmSnapshotRollbackConfirm(name),
      confirmLabel: l10n.sysmSnapshotRollback,
      destructive: true,
    );
    if (!ok) return;
    final rebootRequired = await _ctrl.rollbackSnapshot(name);
    if (!mounted) return;
    if (rebootRequired == null) {
      _snack(_err(l10n), error: true);
    } else if (rebootRequired) {
      _snack(l10n.sysmSnapshotRebootRequired);
    } else {
      _snack(l10n.sysmSnapshotRolledBack);
    }
  }

  Future<void> _factoryReset(AppLocalizations l10n) async {
    final first = await _confirm(
      title: l10n.sysmFactoryReset,
      message: l10n.sysmFactoryResetConfirm1,
      confirmLabel: l10n.versionConflictContinue,
      destructive: true,
    );
    if (!first) return;
    final second = await _confirm(
      title: l10n.sysmFactoryReset,
      message: l10n.sysmFactoryResetConfirm2,
      confirmLabel: l10n.sysmFactoryResetDo,
      destructive: true,
    );
    if (!second) return;
    final done = await _ctrl.factoryReset();
    if (!mounted) return;
    _snack(done ? l10n.sysmFactoryResetStarted : _err(l10n), error: !done);
  }

  Widget _buildDisplayCard(AppLocalizations l10n, SystemManagementState state) {
    final d = state.display;
    return _card(
      icon: Icons.brightness_6_outlined,
      title: l10n.sysmDisplayTitle,
      description: l10n.sysmDisplayDesc,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        child: (!state.displayControllable || d == null)
            ? Row(
                children: [
                  Icon(
                    TeleposIcons.info,
                    size: 18,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l10n.sysmDisplayUnsupported,
                      style: TextStyle(
                        fontSize: 13,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.brightness_low,
                        size: 18,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      Expanded(
                        child: Slider(
                          value: d.brightness.toDouble().clamp(0, 100),
                          min: 0,
                          max: 100,
                          divisions: 20,
                          label: '${d.brightness}%',
                          activeColor: AppColors.primary,
                          onChanged: (v) => _ctrl.setBrightness(v.round()),
                        ),
                      ),
                      Icon(
                        Icons.brightness_high,
                        size: 18,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 44,
                        child: Text(
                          '${d.brightness}%',
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    l10n.sysmRotation,
                    style: TextStyle(
                      fontSize: 13,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [0, 90, 180, 270].map((r) {
                      final selected = d.rotation == r;
                      return ChoiceChip(
                        label: Text('$r°'),
                        selected: selected,
                        selectedColor: selectedSurfaceOf(context),
                        onSelected: (_) => _ctrl.setRotation(r),
                      );
                    }).toList(),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildTimeCard(AppLocalizations l10n, SystemManagementState state) {
    final t = state.time;
    final current =
        _selectedTimezone ??
        (t != null && t.timezone.isNotEmpty ? t.timezone : null);
    final items = <String>[
      ..._timezones,
      if (current != null && !_timezones.contains(current)) current,
    ];
    return _card(
      icon: Icons.schedule,
      title: l10n.sysmTimeTitle,
      description: l10n.sysmTimeDesc,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _kv(
              l10n.sysmTimeCurrent,
              (t != null && t.time.isNotEmpty) ? t.time : '—',
            ),
            const SizedBox(height: 8),
            Text(
              l10n.sysmTimezone,
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            DropdownButton<String>(
              key: const ValueKey('sysm-timezone'),
              value: current,
              isExpanded: true,
              hint: Text(l10n.sysmTimezone),
              items: items
                  .map((tz) => DropdownMenuItem(value: tz, child: Text(tz)))
                  .toList(),
              onChanged: state.savingTimezone
                  ? null
                  : (v) => setState(() => _selectedTimezone = v),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: (state.savingTimezone || current == null)
                        ? null
                        : () => _saveTimezone(l10n, current),
                    icon: state.savingTimezone
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(TeleposIcons.save, size: 18),
                    label: Text(l10n.sysmTimezoneSave),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: state.ntpSyncing ? null : () => _ntpSync(l10n),
                    icon: state.ntpSyncing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.sync, size: 18),
                    label: Text(
                      state.ntpSyncing ? l10n.sysmNtpSyncing : l10n.sysmNtpSync,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveTimezone(AppLocalizations l10n, String tz) async {
    final ok = await _ctrl.setTimezone(tz);
    if (!mounted) return;
    _snack(
      ok ? l10n.sysmTimezoneSaved : l10n.sysmTimezoneSaveError,
      error: !ok,
    );
  }

  Future<void> _ntpSync(AppLocalizations l10n) async {
    final res = await _ctrl.ntpSync();
    if (!mounted) return;
    if (res != null && res.success) {
      _snack(res.message.isNotEmpty ? res.message : l10n.sysmNtpDone);
    } else {
      _snack(
        res != null && res.message.isNotEmpty
            ? res.message
            : l10n.sysmNtpFailed,
        error: true,
      );
    }
  }

  Widget _buildTerminalCard(
    AppLocalizations l10n,
    SystemManagementState state,
  ) {
    return _card(
      icon: Icons.terminal,
      title: l10n.sysmTerminalTitle,
      description: l10n.sysmTerminalDesc,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.shield_outlined,
                  size: 16,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    l10n.sysmTerminalRootNote,
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                key: const ValueKey('sysm-open-terminal'),
                onPressed: () => context.push(AppRoutes.systemTerminal),
                icon: const Icon(Icons.terminal, size: 18),
                label: Text(l10n.sysmTerminalOpen),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildJournalCard(AppLocalizations l10n) {
    return _card(
      icon: Icons.article_outlined,
      title: l10n.logJournalTitle,
      description: l10n.logJournalCardDesc,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        child: SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: () => context.push(AppRoutes.logJournal),
            icon: const Icon(Icons.article_outlined, size: 18),
            label: Text(l10n.logJournalOpen),
            style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
          ),
        ),
      ),
    );
  }

  Widget _buildRemoteCard(AppLocalizations l10n, SystemManagementState state) {
    final s = state.service;
    final remoteOn = s?.remoteEnabled ?? false;
    return _card(
      icon: Icons.support_agent,
      title: l10n.sysmRemoteTitle,
      description: l10n.sysmRemoteDesc,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: context.semantic.canvas,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    TeleposIcons.info,
                    size: 16,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l10n.sysmRemoteHelp,
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.35,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Row(
              children: [
                Icon(
                  remoteOn ? Icons.lock_open : TeleposIcons.lock,
                  size: 18,
                  color: remoteOn ? AppColors.warningGold : AppColors.success,
                ),
                const SizedBox(width: 8),
                Text(
                  remoteOn ? l10n.sysmRemoteOn : l10n.sysmRemoteOff,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: remoteOn
                        ? AppColors.warningGold
                        : Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ],
            ),
            if (remoteOn && (s?.remoteExpiresInSecs ?? 0) > 0)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  l10n.sysmRemoteExpires(
                    ((s!.remoteExpiresInSecs!) ~/ 60).toString(),
                  ),
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: state.togglingRemote
                  ? const Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : remoteOn
                  ? OutlinedButton.icon(
                      onPressed: () => _disableRemote(l10n),
                      icon: const Icon(Icons.link_off, size: 18),
                      label: Text(l10n.sysmRemoteDisable),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Theme.of(context).colorScheme.error,
                        side: BorderSide(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    )
                  : FilledButton.icon(
                      onPressed: () => _enableRemote(l10n),
                      icon: const Icon(Icons.vpn_key, size: 18),
                      label: Text(l10n.sysmRemoteEnable),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _enableRemote(AppLocalizations l10n) async {
    final ok = await _ctrl.enableRemote(minutes: 30);
    if (!mounted) return;
    _snack(ok ? l10n.sysmRemoteEnabled : _err(l10n), error: !ok);
  }

  Future<void> _disableRemote(AppLocalizations l10n) async {
    final ok = await _ctrl.disableRemote();
    if (!mounted) return;
    _snack(ok ? l10n.sysmRemoteDisabled : _err(l10n), error: !ok);
  }

  Widget _buildPowerCard(AppLocalizations l10n, SystemManagementState state) {
    return _card(
      icon: Icons.power_settings_new,
      title: l10n.sysmPowerTitle,
      description: l10n.sysmPowerDesc,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: state.powerBusy ? null : () => _reboot(l10n),
                icon: const Icon(Icons.restart_alt, size: 18),
                label: Text(l10n.sysmReboot),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: state.powerBusy ? null : () => _shutdown(l10n),
                icon: const Icon(Icons.power_settings_new, size: 18),
                label: Text(l10n.sysmShutdown),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.error,
                  side: BorderSide(color: Theme.of(context).colorScheme.error),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _reboot(AppLocalizations l10n) async {
    final ok = await _confirm(
      title: l10n.sysmReboot,
      message: l10n.sysmRebootConfirm,
      confirmLabel: l10n.sysmReboot,
    );
    if (!ok) return;
    final done = await _ctrl.reboot();
    if (!mounted) return;
    if (done) {
      _snack(l10n.sysmRebooting);
    } else {
      _snack(_err(l10n), error: true);
    }
  }

  Future<void> _shutdown(AppLocalizations l10n) async {
    final ok = await _confirm(
      title: l10n.sysmShutdown,
      message: l10n.sysmShutdownConfirm,
      confirmLabel: l10n.sysmShutdown,
      destructive: true,
    );
    if (!ok) return;
    final done = await _ctrl.shutdown();
    if (!mounted) return;
    if (done) {
      _snack(l10n.sysmShuttingDown);
    } else {
      _snack(_err(l10n), error: true);
    }
  }

  String _err(AppLocalizations l10n) {
    final e = ref.read(systemManagementControllerProvider).error;
    return e != null ? l10n.applianceError(e) : l10n.sysmGenericError;
  }

  String _fmtBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    const units = ['B', 'KB', 'MB', 'GB'];
    var b = bytes.toDouble();
    var i = 0;
    while (b >= 1024 && i < units.length - 1) {
      b /= 1024;
      i++;
    }
    return '${b.toStringAsFixed(b >= 10 || i == 0 ? 0 : 1)} ${units[i]}';
  }

  Widget _kv(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label: ',
            style: TextStyle(
              fontSize: 13,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _card({
    required IconData icon,
    required String title,
    required String description,
    required Widget child,
    Widget? trailing,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.semantic.canvas),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Row(
              children: [
                Icon(icon, size: 20, color: AppColors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      Text(
                        description,
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                if (trailing != null) trailing,
              ],
            ),
          ),
          const Divider(height: 16),
          child,
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}

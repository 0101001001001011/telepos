import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:telepos/app/theme/app_colors.dart';
import 'package:telepos/app/theme/app_semantic_colors.dart';
import 'package:telepos/app/theme/app_theme.dart';
import 'package:telepos/app/theme/telepos_icons.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/presentation/controllers/sync/sync_controller.dart';

class SyncScreen extends ConsumerWidget {
  const SyncScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isDesktop = screenWidth >= 900;
    final isTablet = screenWidth >= 600;

    final state = ref.watch(syncProvider);
    final notifier = ref.read(syncProvider.notifier);

    return Scaffold(
      appBar: isDesktop
          ? null
          : AppBar(
              title: Text(AppLocalizations.of(context)!.syncTitle),
              foregroundColor: Theme.of(context).colorScheme.onSurface,
              elevation: 0,
            ),
      body: Padding(
        padding: EdgeInsets.all(isDesktop ? 24 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isDesktop)
              Padding(
                padding: const EdgeInsets.only(bottom: 24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      AppLocalizations.of(context)!.syncTitle,
                      style: AppTextStyles.h2,
                    ),
                    if (state.lastSyncTime != null)
                      Text(
                        AppLocalizations.of(
                          context,
                        )!.syncLastSync(_formatDateTime(state.lastSyncTime!)),
                        style: context.styles.caption,
                      ),
                  ],
                ),
              ),

            _StatusCard(state: state),
            const SizedBox(height: 16),

            Expanded(
              child: Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: context.semantic.canvas),
                ),
                child: isDesktop || isTablet
                    ? _SyncTable(items: state.items)
                    : _SyncList(items: state.items),
              ),
            ),
            const SizedBox(height: 16),

            _ActionButtons(
              state: state,
              onSync: () => notifier.startSync(),
              onAbort: () => notifier.abortSync(),
              onSettings: () =>
                  _showSettingsDialog(context, ref, state, notifier),
            ),
          ],
        ),
      ),
    );
  }

  void _showSettingsDialog(
    BuildContext context,
    WidgetRef ref,
    SyncState state,
    SyncNotifier notifier,
  ) {
    showDialog(
      context: context,
      builder: (context) => _SyncSettingsDialog(
        currentInterval: state.syncIntervalMinutes,
        autoSyncEnabled: state.autoSyncEnabled,
        onIntervalChanged: notifier.setSyncInterval,
        onAutoSyncChanged: notifier.setAutoSyncEnabled,
      ),
    );
  }

  String _formatDateTime(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.state});

  final SyncState state;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: context.semantic.canvas),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _StatusIndicator(status: state.status),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _getStatusLabel(context, state.status),
                        style: AppTextStyles.body.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (state.currentStep != null)
                        Text(
                          _translateStep(context, state.currentStep!),
                          style: context.styles.caption,
                        ),
                    ],
                  ),
                ),
                if (state.status == SyncStatus.syncing)
                  Text(
                    '${state.overallProgress}%',
                    style: AppTextStyles.h3.copyWith(color: AppColors.primary),
                  ),
              ],
            ),
            if (state.status == SyncStatus.syncing) ...[
              const SizedBox(height: 12),
              LinearProgressIndicator(
                value: state.overallProgress / 100,
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                _StatChip(
                  icon: Icons.cloud_upload,
                  label: AppLocalizations.of(context)!.syncToUpload,
                  count: state.totalPendingUploads,
                  color: AppColors.info,
                ),
                const SizedBox(width: 12),
                _StatChip(
                  icon: Icons.cloud_download,
                  label: AppLocalizations.of(context)!.syncToDownload,
                  count: state.totalPendingDownloads,
                  color: AppColors.success,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _getStatusLabel(BuildContext context, SyncStatus status) {
    return switch (status) {
      SyncStatus.idle => AppLocalizations.of(context)!.syncStatus,
      SyncStatus.syncing => AppLocalizations.of(context)!.syncInProgress,
      SyncStatus.completed => AppLocalizations.of(context)!.syncSuccess,
      SyncStatus.error => AppLocalizations.of(context)!.syncFailed,
    };
  }

  String _translateStep(BuildContext context, String step) {
    final l10n = AppLocalizations.of(context)!;
    return switch (step) {
      'preparing' => l10n.syncPreparing,
      'completed' => l10n.syncCompleted,
      _ => step,
    };
  }
}

class _StatusIndicator extends StatelessWidget {
  const _StatusIndicator({required this.status});

  final SyncStatus status;

  @override
  Widget build(BuildContext context) {
    final (color, icon) = switch (status) {
      SyncStatus.idle => (
        Theme.of(context).colorScheme.onSurfaceVariant,
        Icons.hourglass_empty,
      ),
      SyncStatus.syncing => (AppColors.info, Icons.sync),
      SyncStatus.completed => (AppColors.success, TeleposIcons.checkCircle),
      SyncStatus.error => (Theme.of(context).colorScheme.error, Icons.error),
    };

    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(24),
      ),
      child: status == SyncStatus.syncing
          ? Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                ),
              ),
            )
          : Icon(icon, color: color, size: 24),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.icon,
    required this.label,
    required this.count,
    required this.color,
  });

  final IconData icon;
  final String label;
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Text(
            '$label: $count',
            style: context.styles.caption.copyWith(
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _SyncTable extends StatelessWidget {
  const _SyncTable({required this.items});

  final List<SyncItem> items;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: DataTable(
        columnSpacing: 24,
        columns: [
          DataColumn(
            label: Text(AppLocalizations.of(context)!.syncDataTypeCol),
          ),
          DataColumn(
            label: Text(AppLocalizations.of(context)!.syncDirectionCol),
          ),
          DataColumn(
            label: Text(AppLocalizations.of(context)!.syncPendingCol),
            numeric: true,
          ),
          DataColumn(label: Text(AppLocalizations.of(context)!.syncStatusCol)),
          DataColumn(
            label: Text(AppLocalizations.of(context)!.syncProgressCol),
          ),
        ],
        rows: items.map((item) => _buildRow(context, item)).toList(),
      ),
    );
  }

  DataRow _buildRow(BuildContext context, SyncItem item) {
    return DataRow(
      cells: [
        DataCell(Text(item.type.getLabel(AppLocalizations.of(context)!))),
        DataCell(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                item.type.direction == SyncDirection.upload
                    ? Icons.cloud_upload_outlined
                    : Icons.cloud_download_outlined,
                size: 16,
                color: item.type.direction == SyncDirection.upload
                    ? AppColors.info
                    : AppColors.success,
              ),
              const SizedBox(width: 4),
              Text(
                item.type.direction == SyncDirection.upload
                    ? AppLocalizations.of(context)!.syncUpload
                    : AppLocalizations.of(context)!.syncDownload,
              ),
            ],
          ),
        ),
        DataCell(
          Text(
            item.pendingCount.toString(),
            style: TextStyle(
              color: item.pendingCount > 0 ? AppColors.warning : null,
              fontWeight: item.pendingCount > 0 ? FontWeight.bold : null,
            ),
          ),
        ),
        DataCell(_StatusBadge(status: item.status)),
        DataCell(
          item.status == SyncItemStatus.inProgress
              ? SizedBox(
                  width: 100,
                  child: LinearProgressIndicator(
                    value: item.progressPercent / 100,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      AppColors.primary,
                    ),
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}

class _SyncList extends StatelessWidget {
  const _SyncList({required this.items});

  final List<SyncItem> items;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: items.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final item = items[index];
        return _SyncListItem(item: item);
      },
    );
  }
}

class _SyncListItem extends StatelessWidget {
  const _SyncListItem({required this.item});

  final SyncItem item;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                item.type.direction == SyncDirection.upload
                    ? Icons.cloud_upload_outlined
                    : Icons.cloud_download_outlined,
                size: 20,
                color: item.type.direction == SyncDirection.upload
                    ? AppColors.info
                    : AppColors.success,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  item.type.getLabel(AppLocalizations.of(context)!),
                  style: AppTextStyles.body.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              _StatusBadge(status: item.status),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                item.type.direction == SyncDirection.upload
                    ? AppLocalizations.of(context)!.syncUpload
                    : AppLocalizations.of(context)!.syncDownload,
                style: context.styles.caption,
              ),
              const Spacer(),
              if (item.pendingCount > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    AppLocalizations.of(
                      context,
                    )!.syncPendingCount(item.pendingCount),
                    style: context.styles.caption.copyWith(
                      color: AppColors.warning,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
            ],
          ),
          if (item.status == SyncItemStatus.inProgress) ...[
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: item.progressPercent / 100,
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final SyncItemStatus status;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final (color, label) = switch (status) {
      SyncItemStatus.pending => (
        Theme.of(context).colorScheme.onSurfaceVariant,
        l10n.globalLoading,
      ),
      SyncItemStatus.inProgress => (AppColors.info, l10n.syncInProgress),
      SyncItemStatus.completed => (AppColors.success, l10n.globalDone),
      SyncItemStatus.error => (
        Theme.of(context).colorScheme.error,
        l10n.globalError,
      ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: context.styles.caption.copyWith(
          color: color,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _ActionButtons extends StatelessWidget {
  const _ActionButtons({
    required this.state,
    required this.onSync,
    required this.onAbort,
    required this.onSettings,
  });

  final SyncState state;
  final VoidCallback onSync;
  final VoidCallback onAbort;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isDesktop = screenWidth >= 900;

    return Row(
      children: [
        if (state.status == SyncStatus.syncing) ...[
          Expanded(
            child: SizedBox(
              height: 48,
              child: OutlinedButton.icon(
                onPressed: onAbort,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.error,
                  side: BorderSide(color: Theme.of(context).colorScheme.error),
                ),
                icon: const Icon(Icons.stop),
                label: Text(
                  AppLocalizations.of(context)!.globalCancel.toUpperCase(),
                ),
              ),
            ),
          ),
        ] else ...[
          Expanded(
            child: SizedBox(
              height: 48,
              child: ElevatedButton.icon(
                onPressed: state.hasPendingData ? onSync : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.white,
                  disabledBackgroundColor: context.semantic.canvas,
                  disabledForegroundColor: Theme.of(
                    context,
                  ).colorScheme.onSurfaceVariant,
                ),
                icon: const Icon(Icons.sync),
                label: Text(
                  AppLocalizations.of(context)!.syncNow.toUpperCase(),
                ),
              ),
            ),
          ),
        ],
        if (isDesktop && state.status != SyncStatus.syncing) ...[
          const SizedBox(width: 16),
          SizedBox(
            height: 48,
            child: OutlinedButton.icon(
              onPressed: onSettings,
              icon: const Icon(Icons.settings),
              label: Text(
                AppLocalizations.of(context)!.navSettings.toUpperCase(),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _SyncSettingsDialog extends StatefulWidget {
  const _SyncSettingsDialog({
    required this.currentInterval,
    required this.autoSyncEnabled,
    required this.onIntervalChanged,
    required this.onAutoSyncChanged,
  });

  final int currentInterval;
  final bool autoSyncEnabled;
  final void Function(int) onIntervalChanged;
  final void Function(bool) onAutoSyncChanged;

  @override
  State<_SyncSettingsDialog> createState() => _SyncSettingsDialogState();
}

class _SyncSettingsDialogState extends State<_SyncSettingsDialog> {
  late int _selectedInterval;
  late bool _autoSyncEnabled;

  @override
  void initState() {
    super.initState();
    _selectedInterval = widget.currentInterval;
    _autoSyncEnabled = widget.autoSyncEnabled;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(AppLocalizations.of(context)!.telegramSyncInterval),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: selectedSurfaceOf(context),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(TeleposIcons.info, color: AppColors.primary, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    AppLocalizations.of(context)!.syncInfoTelegram,
                    style: TextStyle(fontSize: 12, color: AppColors.primary),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          SwitchListTile(
            title: Text(AppLocalizations.of(context)!.telegramAutoSync),
            subtitle: Text(
              _autoSyncEnabled
                  ? AppLocalizations.of(context)!.syncAutoEnabled
                  : AppLocalizations.of(context)!.syncManualOnly,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            value: _autoSyncEnabled,
            onChanged: (value) {
              setState(() => _autoSyncEnabled = value);
            },
            contentPadding: EdgeInsets.zero,
            activeColor: AppColors.primary,
          ),
          const SizedBox(height: 16),

          Text(
            AppLocalizations.of(context)!.telegramSyncInterval,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: _autoSyncEnabled
                  ? Theme.of(context).colorScheme.onSurface
                  : Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: SyncNotifier.availableIntervals.map((minutes) {
              final isSelected = _selectedInterval == minutes;
              return ChoiceChip(
                label: Text(AppLocalizations.of(context)!.syncMinutes(minutes)),
                selected: isSelected,
                onSelected: _autoSyncEnabled
                    ? (selected) {
                        if (selected) {
                          setState(() => _selectedInterval = minutes);
                        }
                      }
                    : null,
                selectedColor: selectedSurfaceOf(context),
                labelStyle: TextStyle(
                  color: isSelected
                      ? AppColors.primary
                      : Theme.of(context).colorScheme.onSurface,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              );
            }).toList(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(AppLocalizations.of(context)!.globalCancel.toUpperCase()),
        ),
        ElevatedButton(
          onPressed: () {
            widget.onAutoSyncChanged(_autoSyncEnabled);
            widget.onIntervalChanged(_selectedInterval);
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(AppLocalizations.of(context)!.fiscalSaved),
                duration: const Duration(seconds: 2),
              ),
            );
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: AppColors.white,
          ),
          child: Text(AppLocalizations.of(context)!.globalSave.toUpperCase()),
        ),
      ],
    );
  }
}

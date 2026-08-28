import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:telepos/app/theme/telepos_icons.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/presentation/controllers/sync/sync_controller.dart';

class SyncStatusWidget extends ConsumerStatefulWidget {
  final bool compact;

  final VoidCallback? onSyncPressed;

  const SyncStatusWidget({super.key, this.compact = false, this.onSyncPressed});

  @override
  ConsumerState<SyncStatusWidget> createState() => _SyncStatusWidgetState();
}

class _SyncStatusWidgetState extends ConsumerState<SyncStatusWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _rotationController;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _rotationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final syncState = ref.watch(syncProvider);

    if (syncState.status == SyncStatus.syncing) {
      _rotationController.repeat();
    } else {
      _rotationController.stop();
      _rotationController.reset();
    }

    if (widget.compact) {
      return _buildCompactView(context, syncState);
    }
    return _buildDetailedView(context, syncState);
  }

  Widget _buildCompactView(BuildContext context, SyncState syncState) {
    final theme = Theme.of(context);
    final color = _getStatusColor(syncState.status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildStatusIcon(syncState.status, size: 16),
          const SizedBox(width: 8),
          Text(
            _getStatusText(context, syncState.status),
            style: theme.textTheme.bodySmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailedView(BuildContext context, SyncState syncState) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final color = _getStatusColor(syncState.status);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _buildStatusIcon(syncState.status, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _getStatusText(context, syncState.status),
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: color,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (syncState.currentStep != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        syncState.currentStep!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (syncState.status != SyncStatus.syncing)
                IconButton(
                  icon: const Icon(Icons.sync),
                  onPressed: () {
                    widget.onSyncPressed?.call();
                    ref.read(syncProvider.notifier).startSync();
                  },
                  tooltip: l10n.syncNow,
                ),
            ],
          ),

          if (syncState.status == SyncStatus.syncing) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: syncState.overallProgress > 0
                    ? syncState.overallProgress / 100.0
                    : null,
                backgroundColor: color.withValues(alpha: 0.2),
                valueColor: AlwaysStoppedAnimation(color),
              ),
            ),
            if (syncState.overallProgress > 0) ...[
              const SizedBox(height: 4),
              Text(
                '${syncState.overallProgress}%',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ],

          if (syncState.errorMessage != null &&
              syncState.status == SyncStatus.error) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: theme.colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    TeleposIcons.error,
                    color: theme.colorScheme.error,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      syncState.errorMessage!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.error,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () =>
                        ref.read(syncProvider.notifier).startSync(),
                    child: Text(l10n.syncWidgetRetry),
                  ),
                ],
              ),
            ),
          ],

          if (syncState.lastSyncTime != null &&
              syncState.status != SyncStatus.syncing) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  Icons.access_time,
                  size: 16,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 4),
                Text(
                  l10n.syncWidgetLastSync(
                    _formatLastSync(context, syncState.lastSyncTime!),
                  ),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],

          if (syncState.status != SyncStatus.syncing && !widget.compact) ...[
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 8),
            ...syncState.items
                .where((item) => item.type.direction == SyncDirection.upload)
                .map(
                  (item) => _buildSyncItemRow(
                    item.type.name,
                    item.status == SyncItemStatus.completed,
                    item.pendingCount,
                  ),
                ),
          ],
        ],
      ),
    );
  }

  Widget _buildSyncItemRow(String name, bool synced, int count) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            synced ? TeleposIcons.checkCircle : Icons.schedule,
            size: 16,
            color: synced ? Colors.green : Colors.orange,
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(name, style: theme.textTheme.bodySmall)),
          Text(
            count > 0
                ? l10n.syncWidgetRecordsCount(count)
                : l10n.syncWidgetSynced,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusIcon(SyncStatus status, {required double size}) {
    final color = _getStatusColor(status);
    switch (status) {
      case SyncStatus.idle:
      case SyncStatus.completed:
        return Icon(Icons.cloud_done, size: size, color: color);
      case SyncStatus.syncing:
        return RotationTransition(
          turns: _rotationController,
          child: Icon(Icons.sync, size: size, color: color),
        );
      case SyncStatus.error:
        return Icon(Icons.cloud_off, size: size, color: color);
    }
  }

  Color _getStatusColor(SyncStatus status) {
    switch (status) {
      case SyncStatus.idle:
      case SyncStatus.completed:
        return Colors.green;
      case SyncStatus.syncing:
        return Colors.blue;
      case SyncStatus.error:
        return Colors.red;
    }
  }

  String _getStatusText(BuildContext context, SyncStatus status) {
    final l10n = AppLocalizations.of(context)!;
    switch (status) {
      case SyncStatus.idle:
      case SyncStatus.completed:
        return l10n.syncWidgetSynced;
      case SyncStatus.syncing:
        return l10n.syncInProgress;
      case SyncStatus.error:
        return l10n.syncFailed;
    }
  }

  String _formatLastSync(BuildContext context, DateTime time) {
    final l10n = AppLocalizations.of(context)!;
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inMinutes < 1) {
      return l10n.syncWidgetJustNow;
    } else if (diff.inMinutes < 60) {
      return l10n.syncWidgetMinutesAgo(diff.inMinutes);
    } else if (diff.inHours < 24) {
      return l10n.syncWidgetHoursAgo(diff.inHours);
    } else {
      return l10n.syncWidgetDaysAgo(diff.inDays);
    }
  }
}

class SyncStatusIndicator extends ConsumerWidget {
  final VoidCallback? onTap;

  const SyncStatusIndicator({super.key, this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final syncState = ref.watch(syncProvider);
    final color = switch (syncState.status) {
      SyncStatus.syncing => Colors.blue,
      SyncStatus.error => Colors.red,
      _ => Colors.green,
    };
    final icon = switch (syncState.status) {
      SyncStatus.syncing => Icons.sync,
      SyncStatus.error => Icons.cloud_off,
      _ => Icons.cloud_done,
    };

    return IconButton(
      icon: Icon(icon),
      onPressed: onTap,
      tooltip: l10n.syncStatus,
      color: color,
    );
  }
}

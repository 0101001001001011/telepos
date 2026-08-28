import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:telepos/app/theme/telepos_icons.dart';
import 'package:telepos/l10n/app_localizations.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../transport/transport_exports.dart';
import '../../../common/utils/error_localizer.dart';
import '../../../controllers/transport/transport_controller.dart';

class TransportStatusPanel extends ConsumerWidget {
  const TransportStatusPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(transportControllerProvider);

    return Container(
      padding: const EdgeInsets.all(AppTheme.spacing),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(AppTheme.borderRadius),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(_getModeIcon(state.mode), color: AppColors.primary),
              const SizedBox(width: 8),
              Text(
                _getModeTitle(state.mode),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const Spacer(),
              _StatusChip(status: state.displayStatus),
            ],
          ),

          const SizedBox(height: AppTheme.spacing),
          const Divider(height: 1),
          const SizedBox(height: AppTheme.spacing),

          _DetailRow(
            label: l10n.transPrimary,
            value: _getTransportName(state.mode),
            status: state.primaryStatus,
          ),

          if (state.mode == TransportMode.hybrid) ...[
            const SizedBox(height: 8),
            _DetailRow(
              label: l10n.transSecondary,
              value: 'REST API',
              status: state.secondaryStatus ?? TransportStatus.disconnected,
            ),
          ],

          const SizedBox(height: AppTheme.spacing),

          if (state.hasPendingOperations || state.failedOperationsCount > 0)
            _QueueStatsRow(
              queued: state.queuedOperationsCount,
              failed: state.failedOperationsCount,
            ),

          if (state.lastSyncTime != null) ...[
            const SizedBox(height: 8),
            _LastSyncRow(time: state.lastSyncTime!),
          ],

          if (state.error != null) ...[
            const SizedBox(height: AppTheme.spacing),
            _ErrorRow(error: ErrorLocalizer.localize(context, state.error!)),
          ],

          const SizedBox(height: AppTheme.spacing),

          _ActionButtons(
            isSyncing: state.isSyncing,
            hasFailed: state.failedOperationsCount > 0,
            onSync: () =>
                ref.read(transportControllerProvider.notifier).forceSync(),
            onRetry: () =>
                ref.read(transportControllerProvider.notifier).retryFailed(),
          ),
        ],
      ),
    );
  }

  IconData _getModeIcon(TransportMode mode) {
    switch (mode) {
      case TransportMode.telegramOnly:
        return Icons.telegram;
      case TransportMode.restOnly:
        return Icons.cloud;
      case TransportMode.hybrid:
        return Icons.sync_alt;
    }
  }

  String _getModeTitle(TransportMode mode) {
    switch (mode) {
      case TransportMode.telegramOnly:
        return 'Telegram Only';
      case TransportMode.restOnly:
        return 'REST API';
      case TransportMode.hybrid:
        return 'Hybrid Mode';
    }
  }

  String _getTransportName(TransportMode mode) {
    switch (mode) {
      case TransportMode.telegramOnly:
        return 'Telegram';
      case TransportMode.restOnly:
        return 'REST API';
      case TransportMode.hybrid:
        return 'Telegram';
    }
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final TransportDisplayStatus status;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _getColor(context).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _getColor(context).withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _getColor(context),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            _getLabel(l10n),
            style: TextStyle(
              color: _getColor(context),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Color _getColor(BuildContext context) {
    switch (status) {
      case TransportDisplayStatus.online:
        return AppColors.statusOnline;
      case TransportDisplayStatus.offline:
        return AppColors.statusOffline;
      case TransportDisplayStatus.syncing:
        return AppColors.statusSync;
      case TransportDisplayStatus.queued:
      case TransportDisplayStatus.warning:
        return AppColors.warning;
      case TransportDisplayStatus.error:
        return Theme.of(context).colorScheme.error;
    }
  }

  String _getLabel(AppLocalizations l10n) {
    switch (status) {
      case TransportDisplayStatus.online:
        return l10n.transStatusOnline;
      case TransportDisplayStatus.offline:
        return l10n.transStatusOffline;
      case TransportDisplayStatus.syncing:
        return l10n.transStatusSyncing;
      case TransportDisplayStatus.queued:
        return l10n.transStatusQueued;
      case TransportDisplayStatus.warning:
        return l10n.transStatusWarning;
      case TransportDisplayStatus.error:
        return l10n.transStatusError;
    }
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
    required this.status,
  });

  final String label;
  final String value;
  final TransportStatus status;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Text(value),
        const SizedBox(width: 8),
        Icon(_getStatusIcon(), size: 14, color: _getStatusColor(context)),
      ],
    );
  }

  IconData _getStatusIcon() {
    switch (status) {
      case TransportStatus.connected:
        return TeleposIcons.checkCircle;
      case TransportStatus.connecting:
      case TransportStatus.reconnecting:
        return Icons.sync;
      case TransportStatus.disconnected:
        return Icons.cancel;
      case TransportStatus.error:
        return Icons.error;
    }
  }

  Color _getStatusColor(BuildContext context) {
    switch (status) {
      case TransportStatus.connected:
        return AppColors.statusOnline;
      case TransportStatus.connecting:
      case TransportStatus.reconnecting:
        return AppColors.statusSync;
      case TransportStatus.disconnected:
        return AppColors.statusOffline;
      case TransportStatus.error:
        return Theme.of(context).colorScheme.error;
    }
  }
}

class _QueueStatsRow extends StatelessWidget {
  const _QueueStatsRow({required this.queued, required this.failed});

  final int queued;
  final int failed;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Row(
      children: [
        if (queued > 0) ...[
          const Icon(Icons.queue, size: 14, color: AppColors.warning),
          const SizedBox(width: 4),
          Text(
            l10n.transQueuedCount(queued),
            style: const TextStyle(color: AppColors.warning, fontSize: 12),
          ),
        ],
        if (queued > 0 && failed > 0) const SizedBox(width: 16),
        if (failed > 0) ...[
          Icon(
            TeleposIcons.error,
            size: 14,
            color: Theme.of(context).colorScheme.error,
          ),
          const SizedBox(width: 4),
          Text(
            l10n.transFailedCount(failed),
            style: TextStyle(
              color: Theme.of(context).colorScheme.error,
              fontSize: 12,
            ),
          ),
        ],
      ],
    );
  }
}

class _LastSyncRow extends StatelessWidget {
  const _LastSyncRow({required this.time});

  final DateTime time;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final diff = DateTime.now().difference(time);

    return Row(
      children: [
        Icon(
          Icons.history,
          size: 14,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 4),
        Text(
          l10n.transLastSyncAgo(_formatDuration(diff)),
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  String _formatDuration(Duration duration) {
    if (duration.inSeconds < 60) return '${duration.inSeconds}s';
    if (duration.inMinutes < 60) return '${duration.inMinutes}m';
    if (duration.inHours < 24) return '${duration.inHours}h';
    return '${duration.inDays}d';
  }
}

class _ErrorRow extends StatelessWidget {
  const _ErrorRow({required this.error});

  final String error;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.error.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: Theme.of(context).colorScheme.error.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.error,
            size: 16,
            color: Theme.of(context).colorScheme.error,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              error,
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
                fontSize: 12,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButtons extends StatelessWidget {
  const _ActionButtons({
    required this.isSyncing,
    required this.hasFailed,
    required this.onSync,
    required this.onRetry,
  });

  final bool isSyncing;
  final bool hasFailed;
  final VoidCallback onSync;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: isSyncing ? null : onSync,
            icon: isSyncing
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.sync, size: 16),
            label: Text(isSyncing ? l10n.transSyncing : l10n.transSyncNow),
          ),
        ),
        if (hasFailed) ...[
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, size: 16),
              label: Text(l10n.transRetryFailed),
              style: OutlinedButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

Future<void> showTransportStatusPanel(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    builder: (context) => const Padding(
      padding: EdgeInsets.all(16),
      child: TransportStatusPanel(),
    ),
  );
}

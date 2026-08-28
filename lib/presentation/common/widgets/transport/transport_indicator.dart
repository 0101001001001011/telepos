import 'package:telepos/app/theme/telepos_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../transport/transport_exports.dart';
import '../../../common/utils/error_localizer.dart';
import '../../../controllers/transport/transport_controller.dart';

class TransportIndicator extends ConsumerWidget {
  const TransportIndicator({
    this.showLabel = true,
    this.compact = false,
    super.key,
  });

  final bool showLabel;

  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(transportControllerProvider);

    if (compact) {
      return _CompactIndicator(state: state);
    }

    return _FullIndicator(state: state, showLabel: showLabel);
  }
}

class _FullIndicator extends StatelessWidget {
  const _FullIndicator({required this.state, required this.showLabel});

  final TransportState state;
  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: _getTooltip(context),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            children: [
              Icon(_getModeIcon(), size: 16, color: _getStatusColor(context)),
              Positioned(
                right: -2,
                bottom: -2,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _getStatusColor(context),
                    border: Border.all(
                      color: AppColors.darkSurface,
                      width: 1.5,
                    ),
                  ),
                ),
              ),
            ],
          ),

          if (showLabel) ...[
            const SizedBox(width: 6),
            Text(
              _getStatusLabel(),
              style: TextStyle(color: _getStatusColor(context), fontSize: 12),
            ),
          ],

          if (state.hasPendingOperations) ...[
            const SizedBox(width: 4),
            _QueueBadge(count: state.queuedOperationsCount),
          ],

          if (state.failedOperationsCount > 0) ...[
            const SizedBox(width: 4),
            _ErrorBadge(count: state.failedOperationsCount),
          ],
        ],
      ),
    );
  }

  IconData _getModeIcon() {
    switch (state.mode) {
      case TransportMode.telegramOnly:
        return Icons.telegram;
      case TransportMode.restOnly:
        return Icons.cloud;
      case TransportMode.hybrid:
        return Icons.sync_alt;
    }
  }

  Color _getStatusColor(BuildContext context) {
    switch (state.displayStatus) {
      case TransportDisplayStatus.online:
        return AppColors.statusOnline;
      case TransportDisplayStatus.offline:
        return AppColors.statusOffline;
      case TransportDisplayStatus.syncing:
        return AppColors.statusSync;
      case TransportDisplayStatus.queued:
        return AppColors.warning;
      case TransportDisplayStatus.warning:
        return AppColors.warning;
      case TransportDisplayStatus.error:
        return Theme.of(context).colorScheme.error;
    }
  }

  String _getStatusLabel() {
    switch (state.displayStatus) {
      case TransportDisplayStatus.online:
        return 'Online';
      case TransportDisplayStatus.offline:
        return 'Offline';
      case TransportDisplayStatus.syncing:
        return 'Sync...';
      case TransportDisplayStatus.queued:
        return 'Queue';
      case TransportDisplayStatus.warning:
        return 'Warning';
      case TransportDisplayStatus.error:
        return 'Error';
    }
  }

  String _getTooltip(BuildContext context) {
    final buffer = StringBuffer();

    buffer.write('Mode: ${state.mode.name}');

    buffer.write('\nStatus: ${state.displayStatus.name}');

    if (state.hasPendingOperations) {
      buffer.write('\nQueued: ${state.queuedOperationsCount}');
    }

    if (state.failedOperationsCount > 0) {
      buffer.write('\nFailed: ${state.failedOperationsCount}');
    }

    if (state.lastSyncTime != null) {
      final diff = DateTime.now().difference(state.lastSyncTime!);
      buffer.write('\nLast sync: ${_formatDuration(diff)} ago');
    }

    if (state.error != null) {
      buffer.write(
        '\nError: ${ErrorLocalizer.localize(context, state.error!)}',
      );
    }

    return buffer.toString();
  }

  String _formatDuration(Duration duration) {
    if (duration.inSeconds < 60) return '${duration.inSeconds}s';
    if (duration.inMinutes < 60) return '${duration.inMinutes}m';
    return '${duration.inHours}h';
  }
}

class _CompactIndicator extends StatelessWidget {
  const _CompactIndicator({required this.state});

  final TransportState state;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Icon(_getModeIcon(), size: 14, color: _getStatusColor(context)),
        if (state.hasPendingOperations || state.failedOperationsCount > 0)
          Positioned(
            right: -2,
            top: -2,
            child: Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: state.failedOperationsCount > 0
                    ? Theme.of(context).colorScheme.error
                    : AppColors.warning,
              ),
            ),
          ),
      ],
    );
  }

  IconData _getModeIcon() {
    switch (state.mode) {
      case TransportMode.telegramOnly:
        return Icons.telegram;
      case TransportMode.restOnly:
        return Icons.cloud;
      case TransportMode.hybrid:
        return Icons.sync_alt;
    }
  }

  Color _getStatusColor(BuildContext context) {
    switch (state.displayStatus) {
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
}

class _QueueBadge extends StatelessWidget {
  const _QueueBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        count > 99 ? '99+' : count.toString(),
        style: const TextStyle(
          color: AppColors.warning,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _ErrorBadge extends StatelessWidget {
  const _ErrorBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.error.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            TeleposIcons.error,
            size: 10,
            color: Theme.of(context).colorScheme.error,
          ),
          const SizedBox(width: 2),
          Text(
            count > 99 ? '99+' : count.toString(),
            style: TextStyle(
              color: Theme.of(context).colorScheme.error,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class SyncingIndicator extends StatefulWidget {
  const SyncingIndicator({super.key});

  @override
  State<SyncingIndicator> createState() => _SyncingIndicatorState();
}

class _SyncingIndicatorState extends State<SyncingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RotationTransition(
      turns: _controller,
      child: const Icon(Icons.sync, size: 14, color: AppColors.statusSync),
    );
  }
}

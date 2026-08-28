import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:telepos/app/theme/app_colors.dart';
import 'package:telepos/app/theme/app_theme.dart';
import 'package:telepos/app/theme/telepos_icons.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/presentation/controllers/app/app_state_controller.dart';
import 'package:telepos/presentation/controllers/update/update_controller.dart';

class StatusBar extends ConsumerWidget {
  const StatusBar({this.compact = false, super.key});

  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appState = ref.watch(appStateProvider);

    if (compact) {
      return _CompactStatusBar(appState: appState);
    }

    return _FullStatusBar(appState: appState);
  }
}

class _FullStatusBar extends ConsumerWidget {
  const _FullStatusBar({required this.appState});

  final AppState appState;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasUpdate = ref.watch(isUpdateAvailableProvider);

    // Часы берутся из `currentTimeProvider`, а не напрямую из состояния.
    //
    // Значение то же — провайдер и есть `appState.currentTime`, — но точка
    // подмены одна на все три места, где показано время. Пока полоса читала
    // состояние в обход, снимок оболочки нельзя было снять устойчиво: шапка
    // замирала по переопределению, а полоса внизу продолжала показывать
    // время съёмки, и эталон расходился сам с собой на следующей минуте.
    final time = ref.watch(currentTimeProvider);

    return Container(
      height: 32,
      color: AppColors.darkSurface,
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacing),
      child: Row(
        children: [
          _StatusItem(icon: Icons.access_time, label: time),

          const SizedBox(width: AppTheme.spacing),

          _ConnectionStatusIndicator(status: appState.connectionStatus),

          const SizedBox(width: AppTheme.spacing),

          if (appState.posName != null) ...[
            _StatusItem(icon: Icons.point_of_sale, label: appState.posName!),
            const SizedBox(width: AppTheme.spacing),
          ],

          const Spacer(),

          if (appState.userName != null)
            _StatusItem(icon: TeleposIcons.person, label: appState.userName!),

          const SizedBox(width: AppTheme.spacing),

          _StatusItem(icon: TeleposIcons.info, label: 'v${appState.version}'),

          if (hasUpdate) ...[
            const SizedBox(width: AppTheme.spacingSmall),
            Tooltip(
              message: AppLocalizations.of(context)!.updateAvailable,
              child: const Icon(
                Icons.system_update_alt,
                color: AppColors.info,
                size: 18,
              ),
            ),
          ],

          if (appState.isLowStorage) ...[
            const SizedBox(width: AppTheme.spacingSmall),
            Tooltip(
              message: AppLocalizations.of(
                context,
              )!.lowStorageTooltip(appState.freeStorageGB.toStringAsFixed(1)),
              child: const Icon(
                Icons.warning_amber,
                color: AppColors.warning,
                size: 18,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CompactStatusBar extends ConsumerWidget {
  const _CompactStatusBar({required this.appState});

  final AppState appState;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Та же причина, что и в полной полосе: точка подмены времени одна.
    final time = ref.watch(currentTimeProvider);

    return Container(
      height: 28,
      color: AppColors.darkSurface,
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingSmall),
      child: Row(
        children: [
          Text(
            time,
            style: const TextStyle(
              color: AppColors.darkTextPrimary,
              fontSize: 12,
            ),
          ),

          const SizedBox(width: 8),

          _ConnectionStatusDot(status: appState.connectionStatus),

          const Spacer(),

          if (appState.userName != null)
            Text(
              _shortenName(appState.userName!),
              style: const TextStyle(
                color: AppColors.darkTextSecondary,
                fontSize: 12,
              ),
            ),

          if (appState.isLowStorage) ...[
            const SizedBox(width: 8),
            const Icon(Icons.warning_amber, color: AppColors.warning, size: 14),
          ],
        ],
      ),
    );
  }

  String _shortenName(String name) {
    if (name.isEmpty) return name;
    final parts = name.split(' ');
    if (parts.length >= 2 && parts[0].isNotEmpty) {
      return '${parts[0][0]}.${parts.last}';
    }
    return name.length > 10 ? '${name.substring(0, 10)}...' : name;
  }
}

class _StatusItem extends StatelessWidget {
  const _StatusItem({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppColors.darkTextSecondary),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(
            color: AppColors.darkTextPrimary,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

class _ConnectionStatusIndicator extends StatelessWidget {
  const _ConnectionStatusIndicator({required this.status});

  final ConnectionStatus status;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _ConnectionStatusDot(status: status),
        const SizedBox(width: 4),
        Text(
          _getStatusText(context),
          style: TextStyle(color: _getStatusColor(), fontSize: 12),
        ),
      ],
    );
  }

  String _getStatusText(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    switch (status) {
      case ConnectionStatus.online:
        return l10n.statusOnline;
      case ConnectionStatus.offline:
        return l10n.statusOffline;
      case ConnectionStatus.syncing:
        return l10n.statusSyncing;
    }
  }

  Color _getStatusColor() {
    switch (status) {
      case ConnectionStatus.online:
        return AppColors.statusOnline;
      case ConnectionStatus.offline:
        return AppColors.statusOffline;
      case ConnectionStatus.syncing:
        return AppColors.statusSync;
    }
  }
}

class _ConnectionStatusDot extends StatelessWidget {
  const _ConnectionStatusDot({required this.status});

  final ConnectionStatus status;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(shape: BoxShape.circle, color: _getColor()),
    );
  }

  Color _getColor() {
    switch (status) {
      case ConnectionStatus.online:
        return AppColors.statusOnline;
      case ConnectionStatus.offline:
        return AppColors.statusOffline;
      case ConnectionStatus.syncing:
        return AppColors.statusSync;
    }
  }
}

class StatusBarAppBarTitle extends ConsumerWidget {
  const StatusBarAppBarTitle({this.title, super.key});

  final String? title;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final time = ref.watch(currentTimeProvider);
    final status = ref.watch(connectionStatusProvider);

    return Row(
      children: [
        if (title != null) ...[Text(title!), const SizedBox(width: 16)],
        Text(
          time,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(
              context,
            ).appBarTheme.foregroundColor?.withValues(alpha: 0.7),
          ),
        ),
        const SizedBox(width: 8),
        _ConnectionStatusDot(status: status),
      ],
    );
  }
}

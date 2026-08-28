import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:telepos/app/theme/app_colors.dart';
import 'package:telepos/app/theme/app_theme.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/presentation/controllers/app/app_state_controller.dart';

class StorageWarningBanner extends ConsumerWidget {
  const StorageWarningBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appState = ref.watch(appStateProvider);

    if (!appState.isLowStorage || !appState.showStorageWarning) {
      return const SizedBox.shrink();
    }

    return MaterialBanner(
      backgroundColor: AppColors.warningLight,
      leading: const Icon(Icons.warning_amber, color: AppColors.warning),
      content: Text(
        AppLocalizations.of(
          context,
        )!.lowStorageBanner(appState.freeStorageGB.toStringAsFixed(1)),
        style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
      ),
      actions: [
        TextButton(
          onPressed: () {
            ref.read(appStateProvider.notifier).dismissStorageWarning();
          },
          child: Text(AppLocalizations.of(context)!.storageUnderstood),
        ),
      ],
    );
  }
}

class StorageWarningChip extends ConsumerWidget {
  const StorageWarningChip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appState = ref.watch(appStateProvider);

    if (!appState.isLowStorage) {
      return const SizedBox.shrink();
    }

    return Tooltip(
      message: AppLocalizations.of(
        context,
      )!.lowStorageTooltipShort(appState.freeStorageGB.toStringAsFixed(1)),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.warning,
          borderRadius: BorderRadius.circular(AppTheme.borderRadiusSmall),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.storage, size: 14, color: AppColors.white),
            const SizedBox(width: 4),
            Text(
              '${appState.freeStorageGB.toStringAsFixed(1)} GB',
              style: const TextStyle(
                color: AppColors.white,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class StorageWarningDialog extends StatelessWidget {
  const StorageWarningDialog({required this.freeSpaceGB, super.key});

  final double freeSpaceGB;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      icon: const Icon(Icons.warning_amber, color: AppColors.warning, size: 48),
      title: Text(AppLocalizations.of(context)!.storageWarningTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            AppLocalizations.of(
              context,
            )!.storageFree(freeSpaceGB.toStringAsFixed(2)),
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: AppColors.warning,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: AppTheme.spacing),
          Text(
            AppLocalizations.of(context)!.storageRecommendation,
            textAlign: TextAlign.center,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(AppLocalizations.of(context)!.globalClose),
        ),
      ],
    );
  }

  static Future<void> show(BuildContext context, double freeSpaceGB) {
    return showDialog(
      context: context,
      builder: (_) => StorageWarningDialog(freeSpaceGB: freeSpaceGB),
    );
  }
}

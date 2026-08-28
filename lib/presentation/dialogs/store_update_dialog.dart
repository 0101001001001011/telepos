import 'package:flutter/material.dart';
import 'package:telepos/l10n/app_localizations.dart';

import '../../core/services/update/store_update_service.dart';

class StoreUpdateDialog extends StatelessWidget {
  const StoreUpdateDialog({
    required this.updateInfo,
    required this.onUpdate,
    required this.onLater,
    super.key,
  });

  final StoreUpdateInfo updateInfo;

  final VoidCallback onUpdate;

  final VoidCallback onLater;

  static Future<void> show(
    BuildContext context, {
    required StoreUpdateInfo updateInfo,
    required VoidCallback onUpdate,
    required VoidCallback onLater,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: !updateInfo.isCritical,
      builder: (context) => StoreUpdateDialog(
        updateInfo: updateInfo,
        onUpdate: onUpdate,
        onLater: onLater,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final isAppStore = updateInfo.platform == StorePlatform.appStore;

    return AlertDialog(
      title: Row(
        children: [
          Icon(
            isAppStore ? Icons.apple : Icons.android,
            color: theme.colorScheme.primary,
            size: 28,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.updateDialogAvailable,
                  style: theme.textTheme.titleLarge,
                ),
                Text(
                  l10n.storeUpdateVersion(updateInfo.storeVersion.toString()),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.storeUpdateNewVersionAvailable(_getStoreName()),
            style: theme.textTheme.bodyLarge,
          ),
          if (updateInfo.releaseNotes.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(l10n.storeUpdateWhatsNew, style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            Container(
              constraints: const BoxConstraints(maxHeight: 150),
              child: SingleChildScrollView(
                child: Text(
                  updateInfo.releaseNotes,
                  style: theme.textTheme.bodyMedium,
                ),
              ),
            ),
          ],
          if (updateInfo.isCritical) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    color: theme.colorScheme.error,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l10n.storeUpdateRequired,
                      style: TextStyle(
                        color: theme.colorScheme.onErrorContainer,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Icon(
                _getStoreIcon(),
                size: 16,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l10n.storeUpdateGoTo(_getStoreName()),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        if (!updateInfo.isCritical)
          TextButton(onPressed: onLater, child: Text(l10n.updateDialogLater)),
        FilledButton.icon(
          onPressed: onUpdate,
          icon: Icon(_getStoreIcon()),
          label: Text(l10n.storeUpdateButton),
        ),
      ],
    );
  }

  String _getStoreName() {
    return updateInfo.platform == StorePlatform.appStore
        ? 'App Store'
        : 'Google Play';
  }

  IconData _getStoreIcon() {
    return updateInfo.platform == StorePlatform.appStore
        ? Icons.apple
        : Icons.shop;
  }
}

class FlexibleUpdateReadyDialog extends StatelessWidget {
  const FlexibleUpdateReadyDialog({
    required this.onInstall,
    required this.onLater,
    super.key,
  });

  final VoidCallback onInstall;

  final VoidCallback onLater;

  static Future<void> show(
    BuildContext context, {
    required VoidCallback onInstall,
    required VoidCallback onLater,
  }) {
    return showDialog<void>(
      context: context,
      builder: (context) =>
          FlexibleUpdateReadyDialog(onInstall: onInstall, onLater: onLater),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.download_done, color: theme.colorScheme.primary, size: 28),
          const SizedBox(width: 12),
          Text(l10n.storeUpdateDownloaded),
        ],
      ),
      content: Text(l10n.storeUpdateReadyToInstall),
      actions: [
        TextButton(onPressed: onLater, child: Text(l10n.updateDialogLater)),
        FilledButton.icon(
          onPressed: onInstall,
          icon: const Icon(Icons.install_mobile),
          label: Text(l10n.storeUpdateInstall),
        ),
      ],
    );
  }
}

class FlexibleUpdateSnackBar {
  FlexibleUpdateSnackBar._();

  static void showProgress(BuildContext context, {double progress = 0}) {
    final l10n = AppLocalizations.of(context)!;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.download, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.storeUpdateDownloading),
                  const SizedBox(height: 4),
                  LinearProgressIndicator(
                    value: progress,
                    backgroundColor: Colors.white24,
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  static void showReady(
    BuildContext context, {
    required VoidCallback onInstall,
  }) {
    final l10n = AppLocalizations.of(context)!;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.download_done, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(l10n.storeUpdateReadyShort)),
          ],
        ),
        action: SnackBarAction(
          label: l10n.storeUpdateInstall,
          onPressed: onInstall,
        ),
        duration: const Duration(seconds: 10),
      ),
    );
  }
}

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:telepos/app/theme/telepos_icons.dart';
import 'package:telepos/l10n/app_localizations.dart';

import '../../core/platform/platform_info.dart';
import '../../core/utils/update_util.dart';

class VersionConflictDialog extends StatelessWidget {
  const VersionConflictDialog({
    required this.currentVersion,
    required this.conflictVersion,
    required this.onRunPrevious,
    required this.onOpenFolder,
    required this.onContinue,
    this.errorMessage,
    super.key,
  });

  final String currentVersion;

  final String conflictVersion;

  final VoidCallback onRunPrevious;

  final VoidCallback onOpenFolder;

  final VoidCallback onContinue;

  final String? errorMessage;

  static Future<void> show(
    BuildContext context, {
    required String currentVersion,
    required String conflictVersion,
    required VoidCallback onRunPrevious,
    required VoidCallback onOpenFolder,
    required VoidCallback onContinue,
    String? errorMessage,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => VersionConflictDialog(
        currentVersion: currentVersion,
        conflictVersion: conflictVersion,
        onRunPrevious: onRunPrevious,
        onOpenFolder: onOpenFolder,
        onContinue: onContinue,
        errorMessage: errorMessage,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    return AlertDialog(
      title: Row(
        children: [
          Icon(
            Icons.warning_amber_rounded,
            color: theme.colorScheme.error,
            size: 28,
          ),
          const SizedBox(width: 12),
          Text(l10n.versionConflictTitle),
        ],
      ),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.versionConflictDescription,
              style: theme.textTheme.bodyLarge,
            ),
            const SizedBox(height: 16),
            _buildVersionRow(
              context,
              label: l10n.versionConflictCurrent,
              version: currentVersion,
              icon: TeleposIcons.checkCircle,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 8),
            _buildVersionRow(
              context,
              label: l10n.versionConflictFound,
              version: conflictVersion,
              icon: Icons.error,
              color: theme.colorScheme.error,
            ),
            if (errorMessage != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      TeleposIcons.info,
                      color: theme.colorScheme.error,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        errorMessage!,
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
            Text(
              l10n.versionConflictChooseAction,
              style: theme.textTheme.titleSmall,
            ),
          ],
        ),
      ),
      actions: [
        TextButton.icon(
          onPressed: onOpenFolder,
          icon: const Icon(Icons.folder_open),
          label: Text(l10n.versionConflictOpenFolder),
        ),
        OutlinedButton.icon(
          onPressed: onRunPrevious,
          icon: const Icon(Icons.history),
          label: Text(l10n.versionConflictPreviousVersion),
        ),
        FilledButton.icon(
          onPressed: onContinue,
          icon: const Icon(Icons.play_arrow),
          label: Text(l10n.versionConflictContinue),
        ),
      ],
    );
  }

  Widget _buildVersionRow(
    BuildContext context, {
    required String label,
    required String version,
    required IconData icon,
    required Color color,
  }) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        Text(
          version,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

class VersionConflictResolver {
  VersionConflictResolver._();

  static Future<bool> hasConflict() async {
    if (!PlatformInfo.isDesktop) return false;

    try {
      final installDir = UpdateUtil.getInstallDirectory();
      if (!await installDir.exists()) return false;

      final files = await installDir.list().toList();
      for (final file in files) {
        if (file.path.endsWith('.old') || file.path.endsWith('.bak')) {
          return true;
        }
      }

      return false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> openInstallFolder() async {
    final installDir = UpdateUtil.getInstallDirectory();

    if (PlatformInfo.isWindows) {
      await Process.run('explorer', [installDir.path]);
    } else if (PlatformInfo.isMacOS) {
      await Process.run('open', [installDir.path]);
    } else if (PlatformInfo.isLinux) {
      await Process.run('xdg-open', [installDir.path]);
    }
  }

  static Future<bool> runPreviousVersion() async {
    final execPath = UpdateUtil.getExecutablePath();
    final oldPath = '$execPath.old';

    if (await File(oldPath).exists()) {
      await Process.start(oldPath, [], mode: ProcessStartMode.detached);
      return true;
    }

    return false;
  }

  static Future<void> cleanupOldVersions() async {
    try {
      final installDir = UpdateUtil.getInstallDirectory();
      if (!await installDir.exists()) return;

      final files = await installDir.list().toList();
      for (final file in files) {
        if (file.path.endsWith('.old') || file.path.endsWith('.bak')) {
          await file.delete();
        }
      }
    } catch (_) {}
  }
}

import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/services/update/update_info.dart';
import '../../l10n/app_localizations.dart';
import 'package:telepos/core/locale/till_conventions.dart';

class UpdateDialog extends StatefulWidget {
  const UpdateDialog({
    required this.updateInfo,
    required this.onUpdate,
    required this.onLater,
    this.countdownSeconds = 10,
    super.key,
  });

  final UpdateInfo updateInfo;

  final VoidCallback onUpdate;

  final VoidCallback onLater;

  final int countdownSeconds;

  static Future<void> show(
    BuildContext context, {
    required UpdateInfo updateInfo,
    required VoidCallback onUpdate,
    required VoidCallback onLater,
    int countdownSeconds = 10,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => UpdateDialog(
        updateInfo: updateInfo,
        onUpdate: onUpdate,
        onLater: onLater,
        countdownSeconds: countdownSeconds,
      ),
    );
  }

  @override
  State<UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<UpdateDialog> {
  late int _countdown;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _countdown = widget.countdownSeconds;

    if (!widget.updateInfo.isMandatory) {
      _startCountdown();
    }
  }

  void _startCountdown() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _countdown--;
          if (_countdown <= 0) {
            timer.cancel();
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final info = widget.updateInfo;
    final l10n = AppLocalizations.of(context)!;

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.system_update, color: theme.colorScheme.primary, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.updateAvailable, style: theme.textTheme.titleLarge),
                Text(
                  l10n.updateVersion(info.versionString),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (info.releaseNotes.isNotEmpty) ...[
                _buildSection(
                  context,
                  icon: Icons.new_releases_outlined,
                  title: l10n.updateWhatsNew,
                  content: _parseReleaseNotes(info.releaseNotes, 'new'),
                ),
                const SizedBox(height: 16),
                _buildSection(
                  context,
                  icon: Icons.bug_report_outlined,
                  title: l10n.updateFixedIssues,
                  content: _parseReleaseNotes(info.releaseNotes, 'fix'),
                ),
              ],
              const SizedBox(height: 16),
              _buildInfoRow(
                context,
                icon: Icons.folder_outlined,
                label: l10n.updateSize,
                value: info.fileSizeFormatted,
              ),
              _buildInfoRow(
                context,
                icon: Icons.calendar_today_outlined,
                label: l10n.updateDate,
                value: _formatDate(info.releaseDate),
              ),
              if (info.isMandatory) ...[
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
                          l10n.updateMandatory,
                          style: TextStyle(
                            color: theme.colorScheme.onErrorContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        if (!info.isMandatory)
          TextButton(
            onPressed: _countdown <= 0 ? widget.onLater : null,
            child: Text(
              _countdown > 0
                  ? l10n.updateLaterCountdown(_countdown)
                  : l10n.updateLater,
            ),
          ),
        FilledButton.icon(
          onPressed: widget.onUpdate,
          icon: const Icon(Icons.download),
          label: Text(l10n.updatePosNow),
        ),
      ],
    );
  }

  Widget _buildSection(
    BuildContext context, {
    required IconData icon,
    required String title,
    required List<String> content,
  }) {
    if (content.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Text(
              title,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...content.map(
          (item) => Padding(
            padding: const EdgeInsets.only(left: 26, bottom: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('• ', style: theme.textTheme.bodyMedium),
                Expanded(child: Text(item, style: theme.textTheme.bodyMedium)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
  }) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          Text(value, style: theme.textTheme.bodyMedium),
        ],
      ),
    );
  }

  List<String> _parseReleaseNotes(String notes, String type) {
    final lines = notes.split('\n');
    final result = <String>[];

    for (final line in lines) {
      final trimmed = line.trim();
      if (type == 'new' &&
          (trimmed.startsWith('[new]') || trimmed.startsWith('- new:'))) {
        result.add(
          trimmed.replaceFirst('[new]', '').replaceFirst('- new:', '').trim(),
        );
      } else if (type == 'fix' &&
          (trimmed.startsWith('[fix]') || trimmed.startsWith('- fix:'))) {
        result.add(
          trimmed.replaceFirst('[fix]', '').replaceFirst('- fix:', '').trim(),
        );
      } else if (!trimmed.startsWith('[') && !trimmed.startsWith('-')) {
        if (type == 'new' && trimmed.isNotEmpty) {
          result.add(trimmed);
        }
      }
    }

    return result;
  }

  String _formatDate(DateTime date) {
    return TillConventions.current.formatDate(date);
  }
}

class UpdateDownloadDialog extends StatelessWidget {
  const UpdateDownloadDialog({
    required this.progress,
    required this.onCancel,
    super.key,
  });

  final double progress;

  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final percent = (progress * 100).toInt();

    return AlertDialog(
      title: Text(l10n.updateDownloading),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          LinearProgressIndicator(value: progress),
          const SizedBox(height: 16),
          Text('$percent%', style: theme.textTheme.headlineMedium),
          const SizedBox(height: 8),
          Text(
            l10n.updateDownloadingFile,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: onCancel, child: Text(l10n.globalCancel)),
      ],
    );
  }
}

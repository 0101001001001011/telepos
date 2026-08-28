import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:telepos/app/theme/app_colors.dart';
import 'package:telepos/core/logging/log_journal_service.dart';
import 'package:telepos/l10n/app_localizations.dart';

class LogJournalScreen extends ConsumerStatefulWidget {
  const LogJournalScreen({super.key});

  @override
  ConsumerState<LogJournalScreen> createState() => _LogJournalScreenState();
}

class _LogJournalScreenState extends ConsumerState<LogJournalScreen> {
  final _service = LogJournalService();
  List<LogFileInfo> _files = const [];
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() => setState(() => _files = _service.listLogs());

  String _fmtSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _export() async {
    final l10n = AppLocalizations.of(context)!;
    if (_files.isEmpty) {
      _snack(l10n.logJournalEmpty);
      return;
    }
    final dir = await FilePicker.platform.getDirectoryPath(
      dialogTitle: l10n.logJournalPickFolder,
    );
    if (dir == null) return;
    setState(() => _busy = true);
    try {
      final n = await _service.exportTo(dir);
      _snack(l10n.logJournalExported(n, dir));
    } catch (e) {
      _snack('${l10n.globalError}: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deleteOld() async {
    setState(() => _busy = true);
    try {
      final n = await _service.deleteOlderThan(const Duration(days: 7));
      final l10n = AppLocalizations.of(context)!;
      _snack(l10n.logJournalDeletedOld(n));
      _reload();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deleteAll() async {
    final l10n = AppLocalizations.of(context)!;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.logJournalDeleteAllTitle),
        content: Text(l10n.logJournalDeleteAllConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.globalCancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: Text(l10n.globalDelete),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _busy = true);
    try {
      final n = await _service.deleteAllExceptToday();
      _snack(l10n.logJournalDeletedOld(n));
      _reload();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final total = _files.fold<int>(0, (s, f) => s + f.sizeBytes);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.logJournalTitle)),
      body: Column(
        children: [
          if (_busy) const LinearProgressIndicator(minHeight: 2),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.logJournalSummary(_files.length, _fmtSize(total)),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: l10n.globalRefresh,
                  icon: const Icon(Icons.refresh),
                  onPressed: _busy ? null : _reload,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _busy ? null : _export,
                    icon: const Icon(Icons.usb),
                    label: Text(l10n.logJournalExport),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: _busy ? null : _deleteOld,
                  icon: const Icon(Icons.auto_delete_outlined),
                  label: Text(l10n.logJournalDeleteOld),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: _busy ? null : _deleteAll,
                  icon: const Icon(Icons.delete_sweep_outlined),
                  label: Text(l10n.globalDelete),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.error,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _files.isEmpty
                ? Center(
                    child: Text(
                      l10n.logJournalEmpty,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  )
                : ListView.separated(
                    itemCount: _files.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final f = _files[i];
                      return ListTile(
                        leading: const Icon(Icons.description_outlined),
                        title: Text(f.name),
                        subtitle: Text(_fmtSize(f.sizeBytes)),
                        trailing: Text(
                          '${f.modified.day.toString().padLeft(2, '0')}.'
                          '${f.modified.month.toString().padLeft(2, '0')} '
                          '${f.modified.hour.toString().padLeft(2, '0')}:'
                          '${f.modified.minute.toString().padLeft(2, '0')}',
                          style: TextStyle(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                            fontSize: 12,
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

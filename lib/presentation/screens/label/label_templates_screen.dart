import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:telepos/app/theme/app_colors.dart';
import 'package:telepos/app/theme/app_semantic_colors.dart';
import 'package:telepos/app/theme/app_theme.dart';
import 'package:telepos/app/theme/telepos_icons.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/presentation/screens/label/label_template_editor_screen.dart';

class LabelTemplatesScreen extends StatefulWidget {
  const LabelTemplatesScreen({super.key});

  @override
  State<LabelTemplatesScreen> createState() => _LabelTemplatesScreenState();
}

class _LabelTemplatesScreenState extends State<LabelTemplatesScreen> {
  List<LabelTemplate> _templates = const [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final dao = GetIt.I<AppDatabase>().labelTemplateDao;
      await dao.seedDefaults();
      final list = await dao.getAll();
      if (!mounted) return;
      setState(() {
        _templates = list;
        _isLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _create() async {
    final changed = await context.push<bool>(
      '${GoRouterState.of(context).uri.path}/edit',
      extra: const LabelTemplateEditorArgs(),
    );
    if (changed == true) _load();
  }

  Future<void> _edit(LabelTemplate t) async {
    final changed = await context.push<bool>(
      '${GoRouterState.of(context).uri.path}/edit',
      extra: LabelTemplateEditorArgs(templateId: t.id),
    );
    if (changed == true) _load();
  }

  Future<void> _delete(LabelTemplate t) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.labelTemplateDeleteTitle),
        content: Text(l10n.labelTemplateDeleteConfirm(t.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.globalCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: Text(l10n.globalDelete),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await GetIt.I<AppDatabase>().labelTemplateDao.deleteTemplate(t.id);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.labelTemplatesTitle),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _create,
        icon: const Icon(TeleposIcons.add),
        label: Text(l10n.labelTemplateNew),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _templates.isEmpty
          ? Center(child: Text(l10n.labelTemplatesEmpty))
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _templates.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final t = _templates[index];
                return Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  ),
                  child: ListTile(
                    leading: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: selectedSurfaceOf(context),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.label_outline,
                        color: AppColors.primary,
                      ),
                    ),
                    title: Row(
                      children: [
                        Flexible(child: Text(t.name)),
                        if (t.isDefault) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: context.semantic.canvas,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              l10n.labelTemplateBuiltIn,
                              style: TextStyle(
                                fontSize: 11,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    subtitle: Text(
                      '${t.widthMm} × ${t.heightMm} ${l10n.labelMmUnit}',
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit, size: 20),
                          onPressed: () => _edit(t),
                          tooltip: l10n.globalEdit,
                        ),
                        if (!t.isDefault)
                          IconButton(
                            icon: Icon(
                              TeleposIcons.delete,
                              size: 20,
                              color: Theme.of(context).colorScheme.error,
                            ),
                            onPressed: () => _delete(t),
                            tooltip: l10n.globalDelete,
                          ),
                      ],
                    ),
                    onTap: () => _edit(t),
                  ),
                );
              },
            ),
    );
  }
}

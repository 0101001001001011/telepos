import 'package:flutter/material.dart';
import 'package:telepos/app/theme/app_colors.dart';
import 'package:telepos/app/theme/app_semantic_colors.dart';
import 'package:telepos/app/theme/telepos_icons.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/presentation/common/help/help_service.dart';

class HelpDialog {
  HelpDialog._();

  static Future<void> show(BuildContext context, String screenId) async {
    final content = await HelpService.load(screenId);
    if (content == null || !context.mounted) return;

    final isMobile = MediaQuery.sizeOf(context).width < 600;

    if (isMobile) {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        builder: (_) => DraggableScrollableSheet(
          initialChildSize: 0.75,
          minChildSize: 0.4,
          maxChildSize: 0.95,
          expand: false,
          builder: (ctx, scrollController) => _HelpDialogContent(
            content: content,
            scrollController: scrollController,
          ),
        ),
      );
    } else {
      await showDialog<void>(
        context: context,
        builder: (_) => Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560, maxHeight: 600),
            child: _HelpDialogContent(content: content),
          ),
        ),
      );
    }
  }
}

class _HelpDialogContent extends StatelessWidget {
  const _HelpDialogContent({required this.content, this.scrollController});

  final HelpContent content;
  final ScrollController? scrollController;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(20, 16, 8, 12),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: theme.colorScheme.outline),
            ),
          ),
          child: Row(
            children: [
              const Icon(Icons.help_outline, color: AppColors.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  content.title,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(TeleposIcons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),

        Flexible(
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.all(20),
            shrinkWrap: scrollController == null,
            children: [
              Text(
                content.description,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),

              if (content.sections.isNotEmpty) ...[
                const SizedBox(height: 20),
                ...content.sections.map((s) => _buildSection(theme, s)),
              ],

              if (content.tips.isNotEmpty) ...[
                const SizedBox(height: 20),
                Text(
                  l10n?.helpTips ?? 'Советы',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                ...content.tips.map((t) => _buildTip(theme, t)),
              ],

              if (content.shortcuts.isNotEmpty) ...[
                const SizedBox(height: 20),
                Text(
                  l10n?.helpShortcuts ?? 'Горячие клавиши',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                _buildShortcutsTable(theme, l10n),
              ],

              const SizedBox(height: 8),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSection(ThemeData theme, HelpSection section) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            section.heading,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            section.content,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTip(ThemeData theme, String tip) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(
              Icons.lightbulb_outline,
              size: 18,
              color: AppColors.warningGold,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              tip,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShortcutsTable(ThemeData theme, AppLocalizations? l10n) {
    return Table(
      columnWidths: const {0: IntrinsicColumnWidth(), 1: FlexColumnWidth()},
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      children: [
        TableRow(
          decoration: BoxDecoration(
            color: theme.semantic.canvas.withValues(alpha: 0.5),
          ),
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Text(
                l10n?.helpKey ?? 'Клавиша',
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Text(
                l10n?.helpAction ?? 'Действие',
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        ...content.shortcuts.map(
          (s) => TableRow(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: theme.semantic.canvas,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: theme.colorScheme.outline),
                  ),
                  child: Text(
                    s.key,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontFamily: 'TeleposMono',
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                child: Text(s.action, style: theme.textTheme.bodyMedium),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

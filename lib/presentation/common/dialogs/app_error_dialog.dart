import 'package:flutter/material.dart';
import 'package:telepos/app/theme/app_colors.dart';
import 'package:telepos/app/theme/app_semantic_colors.dart';
import 'package:telepos/app/theme/app_theme.dart';
import 'package:telepos/app/theme/telepos_icons.dart';
import 'package:telepos/l10n/app_localizations.dart';

class AppErrorDialog extends StatelessWidget {
  const AppErrorDialog({
    super.key,
    required this.error,
    this.stackTrace,
    this.onRetry,
    this.onOpenFolder,
    this.onLaunchOther,
    this.onExit,
  });

  final String error;

  final String? stackTrace;

  final VoidCallback? onRetry;

  final VoidCallback? onOpenFolder;

  final VoidCallback? onLaunchOther;

  final VoidCallback? onExit;

  static Future<void> show({
    required BuildContext context,
    required String error,
    String? stackTrace,
    VoidCallback? onRetry,
    VoidCallback? onOpenFolder,
    VoidCallback? onLaunchOther,
    VoidCallback? onExit,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AppErrorDialog(
        error: error,
        stackTrace: stackTrace,
        onRetry: onRetry,
        onOpenFolder: onOpenFolder,
        onLaunchOther: onLaunchOther,
        onExit: onExit,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.error.withValues(alpha: 0.1),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.error,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: const Icon(
                      TeleposIcons.error,
                      color: AppColors.white,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppLocalizations.of(context)!.errorCritical,
                          style: AppTextStyles.h3.copyWith(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          AppLocalizations.of(context)!.errorAppProblem,
                          style: context.styles.caption,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppLocalizations.of(context)!.errorDescription,
                      style: AppTextStyles.body.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: context.semantic.canvas,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: SelectableText(
                        error,
                        style: AppTextStyles.body.copyWith(
                          fontFamily: 'TeleposMono',
                        ),
                      ),
                    ),

                    if (stackTrace != null) ...[
                      const SizedBox(height: 16),
                      ExpansionTile(
                        title: Text(
                          AppLocalizations.of(context)!.errorTechnical,
                          style: AppTextStyles.body,
                        ),
                        tilePadding: EdgeInsets.zero,
                        childrenPadding: const EdgeInsets.only(top: 8),
                        children: [
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: context.semantic.canvas,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            constraints: const BoxConstraints(maxHeight: 200),
                            child: SingleChildScrollView(
                              child: SelectableText(
                                stackTrace!,
                                style: context.styles.caption.copyWith(
                                  fontFamily: 'TeleposMono',
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),

            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: context.semantic.canvas)),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      if (onRetry != null)
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              Navigator.of(context).pop();
                              onRetry!();
                            },
                            icon: const Icon(Icons.refresh),
                            label: Text(
                              AppLocalizations.of(context)!.errorRetry,
                            ),
                          ),
                        ),
                      if (onRetry != null && onOpenFolder != null)
                        const SizedBox(width: 12),
                      if (onOpenFolder != null)
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: onOpenFolder,
                            icon: const Icon(Icons.folder_open),
                            label: Text(
                              AppLocalizations.of(context)!.errorOpenFolder,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  Row(
                    children: [
                      if (onLaunchOther != null)
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.of(context).pop();
                              onLaunchOther!();
                            },
                            icon: const Icon(Icons.open_in_new),
                            label: Text(
                              AppLocalizations.of(context)!.errorOtherVersion,
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.warning,
                            ),
                          ),
                        ),
                      if (onLaunchOther != null && onExit != null)
                        const SizedBox(width: 12),
                      if (onExit != null)
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: onExit,
                            icon: const Icon(Icons.exit_to_app),
                            label: Text(
                              AppLocalizations.of(context)!.errorExit,
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Theme.of(
                                context,
                              ).colorScheme.error,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

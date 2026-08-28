import 'package:flutter/material.dart';
import 'package:telepos/app/theme/app_colors.dart';
import 'package:telepos/app/theme/app_theme.dart';
import 'package:telepos/app/theme/telepos_icons.dart';
import 'package:telepos/l10n/app_localizations.dart';

class ConfirmationResult {
  const ConfirmationResult({
    required this.confirmed,
    this.dontAskAgain = false,
  });

  final bool confirmed;
  final bool dontAskAgain;
}

class ConfirmationDialog extends StatefulWidget {
  const ConfirmationDialog({
    super.key,
    required this.title,
    required this.message,
    this.confirmText,
    this.cancelText,
    this.confirmColor,
    this.isDestructive = false,
    this.showDontAskAgain = false,
    this.icon,
  });

  final String title;
  final String message;
  final String? confirmText;
  final String? cancelText;
  final Color? confirmColor;
  final bool isDestructive;
  final bool showDontAskAgain;
  final IconData? icon;

  static Future<bool> show({
    required BuildContext context,
    required String title,
    required String message,
    String? confirmText,
    String? cancelText,
    bool isDestructive = false,
    IconData? icon,
  }) async {
    final result = await showDialog<ConfirmationResult>(
      context: context,
      builder: (context) => ConfirmationDialog(
        title: title,
        message: message,
        confirmText: confirmText,
        cancelText: cancelText,
        isDestructive: isDestructive,
        icon: icon,
      ),
    );
    return result?.confirmed ?? false;
  }

  static Future<ConfirmationResult?> showWithDontAskAgain({
    required BuildContext context,
    required String title,
    required String message,
    String? confirmText,
    String? cancelText,
    bool isDestructive = false,
  }) {
    return showDialog<ConfirmationResult>(
      context: context,
      builder: (context) => ConfirmationDialog(
        title: title,
        message: message,
        confirmText: confirmText,
        cancelText: cancelText,
        isDestructive: isDestructive,
        showDontAskAgain: true,
      ),
    );
  }

  static Future<bool> showDelete({
    required BuildContext context,
    required String itemName,
  }) {
    final l10n = AppLocalizations.of(context)!;
    return show(
      context: context,
      title: l10n.deleteTitle,
      message: l10n.deleteItemConfirm(itemName),
      confirmText: l10n.globalDelete,
      cancelText: l10n.globalCancel,
      isDestructive: true,
      icon: TeleposIcons.delete,
    );
  }

  static Future<bool> showExit({required BuildContext context}) {
    final l10n = AppLocalizations.of(context)!;
    return show(
      context: context,
      title: l10n.exitTitle,
      message: l10n.exitConfirm,
      confirmText: l10n.exitBtn,
      cancelText: l10n.globalCancel,
      icon: Icons.logout,
    );
  }

  @override
  State<ConfirmationDialog> createState() => _ConfirmationDialogState();
}

class _ConfirmationDialogState extends State<ConfirmationDialog> {
  bool _dontAskAgain = false;

  @override
  Widget build(BuildContext context) {
    final effectiveColor =
        widget.confirmColor ??
        (widget.isDestructive
            ? Theme.of(context).colorScheme.error
            : AppColors.primary);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.icon != null)
                Container(
                  width: 64,
                  height: 64,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: effectiveColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(32),
                  ),
                  child: Icon(widget.icon, size: 32, color: effectiveColor),
                ),

              Text(
                widget.title,
                style: AppTextStyles.h3,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),

              Text(
                widget.message,
                style: AppTextStyles.body,
                textAlign: TextAlign.center,
              ),

              if (widget.showDontAskAgain) ...[
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Checkbox(
                      value: _dontAskAgain,
                      onChanged: (value) {
                        setState(() => _dontAskAgain = value ?? false);
                      },
                    ),
                    GestureDetector(
                      onTap: () {
                        setState(() => _dontAskAgain = !_dontAskAgain);
                      },
                      child: Text(
                        AppLocalizations.of(context)!.dontAskAgain,
                        style: AppTextStyles.body,
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 24),

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.of(context).pop(
                          ConfirmationResult(
                            confirmed: false,
                            dontAskAgain: _dontAskAgain,
                          ),
                        );
                      },
                      child: Text(
                        widget.cancelText ??
                            AppLocalizations.of(context)!.globalNo,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).pop(
                          ConfirmationResult(
                            confirmed: true,
                            dontAskAgain: _dontAskAgain,
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: effectiveColor,
                        foregroundColor: AppColors.white,
                      ),
                      child: Text(
                        widget.confirmText ??
                            AppLocalizations.of(context)!.globalYes,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:telepos/app/theme/app_colors.dart';
import 'package:telepos/app/theme/app_theme.dart';
import 'package:telepos/app/theme/telepos_icons.dart';
import 'package:telepos/l10n/app_localizations.dart';

class DialogOption<T> {
  const DialogOption({
    required this.value,
    required this.label,
    this.subtitle,
    this.icon,
    this.enabled = true,
  });

  final T value;
  final String label;
  final String? subtitle;
  final IconData? icon;
  final bool enabled;
}

class OptionsDialog<T> extends StatefulWidget {
  const OptionsDialog({
    super.key,
    required this.title,
    required this.options,
    this.selectedValue,
    this.message,
    this.confirmText,
    this.cancelText,
    this.showRadio = true,
  });

  final String title;
  final List<DialogOption<T>> options;
  final T? selectedValue;
  final String? message;
  final String? confirmText;
  final String? cancelText;
  final bool showRadio;

  static Future<T?> show<T>({
    required BuildContext context,
    required String title,
    required List<DialogOption<T>> options,
    T? selectedValue,
    String? message,
    bool showRadio = true,
  }) {
    return showDialog<T>(
      context: context,
      builder: (context) => OptionsDialog<T>(
        title: title,
        options: options,
        selectedValue: selectedValue,
        message: message,
        showRadio: showRadio,
      ),
    );
  }

  @override
  State<OptionsDialog<T>> createState() => _OptionsDialogState<T>();
}

class _OptionsDialogState<T> extends State<OptionsDialog<T>> {
  late T? _selectedValue;

  @override
  void initState() {
    super.initState();
    _selectedValue = widget.selectedValue;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400, maxHeight: 500),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Text(
                    widget.title,
                    style: AppTextStyles.h3,
                    textAlign: TextAlign.center,
                  ),
                  if (widget.message != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      widget.message!,
                      style: AppTextStyles.body.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ],
              ),
            ),

            const Divider(height: 1),

            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: widget.options.length,
                itemBuilder: (context, index) {
                  final option = widget.options[index];
                  final isSelected = option.value == _selectedValue;

                  return _OptionTile(
                    option: option,
                    isSelected: isSelected,
                    showRadio: widget.showRadio,
                    onTap: option.enabled
                        ? () {
                            if (widget.showRadio) {
                              setState(() => _selectedValue = option.value);
                            } else {
                              Navigator.of(context).pop(option.value);
                            }
                          }
                        : null,
                  );
                },
              ),
            ),

            if (widget.showRadio) ...[
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text(
                          widget.cancelText ??
                              AppLocalizations.of(context)!.globalCancel,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _selectedValue != null
                            ? () => Navigator.of(context).pop(_selectedValue)
                            : null,
                        child: Text(
                          widget.confirmText ??
                              AppLocalizations.of(context)!.globalSelect,
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
    );
  }
}

class _OptionTile<T> extends StatelessWidget {
  const _OptionTile({
    required this.option,
    required this.isSelected,
    required this.showRadio,
    required this.onTap,
  });

  final DialogOption<T> option;
  final bool isSelected;
  final bool showRadio;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        color: isSelected ? AppColors.primary.withValues(alpha: 0.05) : null,
        child: Row(
          children: [
            if (showRadio) ...[
              Radio<bool>(
                value: true,
                groupValue: isSelected ? true : null,
                onChanged: onTap != null ? (_) => onTap!() : null,
              ),
              const SizedBox(width: 8),
            ],
            if (option.icon != null) ...[
              Icon(
                option.icon,
                size: 24,
                color: option.enabled
                    ? (isSelected
                          ? AppColors.primary
                          : Theme.of(context).colorScheme.onSurfaceVariant)
                    : Theme.of(context).colorScheme.outline,
              ),
              const SizedBox(width: 16),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    option.label,
                    style: AppTextStyles.body.copyWith(
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.normal,
                      color: option.enabled
                          ? Theme.of(context).colorScheme.onSurface
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  if (option.subtitle != null) ...[
                    const SizedBox(height: 4),
                    Text(option.subtitle!, style: context.styles.caption),
                  ],
                ],
              ),
            ),
            if (isSelected && !showRadio)
              Icon(TeleposIcons.check, color: AppColors.primary),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:telepos/app/theme/app_colors.dart';
import 'package:telepos/app/theme/app_semantic_colors.dart';
import 'package:telepos/app/theme/app_theme.dart';
import 'package:telepos/app/theme/telepos_icons.dart';
import 'package:telepos/l10n/app_localizations.dart';

class SwitchButton extends StatelessWidget {
  const SwitchButton({
    super.key,
    required this.value,
    required this.onChanged,
    this.label,
    this.activeLabel,
    this.inactiveLabel,
    this.activeColor,
    this.inactiveColor,
    this.enabled = true,
  });

  final bool value;

  final ValueChanged<bool> onChanged;

  final String? label;

  final String? activeLabel;

  final String? inactiveLabel;

  final Color? activeColor;

  final Color? inactiveColor;

  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final effectiveActiveColor = activeColor ?? AppColors.primary;
    final effectiveInactiveColor = inactiveColor ?? context.semantic.canvas;
    final currentColor = value ? effectiveActiveColor : effectiveInactiveColor;

    final l10n = AppLocalizations.of(context)!;
    final displayLabel =
        label ??
        (value
            ? (activeLabel ?? l10n.switchOn)
            : (inactiveLabel ?? l10n.switchOff));

    return GestureDetector(
      onTap: enabled ? () => onChanged(!value) : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: value
              ? effectiveActiveColor.withValues(alpha: 0.1)
              : effectiveInactiveColor.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: currentColor, width: value ? 2 : 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: value ? effectiveActiveColor : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: currentColor, width: 2),
              ),
              child: value
                  ? const Icon(
                      TeleposIcons.check,
                      size: 14,
                      color: AppColors.white,
                    )
                  : null,
            ),
            const SizedBox(width: 8),
            Text(
              displayLabel,
              style: AppTextStyles.body.copyWith(
                color: enabled
                    ? currentColor
                    : Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: value ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ToggleButtonGroup<T> extends StatelessWidget {
  const ToggleButtonGroup({
    super.key,
    required this.items,
    required this.selectedValue,
    required this.onChanged,
    this.direction = Axis.horizontal,
    this.spacing = 8,
    this.enabled = true,
  });

  final List<ToggleItem<T>> items;

  final T selectedValue;

  final ValueChanged<T> onChanged;

  final Axis direction;

  final double spacing;

  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final buttons = items.map((item) {
      final isSelected = item.value == selectedValue;
      return _ToggleButton(
        label: item.label,
        icon: item.icon,
        isSelected: isSelected,
        onTap: enabled ? () => onChanged(item.value) : null,
        activeColor: item.activeColor,
      );
    }).toList();

    if (direction == Axis.horizontal) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: buttons
            .map(
              (btn) => Padding(
                padding: EdgeInsets.only(right: spacing),
                child: btn,
              ),
            )
            .toList(),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: buttons
          .map(
            (btn) => Padding(
              padding: EdgeInsets.only(bottom: spacing),
              child: btn,
            ),
          )
          .toList(),
    );
  }
}

class ToggleItem<T> {
  const ToggleItem({
    required this.value,
    required this.label,
    this.icon,
    this.activeColor,
  });

  final T value;
  final String label;
  final IconData? icon;
  final Color? activeColor;
}

class _ToggleButton extends StatelessWidget {
  const _ToggleButton({
    required this.label,
    this.icon,
    required this.isSelected,
    required this.onTap,
    this.activeColor,
  });

  final String label;
  final IconData? icon;
  final bool isSelected;
  final VoidCallback? onTap;
  final Color? activeColor;

  @override
  Widget build(BuildContext context) {
    final color = activeColor ?? AppColors.primary;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? color : Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? color : AppColors.borderPrimary,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 20,
                color: isSelected
                    ? AppColors.white
                    : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
            ],
            Text(
              label,
              style: AppTextStyles.body.copyWith(
                color: isSelected
                    ? AppColors.white
                    : Theme.of(context).colorScheme.onSurface,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ButtonCheckbox extends StatelessWidget {
  const ButtonCheckbox({
    super.key,
    required this.value,
    required this.onChanged,
    required this.label,
    this.icon,
    this.enabled = true,
  });

  final bool value;
  final ValueChanged<bool> onChanged;
  final String label;
  final IconData? icon;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? () => onChanged(!value) : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: value
              ? AppColors.primary.withValues(alpha: 0.1)
              : Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: value ? AppColors.primary : AppColors.borderPrimary,
            width: value ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: value ? AppColors.primary : Colors.transparent,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: value ? AppColors.primary : AppColors.borderPrimary,
                  width: 2,
                ),
              ),
              child: value
                  ? const Icon(
                      TeleposIcons.check,
                      size: 16,
                      color: AppColors.white,
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            if (icon != null) ...[
              Icon(
                icon,
                size: 20,
                color: value
                    ? AppColors.primary
                    : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
            ],
            Text(
              label,
              style: AppTextStyles.body.copyWith(
                color: enabled
                    ? (value
                          ? AppColors.primary
                          : Theme.of(context).colorScheme.onSurface)
                    : Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: value ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

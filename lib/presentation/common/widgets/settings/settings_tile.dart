import 'package:flutter/material.dart';
import 'package:telepos/app/theme/app_tokens.dart';
import 'package:telepos/app/theme/wizard_metrics.dart';

/// Строка «название — значение».
class SettingsTile extends StatelessWidget {
  const SettingsTile({
    required this.title,
    required this.metrics,
    this.icon,
    this.value,
    this.trailing,
    this.onTap,
    super.key,
  });

  final IconData? icon;
  final String title;
  final String? value;
  final Widget? trailing;
  final VoidCallback? onTap;
  final WizardMetrics metrics;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      // Подсветка при наведении — только там, где есть курсор. На сенсорном
      // экране наведения не существует, и hover-цвет там залипал бы после
      // нажатия.
      hoverColor: metrics.showHover
          ? theme.colorScheme.onSurface.withValues(alpha: 0.04)
          : Colors.transparent,
      focusColor: metrics.showFocusRing
          ? theme.colorScheme.primary.withValues(alpha: 0.10)
          : Colors.transparent,
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: metrics.rowHeight),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTokens.space16,
            vertical: AppTokens.space8,
          ),
          child: Row(
            children: [
              if (icon != null) ...[
                Icon(icon, color: theme.colorScheme.onSurfaceVariant),
                const SizedBox(width: AppTokens.space16),
              ],
              Expanded(child: Text(title, style: theme.textTheme.bodyLarge)),
              if (value != null)
                Padding(
                  padding: const EdgeInsets.only(left: AppTokens.space12),
                  child: Text(
                    value!,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              if (trailing != null) ...[
                const SizedBox(width: AppTokens.space8),
                trailing!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

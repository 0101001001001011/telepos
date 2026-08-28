import 'package:flutter/material.dart';
import 'package:telepos/app/theme/app_tokens.dart';
import 'package:telepos/app/theme/telepos_icons.dart';
import 'package:telepos/app/theme/wizard_metrics.dart';

/// Строка выбора: галочка справа, без рамок и заливок.
///
/// Так выбор показан в Telegram — выбранное отмечено, а не обведено. Карточка
/// с двухпиксельной рамкой и заливкой, которая была здесь раньше, кричит
/// громче, чем сам выбор.
class SettingsChoiceTile extends StatelessWidget {
  const SettingsChoiceTile({
    required this.title,
    required this.selected,
    required this.onTap,
    required this.metrics,
    this.leading,
    this.subtitle,
    this.detail,
    super.key,
  });

  final Widget? leading;
  final String title;
  final String? subtitle;
  final String? detail;
  final bool selected;
  final VoidCallback onTap;
  final WizardMetrics metrics;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      hoverColor: metrics.showHover
          ? theme.colorScheme.onSurface.withValues(alpha: 0.04)
          : Colors.transparent,
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: metrics.rowHeight),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTokens.space16,
            vertical: AppTokens.space12,
          ),
          child: Row(
            children: [
              if (leading != null) ...[
                leading!,
                const SizedBox(width: AppTokens.space16),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: selected
                          ? theme.textTheme.titleMedium
                          : theme.textTheme.bodyLarge,
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: AppTokens.space4),
                      Text(
                        subtitle!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                    if (detail != null) ...[
                      const SizedBox(height: AppTokens.space4),
                      Text(
                        detail!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: AppTokens.space12),
              // Место под галочку занято всегда, иначе строки прыгают по
              // ширине при смене выбора.
              SizedBox(
                width: AppTokens.space24,
                child: selected
                    ? Icon(TeleposIcons.check, color: theme.colorScheme.primary)
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

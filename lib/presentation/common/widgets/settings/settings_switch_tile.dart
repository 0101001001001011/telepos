import 'package:flutter/material.dart';
import 'package:telepos/app/theme/app_tokens.dart';
import 'package:telepos/app/theme/wizard_metrics.dart';

/// Строка с переключателем.
///
/// Цель нажатия — вся строка, а не тумблер шириной 40 px: промах по тумблеру
/// под пальцем означает, что настройка молча не переключилась.
class SettingsSwitchTile extends StatelessWidget {
  const SettingsSwitchTile({
    required this.title,
    required this.value,
    required this.onChanged,
    required this.metrics,
    this.subtitle,
    super.key,
  });

  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final WizardMetrics metrics;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: () => onChanged(!value),
      hoverColor: metrics.showHover
          ? theme.colorScheme.onSurface.withValues(alpha: 0.04)
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
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(title, style: theme.textTheme.bodyLarge),
                    if (subtitle != null) ...[
                      const SizedBox(height: AppTokens.space4),
                      Text(
                        subtitle!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: AppTokens.space12),
              Switch(value: value, onChanged: onChanged),
            ],
          ),
        ),
      ),
    );
  }
}

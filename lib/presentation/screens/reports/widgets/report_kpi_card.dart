import 'package:flutter/material.dart';
import 'package:telepos/app/theme/app_colors.dart';
import 'package:telepos/app/theme/app_semantic_colors.dart';
import 'package:telepos/app/theme/app_theme.dart';

class ReportKpiCard extends StatelessWidget {
  const ReportKpiCard({
    required this.title,
    required this.value,
    this.subtitle,
    this.trend,
    this.trendLabel,
    this.icon,
    this.color,
    super.key,
  });

  final String title;

  final String value;

  final String? subtitle;

  final double? trend;

  final String? trendLabel;

  final IconData? icon;

  final Color? color;

  @override
  Widget build(BuildContext context) {
    final accentColor = color ?? AppColors.primary;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.borderRadius),
        border: Border.all(color: context.semantic.canvas),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadowLight,
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, size: 20, color: accentColor),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Text(
                  title,
                  style: context.styles.caption.copyWith(fontSize: 13),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          Text(
            value,
            style: AppTextStyles.h2.copyWith(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.onSurface,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),

          const SizedBox(height: 6),

          Row(
            children: [
              if (subtitle != null)
                Expanded(
                  child: Text(
                    subtitle!,
                    style: context.styles.caption.copyWith(fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              if (trend != null) ...[
                if (subtitle != null) const SizedBox(width: 8),
                _TrendBadge(trend: trend!, label: trendLabel),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _TrendBadge extends StatelessWidget {
  const _TrendBadge({required this.trend, this.label});

  final double trend;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final isPositive = trend >= 0;
    final trendColor = isPositive
        ? AppColors.success
        : Theme.of(context).colorScheme.error;
    final displayLabel =
        label ?? '${isPositive ? '+' : ''}${trend.toStringAsFixed(1)}%';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: trendColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isPositive ? Icons.trending_up : Icons.trending_down,
            size: 14,
            color: trendColor,
          ),
          const SizedBox(width: 3),
          Text(
            displayLabel,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: trendColor,
            ),
          ),
        ],
      ),
    );
  }
}

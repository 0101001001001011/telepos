import 'package:flutter/material.dart';
import 'package:telepos/app/theme/app_colors.dart';
import 'package:telepos/app/theme/app_semantic_colors.dart';
import 'package:telepos/app/theme/app_theme.dart';

class ReportChartCard extends StatelessWidget {
  const ReportChartCard({
    required this.title,
    required this.child,
    this.subtitle,
    this.onExport,
    this.height = 250,
    super.key,
  });

  final String title;

  final Widget child;

  final String? subtitle;

  final VoidCallback? onExport;

  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
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
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 8, 0),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: AppTextStyles.h3.copyWith(fontSize: 16),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle!,
                          style: context.styles.caption.copyWith(fontSize: 12),
                        ),
                      ],
                    ],
                  ),
                ),
                if (onExport != null)
                  IconButton(
                    onPressed: onExport,
                    icon: const Icon(Icons.download_rounded, size: 20),
                    tooltip: 'Экспорт',
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          SizedBox(
            height: height,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 16, 12),
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}

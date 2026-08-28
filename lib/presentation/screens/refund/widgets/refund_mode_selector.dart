import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:telepos/app/theme/app_colors.dart';
import 'package:telepos/app/theme/app_semantic_colors.dart';
import 'package:telepos/app/theme/app_theme.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/presentation/controllers/refund/refund_controller.dart';

class RefundModeSelector extends ConsumerWidget {
  const RefundModeSelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(refundControllerProvider.select((s) => s.mode));
    final l10n = AppLocalizations.of(context)!;

    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingSmall),
      decoration: BoxDecoration(
        color: context.semantic.canvas,
        borderRadius: BorderRadius.circular(AppTheme.borderRadius),
      ),
      child: Row(
        children: [
          Expanded(
            child: _ModeButton(
              label: l10n.refundWithReceipt,
              icon: Icons.receipt_long,
              isSelected: mode == RefundMode.byReceipt,
              onTap: () {
                ref
                    .read(refundControllerProvider.notifier)
                    .setMode(RefundMode.byReceipt);
              },
            ),
          ),
          const SizedBox(width: AppTheme.spacingSmall),
          Expanded(
            child: _ModeButton(
              label: l10n.refundWithoutReceipt,
              icon: Icons.edit_note,
              isSelected: mode == RefundMode.withoutReceipt,
              onTap: () {
                ref
                    .read(refundControllerProvider.notifier)
                    .setMode(RefundMode.withoutReceipt);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ModeButton extends StatelessWidget {
  const _ModeButton({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isSelected
          ? AppColors.warning
          : Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(AppTheme.borderRadiusSmall),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.borderRadiusSmall),
        child: Container(
          padding: const EdgeInsets.symmetric(
            vertical: AppTheme.spacing,
            horizontal: AppTheme.spacingSmall,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 20,
                color: isSelected
                    ? AppColors.black
                    : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: AppTextStyles.button.copyWith(
                  color: isSelected
                      ? AppColors.black
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

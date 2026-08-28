import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:telepos/app/theme/app_colors.dart';
import 'package:telepos/app/theme/app_semantic_colors.dart';
import 'package:telepos/app/theme/app_theme.dart';
import 'package:telepos/app/theme/telepos_icons.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/presentation/controllers/refund/refund_controller.dart';

class RefundActionButtons extends ConsumerWidget {
  const RefundActionButtons({
    this.onLoadReceipt,
    this.onSearch,
    this.onQuantity,
    this.onRefund,
    super.key,
  });

  final VoidCallback? onLoadReceipt;
  final VoidCallback? onSearch;
  final VoidCallback? onQuantity;
  final VoidCallback? onRefund;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(refundControllerProvider);
    final hasSelection = state.selectedItem != null;
    final hasItems = state.hasItems;
    final canRefund = state.canRefund;
    final isByReceipt = state.mode == RefundMode.byReceipt;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (isByReceipt)
          _ActionButton(
            icon: Icons.receipt_long,
            label: l10n.refundLoadReceipt,
            color: AppColors.warning,
            onPressed: onLoadReceipt,
          )
        else
          _ActionButton(
            icon: Icons.search,
            label: l10n.refundSearchProducts,
            onPressed: onSearch,
          ),
        const SizedBox(height: AppTheme.spacingSmall),

        _ActionButton(
          icon: Icons.check_box,
          label: l10n.refundSelectAll,
          onPressed: hasItems
              ? () => ref.read(refundControllerProvider.notifier).selectAll()
              : null,
        ),
        const SizedBox(height: AppTheme.spacingSmall),

        _ActionButton(
          icon: Icons.check_box_outline_blank,
          label: l10n.refundDeselectAll,
          onPressed: hasItems
              ? () => ref.read(refundControllerProvider.notifier).deselectAll()
              : null,
        ),
        const SizedBox(height: AppTheme.spacingSmall),

        _ActionButton(
          icon: Icons.dialpad,
          label: l10n.globalQuantity,
          onPressed: hasSelection ? onQuantity : null,
        ),
        const SizedBox(height: AppTheme.spacingSmall),

        _ActionButton(
          icon: TeleposIcons.delete,
          label: l10n.globalDelete,
          color: Theme.of(context).colorScheme.error,
          onPressed: hasSelection
              ? () => ref
                    .read(refundControllerProvider.notifier)
                    .removeSelectedItem()
              : null,
        ),

        const Spacer(),

        _RefundButton(onPressed: canRefund ? onRefund : null),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    this.color,
    this.onPressed,
  });

  final IconData icon;
  final String label;
  final Color? color;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final isEnabled = onPressed != null;
    final effectiveColor = color ?? AppColors.warning;

    return Material(
      color: isEnabled
          ? effectiveColor.withValues(alpha: 0.1)
          : context.semantic.canvas,
      borderRadius: BorderRadius.circular(AppTheme.borderRadius),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(AppTheme.borderRadius),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.spacing,
            vertical: AppTheme.spacingSmall + 4,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 20,
                color: isEnabled
                    ? effectiveColor
                    : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: AppTextStyles.button.copyWith(
                  color: isEnabled
                      ? effectiveColor
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RefundButton extends StatelessWidget {
  const _RefundButton({this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isEnabled = onPressed != null;

    return Material(
      color: isEnabled ? AppColors.warning : context.semantic.canvas,
      borderRadius: BorderRadius.circular(AppTheme.borderRadius),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(AppTheme.borderRadius),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: AppTheme.spacing),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.assignment_return,
                size: 24,
                color: isEnabled
                    ? AppColors.black
                    : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 12),
              Text(
                l10n.refundAction,
                style: AppTextStyles.h3.copyWith(
                  color: isEnabled
                      ? AppColors.black
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

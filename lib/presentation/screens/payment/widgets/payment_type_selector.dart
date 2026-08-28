import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:telepos/app/theme/app_colors.dart';
import 'package:telepos/app/theme/app_semantic_colors.dart';
import 'package:telepos/app/theme/app_theme.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/presentation/controllers/payment/payment_controller.dart';

class PaymentTypeSelector extends ConsumerWidget {
  const PaymentTypeSelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final paymentType = ref.watch(
      paymentControllerProvider.select((s) => s.paymentType),
    );

    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingSmall),
      decoration: BoxDecoration(
        color: context.semantic.canvas,
        borderRadius: BorderRadius.circular(AppTheme.borderRadius),
      ),
      child: Row(
        children: [
          Expanded(
            child: _TypeButton(
              label: l10n.paymentTypeCash,
              icon: Icons.payments_outlined,
              isSelected: paymentType == PaymentType.cash,
              color: AppColors.paymentCash,
              onTap: () {
                ref
                    .read(paymentControllerProvider.notifier)
                    .setPaymentType(PaymentType.cash);
              },
            ),
          ),
          const SizedBox(width: AppTheme.spacingSmall),
          Expanded(
            child: _TypeButton(
              label: l10n.paymentTypeCard,
              icon: Icons.credit_card,
              isSelected: paymentType == PaymentType.card,
              color: AppColors.paymentCard,
              onTap: () {
                ref
                    .read(paymentControllerProvider.notifier)
                    .setPaymentType(PaymentType.card);
              },
            ),
          ),
          const SizedBox(width: AppTheme.spacingSmall),
          Expanded(
            child: _TypeButton(
              label: l10n.paymentTypeMixed,
              icon: Icons.sync_alt,
              isSelected: paymentType == PaymentType.mixed,
              color: AppColors.paymentMixed,
              onTap: () {
                ref
                    .read(paymentControllerProvider.notifier)
                    .setPaymentType(PaymentType.mixed);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _TypeButton extends StatelessWidget {
  const _TypeButton({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.color,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool isSelected;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isSelected ? color : Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(AppTheme.borderRadiusSmall),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.borderRadiusSmall),
        child: Container(
          padding: const EdgeInsets.symmetric(
            vertical: AppTheme.spacing,
            horizontal: AppTheme.spacingSmall,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 24,
                color: isSelected
                    ? AppColors.white
                    : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: AppTextStyles.button.copyWith(
                  color: isSelected
                      ? AppColors.white
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  fontSize: 12,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

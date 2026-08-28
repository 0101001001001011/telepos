import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:telepos/app/theme/app_colors.dart';
import 'package:telepos/app/theme/app_theme.dart';
import 'package:telepos/app/theme/telepos_icons.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/presentation/controllers/payment/payment_controller.dart';

class DenominationGrid extends ConsumerWidget {
  const DenominationGrid({this.crossAxisCount = 4, super.key});

  final int crossAxisCount;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final denominationsAsync = ref.watch(denominationsProvider);
    final state = ref.watch(paymentControllerProvider);

    if (state.paymentType == PaymentType.card) {
      return const SizedBox.shrink();
    }

    final denominations = denominationsAsync.value ?? [];
    if (denominations.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(AppTheme.spacing),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.borderRadius),
        border: Border.all(color: Theme.of(context).colorScheme.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.payments_outlined,
                size: 20,
                color: AppColors.paymentCash,
              ),
              const SizedBox(width: 8),
              Text(l10n.paymentDenominations, style: AppTextStyles.h3),
              const Spacer(),
              TextButton.icon(
                onPressed: () {
                  ref.read(paymentControllerProvider.notifier).setExactAmount();
                },
                icon: const Icon(TeleposIcons.checkCircle, size: 18),
                label: Text(l10n.paymentExactAmount),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.success,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacing),

          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              crossAxisSpacing: AppTheme.spacingSmall,
              mainAxisSpacing: AppTheme.spacingSmall,
              childAspectRatio: 1.5,
            ),
            itemCount: denominations.length,
            itemBuilder: (context, index) {
              final denomination = denominations[index];
              return _DenominationButton(
                amount: denomination,
                onTap: () {
                  ref
                      .read(paymentControllerProvider.notifier)
                      .addCash(denomination);
                },
              );
            },
          ),
        ],
      ),
    );
  }
}

class _DenominationButton extends StatelessWidget {
  const _DenominationButton({required this.amount, required this.onTap});

  final Decimal amount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.paymentCash.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(AppTheme.borderRadius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.borderRadius),
        child: Container(
          alignment: Alignment.center,
          child: Text(
            _formatAmount(amount),
            style: AppTextStyles.h3.copyWith(color: AppColors.paymentCash),
          ),
        ),
      ),
    );
  }

  String _formatAmount(Decimal amount) {
    final value = amount.toDouble();
    if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(0)}K';
    }
    return amount.toString();
  }
}

class DenominationRow extends ConsumerWidget {
  const DenominationRow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final denominationsAsync = ref.watch(denominationsProvider);
    final state = ref.watch(paymentControllerProvider);

    if (state.paymentType == PaymentType.card) {
      return const SizedBox.shrink();
    }

    final denominations = denominationsAsync.value ?? [];
    if (denominations.isEmpty) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacing),
        itemCount: denominations.length + 1,
        separatorBuilder: (_, __) =>
            const SizedBox(width: AppTheme.spacingSmall),
        itemBuilder: (context, index) {
          if (index == 0) {
            return ActionChip(
              avatar: const Icon(
                TeleposIcons.checkCircle,
                size: 18,
                color: AppColors.success,
              ),
              label: Text(l10n.paymentExactAmount),
              onPressed: () {
                ref.read(paymentControllerProvider.notifier).setExactAmount();
              },
              backgroundColor: AppColors.success.withValues(alpha: 0.1),
              side: BorderSide.none,
            );
          }

          final denomination = denominations[index - 1];
          return ActionChip(
            label: Text(_formatAmount(denomination)),
            onPressed: () {
              ref
                  .read(paymentControllerProvider.notifier)
                  .addCash(denomination);
            },
            backgroundColor: AppColors.paymentCash.withValues(alpha: 0.1),
            labelStyle: TextStyle(
              color: AppColors.paymentCash,
              fontWeight: FontWeight.w600,
            ),
            side: BorderSide.none,
          );
        },
      ),
    );
  }

  String _formatAmount(Decimal amount) {
    final value = amount.toDouble();
    if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(0)}K';
    }
    return amount.toString();
  }
}

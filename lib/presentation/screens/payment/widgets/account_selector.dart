import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:telepos/app/theme/app_colors.dart';
import 'package:telepos/app/theme/app_theme.dart';
import 'package:telepos/app/theme/telepos_icons.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/presentation/controllers/payment/payment_controller.dart';

class AccountSelector extends ConsumerWidget {
  const AccountSelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accountsAsync = ref.watch(paymentAccountsProvider);
    final selectedId = ref.watch(
      paymentControllerProvider.select((s) => s.selectedAccountId),
    );
    final paymentType = ref.watch(
      paymentControllerProvider.select((s) => s.paymentType),
    );

    if (paymentType == PaymentType.cash) {
      return const SizedBox.shrink();
    }

    return accountsAsync.when(
      loading: () => Container(
        padding: const EdgeInsets.all(AppTheme.spacing),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(AppTheme.borderRadius),
          border: Border.all(color: Theme.of(context).colorScheme.outline),
        ),
        child: const Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => const SizedBox.shrink(),
      data: (accounts) => _buildContent(
        context,
        ref,
        accounts,
        selectedId,
        AppLocalizations.of(context)!,
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    WidgetRef ref,
    List<PaymentAccount> accounts,
    int? selectedId,
    AppLocalizations l10n,
  ) {
    if (accounts.isEmpty) {
      return const SizedBox.shrink();
    }

    final effectiveSelectedId =
        selectedId ??
        accounts
            .firstWhere((a) => a.isDefault, orElse: () => accounts.first)
            .id;

    if (selectedId == null) {
      Future.microtask(() {
        ref
            .read(paymentControllerProvider.notifier)
            .selectAccount(effectiveSelectedId);
      });
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
                Icons.account_balance,
                size: 20,
                color: AppColors.paymentCard,
              ),
              const SizedBox(width: 8),
              Text(l10n.paymentAccount, style: AppTextStyles.h3),
            ],
          ),
          const SizedBox(height: AppTheme.spacing),

          if (accounts.length <= 3)
            Wrap(
              spacing: AppTheme.spacingSmall,
              runSpacing: AppTheme.spacingSmall,
              children: accounts.map((account) {
                final isSelected = account.id == effectiveSelectedId;
                return ChoiceChip(
                  label: Text(account.name),
                  selected: isSelected,
                  onSelected: (_) {
                    ref
                        .read(paymentControllerProvider.notifier)
                        .selectAccount(account.id);
                  },
                  selectedColor: AppColors.paymentCard,
                  labelStyle: TextStyle(
                    color: isSelected
                        ? AppColors.white
                        : Theme.of(context).colorScheme.onSurface,
                  ),
                  avatar: isSelected
                      ? const Icon(
                          TeleposIcons.check,
                          size: 18,
                          color: AppColors.white,
                        )
                      : null,
                );
              }).toList(),
            )
          else
            DropdownButtonFormField<int>(
              value: effectiveSelectedId,
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.borderRadius),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.spacing,
                  vertical: AppTheme.spacingSmall,
                ),
              ),
              items: accounts.map((account) {
                return DropdownMenuItem(
                  value: account.id,
                  child: Row(
                    children: [
                      Text(account.name),
                      if (account.isDefault) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            l10n.paymentDefaultLabel,
                            style: context.styles.caption.copyWith(
                              color: AppColors.primary,
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  ref
                      .read(paymentControllerProvider.notifier)
                      .selectAccount(value);
                }
              },
            ),
        ],
      ),
    );
  }
}

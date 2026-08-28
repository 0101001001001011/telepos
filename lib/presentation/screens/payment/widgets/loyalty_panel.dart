import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:telepos/app/theme/app_colors.dart';
import 'package:telepos/app/theme/app_theme.dart';
import 'package:telepos/app/theme/telepos_icons.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/presentation/controllers/payment/payment_controller.dart';

class LoyaltyPanel extends ConsumerStatefulWidget {
  const LoyaltyPanel({super.key});

  @override
  ConsumerState<LoyaltyPanel> createState() => _LoyaltyPanelState();
}

class _LoyaltyPanelState extends ConsumerState<LoyaltyPanel> {
  final _phoneController = TextEditingController();
  final _bonusController = TextEditingController();

  @override
  void dispose() {
    _phoneController.dispose();
    _bonusController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(paymentControllerProvider);

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
                Icons.card_giftcard,
                size: 20,
                color: AppColors.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l10n.paymentLoyaltyProgram,
                  style: AppTextStyles.h3,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (state.hasLoyaltyCustomer)
                IconButton(
                  onPressed: () {
                    ref
                        .read(paymentControllerProvider.notifier)
                        .clearLoyaltyCustomer();
                    _phoneController.clear();
                    _bonusController.clear();
                  },
                  icon: const Icon(TeleposIcons.close),
                  iconSize: 20,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppTheme.spacing),

          TextField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(11),
            ],
            decoration: InputDecoration(
              labelText: l10n.paymentPhoneNumber,
              hintText: '7XXXXXXXXXX',
              prefixIcon: const Icon(Icons.phone),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.borderRadius),
              ),
              suffixIcon: state.hasLoyaltyCustomer
                  ? const Icon(
                      TeleposIcons.checkCircle,
                      color: AppColors.success,
                    )
                  : null,
            ),
            onChanged: (value) {
              ref
                  .read(paymentControllerProvider.notifier)
                  .searchLoyaltyCustomer(value);
            },
          ),

          if (state.hasLoyaltyCustomer) ...[
            const SizedBox(height: AppTheme.spacing),

            Container(
              padding: const EdgeInsets.all(AppTheme.spacing),
              decoration: BoxDecoration(
                color: selectedSurfaceOf(context),
                borderRadius: BorderRadius.circular(AppTheme.borderRadius),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        TeleposIcons.person,
                        size: 20,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          state.loyaltyCustomer!.name,
                          style: AppTextStyles.productName.copyWith(
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        l10n.paymentAvailableBonus,
                        style: AppTextStyles.body,
                      ),
                      Text(
                        '${state.availableBonus}',
                        style: AppTextStyles.h3.copyWith(
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppTheme.spacing),

            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _bonusController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: l10n.paymentUseBonuses,
                      hintText: '0',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(
                          AppTheme.borderRadius,
                        ),
                      ),
                    ),
                    onChanged: (value) {
                      final amount = Decimal.tryParse(value) ?? Decimal.zero;
                      ref
                          .read(paymentControllerProvider.notifier)
                          .setBonusToUse(amount);
                    },
                  ),
                ),
                const SizedBox(width: AppTheme.spacingSmall),
                ElevatedButton(
                  onPressed: state.availableBonus > Decimal.zero
                      ? () {
                          ref
                              .read(paymentControllerProvider.notifier)
                              .useAllBonus();
                          _bonusController.text = state.availableBonus
                              .toString();
                        }
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.spacing,
                      vertical: AppTheme.spacing,
                    ),
                  ),
                  child: Text(l10n.globalAll),
                ),
              ],
            ),

            if (state.bonusToUse > Decimal.zero) ...[
              const SizedBox(height: AppTheme.spacingSmall),
              Text(
                l10n.paymentBonusToDeduct('${state.bonusToUse}'),
                style: AppTextStyles.body.copyWith(
                  color: AppColors.success,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class LoyaltyPanelCompact extends ConsumerStatefulWidget {
  const LoyaltyPanelCompact({super.key});

  @override
  ConsumerState<LoyaltyPanelCompact> createState() =>
      _LoyaltyPanelCompactState();
}

class _LoyaltyPanelCompactState extends ConsumerState<LoyaltyPanelCompact> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(paymentControllerProvider);

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.borderRadius),
        border: Border.all(color: Theme.of(context).colorScheme.outline),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () {
              setState(() {
                _isExpanded = !_isExpanded;
              });
            },
            borderRadius: BorderRadius.circular(AppTheme.borderRadius),
            child: Padding(
              padding: const EdgeInsets.all(AppTheme.spacing),
              child: Row(
                children: [
                  const Icon(
                    Icons.card_giftcard,
                    size: 20,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      state.hasLoyaltyCustomer
                          ? state.loyaltyCustomer!.name
                          : AppLocalizations.of(context)!.paymentLoyaltyProgram,
                      style: AppTextStyles.body.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (state.bonusToUse > Decimal.zero)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.success.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '-${state.bonusToUse}',
                        style: context.styles.caption.copyWith(
                          color: AppColors.success,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  const SizedBox(width: 8),
                  Icon(
                    _isExpanded ? Icons.expand_less : Icons.expand_more,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),

          if (_isExpanded) ...[
            const Divider(height: 1),
            const Padding(
              padding: EdgeInsets.all(AppTheme.spacing),
              child: LoyaltyPanel(),
            ),
          ],
        ],
      ),
    );
  }
}

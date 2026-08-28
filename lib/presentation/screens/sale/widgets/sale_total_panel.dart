import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:telepos/app/theme/app_colors.dart';
import 'package:telepos/app/theme/app_semantic_colors.dart';
import 'package:telepos/app/theme/app_theme.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/presentation/controllers/sale/sale_controller.dart';

class SaleTotalPanel extends ConsumerWidget {
  const SaleTotalPanel({this.onPay, this.compact = false, super.key});

  final VoidCallback? onPay;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(saleControllerProvider);

    if (compact) {
      return _CompactTotalPanel(state: state, onPay: onPay);
    }

    return _FullTotalPanel(state: state, onPay: onPay);
  }
}

class _FullTotalPanel extends StatelessWidget {
  const _FullTotalPanel({required this.state, this.onPay});

  final SaleState state;
  final VoidCallback? onPay;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

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
                Icons.receipt_long,
                size: 20,
                color: AppColors.primary,
              ),
              const SizedBox(width: 8),
              Text(l10n.saleReceiptTotal, style: AppTextStyles.h3),
              const Spacer(),
              _ModeChip(mode: state.mode),
            ],
          ),
          const SizedBox(height: AppTheme.spacing),
          const Divider(height: 1),
          const SizedBox(height: AppTheme.spacing),

          _TotalRow(label: l10n.salePositions, value: '${state.itemCount}'),
          const SizedBox(height: AppTheme.spacingSmall),

          _TotalRow(
            label: l10n.globalQuantity,
            value: '${state.totalQuantity}',
          ),
          const SizedBox(height: AppTheme.spacingSmall),

          _TotalRow(label: l10n.globalAmount, value: '${state.subtotal}'),

          if (state.totalDiscount > Decimal.zero) ...[
            const SizedBox(height: AppTheme.spacingSmall),
            _TotalRow(
              label: l10n.globalDiscount,
              value: '-${state.totalDiscount}',
              valueColor: Theme.of(context).colorScheme.error,
            ),
          ],

          const SizedBox(height: AppTheme.spacing),
          const Divider(height: 1),
          const SizedBox(height: AppTheme.spacing),

          _TotalRow(
            label: l10n.saleToPay,
            value: '${state.total}',
            isTotal: true,
          ),

          if (state.agentName != null) ...[
            const SizedBox(height: AppTheme.spacing),
            _AgentInfo(name: state.agentName!),
          ],
        ],
      ),
    );
  }
}

class _CompactTotalPanel extends StatelessWidget {
  const _CompactTotalPanel({required this.state, this.onPay});

  final SaleState state;
  final VoidCallback? onPay;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isEnabled = state.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(AppTheme.spacing),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      // `Flexible` с многоточием: подпись «Итого:» на узком
                      // экране не влезала рядом с плашкой режима — измерено
                      // 2.2 точки переполнения. Дефект прятался тем, что тест
                      // экрана поднимал `MaterialApp` БЕЗ темы приложения:
                      // умолчание Material берёт другой шрифт, и подпись в
                      // нём чуть уже. Плашка режима не жмётся — она короткая
                      // и её сокращение ничего не даст; жмётся подпись.
                      Flexible(
                        child: Text(
                          l10n.saleTotalColon,
                          style: AppTextStyles.body,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      _ModeChip(mode: state.mode, small: true),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${state.total}',
                    style: AppTextStyles.h2.copyWith(color: AppColors.primary),
                  ),
                  if (state.itemCount > 0)
                    Text(
                      l10n.salePositionsAndQuantity(
                        state.itemCount,
                        '${state.totalQuantity}',
                      ),
                      style: context.styles.caption,
                    ),
                ],
              ),
            ),

            SizedBox(
              height: 56,
              child: ElevatedButton.icon(
                onPressed: isEnabled ? onPay : null,
                icon: const Icon(Icons.payment),
                label: Text(l10n.salePay),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
                  foregroundColor: AppColors.white,
                  disabledBackgroundColor: context.semantic.canvas,
                  disabledForegroundColor: Theme.of(
                    context,
                  ).colorScheme.onSurfaceVariant,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.borderRadius),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TotalRow extends StatelessWidget {
  const _TotalRow({
    required this.label,
    required this.value,
    this.valueColor,
    this.isTotal = false,
  });

  final String label;
  final String value;
  final Color? valueColor;
  final bool isTotal;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: isTotal
              ? AppTextStyles.h3
              : AppTextStyles.body.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
        ),
        Text(
          value,
          style: isTotal
              ? AppTextStyles.h2.copyWith(color: AppColors.primary)
              : AppTextStyles.body.copyWith(
                  fontWeight: FontWeight.w600,
                  color: valueColor,
                ),
        ),
      ],
    );
  }
}

class _ModeChip extends StatelessWidget {
  const _ModeChip({required this.mode, this.small = false});

  final SaleMode mode;
  final bool small;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isWholesale = mode == SaleMode.wholesale;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: small ? 6 : 8,
        vertical: small ? 2 : 4,
      ),
      decoration: BoxDecoration(
        color: isWholesale
            ? AppColors.warning.withValues(alpha: 0.1)
            : AppColors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(small ? 4 : 6),
      ),
      child: Text(
        isWholesale ? l10n.saleWholesale : l10n.saleRetail,
        style: (small ? context.styles.caption : AppTextStyles.body).copyWith(
          color: isWholesale ? AppColors.warning : AppColors.primary,
          fontWeight: FontWeight.w600,
          fontSize: small ? 10 : null,
        ),
      ),
    );
  }
}

class _AgentInfo extends StatelessWidget {
  const _AgentInfo({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingSmall),
      decoration: BoxDecoration(
        color: selectedSurfaceOf(context),
        borderRadius: BorderRadius.circular(AppTheme.borderRadius),
      ),
      child: Row(
        children: [
          const Icon(Icons.person_outline, size: 16, color: AppColors.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              name,
              style: AppTextStyles.body.copyWith(color: AppColors.primary),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:telepos/app/theme/app_colors.dart';
import 'package:telepos/app/theme/app_semantic_colors.dart';
import 'package:telepos/app/theme/app_theme.dart';
import 'package:telepos/app/theme/telepos_icons.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/presentation/controllers/shift/shift_controller.dart';
import 'package:telepos/core/locale/till_conventions.dart';

class ShiftInfoPanel extends StatelessWidget {
  const ShiftInfoPanel({super.key, required this.state});

  final ShiftState state;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.surface,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStatusSection(context),
            const SizedBox(height: 24),

            if (state.isOpen) ...[
              _buildCashierSection(context),
              const SizedBox(height: 24),
            ],

            if (state.isOpen) ...[
              _buildTotalsSection(context),
              const SizedBox(height: 24),
            ],

            if (state.isOpen && state.enteredTotal > Decimal.zero)
              _buildDifferenceSection(context),

            if (state.isOpen && state.hasUnfinishedSales) ...[
              const SizedBox(height: 24),
              _buildBlockersSection(context),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusSection(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Row(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: state.isOpen
                ? AppColors.success.withValues(alpha: 0.1)
                : context.semantic.canvas,
            borderRadius: BorderRadius.circular(28),
          ),
          child: Icon(
            state.isOpen ? Icons.lock_open : Icons.lock,
            color: state.isOpen
                ? AppColors.success
                : Theme.of(context).colorScheme.onSurfaceVariant,
            size: 28,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                state.isOpen ? l10n.shiftOpened : l10n.shiftClosed,
                style: AppTextStyles.h3,
              ),
              if (state.isOpen && state.openTime != null)
                Text(
                  l10n.shiftOpenedAt(_formatDateTime(state.openTime!)),
                  style: AppTextStyles.body.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCashierSection(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.shiftCashierLabel,
          style: AppTextStyles.body.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Icon(
              Icons.person_outline,
              size: 20,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 8),
            Text(
              state.cashierName ?? l10n.shiftUnknown,
              style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTotalsSection(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.success.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.success.withValues(alpha: 0.2)),
          ),
          child: Column(
            children: [
              _buildTotalRow(
                context,
                l10n.shiftSalesLabel,
                Decimal.fromInt(state.salesCount),
                isCount: true,
              ),
              const SizedBox(height: 8),
              _buildTotalRow(
                context,
                l10n.shiftSalesTotal,
                state.salesTotal,
                bold: true,
              ),
              if (state.cashSalesTotal > Decimal.zero ||
                  state.cardSalesTotal > Decimal.zero) ...[
                const SizedBox(height: 4),
                _buildTotalRow(
                  context,
                  '  ${l10n.shiftCashSales}',
                  state.cashSalesTotal,
                  small: true,
                ),
                _buildTotalRow(
                  context,
                  '  ${l10n.shiftCardSales}',
                  state.cardSalesTotal,
                  small: true,
                ),
              ],
              if (state.refundsCount > 0) ...[
                const Divider(height: 16),
                _buildTotalRow(
                  context,
                  l10n.shiftRefundsTotal,
                  state.refundsTotal,
                  color: Theme.of(context).colorScheme.error,
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),

        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: context.semantic.canvas,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              // `expectedCash`, а не `systemTotal`. Подпись говорит
              // «должно быть», и стоять под ней обязано то самое число, с
              // которым сличают пересчёт. Прежде стоял остаток счёта
              // кассы, не видевший подъёмных: кассир клал в ящик 200 $, а
              // панель показывала 0.00.
              _buildTotalRow(
                context,
                l10n.shiftSystemTotal,
                state.expectedCash,
                bold: true,
              ),
              const SizedBox(height: 12),
              _buildTotalRow(
                context,
                l10n.shiftEnteredTotal,
                state.enteredTotal,
              ),
              if (state.cashOperations.isNotEmpty) ...[
                const Divider(height: 24),
                _buildTotalRow(
                  context,
                  l10n.shiftCashOperations,
                  state.investmentTotal -
                      state.expenseTotal -
                      state.dividendTotal,
                  subtitle:
                      '+${state.investmentTotal.toStringAsFixed(0)} / -${state.expenseTotal.toStringAsFixed(0)} / -${state.dividendTotal.toStringAsFixed(0)}',
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  // Контекст здесь не для удобства: приглушённый цвет мелкой строки — роль
  // темы, и взять его можно только из `Theme.of`.
  Widget _buildTotalRow(
    BuildContext context,
    String label,
    Decimal value, {
    String? subtitle,
    bool bold = false,
    bool small = false,
    bool isCount = false,
    Color? color,
  }) {
    final textStyle = small
        ? context.styles.caption.copyWith(
            color: color ?? Theme.of(context).colorScheme.onSurfaceVariant,
          )
        : AppTextStyles.body.copyWith(color: color);
    final valueStyle = small
        ? context.styles.caption.copyWith(
            fontWeight: FontWeight.w500,
            color: color ?? Theme.of(context).colorScheme.onSurfaceVariant,
          )
        : AppTextStyles.body.copyWith(
            fontWeight: bold ? FontWeight.bold : FontWeight.w600,
            color: color,
            fontSize: bold ? 16 : null,
          );

    return Padding(
      padding: EdgeInsets.symmetric(vertical: small ? 1 : 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: textStyle),
                if (subtitle != null)
                  Text(
                    subtitle,
                    style: AppTextStyles.body.copyWith(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            isCount ? value.toStringAsFixed(0) : value.toStringAsFixed(2),
            style: valueStyle,
          ),
        ],
      ),
    );
  }

  Widget _buildDifferenceSection(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final diff = state.difference;
    final isPositive = diff > Decimal.zero;
    final isNegative = diff < Decimal.zero;

    final color = isNegative
        ? Theme.of(context).colorScheme.error
        : isPositive
        ? AppColors.success
        : Theme.of(context).colorScheme.onSurface;

    final bgColor = isNegative
        ? Theme.of(context).colorScheme.error.withValues(alpha: 0.1)
        : isPositive
        ? AppColors.success.withValues(alpha: 0.1)
        : context.semantic.canvas;

    final icon = isNegative
        ? Icons.trending_down
        : isPositive
        ? Icons.trending_up
        : Icons.trending_flat;

    final message = isNegative
        ? l10n.shiftShortage
        : isPositive
        ? l10n.shiftSurplus
        : l10n.shiftBalances;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.shiftDifference,
                  style: AppTextStyles.body.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                Text(message, style: AppTextStyles.body.copyWith(color: color)),
              ],
            ),
          ),
          Text(
            '${isPositive ? '+' : ''}${diff.toStringAsFixed(2)}',
            style: AppTextStyles.h2.copyWith(color: color),
          ),
        ],
      ),
    );
  }

  Widget _buildBlockersSection(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(TeleposIcons.info, color: AppColors.warning),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l10n.shiftCloseBlocked,
                  style: AppTextStyles.body.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.warning,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (state.activeSalesCount > 0)
            _buildBlockerItem(
              context,
              l10n.shiftActiveSalesCount(state.activeSalesCount),
              Icons.shopping_cart_outlined,
            ),
          if (state.pendingSalesCount > 0)
            _buildBlockerItem(
              context,
              l10n.shiftPendingSalesCount(state.pendingSalesCount),
              Icons.pause_circle_outline,
            ),
        ],
      ),
    );
  }

  Widget _buildBlockerItem(BuildContext context, String text, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(
            icon,
            size: 16,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 8),
          Text(text, style: AppTextStyles.body),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime time) {
    return TillConventions.current.formatDateTime(time);
  }
}

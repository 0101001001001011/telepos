import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:telepos/l10n/app_localizations.dart';

class ServiceCostSummary extends StatelessWidget {
  const ServiceCostSummary({
    required this.totalCost,
    required this.prepaid,
    required this.remaining,
    super.key,
  });

  final Decimal totalCost;
  final Decimal prepaid;
  final Decimal remaining;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.serviceDetailCost,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            _CostRow(
              label: l10n.serviceTotalCost,
              amount: totalCost,
              currency: l10n.currencySymbol,
            ),
            _CostRow(
              label: l10n.servicePrepaid,
              amount: prepaid,
              currency: l10n.currencySymbol,
              color: Colors.green,
            ),
            const Divider(height: 16),
            _CostRow(
              label: l10n.serviceRemaining,
              amount: remaining,
              currency: l10n.currencySymbol,
              isBold: true,
              color: remaining > Decimal.zero ? theme.colorScheme.error : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _CostRow extends StatelessWidget {
  const _CostRow({
    required this.label,
    required this.amount,
    required this.currency,
    this.isBold = false,
    this.color,
  });

  final String label;
  final Decimal amount;
  final String currency;
  final bool isBold;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = isBold
        ? theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: color,
          )
        : theme.textTheme.bodyMedium?.copyWith(color: color);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: style),
          Text('$amount $currency', style: style),
        ],
      ),
    );
  }
}

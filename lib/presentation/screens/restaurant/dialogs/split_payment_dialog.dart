import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';

import 'package:telepos/app/theme/app_colors.dart';
import 'package:telepos/l10n/app_localizations.dart';

class SplitPaymentDialog extends StatefulWidget {
  const SplitPaymentDialog({
    super.key,
    required this.guests,
    required this.amountForGuest,
    required this.total,
  });

  final List<int> guests;

  final Decimal Function(int guest) amountForGuest;

  final Decimal total;

  static ({Decimal cash, Decimal card}) aggregate(
    List<int> guests,
    Decimal Function(int) amountForGuest,
    Map<int, bool> methods,
    Decimal total,
  ) {
    Decimal cash = Decimal.zero;
    for (final g in guests) {
      if (methods[g] != true) cash += amountForGuest(g);
    }
    if (cash > total) cash = total;
    if (cash < Decimal.zero) cash = Decimal.zero;
    return (cash: cash, card: total - cash);
  }

  static Future<Map<int, bool>?> show(
    BuildContext context, {
    required List<int> guests,
    required Decimal Function(int) amountForGuest,
    required Decimal total,
  }) {
    return showDialog<Map<int, bool>>(
      context: context,
      builder: (_) => SplitPaymentDialog(
        guests: guests,
        amountForGuest: amountForGuest,
        total: total,
      ),
    );
  }

  @override
  State<SplitPaymentDialog> createState() => _SplitPaymentDialogState();
}

class _SplitPaymentDialogState extends State<SplitPaymentDialog> {
  late final Map<int, bool> _isCard = {for (final g in widget.guests) g: false};

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(l10n.restaurantSplitPaymentTitle),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final g in widget.guests)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${l10n.restaurantSplitGuest(g)}: '
                        '${widget.amountForGuest(g)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    ToggleButtons(
                      key: Key('split.guest.$g.method'),
                      isSelected: [!_isCard[g]!, _isCard[g]!],
                      onPressed: (i) => setState(() => _isCard[g] = i == 1),
                      borderRadius: BorderRadius.circular(8),
                      constraints: const BoxConstraints(
                        minHeight: 36,
                        minWidth: 88,
                      ),
                      children: [
                        Text(l10n.paymentCash),
                        Text(l10n.paymentCard),
                      ],
                    ),
                  ],
                ),
              ),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  l10n.restaurantSplitPaymentProceed,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(
                  '${widget.total}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.globalCancel),
        ),
        FilledButton(
          key: const Key('split.payment.proceed'),
          onPressed: () => Navigator.of(context).pop(_isCard),
          child: Text(l10n.restaurantSplitPaymentProceed),
        ),
      ],
    );
  }
}

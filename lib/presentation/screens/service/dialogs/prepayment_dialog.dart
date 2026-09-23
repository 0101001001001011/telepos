import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/presentation/common/utils/till_money.dart';

class PrepaymentDialog extends StatefulWidget {
  const PrepaymentDialog({this.currentAmount, super.key});

  final Decimal? currentAmount;

  static Future<Decimal?> show(BuildContext context, {Decimal? currentAmount}) {
    return showDialog<Decimal>(
      context: context,
      builder: (_) => PrepaymentDialog(currentAmount: currentAmount),
    );
  }

  @override
  State<PrepaymentDialog> createState() => _PrepaymentDialogState();
}

class _PrepaymentDialogState extends State<PrepaymentDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.currentAmount?.toString() ?? '',
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return AlertDialog(
      title: Text(l10n.servicePrepayment),
      content: SizedBox(
        width: 280,
        child: TextField(
          controller: _controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
          ],
          decoration: InputDecoration(
            labelText: l10n.servicePrepaymentAmount,
            suffixText: tillCurrencySymbol(),
            border: const OutlineInputBorder(),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.serviceIntakeCancel),
        ),
        FilledButton(
          onPressed: () {
            final text = _controller.text.trim();
            if (text.isEmpty) {
              Navigator.of(context).pop();
              return;
            }
            final amount = Decimal.tryParse(text);
            if (amount != null && amount > Decimal.zero) {
              Navigator.of(context).pop(amount);
            }
          },
          child: Text(l10n.serviceIntakeSave),
        ),
      ],
    );
  }
}

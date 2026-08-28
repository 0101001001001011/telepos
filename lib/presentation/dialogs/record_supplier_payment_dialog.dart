import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:telepos/app/theme/app_colors.dart';
import 'package:telepos/app/theme/app_theme.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/presentation/controllers/agent/supplier_payment_controller.dart';

class RecordSupplierPaymentDialog extends ConsumerStatefulWidget {
  const RecordSupplierPaymentDialog({
    super.key,
    required this.supplierId,
    required this.supplierName,
    required this.currentBalance,
  });

  final int supplierId;
  final String supplierName;

  final Decimal currentBalance;

  @override
  ConsumerState<RecordSupplierPaymentDialog> createState() =>
      _RecordSupplierPaymentDialogState();
}

class _RecordSupplierPaymentDialogState
    extends ConsumerState<RecordSupplierPaymentDialog> {
  final _controller = TextEditingController();
  String? _error;
  bool _submitting = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Decimal? _parseAmount() {
    final raw = _controller.text.trim().replaceAll(',', '.');
    if (raw.isEmpty) return null;
    return Decimal.tryParse(raw);
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context)!;
    final amount = _parseAmount();
    if (amount == null || amount <= Decimal.zero) {
      setState(() => _error = l10n.supplierRepayAmountError);
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    final outcome = await ref
        .read(supplierPaymentControllerProvider.notifier)
        .repay(agentId: widget.supplierId, amount: amount);

    if (!mounted) return;

    if (outcome.success) {
      Navigator.of(context).pop(outcome);
    } else {
      setState(() {
        _submitting = false;
        _error = outcome.errorMessage ?? l10n.supplierRepayError;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final hasDebt = widget.currentBalance > Decimal.zero;
    final debtText = widget.currentBalance.abs().toStringAsFixed(2);

    return AlertDialog(
      title: Text(l10n.supplierRepayTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.supplierName,
            style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            hasDebt
                ? l10n.supplierRepayCurrentDebt(debtText)
                : l10n.supplierRepayNoDebt,
            style: AppTextStyles.body.copyWith(
              fontSize: 13,
              color: hasDebt
                  ? Theme.of(context).colorScheme.error
                  : Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            autofocus: true,
            enabled: !_submitting,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
            ],
            decoration: InputDecoration(
              labelText: l10n.supplierRepayAmountLabel,
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.payments),
            ),
            onSubmitted: (_) => _submit(),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              style: AppTextStyles.body.copyWith(
                color: Theme.of(context).colorScheme.error,
                fontSize: 13,
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.of(context).pop(),
          child: Text(l10n.globalCancel),
        ),
        ElevatedButton(
          onPressed: _submitting ? null : _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: AppColors.white,
          ),
          child: _submitting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.white,
                  ),
                )
              : Text(l10n.supplierRepaySubmit),
        ),
      ],
    );
  }
}

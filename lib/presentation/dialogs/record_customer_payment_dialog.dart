import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:telepos/app/theme/app_colors.dart';
import 'package:telepos/app/theme/app_theme.dart';
import 'package:telepos/presentation/controllers/agent/customer_payment_controller.dart';

class RecordCustomerPaymentDialog extends ConsumerStatefulWidget {
  const RecordCustomerPaymentDialog({
    super.key,
    required this.agentId,
    required this.agentName,
    required this.currentBalance,
  });

  final int agentId;
  final String agentName;

  final Decimal currentBalance;

  @override
  ConsumerState<RecordCustomerPaymentDialog> createState() =>
      _RecordCustomerPaymentDialogState();
}

class _RecordCustomerPaymentDialogState
    extends ConsumerState<RecordCustomerPaymentDialog> {
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
    final amount = _parseAmount();
    if (amount == null || amount <= Decimal.zero) {
      setState(() => _error = 'Введите сумму больше 0');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    final outcome = await ref
        .read(customerPaymentControllerProvider.notifier)
        .record(
          agentId: widget.agentId,
          amount: amount,
          note: 'Погашение долга / оплата (${widget.agentName})',
        );

    if (!mounted) return;

    if (outcome.success) {
      Navigator.of(context).pop(outcome);
    } else {
      setState(() {
        _submitting = false;
        _error = outcome.errorMessage ?? 'Ошибка проведения оплаты';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasDebt = widget.currentBalance < Decimal.zero;
    final debtText = hasDebt
        ? (-widget.currentBalance).toStringAsFixed(2)
        : widget.currentBalance.toStringAsFixed(2);

    return AlertDialog(
      title: const Text('Принять оплату / погасить долг'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.agentName,
            style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            hasDebt ? 'Текущий долг: $debtText' : 'Баланс: $debtText',
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
            decoration: const InputDecoration(
              labelText: 'Сумма оплаты',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.payments),
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
          child: const Text('Отмена'),
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
              : const Text('Принять оплату'),
        ),
      ],
    );
  }
}

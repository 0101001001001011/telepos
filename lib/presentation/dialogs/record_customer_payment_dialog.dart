import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:telepos/app/theme/app_colors.dart';
import 'package:telepos/app/theme/app_theme.dart';
import 'package:telepos/core/logging/app_talker.dart';
import 'package:telepos/domain/payment/payment_kind.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/presentation/controllers/agent/customer_payment_controller.dart';

/// Приём оплаты / погашение долга покупателя.
///
/// Слова — из словаря (2026-09-15, обход группы F; проба
/// `test/presentation/dialogs/payment_dialogs_text_test.dart`). Причина
/// отказа кассы (`CustomerPaymentOutcome.errorMessage`) пишется юзкейсом
/// по-русски — на экран она не едет, едет фраза словаря, а причина уходит в
/// журнал. Примечание проводки (`note`) — данные записи, а не фраза экрана.
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

  /// Чем приняты деньги. Хранится у операции и решает тип оплаты чека
  /// аванса (решение заказчика 2026-09-14, п.4).
  int _tenderKindId = SystemPaymentKindIds.cash;

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
      setState(() => _error = l10n.customerPaymentAmountInvalid);
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
          tenderKindId: _tenderKindId,
          note: 'Погашение долга / оплата (${widget.agentName})',
        );

    if (!mounted) return;

    if (outcome.success) {
      Navigator.of(context).pop(outcome);
    } else {
      final reason = outcome.errorMessage;
      if (reason != null) {
        talker.warning('Customer payment refused: $reason');
      }
      setState(() {
        _submitting = false;
        _error = l10n.customerPaymentFailed;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final hasDebt = widget.currentBalance < Decimal.zero;
    final debtText = hasDebt
        ? (-widget.currentBalance).toStringAsFixed(2)
        : widget.currentBalance.toStringAsFixed(2);

    return AlertDialog(
      title: Text(l10n.customerPaymentTitle),
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
            hasDebt
                ? l10n.customerPaymentCurrentDebt(debtText)
                : l10n.customerPaymentBalance(debtText),
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
              labelText: l10n.customerPaymentAmount,
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.payments),
            ),
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 12),
          Text(l10n.customerPaymentTender, style: AppTextStyles.body),
          const SizedBox(height: 6),
          SegmentedButton<int>(
            key: const ValueKey('customer-payment-tender'),
            segments: [
              ButtonSegment(
                value: SystemPaymentKindIds.cash,
                label: Text(l10n.paymentCash),
              ),
              ButtonSegment(
                value: SystemPaymentKindIds.card,
                label: Text(l10n.paymentCard),
              ),
            ],
            selected: {_tenderKindId},
            onSelectionChanged: _submitting
                ? null
                : (s) => setState(() => _tenderKindId = s.single),
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
              : Text(l10n.customerPaymentSubmit),
        ),
      ],
    );
  }
}

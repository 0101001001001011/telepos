import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:telepos/app/theme/app_colors.dart';
import 'package:telepos/app/theme/telepos_icons.dart';
import 'package:get_it/get_it.dart';
import 'package:telepos/domain/fiscal/fiscal_models.dart';
import 'package:telepos/domain/services/currency_service.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/presentation/controllers/shift/shift_controller.dart';

class FiscalCorrectionScreen extends ConsumerStatefulWidget {
  const FiscalCorrectionScreen({super.key});

  @override
  ConsumerState<FiscalCorrectionScreen> createState() =>
      _FiscalCorrectionScreenState();
}

class _FiscalCorrectionScreenState
    extends ConsumerState<FiscalCorrectionScreen> {
  final _amountController = TextEditingController();
  final _reasonController = TextEditingController();
  FiscalPaymentKind _paymentKind = FiscalPaymentKind.cash;
  bool _submitting = false;
  FiscalResult? _lastResult;

  @override
  void dispose() {
    _amountController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  Decimal? _parseAmount() {
    final raw = _amountController.text.trim().replaceAll(',', '.');
    if (raw.isEmpty) return null;
    final v = Decimal.tryParse(raw);
    if (v == null || v <= Decimal.zero) return null;
    return v;
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context)!;
    final amount = _parseAmount();
    if (amount == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.setCorrectionInvalidAmount),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
      return;
    }

    setState(() => _submitting = true);

    final key = 'corr-${DateTime.now().microsecondsSinceEpoch}';
    final position = FiscalPosition(
      name: _reasonController.text.trim().isEmpty
          ? l10n.setCorrectionDefaultName
          : _reasonController.text.trim(),
      quantity: Decimal.one,
      unitPrice: amount,
      lineTotal: amount,
      tax: FiscalTax.none(),
    );
    final req = FiscalCorrectionRequest(
      idempotencyKey: key,
      positions: [position],
      payments: [FiscalPayment(kind: _paymentKind, amount: amount)],
      comment: _reasonController.text.trim().isEmpty
          ? null
          : _reasonController.text.trim(),
    );

    final result = await ref
        .read(shiftControllerProvider.notifier)
        .runCorrection(req);

    if (!mounted) return;
    setState(() {
      _submitting = false;
      _lastResult = result;
    });

    final messenger = ScaffoldMessenger.of(context);
    final (msg, color) = _resultFeedback(result);
    messenger.showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color),
    );
  }

  (String, Color) _resultFeedback(FiscalResult r) {
    final l10n = AppLocalizations.of(context)!;
    if (r.success) {
      if (r.queued || r.offlineMode) {
        return (l10n.setCorrectionQueued, AppColors.warning);
      }
      return (l10n.setCorrectionSent, AppColors.success);
    }
    if (r.errorCode == FiscalErrorCode.unsupported) {
      return (
        r.errorMessage ?? l10n.setCorrectionUnsupported,
        Theme.of(context).colorScheme.error,
      );
    }
    if (r.errorCode == FiscalErrorCode.notConfigured) {
      return (
        l10n.setCorrectionNotConfigured,
        Theme.of(context).colorScheme.error,
      );
    }
    return (
      r.errorMessage ?? l10n.setCorrectionError,
      Theme.of(context).colorScheme.error,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.setCorrectionTitle)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  l10n.setCorrectionIntro,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  l10n.setCorrectionReasonLabel,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  key: const ValueKey('correction-reason'),
                  controller: _reasonController,
                  decoration: InputDecoration(
                    hintText: l10n.setCorrectionReasonHint,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  l10n.setCorrectionAmountLabel(
                    GetIt.I<CurrencyService>().code,
                  ),
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  key: const ValueKey('correction-amount'),
                  controller: _amountController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    hintText: '0.00',
                    // Валюта кассы, а не тенге: чек коррекции — деньги.
                    suffixText: GetIt.I<CurrencyService>().code,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  l10n.setCorrectionPaymentLabel,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                SegmentedButton<FiscalPaymentKind>(
                  segments: [
                    ButtonSegment(
                      value: FiscalPaymentKind.cash,
                      label: Text(l10n.setCorrectionCash),
                      icon: const Icon(Icons.payments_outlined),
                    ),
                    ButtonSegment(
                      value: FiscalPaymentKind.card,
                      label: Text(l10n.setCorrectionCard),
                      icon: const Icon(Icons.credit_card),
                    ),
                  ],
                  selected: {_paymentKind},
                  onSelectionChanged: (s) =>
                      setState(() => _paymentKind = s.first),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  key: const ValueKey('correction-submit'),
                  onPressed: _submitting ? null : _submit,
                  icon: _submitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.receipt_long),
                  label: Text(l10n.setCorrectionSubmit),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
                if (_lastResult != null) ...[
                  const SizedBox(height: 16),
                  _buildResultBanner(_lastResult!),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildResultBanner(FiscalResult r) {
    final (msg, color) = _resultFeedback(r);
    return Container(
      key: const ValueKey('correction-result'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color),
      ),
      child: Row(
        children: [
          Icon(
            r.success ? TeleposIcons.checkCircle : TeleposIcons.error,
            color: color,
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(msg)),
        ],
      ),
    );
  }
}

Future<void> showFiscalCorrectionScreen(BuildContext context) {
  return Navigator.of(context).push<void>(
    MaterialPageRoute(builder: (_) => const FiscalCorrectionScreen()),
  );
}

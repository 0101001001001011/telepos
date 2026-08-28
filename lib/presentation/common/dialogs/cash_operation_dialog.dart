import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:telepos/app/theme/app_colors.dart';
import 'package:telepos/app/theme/app_semantic_colors.dart';
import 'package:telepos/app/theme/app_theme.dart';
import 'package:telepos/domain/services/currency_service.dart';
import 'package:telepos/l10n/app_localizations.dart';

enum CashOperationType {
  cashIn(Icons.add_circle_outline, AppColors.success),

  cashOut(Icons.remove_circle_outline, AppColors.warning);

  const CashOperationType(this.icon, this.color);

  final IconData icon;
  final Color color;

  String getLabel(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return switch (this) {
      CashOperationType.cashIn => l10n.cashInvestment,
      CashOperationType.cashOut => l10n.cashWithdrawal,
    };
  }
}

class CashOperationResult {
  const CashOperationResult({
    required this.type,
    required this.amount,
    this.comment,
  });

  final CashOperationType type;
  final Decimal amount;
  final String? comment;
}

class CashOperationDialog extends StatefulWidget {
  const CashOperationDialog({super.key, required this.type, this.currentCash});

  final CashOperationType type;
  final Decimal? currentCash;

  static Future<CashOperationResult?> showCashIn({
    required BuildContext context,
    Decimal? currentCash,
  }) {
    return showDialog<CashOperationResult>(
      context: context,
      builder: (context) => CashOperationDialog(
        type: CashOperationType.cashIn,
        currentCash: currentCash,
      ),
    );
  }

  static Future<CashOperationResult?> showCashOut({
    required BuildContext context,
    Decimal? currentCash,
  }) {
    return showDialog<CashOperationResult>(
      context: context,
      builder: (context) => CashOperationDialog(
        type: CashOperationType.cashOut,
        currentCash: currentCash,
      ),
    );
  }

  @override
  State<CashOperationDialog> createState() => _CashOperationDialogState();
}

class _CashOperationDialogState extends State<CashOperationDialog> {
  final _amountController = TextEditingController();
  final _commentController = TextEditingController();
  String? _errorText;

  @override
  void dispose() {
    _amountController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  void _validate() {
    final text = _amountController.text;
    if (text.isEmpty) {
      setState(() => _errorText = AppLocalizations.of(context)!.enterAmount);
      return;
    }

    try {
      final amount = Decimal.parse(
        text.replaceAll(',', '.').replaceAll(' ', ''),
      );
      if (amount <= Decimal.zero) {
        setState(
          () => _errorText = AppLocalizations.of(context)!.amountMustBePositive,
        );
        return;
      }

      if (widget.type == CashOperationType.cashOut &&
          widget.currentCash != null &&
          amount > widget.currentCash!) {
        setState(
          () =>
              _errorText = AppLocalizations.of(context)!.notEnoughCashInDrawer,
        );
        return;
      }

      setState(() => _errorText = null);
    } catch (_) {
      setState(
        () => _errorText = AppLocalizations.of(context)!.enterValidAmount,
      );
    }
  }

  void _submit() {
    _validate();
    if (_errorText != null) return;

    try {
      final amount = Decimal.parse(
        _amountController.text.replaceAll(',', '.').replaceAll(' ', ''),
      );
      final comment = _commentController.text.trim();

      Navigator.of(context).pop(
        CashOperationResult(
          type: widget.type,
          amount: amount,
          comment: comment.isNotEmpty ? comment : null,
        ),
      );
    } catch (_) {}
  }

  String get _currencySymbol => GetIt.I<CurrencyService>().symbol;

  String _formatMoney(Decimal value) {
    return '${value.toStringAsFixed(2)} $_currencySymbol';
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: widget.type.color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Icon(widget.type.icon, color: widget.type.color),
                  ),
                  const SizedBox(width: 16),
                  Text(widget.type.getLabel(context), style: AppTextStyles.h3),
                ],
              ),

              if (widget.currentCash != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: context.semantic.canvas,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        AppLocalizations.of(context)!.cashInDrawer,
                        style: AppTextStyles.body,
                      ),
                      Text(
                        _formatMoney(widget.currentCash!),
                        style: AppTextStyles.body.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 24),

              TextField(
                controller: _amountController,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                textAlign: TextAlign.center,
                style: AppTextStyles.h2,
                onChanged: (_) => _validate(),
                decoration: InputDecoration(
                  labelText: AppLocalizations.of(context)!.globalAmount,
                  hintText: '0.00',
                  errorText: _errorText,
                  suffixText: _currencySymbol,
                  suffixStyle: AppTextStyles.h3.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              TextField(
                controller: _commentController,
                maxLines: 2,
                maxLength: 100,
                decoration: InputDecoration(
                  labelText: AppLocalizations.of(context)!.commentOptional,
                  hintText: AppLocalizations.of(context)!.operationReason,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(AppLocalizations.of(context)!.globalCancel),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: widget.type.color,
                      ),
                      child: Text(widget.type.getLabel(context)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

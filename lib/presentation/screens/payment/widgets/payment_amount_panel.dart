import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:telepos/app/theme/app_colors.dart';
import 'package:telepos/app/theme/app_theme.dart';
import 'package:telepos/app/theme/telepos_icons.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/presentation/controllers/payment/payment_controller.dart';

class PaymentAmountPanel extends ConsumerWidget {
  const PaymentAmountPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(paymentControllerProvider);

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
          _AmountRow(
            label: l10n.paymentAmountDue,
            amount: state.totalAmount,
            isLarge: true,
          ),

          if (state.bonusToUse > Decimal.zero) ...[
            const SizedBox(height: AppTheme.spacingSmall),
            _AmountRow(
              label: l10n.paymentBonus,
              amount: state.bonusToUse,
              prefix: '-',
              color: AppColors.success,
            ),
            const Divider(height: AppTheme.spacing),
            _AmountRow(
              label: l10n.paymentTotalDue,
              amount: state.amountToPay,
              isLarge: true,
              color: AppColors.primary,
            ),
          ],

          const Divider(height: AppTheme.spacingLarge),

          if (state.paymentType != PaymentType.card) ...[
            _AmountInputRow(
              label: state.paymentType == PaymentType.mixed
                  ? l10n.paymentCashLabel
                  : l10n.paymentReceived,
              amount: state.cashReceived,
              inputText: state.cashInputText,
              isActive: state.activeInput == PaymentInputField.cash,
              onTap: () => ref
                  .read(paymentControllerProvider.notifier)
                  .setActiveInput(PaymentInputField.cash),
              onChanged: (value) {
                final amount = Decimal.tryParse(value) ?? Decimal.zero;
                ref
                    .read(paymentControllerProvider.notifier)
                    .setCashReceived(amount);
              },
              onClear: () {
                ref
                    .read(paymentControllerProvider.notifier)
                    .clearCashReceived();
              },
            ),

            if (state.paymentType == PaymentType.mixed) ...[
              const SizedBox(height: AppTheme.spacing),
              _AmountInputRow(
                label: l10n.paymentByCard,
                amount: state.cardAmount,
                inputText: state.cardInputText,
                color: AppColors.paymentCard,
                isActive: state.activeInput == PaymentInputField.card,
                onTap: () => ref
                    .read(paymentControllerProvider.notifier)
                    .setActiveInput(PaymentInputField.card),
                onChanged: (value) {
                  final amount = Decimal.tryParse(value) ?? Decimal.zero;
                  ref
                      .read(paymentControllerProvider.notifier)
                      .setCardAmount(amount);
                },
              ),
            ],

            const Divider(height: AppTheme.spacingLarge),

            if (state.change > Decimal.zero)
              _AmountRow(
                label: l10n.paymentChangeLabel,
                amount: state.change,
                isLarge: true,
                color: AppColors.success,
              )
            else if (state.remaining > Decimal.zero)
              _AmountRow(
                label: l10n.paymentRemainingLabel,
                amount: state.remaining,
                isLarge: true,
                color: Theme.of(context).colorScheme.error,
              )
            else
              _AmountRow(
                label: l10n.paymentChangeLabel,
                amount: Decimal.zero,
                isLarge: true,
              ),
          ],

          if (state.paymentType == PaymentType.card) ...[
            Container(
              padding: const EdgeInsets.all(AppTheme.spacing),
              decoration: BoxDecoration(
                color: AppColors.paymentCard.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppTheme.borderRadius),
              ),
              child: Row(
                children: [
                  const Icon(Icons.credit_card, color: AppColors.paymentCard),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      l10n.paymentCardAmount('${state.amountToPay}'),
                      style: AppTextStyles.body.copyWith(
                        color: AppColors.paymentCard,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _AmountRow extends StatelessWidget {
  const _AmountRow({
    required this.label,
    required this.amount,
    this.prefix = '',
    this.color,
    this.isLarge = false,
  });

  final String label;
  final Decimal amount;
  final String prefix;
  final Color? color;
  final bool isLarge;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: isLarge
              ? AppTextStyles.h3
              : AppTextStyles.body.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
        ),
        Text(
          '$prefix$amount',
          style: isLarge
              ? AppTextStyles.h2.copyWith(
                  color: color ?? Theme.of(context).colorScheme.onSurface,
                )
              : AppTextStyles.body.copyWith(
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
        ),
      ],
    );
  }
}

class _AmountInputRow extends StatefulWidget {
  const _AmountInputRow({
    required this.label,
    required this.amount,
    required this.onChanged,
    this.inputText,
    this.color,
    this.onClear,
    this.isActive = false,
    this.onTap,
  });

  final String label;
  final Decimal amount;
  final void Function(String) onChanged;
  final String? inputText;
  final Color? color;
  final VoidCallback? onClear;
  final bool isActive;
  final VoidCallback? onTap;

  @override
  State<_AmountInputRow> createState() => _AmountInputRowState();
}

class _AmountInputRowState extends State<_AmountInputRow> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: _displayText);
  }

  String get _displayText {
    if (widget.inputText != null && widget.inputText!.isNotEmpty) {
      return widget.inputText!;
    }
    return widget.amount > Decimal.zero ? widget.amount.toString() : '';
  }

  @override
  void didUpdateWidget(_AmountInputRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    final newText = _displayText;
    if (_controller.text != newText && !_controller.text.endsWith('.')) {
      _controller.text = newText;
      _controller.selection = TextSelection.fromPosition(
        TextPosition(offset: _controller.text.length),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final activeColor = widget.color ?? AppColors.paymentCash;

    return Row(
      children: [
        Expanded(
          flex: 2,
          child: GestureDetector(
            onTap: widget.onTap,
            child: Text(
              widget.label,
              style: AppTextStyles.h3.copyWith(
                color: widget.color ?? Theme.of(context).colorScheme.onSurface,
                fontWeight: widget.isActive ? FontWeight.bold : FontWeight.w600,
              ),
            ),
          ),
        ),
        Expanded(
          flex: 3,
          child: GestureDetector(
            onTap: widget.onTap,
            child: TextField(
              controller: _controller,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              textAlign: TextAlign.right,
              style: AppTextStyles.h2.copyWith(color: activeColor),
              decoration: InputDecoration(
                hintText: '0',
                hintStyle: AppTextStyles.h2.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.borderRadius),
                  borderSide: BorderSide(
                    color: widget.isActive
                        ? activeColor
                        : Theme.of(context).colorScheme.outline,
                    width: widget.isActive ? 2 : 1,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.borderRadius),
                  borderSide: BorderSide(
                    color: widget.isActive
                        ? activeColor
                        : Theme.of(context).colorScheme.outline,
                    width: widget.isActive ? 2 : 1,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.borderRadius),
                  borderSide: BorderSide(color: activeColor, width: 2),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.spacing,
                  vertical: AppTheme.spacingSmall,
                ),
                suffixIcon:
                    widget.onClear != null && widget.amount > Decimal.zero
                    ? IconButton(
                        icon: const Icon(TeleposIcons.close),
                        onPressed: () {
                          _controller.clear();
                          widget.onClear?.call();
                        },
                      )
                    : null,
              ),
              onChanged: widget.onChanged,
              onTap: widget.onTap,
            ),
          ),
        ),
      ],
    );
  }
}

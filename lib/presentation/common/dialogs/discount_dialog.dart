import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:telepos/app/theme/app_colors.dart';
import 'package:telepos/app/theme/app_theme.dart';
import 'package:telepos/domain/services/currency_service.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/presentation/common/widgets/keyboards/num_pad.dart';

enum DiscountType { percent, fixed }

class DiscountResult {
  const DiscountResult({required this.type, required this.value});

  final DiscountType type;
  final Decimal value;

  Decimal calculate(Decimal subtotal) {
    if (type == DiscountType.percent) {
      return (subtotal * value / Decimal.fromInt(100)).toDecimal();
    }
    return value;
  }
}

class DiscountDialog extends StatefulWidget {
  const DiscountDialog({
    super.key,
    this.currentDiscount,
    this.currentType,
    this.maxPercent = 100,
    this.maxAmount,
    this.subtotal,
  });

  final Decimal? currentDiscount;
  final DiscountType? currentType;
  final int maxPercent;
  final Decimal? maxAmount;
  final Decimal? subtotal;

  static Future<DiscountResult?> show({
    required BuildContext context,
    Decimal? currentDiscount,
    DiscountType? currentType,
    int maxPercent = 100,
    Decimal? maxAmount,
    Decimal? subtotal,
  }) {
    return showDialog<DiscountResult>(
      context: context,
      builder: (context) => DiscountDialog(
        currentDiscount: currentDiscount,
        currentType: currentType,
        maxPercent: maxPercent,
        maxAmount: maxAmount,
        subtotal: subtotal,
      ),
    );
  }

  @override
  State<DiscountDialog> createState() => _DiscountDialogState();
}

class _DiscountDialogState extends State<DiscountDialog> {
  late DiscountType _type;
  late TextEditingController _controller;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _type = widget.currentType ?? DiscountType.percent;
    _controller = TextEditingController(
      text: widget.currentDiscount?.toString() ?? '',
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _validate() {
    final text = _controller.text;
    if (text.isEmpty) {
      setState(() => _errorText = null);
      return;
    }

    try {
      final value = Decimal.parse(text.replaceAll(',', '.'));
      if (value < Decimal.zero) {
        setState(
          () =>
              _errorText = AppLocalizations.of(context)!.valueCannotBeNegative,
        );
        return;
      }

      if (_type == DiscountType.percent &&
          value > Decimal.fromInt(widget.maxPercent)) {
        setState(
          () => _errorText = AppLocalizations.of(
            context,
          )!.maxPercent(widget.maxPercent),
        );
        return;
      }

      if (_type == DiscountType.fixed &&
          widget.maxAmount != null &&
          value > widget.maxAmount!) {
        setState(
          () => _errorText = AppLocalizations.of(
            context,
          )!.maxAmount(widget.maxAmount.toString()),
        );
        return;
      }

      setState(() => _errorText = null);
    } catch (_) {
      setState(
        () => _errorText = AppLocalizations.of(context)!.enterValidNumber,
      );
    }
  }

  void _submit() {
    _validate();
    if (_errorText != null) return;

    final text = _controller.text;
    if (text.isEmpty) {
      Navigator.of(context).pop();
      return;
    }

    try {
      final value = Decimal.parse(text.replaceAll(',', '.'));
      Navigator.of(context).pop(DiscountResult(type: _type, value: value));
    } catch (_) {}
  }

  void _onKey(String d) {
    _controller.text = _controller.text + d;
    _validate();
  }

  void _onDot() {
    if (_controller.text.contains('.')) return;
    final base = _controller.text.isEmpty ? '0' : _controller.text;
    _controller.text = '$base.';
    _validate();
  }

  void _onBackspace() {
    final t = _controller.text;
    if (t.isEmpty) return;
    _controller.text = t.substring(0, t.length - 1);
    _validate();
  }

  void _onClear() {
    _controller.clear();
    _validate();
  }

  String get _currencySymbol => GetIt.I<CurrencyService>().symbol;

  String _formatMoney(Decimal value) {
    return '${value.toStringAsFixed(2)} $_currencySymbol';
  }

  @override
  Widget build(BuildContext context) {
    Decimal? previewAmount;
    if (widget.subtotal != null &&
        _controller.text.isNotEmpty &&
        _errorText == null) {
      try {
        final value = Decimal.parse(_controller.text.replaceAll(',', '.'));
        previewAmount = DiscountResult(
          type: _type,
          value: value,
        ).calculate(widget.subtotal!);
      } catch (_) {}
    }

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  AppLocalizations.of(context)!.discountTitle,
                  style: AppTextStyles.h3,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),

                SegmentedButton<DiscountType>(
                  segments: [
                    const ButtonSegment(
                      value: DiscountType.percent,
                      label: Text('%'),
                    ),
                    ButtonSegment(
                      value: DiscountType.fixed,
                      label: Text(AppLocalizations.of(context)!.globalAmount),
                    ),
                  ],
                  selected: {_type},
                  onSelectionChanged: (set) {
                    setState(() => _type = set.first);
                    _validate();
                  },
                ),
                const SizedBox(height: 16),

                TextField(
                  controller: _controller,
                  readOnly: true,
                  showCursor: true,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  textAlign: TextAlign.center,
                  style: AppTextStyles.h2,
                  onChanged: (_) => _validate(),
                  onSubmitted: (_) => _submit(),
                  decoration: InputDecoration(
                    hintText: _type == DiscountType.percent ? '0' : '0.00',
                    errorText: _errorText,
                    suffixText: _type == DiscountType.percent
                        ? '%'
                        : _currencySymbol,
                    suffixStyle: AppTextStyles.h3.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                Center(
                  child: NumPad(
                    buttonSize: 48,
                    spacing: 8,
                    showEnter: true,
                    onKeyPressed: _onKey,
                    onBackspace: _onBackspace,
                    onClear: _onClear,
                    onEnter: _submit,
                  ),
                ),
                const SizedBox(height: 8),
                Center(
                  child: SizedBox(
                    width: 168,
                    child: OutlinedButton(
                      onPressed: _onDot,
                      child: const Text('.', style: TextStyle(fontSize: 20)),
                    ),
                  ),
                ),

                if (previewAmount != null && widget.subtotal != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          AppLocalizations.of(context)!.discountAmount,
                          style: AppTextStyles.body,
                        ),
                        Text(
                          '-${_formatMoney(previewAmount)}',
                          style: AppTextStyles.body.copyWith(
                            color: AppColors.success,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
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
                        child: Text(
                          AppLocalizations.of(context)!.discountApply,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

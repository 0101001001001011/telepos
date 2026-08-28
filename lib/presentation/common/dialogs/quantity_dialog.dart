import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:telepos/app/theme/app_colors.dart';
import 'package:telepos/app/theme/app_semantic_colors.dart';
import 'package:telepos/app/theme/app_theme.dart';
import 'package:telepos/app/theme/telepos_icons.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/presentation/common/widgets/keyboards/num_pad.dart';

class QuantityDialog extends StatefulWidget {
  const QuantityDialog({
    super.key,
    this.initialQuantity,
    this.minQuantity,
    this.maxQuantity,
    this.step,
    this.unit,
    this.title,
    this.allowDecimal = false,
  });

  final Decimal? initialQuantity;
  final Decimal? minQuantity;
  final Decimal? maxQuantity;
  final Decimal? step;
  final String? unit;
  final String? title;
  final bool allowDecimal;

  static Future<Decimal?> show({
    required BuildContext context,
    Decimal? initialQuantity,
    Decimal? minQuantity,
    Decimal? maxQuantity,
    Decimal? step,
    String? unit,
    String? title,
    bool allowDecimal = false,
  }) {
    return showDialog<Decimal>(
      context: context,
      builder: (context) => QuantityDialog(
        initialQuantity: initialQuantity,
        minQuantity: minQuantity,
        maxQuantity: maxQuantity,
        step: step,
        unit: unit,
        title: title,
        allowDecimal: allowDecimal,
      ),
    );
  }

  @override
  State<QuantityDialog> createState() => _QuantityDialogState();
}

class _QuantityDialogState extends State<QuantityDialog> {
  late Decimal _quantity;
  late TextEditingController _controller;

  Decimal get _minQty => widget.minQuantity ?? Decimal.one;
  Decimal get _maxQty => widget.maxQuantity ?? Decimal.fromInt(9999);
  Decimal get _step => widget.step ?? Decimal.one;

  @override
  void initState() {
    super.initState();
    _quantity = widget.initialQuantity ?? Decimal.one;
    _controller = TextEditingController(text: _formatQuantity(_quantity));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _formatQuantity(Decimal qty) {
    if (widget.allowDecimal) {
      return qty.toStringAsFixed(3).replaceAll(RegExp(r'\.?0+$'), '');
    }
    return qty.toStringAsFixed(0);
  }

  void _updateQuantity(Decimal newQty) {
    if (newQty < _minQty) newQty = _minQty;
    if (newQty > _maxQty) newQty = _maxQty;

    setState(() {
      _quantity = newQty;
      _controller.text = _formatQuantity(newQty);
    });
  }

  void _increment() => _updateQuantity(_quantity + _step);
  void _decrement() => _updateQuantity(_quantity - _step);

  void _onTextChanged(String value) {
    try {
      final parsed = Decimal.parse(value.replaceAll(',', '.'));
      setState(() => _quantity = parsed);
    } catch (_) {}
  }

  void _onKey(String d) {
    final text = _controller.text == '0' ? '' : _controller.text;
    _controller.text = text + d;
    _onTextChanged(_controller.text);
  }

  void _onDot() {
    if (!widget.allowDecimal) return;
    if (_controller.text.contains('.')) return;
    final base = _controller.text.isEmpty ? '0' : _controller.text;
    _controller.text = '$base.';
  }

  void _onBackspace() {
    final t = _controller.text;
    if (t.isEmpty) return;
    _controller.text = t.substring(0, t.length - 1);
    _onTextChanged(_controller.text);
  }

  void _onClear() {
    _controller.clear();
    setState(() => _quantity = _minQty);
  }

  void _submit() {
    if (_quantity >= _minQty && _quantity <= _maxQty) {
      Navigator.of(context).pop(_quantity);
    }
  }

  @override
  Widget build(BuildContext context) {
    final canDecrement = _quantity > _minQty;
    final canIncrement = _quantity < _maxQty;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 350),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.title ?? AppLocalizations.of(context)!.globalQuantity,
                  style: AppTextStyles.h3,
                ),
                const SizedBox(height: 24),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _QuantityButton(
                      icon: Icons.remove,
                      onPressed: canDecrement ? _decrement : null,
                    ),
                    const SizedBox(width: 16),

                    SizedBox(
                      width: 120,
                      child: TextField(
                        controller: _controller,
                        readOnly: true,
                        showCursor: true,
                        textAlign: TextAlign.center,
                        style: AppTextStyles.h1,
                        keyboardType: TextInputType.numberWithOptions(
                          decimal: widget.allowDecimal,
                        ),
                        onChanged: _onTextChanged,
                        onSubmitted: (_) => _submit(),
                        decoration: InputDecoration(
                          suffixText:
                              widget.unit ??
                              AppLocalizations.of(context)!.unitPcs,
                          suffixStyle: AppTextStyles.body.copyWith(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),

                    _QuantityButton(
                      icon: TeleposIcons.add,
                      onPressed: canIncrement ? _increment : null,
                    ),
                  ],
                ),

                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: [1, 2, 5, 10, 20, 50].map((qty) {
                    return _QuickButton(
                      label: qty.toString(),
                      onTap: () => _updateQuantity(Decimal.fromInt(qty)),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),

                if (widget.allowDecimal) ...[
                  Align(
                    alignment: Alignment.center,
                    child: SizedBox(
                      width: 180,
                      child: OutlinedButton(
                        onPressed: _onDot,
                        child: const Text('.', style: TextStyle(fontSize: 22)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],

                NumPad(
                  buttonSize: 52,
                  spacing: 8,
                  showEnter: false,
                  onKeyPressed: _onKey,
                  onBackspace: _onBackspace,
                  onClear: _onClear,
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
                        child: Text(AppLocalizations.of(context)!.globalOk),
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

class _QuantityButton extends StatelessWidget {
  const _QuantityButton({required this.icon, this.onPressed});

  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 56,
      height: 56,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          padding: EdgeInsets.zero,
          backgroundColor: onPressed != null
              ? AppColors.primary
              : context.semantic.canvas,
          foregroundColor: onPressed != null
              ? AppColors.white
              : Theme.of(context).colorScheme.onSurfaceVariant,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Icon(icon, size: 28),
      ),
    );
  }
}

class _QuickButton extends StatelessWidget {
  const _QuickButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: context.semantic.canvas,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(label, style: AppTextStyles.body),
      ),
    );
  }
}

class WeightDialog extends StatefulWidget {
  const WeightDialog({
    super.key,
    this.initialWeight,
    this.maxWeight,
    this.unit,
  });

  final Decimal? initialWeight;
  final Decimal? maxWeight;
  final String? unit;

  static Future<Decimal?> show({
    required BuildContext context,
    Decimal? initialWeight,
    Decimal? maxWeight,
    String? unit,
  }) {
    return showDialog<Decimal>(
      context: context,
      builder: (context) => WeightDialog(
        initialWeight: initialWeight,
        maxWeight: maxWeight,
        unit: unit,
      ),
    );
  }

  @override
  State<WeightDialog> createState() => _WeightDialogState();
}

class _WeightDialogState extends State<WeightDialog> {
  late TextEditingController _controller;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.initialWeight?.toStringAsFixed(3) ?? '',
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
      setState(() => _errorText = AppLocalizations.of(context)!.enterWeight);
      return;
    }

    try {
      final weight = Decimal.parse(text.replaceAll(',', '.'));
      if (weight <= Decimal.zero) {
        setState(
          () => _errorText = AppLocalizations.of(context)!.weightMustBePositive,
        );
        return;
      }
      if (widget.maxWeight != null && weight > widget.maxWeight!) {
        final effectiveUnit =
            widget.unit ?? AppLocalizations.of(context)!.unitKg;
        setState(
          () => _errorText = AppLocalizations.of(
            context,
          )!.maxWeightValue(widget.maxWeight.toString(), effectiveUnit),
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

    try {
      final weight = Decimal.parse(_controller.text.replaceAll(',', '.'));
      Navigator.of(context).pop(weight);
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

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 350),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.scale, size: 48, color: AppColors.primary),
                const SizedBox(height: 16),
                Text(
                  AppLocalizations.of(context)!.enterWeight,
                  style: AppTextStyles.h3,
                ),
                const SizedBox(height: 24),

                TextField(
                  controller: _controller,
                  readOnly: true,
                  showCursor: true,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.h2,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  onChanged: (_) => _validate(),
                  onSubmitted: (_) => _submit(),
                  decoration: InputDecoration(
                    hintText: '0.000',
                    errorText: _errorText,
                    suffixText:
                        widget.unit ?? AppLocalizations.of(context)!.unitKg,
                    suffixStyle: AppTextStyles.h3.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                Align(
                  alignment: Alignment.center,
                  child: SizedBox(
                    width: 180,
                    child: OutlinedButton(
                      onPressed: _onDot,
                      child: const Text('.', style: TextStyle(fontSize: 22)),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                NumPad(
                  buttonSize: 52,
                  spacing: 8,
                  showEnter: false,
                  onKeyPressed: _onKey,
                  onBackspace: _onBackspace,
                  onClear: _onClear,
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
                        child: Text(AppLocalizations.of(context)!.globalOk),
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

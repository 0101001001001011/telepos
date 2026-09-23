import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:telepos/app/theme/app_colors.dart';
import 'package:telepos/app/theme/app_theme.dart';

class MoneyFormatter extends TextInputFormatter {
  MoneyFormatter({
    this.decimalSeparator = '.',
    this.thousandsSeparator = ' ',
    this.decimalDigits = 2,
  });

  final String decimalSeparator;

  final String thousandsSeparator;

  final int decimalDigits;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    String text = newValue.text.replaceAll(RegExp(r'[^\d.,]'), '');

    text = text.replaceAll(',', '.');

    final parts = text.split('.');
    if (parts.length > 2) {
      text = '${parts[0]}.${parts.sublist(1).join('')}';
    }

    if (parts.length == 2 && parts[1].length > decimalDigits) {
      text = '${parts[0]}.${parts[1].substring(0, decimalDigits)}';
    }

    final formatted = _formatWithThousands(text);

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }

  String _formatWithThousands(String value) {
    if (value.isEmpty) return '';

    final parts = value.split('.');
    final integerPart = parts[0];
    final decimalPart = parts.length > 1 ? parts[1] : null;

    final buffer = StringBuffer();
    int count = 0;
    for (int i = integerPart.length - 1; i >= 0; i--) {
      if (count > 0 && count % 3 == 0) {
        buffer.write(thousandsSeparator);
      }
      buffer.write(integerPart[i]);
      count++;
    }

    String result = buffer.toString().split('').reversed.join('');

    if (decimalPart != null || value.contains('.')) {
      result += decimalSeparator + (decimalPart ?? '');
    }

    return result;
  }

  Decimal parse(String formatted) {
    if (formatted.isEmpty) return Decimal.zero;

    String cleaned = formatted
        .replaceAll(thousandsSeparator, '')
        .replaceAll(decimalSeparator, '.');

    try {
      return Decimal.parse(cleaned);
    } catch (_) {
      return Decimal.zero;
    }
  }
}

class MoneyField extends StatefulWidget {
  const MoneyField({
    super.key,
    this.controller,
    this.initialValue,
    this.label,
    this.hint,
    this.errorText,
    this.currency,
    this.currencySymbol,
    this.onChanged,
    this.onSubmitted,
    this.enabled = true,
    this.autofocus = false,
    this.decimalDigits = 2,
    this.showKeyboard = true,
  });

  final TextEditingController? controller;

  final Decimal? initialValue;

  final String? label;

  final String? hint;

  final String? errorText;

  final String? currency;

  final String? currencySymbol;

  final ValueChanged<Decimal>? onChanged;

  final ValueChanged<Decimal>? onSubmitted;

  final bool enabled;

  final bool autofocus;

  final int decimalDigits;

  final bool showKeyboard;

  @override
  State<MoneyField> createState() => _MoneyFieldState();
}

class _MoneyFieldState extends State<MoneyField> {
  late TextEditingController _controller;
  late MoneyFormatter _formatter;

  @override
  void initState() {
    super.initState();
    _formatter = MoneyFormatter(decimalDigits: widget.decimalDigits);
    _controller = widget.controller ?? TextEditingController();

    if (widget.initialValue != null) {
      _controller.text = _formatInitial(widget.initialValue!);
    }
  }

  @override
  void dispose() {
    if (widget.controller == null) {
      _controller.dispose();
    }
    super.dispose();
  }

  String _formatInitial(Decimal value) {
    final str = value.toStringAsFixed(widget.decimalDigits);
    return _formatter
        .formatEditUpdate(const TextEditingValue(), TextEditingValue(text: str))
        .text;
  }

  void _onChanged(String value) {
    final decimal = _formatter.parse(value);
    widget.onChanged?.call(decimal);
  }

  void _onSubmitted(String value) {
    final decimal = _formatter.parse(value);
    widget.onSubmitted?.call(decimal);
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      enabled: widget.enabled,
      autofocus: widget.autofocus,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      readOnly: !widget.showKeyboard,
      showCursor: true,
      inputFormatters: [_formatter],
      onChanged: _onChanged,
      onSubmitted: _onSubmitted,
      textAlign: TextAlign.right,
      style: AppTextStyles.h2,
      decoration: InputDecoration(
        labelText: widget.label,
        hintText: widget.hint ?? '0.00',
        errorText: widget.errorText,
        prefixText: widget.currencySymbol,
        prefixStyle: AppTextStyles.h2.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        suffixText: widget.currency,
        suffixStyle: AppTextStyles.body.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: AppColors.borderPrimary),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: AppColors.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Theme.of(context).colorScheme.error),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),
    );
  }
}

class MoneyDisplay extends StatelessWidget {
  const MoneyDisplay({
    super.key,
    required this.value,
    this.currency,
    this.currencySymbol,
    this.style,
    this.currencyStyle,
    this.decimalDigits = 2,
  });

  final Decimal value;

  final String? currency;

  final String? currencySymbol;

  final TextStyle? style;

  final TextStyle? currencyStyle;

  final int decimalDigits;

  String get _formattedValue {
    final str = value.toStringAsFixed(decimalDigits);
    final parts = str.split('.');

    final buffer = StringBuffer();
    int count = 0;
    for (int i = parts[0].length - 1; i >= 0; i--) {
      if (count > 0 && count % 3 == 0) {
        buffer.write(' ');
      }
      buffer.write(parts[0][i]);
      count++;
    }

    String result = buffer.toString().split('').reversed.join('');
    if (parts.length > 1) {
      result += '.${parts[1]}';
    }

    return result;
  }

  @override
  Widget build(BuildContext context) {
    final textStyle = style ?? AppTextStyles.h2;
    final curStyle =
        currencyStyle ??
        textStyle.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        );

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        if (currencySymbol != null) Text(currencySymbol!, style: curStyle),
        Text(_formattedValue, style: textStyle),
        if (currency != null) ...[
          const SizedBox(width: 4),
          Text(currency!, style: curStyle),
        ],
      ],
    );
  }
}

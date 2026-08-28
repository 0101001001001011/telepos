import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:telepos/app/theme/app_colors.dart';
import 'package:telepos/app/theme/app_theme.dart';
import 'package:telepos/l10n/app_localizations.dart';

enum InputType { text, integer, decimal, pin }

class InputDialog extends StatefulWidget {
  const InputDialog({
    super.key,
    required this.title,
    this.message,
    this.initialValue,
    this.hint,
    this.inputType = InputType.text,
    this.maxLength,
    this.confirmText,
    this.cancelText,
    this.validator,
    this.obscureText = false,
  });

  final String title;
  final String? message;
  final String? initialValue;
  final String? hint;
  final InputType inputType;
  final int? maxLength;
  final String? confirmText;
  final String? cancelText;
  final String? Function(String value)? validator;
  final bool obscureText;

  static Future<String?> showText({
    required BuildContext context,
    required String title,
    String? message,
    String? initialValue,
    String? hint,
    int? maxLength,
    String? Function(String value)? validator,
  }) {
    return showDialog<String>(
      context: context,
      builder: (context) => InputDialog(
        title: title,
        message: message,
        initialValue: initialValue,
        hint: hint,
        inputType: InputType.text,
        maxLength: maxLength,
        validator: validator,
      ),
    );
  }

  static Future<int?> showInteger({
    required BuildContext context,
    required String title,
    String? message,
    int? initialValue,
    String? hint,
    int? Function(int value)? validator,
  }) async {
    final result = await showDialog<String>(
      context: context,
      builder: (context) => InputDialog(
        title: title,
        message: message,
        initialValue: initialValue?.toString(),
        hint: hint,
        inputType: InputType.integer,
        validator: (value) {
          final parsed = int.tryParse(value);
          if (parsed == null)
            return AppLocalizations.of(context)!.enterIntegerNumber;
          return validator?.call(parsed)?.toString();
        },
      ),
    );
    return result != null ? int.tryParse(result) : null;
  }

  static Future<Decimal?> showDecimal({
    required BuildContext context,
    required String title,
    String? message,
    Decimal? initialValue,
    String? hint,
  }) async {
    final result = await showDialog<String>(
      context: context,
      builder: (context) => InputDialog(
        title: title,
        message: message,
        initialValue: initialValue?.toString(),
        hint: hint ?? '0.00',
        inputType: InputType.decimal,
        validator: (value) {
          try {
            Decimal.parse(value.replaceAll(',', '.'));
            return null;
          } catch (_) {
            return AppLocalizations.of(context)!.enterValidAmount;
          }
        },
      ),
    );
    if (result != null) {
      try {
        return Decimal.parse(result.replaceAll(',', '.'));
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  static Future<String?> showPin({
    required BuildContext context,
    required String title,
    String? message,
    int length = 4,
  }) {
    return showDialog<String>(
      context: context,
      builder: (context) => InputDialog(
        title: title,
        message: message,
        hint: '●' * length,
        inputType: InputType.pin,
        maxLength: length,
        obscureText: true,
        validator: (value) {
          if (value.length != length) {
            return AppLocalizations.of(context)!.enterDigits(length);
          }
          return null;
        },
      ),
    );
  }

  @override
  State<InputDialog> createState() => _InputDialogState();
}

class _InputDialogState extends State<InputDialog> {
  late TextEditingController _controller;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _validate() {
    if (widget.validator != null) {
      setState(() {
        _errorText = widget.validator!(_controller.text);
      });
    }
  }

  void _submit() {
    _validate();
    if (_errorText == null) {
      Navigator.of(context).pop(_controller.text);
    }
  }

  TextInputType get _keyboardType {
    return switch (widget.inputType) {
      InputType.text => TextInputType.text,
      InputType.integer => TextInputType.number,
      InputType.decimal => const TextInputType.numberWithOptions(decimal: true),
      InputType.pin => TextInputType.number,
    };
  }

  List<TextInputFormatter>? get _formatters {
    return switch (widget.inputType) {
      InputType.text => null,
      InputType.integer => [FilteringTextInputFormatter.digitsOnly],
      InputType.decimal => [
        FilteringTextInputFormatter.allow(RegExp(r'[\d.,]')),
      ],
      InputType.pin => [FilteringTextInputFormatter.digitsOnly],
    };
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
              Text(
                widget.title,
                style: AppTextStyles.h3,
                textAlign: TextAlign.center,
              ),

              if (widget.message != null) ...[
                const SizedBox(height: 8),
                Text(
                  widget.message!,
                  style: AppTextStyles.body.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
              const SizedBox(height: 24),

              TextField(
                controller: _controller,
                autofocus: true,
                obscureText: widget.obscureText,
                keyboardType: _keyboardType,
                inputFormatters: _formatters,
                maxLength: widget.maxLength,
                textAlign: widget.inputType == InputType.pin
                    ? TextAlign.center
                    : TextAlign.start,
                style: widget.inputType == InputType.pin
                    ? AppTextStyles.h2
                    : null,
                onChanged: (_) => _validate(),
                onSubmitted: (_) => _submit(),
                decoration: InputDecoration(
                  hintText: widget.hint,
                  errorText: _errorText,
                  counterText: '',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: AppColors.primary, width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(
                        widget.cancelText ??
                            AppLocalizations.of(context)!.globalCancel,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _submit,
                      child: Text(
                        widget.confirmText ??
                            AppLocalizations.of(context)!.globalOk,
                      ),
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

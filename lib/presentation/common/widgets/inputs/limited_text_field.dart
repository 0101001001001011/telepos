import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:telepos/app/theme/app_colors.dart';
import 'package:telepos/app/theme/app_theme.dart';
import 'package:telepos/l10n/app_localizations.dart';

class LimitedTextField extends StatefulWidget {
  const LimitedTextField({
    super.key,
    this.controller,
    required this.maxLength,
    this.label,
    this.hint,
    this.errorText,
    this.prefixIcon,
    this.minLines = 1,
    this.maxLines = 1,
    this.onChanged,
    this.onSubmitted,
    this.enabled = true,
    this.autofocus = false,
    this.showCounter = true,
    this.keyboardType,
  });

  final TextEditingController? controller;

  final int maxLength;

  final String? label;

  final String? hint;

  final String? errorText;

  final IconData? prefixIcon;

  final int minLines;

  final int maxLines;

  final ValueChanged<String>? onChanged;

  final ValueChanged<String>? onSubmitted;

  final bool enabled;

  final bool autofocus;

  final bool showCounter;

  final TextInputType? keyboardType;

  @override
  State<LimitedTextField> createState() => _LimitedTextFieldState();
}

class _LimitedTextFieldState extends State<LimitedTextField> {
  late TextEditingController _controller;
  int _currentLength = 0;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? TextEditingController();
    _currentLength = _controller.text.length;
    _controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    if (widget.controller == null) {
      _controller.dispose();
    }
    super.dispose();
  }

  void _onTextChanged() {
    setState(() {
      _currentLength = _controller.text.length;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isOverLimit = _currentLength > widget.maxLength;
    final counterColor = isOverLimit
        ? Theme.of(context).colorScheme.error
        : Theme.of(context).colorScheme.onSurfaceVariant;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: _controller,
          enabled: widget.enabled,
          autofocus: widget.autofocus,
          minLines: widget.minLines,
          maxLines: widget.maxLines,
          keyboardType: widget.keyboardType,
          inputFormatters: [LengthLimitingTextInputFormatter(widget.maxLength)],
          onChanged: widget.onChanged,
          onSubmitted: widget.onSubmitted,
          decoration: InputDecoration(
            labelText: widget.label,
            hintText: widget.hint,
            errorText: widget.errorText,
            prefixIcon: widget.prefixIcon != null
                ? Icon(widget.prefixIcon)
                : null,
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
              borderSide: BorderSide(
                color: Theme.of(context).colorScheme.error,
              ),
            ),
          ),
        ),
        if (widget.showCounter)
          Padding(
            padding: const EdgeInsets.only(top: 4, right: 8),
            child: Align(
              alignment: Alignment.centerRight,
              child: Text(
                '$_currentLength/${widget.maxLength}',
                style: context.styles.caption.copyWith(color: counterColor),
              ),
            ),
          ),
      ],
    );
  }
}

class ReceiptCommentField extends StatelessWidget {
  const ReceiptCommentField({
    super.key,
    this.controller,
    this.onChanged,
    this.enabled = true,
  });

  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return LimitedTextField(
      controller: controller,
      maxLength: 100,
      label: AppLocalizations.of(context)!.commentReceipt,
      hint: AppLocalizations.of(context)!.commentReceiptHint,
      prefixIcon: Icons.comment,
      minLines: 1,
      maxLines: 3,
      onChanged: onChanged,
      enabled: enabled,
    );
  }
}

class ProductNameField extends StatelessWidget {
  const ProductNameField({
    super.key,
    this.controller,
    this.onChanged,
    this.errorText,
    this.enabled = true,
  });

  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final String? errorText;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return LimitedTextField(
      controller: controller,
      maxLength: 200,
      label: AppLocalizations.of(context)!.productNameLabel,
      hint: AppLocalizations.of(context)!.productNameHint,
      errorText: errorText,
      onChanged: onChanged,
      enabled: enabled,
    );
  }
}

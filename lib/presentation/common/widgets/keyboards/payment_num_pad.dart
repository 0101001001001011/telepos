import 'package:flutter/material.dart';
import 'package:telepos/app/theme/app_colors.dart';
import 'package:telepos/app/theme/app_semantic_colors.dart';
import 'package:telepos/app/theme/app_theme.dart';

class PaymentNumPad extends StatelessWidget {
  const PaymentNumPad({
    super.key,
    required this.onKeyPressed,
    this.onBackspace,
    this.onClear,
    this.buttonSize = 64,
    this.spacing = 8,
    this.decimalSeparator = '.',
  });

  final ValueChanged<String> onKeyPressed;

  final VoidCallback? onBackspace;

  final VoidCallback? onClear;

  final double buttonSize;

  final double spacing;

  final String decimalSeparator;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildRow(context, ['7', '8', '9']),
        SizedBox(height: spacing),
        _buildRow(context, ['4', '5', '6']),
        SizedBox(height: spacing),
        _buildRow(context, ['1', '2', '3']),
        SizedBox(height: spacing),
        _buildBottomRow(context),
        SizedBox(height: spacing),
        _buildExtraRow(context),
      ],
    );
  }

  // [context] прокинут: заливка клавиши берётся ролью темы, а не константой.
  Widget _buildRow(BuildContext context, List<String> keys) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: keys.map((key) {
        return Padding(
          padding: EdgeInsets.symmetric(horizontal: spacing / 2),
          child: _PaymentButton(
            label: key,
            onPressed: () => onKeyPressed(key),
            size: buttonSize,
          ),
        );
      }).toList(),
    );
  }

  // [context] прокинут: заливка клавиши берётся ролью темы, а не константой.
  Widget _buildBottomRow(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: spacing / 2),
          child: _PaymentButton(
            label: '00',
            onPressed: () => onKeyPressed('00'),
            size: buttonSize,
          ),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: spacing / 2),
          child: _PaymentButton(
            label: '0',
            onPressed: () => onKeyPressed('0'),
            size: buttonSize,
          ),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: spacing / 2),
          child: _PaymentButton(
            label: decimalSeparator,
            onPressed: () => onKeyPressed(decimalSeparator),
            size: buttonSize,
          ),
        ),
      ],
    );
  }

  // [context] прокинут: заливка клавиши берётся ролью темы, а не константой.
  Widget _buildExtraRow(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: spacing / 2),
          child: _PaymentButton(
            label: 'C',
            onPressed: onClear,
            size: buttonSize,
            backgroundColor: AppColors.warning,
            foregroundColor: AppColors.white,
          ),
        ),
        SizedBox(width: buttonSize + spacing),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: spacing / 2),
          child: _PaymentButton(
            icon: Icons.backspace_outlined,
            onPressed: onBackspace,
            size: buttonSize,
            backgroundColor: context.semantic.canvas,
          ),
        ),
      ],
    );
  }
}

class _PaymentButton extends StatelessWidget {
  const _PaymentButton({
    this.label,
    this.icon,
    required this.onPressed,
    required this.size,
    this.backgroundColor,
    this.foregroundColor,
  });

  final String? label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final double size;
  final Color? backgroundColor;
  final Color? foregroundColor;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor:
              backgroundColor ?? Theme.of(context).colorScheme.surface,
          foregroundColor:
              foregroundColor ?? Theme.of(context).colorScheme.onSurface,
          elevation: 2,
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: icon != null
            ? Icon(icon, size: size * 0.4)
            : Text(
                label ?? '',
                style: TextStyle(
                  fontSize: label != null && label!.length > 1
                      ? size * 0.3
                      : size * 0.4,
                  fontWeight: FontWeight.w500,
                ),
              ),
      ),
    );
  }
}

class CompactPaymentNumPad extends StatelessWidget {
  const CompactPaymentNumPad({
    super.key,
    required this.onKeyPressed,
    this.onBackspace,
    this.onClear,
    this.decimalSeparator = '.',
  });

  final ValueChanged<String> onKeyPressed;
  final VoidCallback? onBackspace;
  final VoidCallback? onClear;
  final String decimalSeparator;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(top: BorderSide(color: context.semantic.canvas)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildRow(context, ['1', '2', '3']),
          const SizedBox(height: 4),
          _buildRow(context, ['4', '5', '6']),
          const SizedBox(height: 4),
          _buildRow(context, ['7', '8', '9']),
          const SizedBox(height: 4),
          _buildBottomRow(context),
        ],
      ),
    );
  }

  // [context] прокинут: заливка клавиши берётся ролью темы, а не константой.
  Widget _buildRow(BuildContext context, List<String> keys) {
    return Row(
      children: keys.map((key) {
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: () => onKeyPressed(key),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.surface,
                  foregroundColor: Theme.of(context).colorScheme.onSurface,
                  elevation: 1,
                  padding: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(key, style: AppTextStyles.h3),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  // [context] прокинут: заливка клавиши берётся ролью темы, а не константой.
  Widget _buildBottomRow(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: () => onKeyPressed('00'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.surface,
                  foregroundColor: Theme.of(context).colorScheme.onSurface,
                  elevation: 1,
                  padding: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text('00', style: AppTextStyles.h3),
              ),
            ),
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: () => onKeyPressed('0'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.surface,
                  foregroundColor: Theme.of(context).colorScheme.onSurface,
                  elevation: 1,
                  padding: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text('0', style: AppTextStyles.h3),
              ),
            ),
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: onBackspace,
                style: ElevatedButton.styleFrom(
                  backgroundColor: context.semantic.canvas,
                  foregroundColor: Theme.of(context).colorScheme.onSurface,
                  elevation: 1,
                  padding: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Icon(Icons.backspace_outlined, size: 24),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

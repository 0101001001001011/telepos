import 'package:flutter/material.dart';
import 'package:telepos/app/theme/app_colors.dart';
import 'package:telepos/app/theme/app_semantic_colors.dart';
import 'package:telepos/app/theme/telepos_icons.dart';

class NumPad extends StatelessWidget {
  const NumPad({
    super.key,
    required this.onKeyPressed,
    this.onBackspace,
    this.onClear,
    this.onEnter,
    this.showClear = true,
    this.showEnter = true,
    this.buttonSize = 64,
    this.spacing = 8,
  });

  final ValueChanged<String> onKeyPressed;

  final VoidCallback? onBackspace;

  final VoidCallback? onClear;

  final VoidCallback? onEnter;

  final bool showClear;

  final bool showEnter;

  final double buttonSize;

  final double spacing;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildRow(context, ['1', '2', '3']),
        SizedBox(height: spacing),
        _buildRow(context, ['4', '5', '6']),
        SizedBox(height: spacing),
        _buildRow(context, ['7', '8', '9']),
        SizedBox(height: spacing),
        _buildBottomRow(context),
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
          child: _NumPadButton(
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
          child: showClear
              ? _NumPadButton(
                  icon: TeleposIcons.close,
                  onPressed: onClear,
                  size: buttonSize,
                  backgroundColor: context.semantic.canvas,
                )
              : SizedBox(width: buttonSize, height: buttonSize),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: spacing / 2),
          child: _NumPadButton(
            label: '0',
            onPressed: () => onKeyPressed('0'),
            size: buttonSize,
          ),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: spacing / 2),
          child: showEnter
              ? _NumPadButton(
                  icon: TeleposIcons.check,
                  onPressed: onEnter,
                  size: buttonSize,
                  backgroundColor: AppColors.success,
                  foregroundColor: AppColors.white,
                )
              : _NumPadButton(
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

class _NumPadButton extends StatelessWidget {
  const _NumPadButton({
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
                  fontSize: size * 0.4,
                  fontWeight: FontWeight.w500,
                ),
              ),
      ),
    );
  }
}

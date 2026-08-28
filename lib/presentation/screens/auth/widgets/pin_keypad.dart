import 'package:flutter/material.dart';
import 'package:telepos/app/theme/app_semantic_colors.dart';
import 'package:telepos/app/theme/app_theme.dart';

typedef PinKeyCallback = void Function(String key);

class PinKeypad extends StatelessWidget {
  const PinKeypad({
    required this.onKeyPressed,
    this.onClear,
    this.onBackspace,
    this.enabled = true,
    super.key,
  });

  final PinKeyCallback onKeyPressed;

  final VoidCallback? onClear;

  final VoidCallback? onBackspace;

  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildRow(['1', '2', '3']),
        const SizedBox(height: 8),
        _buildRow(['4', '5', '6']),
        const SizedBox(height: 8),
        _buildRow(['7', '8', '9']),
        const SizedBox(height: 8),
        _buildRow(['C', '0', '⌫']),
      ],
    );
  }

  Widget _buildRow(List<String> keys) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: keys.map((key) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: _PinKey(
            label: key,
            enabled: enabled,
            onPressed: () => _handleKeyPress(key),
          ),
        );
      }).toList(),
    );
  }

  void _handleKeyPress(String key) {
    if (!enabled) return;

    if (key == 'C') {
      onClear?.call();
    } else if (key == '⌫') {
      onBackspace?.call();
    } else {
      onKeyPressed(key);
    }
  }
}

class _PinKey extends StatelessWidget {
  const _PinKey({
    required this.label,
    required this.onPressed,
    required this.enabled,
  });

  final String label;
  final VoidCallback onPressed;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final isAction = label == 'C' || label == '⌫';
    final keys = _PinKeyColors.of(context, label);

    return SizedBox(
      width: 72,
      height: 56,
      child: ElevatedButton(
        onPressed: enabled ? onPressed : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: isAction ? keys.actionFill : keys.fill,
          foregroundColor: keys.ink,
          // Тень убрана вместе с остальными: тема плоская, и единственная
          // приподнятая кнопка в приложении читалась как чужая.
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.borderRadius),
            side: BorderSide(color: keys.hairline),
          ),
          padding: EdgeInsets.zero,
        ),
        child: label == '⌫'
            ? Icon(Icons.backspace_outlined, color: keys.ink, size: 24)
            : Text(
                label,
                style: AppTextStyles.numpadButton.copyWith(color: keys.ink),
              ),
      ),
    );
  }
}

/// Цвета клавиши, разрешённые темой.
///
/// Заведено ради одного: до 2026-08-04 клавиша заливалась `AppColors.white`, а
/// цифра красилась `Theme.of(context).colorScheme.onSurface` — обе константы светлой темы. В
/// тёмной это давало белую клавиатуру посреди ночного экрана, а `C` — красный
/// #DF3F40, который на ней же не брал порога. Роли те же, источник другой.
///
/// Одна структура на четыре места: цифровых клавиатур в файле две (обычная и
/// компактная), в каждой по два вида клавиш, и решение о цвете повторялось
/// четырежды. Повторённое решение расходится.
class _PinKeyColors {
  const _PinKeyColors({
    required this.fill,
    required this.actionFill,
    required this.ink,
    required this.hairline,
  });

  factory _PinKeyColors.of(BuildContext context, String label) {
    final scheme = Theme.of(context).colorScheme;
    return _PinKeyColors(
      // Клавиша — поверхность секции, служебная — подложка под секциями. Так
      // они различаются в обеих темах одинаково, а не «белая против серой».
      fill: scheme.surface,
      actionFill: context.semantic.canvas,
      // Сброс — разрушающее действие, и цвет здесь несёт смысл. Берётся
      // `scheme.error`: в тёмной теме это #FF6B6B (5.03:1), а не дневной
      // #DF3F40, который на ночной секции давал 3.27:1.
      ink: label == 'C' ? scheme.error : scheme.onSurface,
      hairline: context.semantic.hairline,
    );
  }

  final Color fill;
  final Color actionFill;
  final Color ink;
  final Color hairline;
}

class PinKeypadCompact extends StatelessWidget {
  const PinKeypadCompact({
    required this.onKeyPressed,
    this.onClear,
    this.onBackspace,
    this.enabled = true,
    super.key,
  });

  final PinKeyCallback onKeyPressed;
  final VoidCallback? onClear;
  final VoidCallback? onBackspace;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildRow(['1', '2', '3']),
        const SizedBox(height: 4),
        _buildRow(['4', '5', '6']),
        const SizedBox(height: 4),
        _buildRow(['7', '8', '9']),
        const SizedBox(height: 4),
        _buildRow(['C', '0', '⌫']),
      ],
    );
  }

  Widget _buildRow(List<String> keys) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: keys.map((key) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: _PinKeyCompact(
            label: key,
            enabled: enabled,
            onPressed: () => _handleKeyPress(key),
          ),
        );
      }).toList(),
    );
  }

  void _handleKeyPress(String key) {
    if (!enabled) return;

    if (key == 'C') {
      onClear?.call();
    } else if (key == '⌫') {
      onBackspace?.call();
    } else {
      onKeyPressed(key);
    }
  }
}

class _PinKeyCompact extends StatelessWidget {
  const _PinKeyCompact({
    required this.label,
    required this.onPressed,
    required this.enabled,
  });

  final String label;
  final VoidCallback onPressed;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final isAction = label == 'C' || label == '⌫';
    final keys = _PinKeyColors.of(context, label);

    return SizedBox(
      width: 64,
      height: 48,
      child: ElevatedButton(
        onPressed: enabled ? onPressed : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: isAction ? keys.actionFill : keys.fill,
          foregroundColor: keys.ink,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.borderRadiusSmall),
            side: BorderSide(color: keys.hairline),
          ),
          padding: EdgeInsets.zero,
        ),
        child: label == '⌫'
            ? Icon(Icons.backspace_outlined, color: keys.ink, size: 20)
            : Text(
                label,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w500,
                  color: keys.ink,
                ),
              ),
      ),
    );
  }
}

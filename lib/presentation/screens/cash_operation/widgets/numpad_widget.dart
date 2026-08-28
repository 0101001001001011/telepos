import 'package:flutter/material.dart';
import 'package:telepos/app/theme/app_semantic_colors.dart';

class NumpadWidget extends StatelessWidget {
  const NumpadWidget({
    super.key,
    required this.onDigit,
    required this.onDecimal,
    required this.onBackspace,
    required this.onClear,
    this.onQuickAmount,
    this.quickAmounts = const [],
    this.compact = false,
  });

  final void Function(int digit) onDigit;

  final VoidCallback onDecimal;

  final VoidCallback onBackspace;

  final VoidCallback onClear;

  final void Function(int amount)? onQuickAmount;

  final List<int> quickAmounts;

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (quickAmounts.isNotEmpty) ...[
          _buildQuickAmounts(),
          SizedBox(height: compact ? 8 : 12),
        ],
        _buildMainKeyboard(context),
      ],
    );
  }

  Widget _buildQuickAmounts() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: quickAmounts.map((amount) {
        return _QuickAmountButton(
          amount: amount,
          onTap: () => onQuickAmount?.call(amount),
          compact: compact,
        );
      }).toList(),
    );
  }

  Widget _buildMainKeyboard(BuildContext context) {
    final buttonSize = compact ? 56.0 : 64.0;
    final spacing = compact ? 8.0 : 12.0;

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _NumpadButton(digit: 7, onTap: () => onDigit(7), size: buttonSize),
            SizedBox(width: spacing),
            _NumpadButton(digit: 8, onTap: () => onDigit(8), size: buttonSize),
            SizedBox(width: spacing),
            _NumpadButton(digit: 9, onTap: () => onDigit(9), size: buttonSize),
          ],
        ),
        SizedBox(height: spacing),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _NumpadButton(digit: 4, onTap: () => onDigit(4), size: buttonSize),
            SizedBox(width: spacing),
            _NumpadButton(digit: 5, onTap: () => onDigit(5), size: buttonSize),
            SizedBox(width: spacing),
            _NumpadButton(digit: 6, onTap: () => onDigit(6), size: buttonSize),
          ],
        ),
        SizedBox(height: spacing),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _NumpadButton(digit: 1, onTap: () => onDigit(1), size: buttonSize),
            SizedBox(width: spacing),
            _NumpadButton(digit: 2, onTap: () => onDigit(2), size: buttonSize),
            SizedBox(width: spacing),
            _NumpadButton(digit: 3, onTap: () => onDigit(3), size: buttonSize),
          ],
        ),
        SizedBox(height: spacing),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _ActionButton(
              label: 'C',
              onTap: onClear,
              size: buttonSize,
              // Смысл несёт ЗАЛИВКА, а подпись остаётся обычным текстом.
              // Измерено, и это не вкус: жёлтый #F5A623 по жёлтому тону
              // #FDEBD0 давал **1.73:1** при пороге 4.5:1 — то есть подпись
              // «C» не читалась уже в светлой теме, до всякой тёмной. Тон из
              // роли под обычными чернилами даёт 17.31:1 в светлой и 11.02:1
              // в тёмной, а жёлтый остаётся виден — фоном.
              color: context.semantic.warning.withValues(alpha: 0.12),
            ),
            SizedBox(width: spacing),
            _NumpadButton(digit: 0, onTap: () => onDigit(0), size: buttonSize),
            SizedBox(width: spacing),
            _ActionButton(label: '.', onTap: onDecimal, size: buttonSize),
          ],
        ),
        SizedBox(height: spacing),
        SizedBox(
          width: buttonSize * 3 + spacing * 2,
          height: buttonSize * 0.75,
          child: _ActionButton(
            icon: Icons.backspace_outlined,
            onTap: onBackspace,
            size: buttonSize * 0.75,
            // Та же причина: красный #DF3F40 по красному тону #F3B2B2 —
            // **2.40:1**. Тон несёт смысл, значок остаётся читаемым.
            color: Theme.of(context).colorScheme.error.withValues(alpha: 0.12),
            fullWidth: true,
          ),
        ),
      ],
    );
  }
}

class _NumpadButton extends StatelessWidget {
  const _NumpadButton({
    required this.digit,
    required this.onTap,
    required this.size,
  });

  final int digit;
  final VoidCallback onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return SizedBox(
      width: size,
      height: size,
      child: Material(
        // Клавиша — поверхность секции, а не белый цвет. `AppColors.white`
        // здесь оставался белым и в тёмной теме, а цифра на ней —
        // `Theme.of(context).colorScheme.onSurface`, то есть клавиатура светилась белым пятном
        // посреди ночного экрана.
        color: scheme.surface,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: context.semantic.hairline),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                '$digit',
                style: TextStyle(
                  fontSize: size * 0.4,
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurface,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    this.label,
    this.icon,
    required this.onTap,
    required this.size,
    this.color,
    this.fullWidth = false,
  });

  final String? label;
  final IconData? icon;
  final VoidCallback onTap;
  final double size;
  final Color? color;
  final bool fullWidth;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // Подпись служебной клавиши — обычные чернила при любой заливке.
    // Параметра `textColor` больше нет: он существовал ровно затем, чтобы
    // красить подпись в тот же цвет, что и фон под ней, и оба вызова, которые
    // им пользовались, порога AA не брали (1.73:1 и 2.40:1).
    final ink = scheme.onSurface;

    return SizedBox(
      width: fullWidth ? null : size,
      height: size,
      child: Material(
        color: color ?? context.semantic.canvas,
        // Граница, а не только заливка. Служебная клавиша без своего тона
        // заливается подложкой, а подложка — это ровно тот цвет, на котором
        // клавиатура и стоит: клавиша «.» была невидима, и в светлой теме тоже.
        // Видно это стало на эталоне, снятом здесь впервые.
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: context.semantic.hairline),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Center(
            child: icon != null
                ? Icon(icon, size: size * 0.4, color: ink)
                : Text(
                    label ?? '',
                    style: TextStyle(
                      fontSize: size * 0.4,
                      fontWeight: FontWeight.w600,
                      color: ink,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

class _QuickAmountButton extends StatelessWidget {
  const _QuickAmountButton({
    required this.amount,
    required this.onTap,
    required this.compact,
  });

  final int amount;
  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Material(
      // Тон акцента, а не заготовленный светлый оттенок: #EAF3FD в тёмной теме
      // остался бы почти белой плашкой. Синий по синему тону давал 2.95:1 —
      // сумма на кнопке быстрого ввода не читалась и в светлой теме.
      color: scheme.primary.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 12 : 16,
            vertical: compact ? 8 : 10,
          ),
          child: Text(
            _formatAmount(amount),
            style: TextStyle(
              fontSize: compact ? 13 : 14,
              fontWeight: FontWeight.w600,
              color: scheme.onSurface,
            ),
          ),
        ),
      ),
    );
  }

  String _formatAmount(int amount) {
    if (amount >= 1000) {
      return '${amount ~/ 1000}K';
    }
    return '$amount';
  }
}

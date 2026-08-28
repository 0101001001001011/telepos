import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:telepos/app/theme/app_colors.dart';
import 'package:telepos/app/theme/app_semantic_colors.dart';
import 'package:telepos/app/theme/app_theme.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/presentation/controllers/shift/shift_controller.dart';

class TotalTab extends ConsumerStatefulWidget {
  const TotalTab({super.key, this.compact = false});

  final bool compact;

  @override
  ConsumerState<TotalTab> createState() => _TotalTabState();
}

class _TotalTabState extends ConsumerState<TotalTab> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(shiftControllerProvider);
    final notifier = ref.read(shiftControllerProvider.notifier);

    if (widget.compact) {
      return _buildCompactLayout(context, state, notifier);
    }

    return _buildFullLayout(context, state, notifier);
  }

  Widget _buildFullLayout(
    BuildContext context,
    ShiftState state,
    ShiftNotifier notifier,
  ) {
    final l10n = AppLocalizations.of(context)!;

    return Container(
      color: Theme.of(context).colorScheme.surface,
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          TextField(
            controller: _controller,
            focusNode: _focusNode,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
            ],
            style: AppTextStyles.h1,
            textAlign: TextAlign.center,
            decoration: InputDecoration(
              hintText: '0.00',
              hintStyle: AppTextStyles.h1.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: context.semantic.canvas),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: AppColors.primary,
                  width: 2,
                ),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 20,
              ),
            ),
            onChanged: (value) {
              final amount = Decimal.tryParse(value) ?? Decimal.zero;
              notifier.setManualTotal(amount);
            },
          ),

          const SizedBox(height: 24),

          _NumericKeyboard(
            onDigit: (digit) {
              final current = _controller.text;
              _controller.text = current + digit;
              _controller.selection = TextSelection.fromPosition(
                TextPosition(offset: _controller.text.length),
              );
              _updateValue(notifier);
            },
            onDecimal: () {
              if (!_controller.text.contains('.')) {
                final current = _controller.text;
                _controller.text = current.isEmpty ? '0.' : '$current.';
                _controller.selection = TextSelection.fromPosition(
                  TextPosition(offset: _controller.text.length),
                );
                _updateValue(notifier);
              }
            },
            onBackspace: () {
              final current = _controller.text;
              if (current.isNotEmpty) {
                _controller.text = current.substring(0, current.length - 1);
                _controller.selection = TextSelection.fromPosition(
                  TextPosition(offset: _controller.text.length),
                );
                _updateValue(notifier);
              }
            },
            onClear: () {
              _controller.clear();
              notifier.clearManualTotal();
            },
            clearLabel: l10n.globalClear,
          ),

          const Spacer(),

          _buildComparison(context, state),
        ],
      ),
    );
  }

  Widget _buildCompactLayout(
    BuildContext context,
    ShiftState state,
    ShiftNotifier notifier,
  ) {
    final l10n = AppLocalizations.of(context)!;

    return Column(
      children: [
        TextField(
          controller: _controller,
          focusNode: _focusNode,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
          ],
          style: AppTextStyles.h3,
          textAlign: TextAlign.center,
          decoration: InputDecoration(
            hintText: '0.00',
            hintStyle: AppTextStyles.h3.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
          ),
          onChanged: (value) {
            final amount = Decimal.tryParse(value) ?? Decimal.zero;
            notifier.setManualTotal(amount);
          },
        ),

        const SizedBox(height: 12),

        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () {
                  notifier.setManualTotal(state.systemTotal);
                  _controller.text = state.systemTotal.toStringAsFixed(2);
                },
                child: Text(l10n.shiftEqualsSystem),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton(
                onPressed: () {
                  _controller.clear();
                  notifier.clearManualTotal();
                },
                child: Text(l10n.globalClear),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildComparison(BuildContext context, ShiftState state) {
    final l10n = AppLocalizations.of(context)!;
    final diff = state.difference;
    final isPositive = diff > Decimal.zero;
    final isNegative = diff < Decimal.zero;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isNegative
            ? Theme.of(context).colorScheme.error.withValues(alpha: 0.1)
            : isPositive
            ? AppColors.success.withValues(alpha: 0.1)
            : context.semantic.canvas,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(l10n.shiftSystemTotal, style: AppTextStyles.body),
              Text(
                state.systemTotal.toStringAsFixed(2),
                style: AppTextStyles.h3,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(l10n.shiftEnteredTotal, style: AppTextStyles.body),
              Text(
                state.manualTotal.toStringAsFixed(2),
                style: AppTextStyles.h3,
              ),
            ],
          ),
          const Divider(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${l10n.shiftDifference}:',
                style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600),
              ),
              Text(
                '${isPositive ? '+' : ''}${diff.toStringAsFixed(2)}',
                style: AppTextStyles.h3.copyWith(
                  color: isNegative
                      ? Theme.of(context).colorScheme.error
                      : isPositive
                      ? AppColors.success
                      : Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _updateValue(ShiftNotifier notifier) {
    final text = _controller.text;
    if (text.isEmpty) {
      notifier.setManualTotal(Decimal.zero);
    } else {
      try {
        final amount = Decimal.parse(text);
        notifier.setManualTotal(amount);
      } catch (_) {}
    }
  }
}

class _NumericKeyboard extends StatelessWidget {
  const _NumericKeyboard({
    required this.onDigit,
    required this.onDecimal,
    required this.onBackspace,
    required this.onClear,
    required this.clearLabel,
  });

  final ValueChanged<String> onDigit;
  final VoidCallback onDecimal;
  final VoidCallback onBackspace;
  final VoidCallback onClear;
  final String clearLabel;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            _buildKey(context, '7', () => onDigit('7')),
            _buildKey(context, '8', () => onDigit('8')),
            _buildKey(context, '9', () => onDigit('9')),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _buildKey(context, '4', () => onDigit('4')),
            _buildKey(context, '5', () => onDigit('5')),
            _buildKey(context, '6', () => onDigit('6')),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _buildKey(context, '1', () => onDigit('1')),
            _buildKey(context, '2', () => onDigit('2')),
            _buildKey(context, '3', () => onDigit('3')),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _buildKey(context, '.', onDecimal),
            _buildKey(context, '0', () => onDigit('0')),
            _buildKey(context, '\u232b', onBackspace, isAction: true),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: OutlinedButton(
            onPressed: onClear,
            style: OutlinedButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: Text(clearLabel),
          ),
        ),
      ],
    );
  }

  /// [context] прокинут явно: подложка клавиши берётся из темы, а до этого
  /// метод обходился без него и красил константой — в тёмной теме клавиша
  /// оставалась белой, а подпись приходила из темы белой же.
  Widget _buildKey(
    BuildContext context,
    String label,
    VoidCallback onTap, {
    bool isAction = false,
  }) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Material(
          color: isAction
              ? context.semantic.canvas
              : Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              height: 56,
              decoration: BoxDecoration(
                border: Border.all(color: context.semantic.canvas),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text(
                  label,
                  style: AppTextStyles.h2.copyWith(
                    color: isAction
                        ? Theme.of(context).colorScheme.onSurfaceVariant
                        : Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

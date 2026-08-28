import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:telepos/app/theme/app_colors.dart';
import 'package:telepos/app/theme/app_semantic_colors.dart';
import 'package:telepos/app/theme/app_theme.dart';
import 'package:telepos/app/theme/telepos_icons.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/presentation/controllers/shift/shift_controller.dart';

class BillsTab extends ConsumerWidget {
  const BillsTab({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(shiftControllerProvider);
    final notifier = ref.read(shiftControllerProvider.notifier);

    if (compact) {
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
      child: Column(
        children: [
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: kBillDenominations.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final denomination = kBillDenominations[index];
                final count = state.billCounts[denomination] ?? 0;
                final sum = Decimal.fromInt(denomination * count);

                return _BillCounterRow(
                  denomination: denomination,
                  count: count,
                  sum: sum,
                  onIncrement: () => notifier.incrementBill(denomination),
                  onDecrement: () => notifier.decrementBill(denomination),
                  onCountChanged: (value) =>
                      notifier.setBillCount(denomination, value),
                );
              },
            ),
          ),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: context.semantic.canvas,
              border: Border(top: BorderSide(color: context.semantic.canvas)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(l10n.shiftBillsTotal, style: AppTextStyles.h3),
                Text(
                  state.billsTotal.toStringAsFixed(2),
                  style: AppTextStyles.h2.copyWith(color: AppColors.primary),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: OutlinedButton.icon(
              onPressed: () => notifier.clearBills(),
              icon: const Icon(Icons.clear_all),
              label: Text(l10n.globalClear),
              style: OutlinedButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
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
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 2.5,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
          ),
          itemCount: kBillDenominations.length,
          itemBuilder: (context, index) {
            final denomination = kBillDenominations[index];
            final count = state.billCounts[denomination] ?? 0;

            return _CompactBillCounter(
              denomination: denomination,
              count: count,
              onIncrement: () => notifier.incrementBill(denomination),
              onDecrement: () => notifier.decrementBill(denomination),
            );
          },
        ),

        const SizedBox(height: 16),

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('${l10n.globalTotal}:', style: AppTextStyles.body),
            Text(
              state.billsTotal.toStringAsFixed(2),
              style: AppTextStyles.h3.copyWith(color: AppColors.primary),
            ),
          ],
        ),
      ],
    );
  }
}

class _BillCounterRow extends StatelessWidget {
  const _BillCounterRow({
    required this.denomination,
    required this.count,
    required this.sum,
    required this.onIncrement,
    required this.onDecrement,
    required this.onCountChanged,
  });

  final int denomination;
  final int count;
  final Decimal sum;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;
  final ValueChanged<int> onCountChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              _formatDenomination(denomination),
              style: AppTextStyles.h3,
            ),
          ),

          const SizedBox(width: 16),

          Row(
            children: [
              _CounterButton(
                icon: Icons.remove,
                onPressed: count > 0 ? onDecrement : null,
              ),
              SizedBox(
                width: 60,
                child: Text(
                  count.toString(),
                  textAlign: TextAlign.center,
                  style: AppTextStyles.h3,
                ),
              ),
              _CounterButton(icon: TeleposIcons.add, onPressed: onIncrement),
            ],
          ),

          const Spacer(),

          SizedBox(
            width: 120,
            child: Text(
              sum.toStringAsFixed(2),
              textAlign: TextAlign.right,
              style: AppTextStyles.body.copyWith(
                color: count > 0
                    ? Theme.of(context).colorScheme.onSurface
                    : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDenomination(int value) {
    if (value >= 1000) {
      return '${value ~/ 1000}K';
    }
    return value.toString();
  }
}

class _CounterButton extends StatelessWidget {
  const _CounterButton({required this.icon, required this.onPressed});

  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      // Одна роль на оба состояния, а не тернарник. Он был здесь и раньше, но
      // ничего не различал: `context.semantic.canvas` и `AppColors.background` —
      // два имени одного и того же `tgCanvas`. Отключённость видна по цвету
      // значка ниже, а не по подложке.
      color: context.semantic.canvas,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          width: 40,
          height: 40,
          child: Icon(
            icon,
            color: onPressed != null
                ? Theme.of(context).colorScheme.onSurface
                : Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

class _CompactBillCounter extends StatelessWidget {
  const _CompactBillCounter({
    required this.denomination,
    required this.count,
    required this.onIncrement,
    required this.onDecrement,
  });

  final int denomination;
  final int count;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: count > 0 ? AppColors.primaryLight : context.semantic.canvas,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: count > 0 ? AppColors.primary : context.semantic.canvas,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            _formatDenomination(denomination),
            style: AppTextStyles.body.copyWith(
              fontWeight: FontWeight.w600,
              color: count > 0
                  ? AppColors.primary
                  : Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),

          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                onTap: count > 0 ? onDecrement : null,
                child: Icon(
                  Icons.remove_circle_outline,
                  size: 24,
                  color: count > 0
                      ? Theme.of(context).colorScheme.onSurfaceVariant
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              SizedBox(
                width: 32,
                child: Text(
                  count.toString(),
                  textAlign: TextAlign.center,
                  style: AppTextStyles.body.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              GestureDetector(
                onTap: onIncrement,
                child: const Icon(
                  Icons.add_circle_outline,
                  size: 24,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDenomination(int value) {
    if (value >= 1000) {
      return '${value ~/ 1000}K';
    }
    return value.toString();
  }
}

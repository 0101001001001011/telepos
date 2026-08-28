import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:telepos/app/theme/app_colors.dart';
import 'package:telepos/app/theme/app_semantic_colors.dart';
import 'package:telepos/app/theme/app_theme.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/presentation/controllers/shift/shift_controller.dart';

class CashOperationsTab extends ConsumerWidget {
  const CashOperationsTab({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(shiftControllerProvider);

    if (compact) {
      return _buildCompactLayout(context, state);
    }

    return _buildFullLayout(context, state);
  }

  Widget _buildFullLayout(BuildContext context, ShiftState state) {
    final l10n = AppLocalizations.of(context)!;

    return Container(
      color: Theme.of(context).colorScheme.surface,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: context.semantic.canvas,
            child: Row(
              children: [
                Expanded(
                  child: _SummaryCard(
                    label: l10n.shiftCashInvestments,
                    amount: state.investmentTotal.toStringAsFixed(2),
                    icon: Icons.add_circle_outline,
                    color: AppColors.success,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _SummaryCard(
                    label: l10n.shiftCashExpenses,
                    amount: state.expenseTotal.toStringAsFixed(2),
                    icon: Icons.remove_circle_outline,
                    color: AppColors.warning,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _SummaryCard(
                    label: l10n.shiftCashDividends,
                    amount: state.dividendTotal.toStringAsFixed(2),
                    icon: Icons.output,
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: state.cashOperations.isEmpty
                ? _buildEmptyState(context)
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: state.cashOperations.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final op = state.cashOperations[index];
                      return _OperationTile(operation: op);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactLayout(BuildContext context, ShiftState state) {
    final l10n = AppLocalizations.of(context)!;

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _CompactSummary(
                label: l10n.shiftCashInvestments,
                amount: state.investmentTotal.toStringAsFixed(2),
                color: AppColors.success,
              ),
            ),
            Expanded(
              child: _CompactSummary(
                label: l10n.shiftCashExpenses,
                amount: state.expenseTotal.toStringAsFixed(2),
                color: AppColors.warning,
              ),
            ),
            Expanded(
              child: _CompactSummary(
                label: l10n.shiftCashDividends,
                amount: state.dividendTotal.toStringAsFixed(2),
                color: Theme.of(context).colorScheme.error,
              ),
            ),
          ],
        ),

        if (state.cashOperations.isNotEmpty) ...[
          const SizedBox(height: 12),
          const Divider(),
          const SizedBox(height: 8),

          ...state.cashOperations
              .take(3)
              .map(
                (op) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _CompactOperationTile(operation: op),
                ),
              ),

          if (state.cashOperations.length > 3)
            Text(
              l10n.shiftMoreItems(state.cashOperations.length - 3),
              style: AppTextStyles.body.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
        ],
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.receipt_long_outlined,
            size: 64,
            color: AppColors.textDisabled,
          ),
          const SizedBox(height: 16),
          Text(
            l10n.shiftNoCashOps,
            style: AppTextStyles.body.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.shiftNoCashOpsDescription,
            textAlign: TextAlign.center,
            style: AppTextStyles.body.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.label,
    required this.amount,
    required this.icon,
    required this.color,
  });

  final String label;
  final String amount;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 8),
          Text(
            label,
            style: AppTextStyles.body.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Text(amount, style: AppTextStyles.h3.copyWith(color: color)),
        ],
      ),
    );
  }
}

class _CompactSummary extends StatelessWidget {
  const _CompactSummary({
    required this.label,
    required this.amount,
    required this.color,
  });

  final String label;
  final String amount;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: AppTextStyles.body.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          amount,
          style: AppTextStyles.body.copyWith(
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _OperationTile extends StatelessWidget {
  const _OperationTile({required this.operation});

  final CashOperationItem operation;

  @override
  Widget build(BuildContext context) {
    final color = switch (operation.type) {
      CashOperationType.investment => AppColors.success,
      CashOperationType.expense => AppColors.warning,
      CashOperationType.dividend => Theme.of(context).colorScheme.error,
    };

    final icon = switch (operation.type) {
      CashOperationType.investment => Icons.add_circle_outline,
      CashOperationType.expense => Icons.remove_circle_outline,
      CashOperationType.dividend => Icons.output,
    };

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(
        operation.localizedTypeLabel(AppLocalizations.of(context)!),
        style: AppTextStyles.body,
      ),
      subtitle: operation.note != null
          ? Text(
              operation.note!,
              style: AppTextStyles.body.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            )
          : null,
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            operation.amount.toStringAsFixed(2),
            style: AppTextStyles.body.copyWith(
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
          Text(
            _formatTime(operation.time),
            style: AppTextStyles.body.copyWith(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    final h = time.hour.toString().padLeft(2, '0');
    final m = time.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}

class _CompactOperationTile extends StatelessWidget {
  const _CompactOperationTile({required this.operation});

  final CashOperationItem operation;

  @override
  Widget build(BuildContext context) {
    final color = switch (operation.type) {
      CashOperationType.investment => AppColors.success,
      CashOperationType.expense => AppColors.warning,
      CashOperationType.dividend => Theme.of(context).colorScheme.error,
    };

    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            operation.localizedTypeLabel(AppLocalizations.of(context)!),
            style: AppTextStyles.body.copyWith(fontSize: 13),
          ),
        ),
        Text(
          operation.amount.toStringAsFixed(2),
          style: AppTextStyles.body.copyWith(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:telepos/app/theme/app_colors.dart';
import 'package:telepos/app/theme/app_theme.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/presentation/controllers/refund/refund_controller.dart';

class RefundItemsTable extends ConsumerWidget {
  const RefundItemsTable({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(refundControllerProvider);

    if (!state.hasItems) {
      return const _EmptyState();
    }

    return Column(
      children: [
        _TableHeader(
          allSelected: state.allSelected,
          onSelectAll: (selected) {
            if (selected) {
              ref.read(refundControllerProvider.notifier).selectAll();
            } else {
              ref.read(refundControllerProvider.notifier).deselectAll();
            }
          },
        ),
        const Divider(height: 1),

        Expanded(
          child: ListView.separated(
            itemCount: state.items.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final item = state.items[index];
              final isEditing = item.id == state.selectedItemId;
              return _TableRow(
                item: item,
                index: index + 1,
                isEditing: isEditing,
                onCheckChanged: (checked) {
                  ref
                      .read(refundControllerProvider.notifier)
                      .toggleItemSelection(item.id);
                },
                onTap: () {
                  ref
                      .read(refundControllerProvider.notifier)
                      .selectItem(isEditing ? null : item.id);
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _TableHeader extends StatelessWidget {
  const _TableHeader({required this.allSelected, required this.onSelectAll});

  final bool allSelected;
  final void Function(bool) onSelectAll;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacing,
        vertical: AppTheme.spacingSmall,
      ),
      color: AppColors.warningLight,
      child: Row(
        children: [
          SizedBox(
            width: 48,
            child: Checkbox(
              value: allSelected,
              onChanged: (value) => onSelectAll(value ?? false),
              activeColor: AppColors.warning,
              checkColor: AppColors.black,
            ),
          ),

          SizedBox(
            width: 40,
            child: Text('#', style: context.styles.tableHeader),
          ),

          Expanded(
            flex: 3,
            child: Text(
              l10n.refundColumnName,
              style: context.styles.tableHeader,
            ),
          ),

          SizedBox(
            width: 100,
            child: Text(
              l10n.globalPrice,
              style: context.styles.tableHeader,
              textAlign: TextAlign.right,
            ),
          ),

          SizedBox(
            width: 80,
            child: Text(
              l10n.refundColumnQty,
              style: context.styles.tableHeader,
              textAlign: TextAlign.center,
            ),
          ),

          SizedBox(
            width: 120,
            child: Text(
              l10n.globalAmount,
              style: context.styles.tableHeader,
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}

class _TableRow extends StatelessWidget {
  const _TableRow({
    required this.item,
    required this.index,
    required this.isEditing,
    required this.onCheckChanged,
    required this.onTap,
  });

  final RefundItem item;
  final int index;
  final bool isEditing;
  final void Function(bool?) onCheckChanged;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spacing,
          vertical: AppTheme.spacingSmall,
        ),
        color: isEditing
            ? AppColors.warningLight
            : (item.isSelected
                  ? AppColors.warningLight.withValues(alpha: 0.3)
                  : null),
        child: Row(
          children: [
            SizedBox(
              width: 48,
              child: Checkbox(
                value: item.isSelected,
                onChanged: onCheckChanged,
                activeColor: AppColors.warning,
                checkColor: AppColors.black,
              ),
            ),

            SizedBox(
              width: 40,
              child: Text('$index', style: AppTextStyles.tableCell),
            ),

            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: AppTextStyles.productName.copyWith(
                      color: item.isSelected
                          ? Theme.of(context).colorScheme.onSurface
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (item.barcode != null)
                    Text(item.barcode!, style: context.styles.barcode),
                ],
              ),
            ),

            SizedBox(
              width: 100,
              child: Text(
                '${item.price}',
                style: AppTextStyles.priceItem.copyWith(
                  color: item.isSelected
                      ? Theme.of(context).colorScheme.onSurface
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.right,
              ),
            ),

            SizedBox(
              width: 80,
              child: Text(
                '${item.quantity}',
                style: AppTextStyles.tableCell.copyWith(
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
            ),

            SizedBox(
              width: 120,
              child: Text(
                '${item.total}',
                style: AppTextStyles.priceTotal.copyWith(
                  fontSize: 18,
                  color: item.isSelected
                      ? AppColors.warning
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.right,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.assignment_return_outlined,
            size: 64,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: AppTheme.spacing),
          Text(
            l10n.refundNoItems,
            style: AppTextStyles.h3.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppTheme.spacingSmall),
          Text(
            l10n.refundEmptyHint,
            style: AppTextStyles.body.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

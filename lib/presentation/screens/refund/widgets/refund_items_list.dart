import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:telepos/app/theme/app_colors.dart';
import 'package:telepos/app/theme/app_theme.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/presentation/controllers/refund/refund_controller.dart';

class RefundItemsList extends ConsumerWidget {
  const RefundItemsList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(refundControllerProvider);

    if (!state.hasItems) {
      return const _EmptyState();
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: AppTheme.spacingSmall),
      itemCount: state.items.length,
      itemBuilder: (context, index) {
        final item = state.items[index];
        final isEditing = item.id == state.selectedItemId;
        return _RefundItemCard(
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
    );
  }
}

class _RefundItemCard extends StatelessWidget {
  const _RefundItemCard({
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
    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacing,
        vertical: AppTheme.spacingSmall / 2,
      ),
      color: isEditing
          ? AppColors.warningLight
          : (item.isSelected
                ? AppColors.warningLight.withValues(alpha: 0.5)
                : AppColors.white),
      elevation: isEditing ? 2 : 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.borderRadius),
        side: BorderSide(
          color: isEditing
              ? AppColors.warning
              : (item.isSelected
                    ? AppColors.warning
                    : Theme.of(context).colorScheme.outline),
          width: isEditing ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.borderRadius),
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacing),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Checkbox(
                value: item.isSelected,
                onChanged: onCheckChanged,
                activeColor: AppColors.warning,
                checkColor: AppColors.black,
              ),
              const SizedBox(width: 8),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: AppColors.warningLight,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            '$index',
                            style: context.styles.caption.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppColors.warning,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            item.name,
                            style: AppTextStyles.productName.copyWith(
                              color: item.isSelected
                                  ? Theme.of(context).colorScheme.onSurface
                                  : Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),

                    if (item.barcode != null) ...[
                      const SizedBox(height: 4),
                      Text(item.barcode!, style: context.styles.barcode),
                    ],

                    const SizedBox(height: 8),

                    Builder(
                      builder: (context) {
                        final l10n = AppLocalizations.of(context)!;
                        return Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    l10n.globalPrice,
                                    style: context.styles.caption,
                                  ),
                                  Text(
                                    '${item.price}',
                                    style: AppTextStyles.body.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Text(
                                    l10n.refundColumnQty,
                                    style: context.styles.caption,
                                  ),
                                  Text(
                                    '${item.quantity}',
                                    style: AppTextStyles.body.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    l10n.globalAmount,
                                    style: context.styles.caption,
                                  ),
                                  Text(
                                    '${item.total}',
                                    style: AppTextStyles.priceItem.copyWith(
                                      color: item.isSelected
                                          ? AppColors.warning
                                          : Theme.of(
                                              context,
                                            ).colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
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
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingLarge),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.assignment_return_outlined,
              size: 48,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: AppTheme.spacing),
            Text(
              l10n.refundNoItemsShort,
              style: AppTextStyles.h3.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppTheme.spacingSmall),
            Text(
              l10n.refundEmptyHintShort,
              style: AppTextStyles.body.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

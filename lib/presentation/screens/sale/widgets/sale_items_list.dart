import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:telepos/app/theme/app_colors.dart';
import 'package:telepos/app/theme/app_semantic_colors.dart';
import 'package:telepos/app/theme/app_theme.dart';
import 'package:telepos/app/theme/telepos_icons.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/presentation/common/widgets/scroll_assist.dart';
import 'package:telepos/presentation/controllers/sale/sale_controller.dart';

class SaleItemsList extends ConsumerStatefulWidget {
  const SaleItemsList({super.key});

  @override
  ConsumerState<SaleItemsList> createState() => _SaleItemsListState();
}

class _SaleItemsListState extends ConsumerState<SaleItemsList> {
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(saleControllerProvider);

    if (state.isEmpty) {
      return const _EmptyState();
    }

    return ScrollAssist(
      controller: _scrollController,
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.symmetric(vertical: AppTheme.spacingSmall),
        itemCount: state.items.length,
        itemBuilder: (context, index) {
          final item = state.items[index];
          final isSelected = item.id == state.selectedItemId;
          return _SaleItemCard(
            key: ValueKey(item.id),
            item: item,
            index: index + 1,
            isSelected: isSelected,
            onTap: () {
              ref
                  .read(saleControllerProvider.notifier)
                  .selectItem(isSelected ? null : item.id);
            },
            onIncrement: () {
              ref.read(saleControllerProvider.notifier).selectItem(item.id);
              ref.read(saleControllerProvider.notifier).incrementQuantity();
            },
            onDecrement: () {
              ref.read(saleControllerProvider.notifier).selectItem(item.id);
              ref.read(saleControllerProvider.notifier).decrementQuantity();
            },
          );
        },
      ),
    );
  }
}

class _SaleItemCard extends StatelessWidget {
  const _SaleItemCard({
    super.key,
    required this.item,
    required this.index,
    required this.isSelected,
    required this.onTap,
    required this.onIncrement,
    required this.onDecrement,
  });

  final SaleItem item;
  final int index;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacing,
        vertical: AppTheme.spacingSmall / 2,
      ),
      color: isSelected
          ? selectedSurfaceOf(context)
          : Theme.of(context).colorScheme.surface,
      elevation: isSelected ? 2 : 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.borderRadius),
        side: BorderSide(
          color: isSelected
              ? AppColors.primary
              : Theme.of(context).colorScheme.outline,
          width: isSelected ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.borderRadius),
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacing),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: selectedSurfaceOf(context),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '$index',
                      style: context.styles.caption.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.name,
                          style: AppTextStyles.productName,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (item.barcode != null)
                          Text(item.barcode!, style: context.styles.barcode),
                      ],
                    ),
                  ),

                  Text('${item.total}', style: AppTextStyles.priceTotal),
                ],
              ),

              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppLocalizations.of(context)!.priceLabel,
                          style: context.styles.caption,
                        ),
                        Text('${item.price}', style: AppTextStyles.priceItem),
                      ],
                    ),
                  ),

                  Row(
                    children: [
                      _QuantityButton(
                        icon: Icons.remove,
                        onPressed: onDecrement,
                      ),
                      Container(
                        width: 48,
                        alignment: Alignment.center,
                        child: Text(
                          '${item.quantity}',
                          style: AppTextStyles.h3,
                        ),
                      ),
                      _QuantityButton(
                        icon: TeleposIcons.add,
                        onPressed: onIncrement,
                      ),
                    ],
                  ),

                  if (item.discount > Decimal.zero)
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            AppLocalizations.of(context)!.discountTitle,
                            style: context.styles.caption,
                          ),
                          Text(
                            '-${item.discount}',
                            style: AppTextStyles.body.copyWith(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuantityButton extends StatelessWidget {
  const _QuantityButton({required this.icon, required this.onPressed});

  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.semantic.canvas,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          child: Icon(icon, size: 20, color: AppColors.primary),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingLarge),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.shopping_cart_outlined,
              size: 48,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: AppTheme.spacing),
            Text(
              AppLocalizations.of(context)!.emptyReceipt,
              style: AppTextStyles.h3.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppTheme.spacingSmall),
            Text(
              AppLocalizations.of(context)!.addProductsViaSearchShort,
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

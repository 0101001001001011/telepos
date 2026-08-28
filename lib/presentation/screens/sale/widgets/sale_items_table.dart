import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:telepos/app/theme/app_colors.dart';
import 'package:telepos/app/theme/app_semantic_colors.dart';
import 'package:telepos/app/theme/app_theme.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/presentation/common/widgets/scroll_assist.dart';
import 'package:telepos/presentation/controllers/sale/sale_controller.dart';

class SaleItemsTable extends ConsumerStatefulWidget {
  const SaleItemsTable({super.key});

  @override
  ConsumerState<SaleItemsTable> createState() => _SaleItemsTableState();
}

class _SaleItemsTableState extends ConsumerState<SaleItemsTable> {
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

    return Column(
      children: [
        const _TableHeader(),
        const Divider(height: 1),

        Expanded(
          child: ScrollAssist(
            controller: _scrollController,
            child: ListView.separated(
              controller: _scrollController,
              itemCount: state.items.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final item = state.items[index];
                final isSelected = item.id == state.selectedItemId;
                return _TableRow(
                  item: item,
                  index: index + 1,
                  isSelected: isSelected,
                  onTap: () {
                    ref
                        .read(saleControllerProvider.notifier)
                        .selectItem(isSelected ? null : item.id);
                  },
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _TableHeader extends StatelessWidget {
  const _TableHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacing,
        vertical: AppTheme.spacingSmall,
      ),
      color: context.semantic.canvas,
      child: Row(
        children: [
          SizedBox(
            width: 40,
            child: Text('#', style: context.styles.tableHeader),
          ),
          Expanded(
            flex: 3,
            child: Text(
              AppLocalizations.of(context)!.tableHeaderName,
              style: context.styles.tableHeader,
            ),
          ),
          SizedBox(
            width: 100,
            child: Text(
              AppLocalizations.of(context)!.tableHeaderPrice,
              style: context.styles.tableHeader,
              textAlign: TextAlign.right,
            ),
          ),
          SizedBox(
            width: 80,
            child: Text(
              AppLocalizations.of(context)!.tableHeaderQty,
              style: context.styles.tableHeader,
              textAlign: TextAlign.center,
            ),
          ),
          SizedBox(
            width: 80,
            child: Text(
              AppLocalizations.of(context)!.discountTitle,
              style: context.styles.tableHeader,
              textAlign: TextAlign.right,
            ),
          ),
          SizedBox(
            width: 120,
            child: Text(
              AppLocalizations.of(context)!.tableHeaderTotal,
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
    required this.isSelected,
    required this.onTap,
  });

  final SaleItem item;
  final int index;
  final bool isSelected;
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
        color: isSelected ? selectedSurfaceOf(context) : null,
        child: Row(
          children: [
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
                    style: AppTextStyles.productName,
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
                style: AppTextStyles.priceItem,
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
              width: 80,
              child: Text(
                item.discount > Decimal.zero ? '-${item.discount}' : '-',
                style: AppTextStyles.tableCell.copyWith(
                  color: item.discount > Decimal.zero
                      ? Theme.of(context).colorScheme.error
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.right,
              ),
            ),

            SizedBox(
              width: 120,
              child: Text(
                '${item.total}',
                style: AppTextStyles.priceTotal,
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
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.shopping_cart_outlined,
            size: 64,
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
            AppLocalizations.of(context)!.addProductsViaSearch,
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

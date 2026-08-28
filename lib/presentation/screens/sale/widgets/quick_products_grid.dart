import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';
import 'package:telepos/app/theme/app_colors.dart';
import 'package:telepos/app/theme/app_theme.dart';
import 'package:telepos/app/theme/telepos_icons.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/presentation/controllers/sale/sale_controller.dart';

class QuickProduct {
  const QuickProduct({
    required this.id,
    required this.name,
    required this.price,
    this.color,
    this.icon,
  });

  final int id;
  final String name;
  final Decimal price;
  final Color? color;
  final IconData? icon;
}

class QuickProductCategory {
  const QuickProductCategory({required this.id, required this.name});

  final int id;
  final String name;
}

final quickProductCategoriesProvider =
    FutureProvider<List<QuickProductCategory>>((ref) async {
      final db = GetIt.I<AppDatabase>();
      final all = await db.quickProductDao.findAllByParents();
      return all
          .where((qp) => qp.ucode == null && qp.name != null)
          .map((qp) => QuickProductCategory(id: qp.id, name: qp.name!))
          .toList();
    });

final quickProductsByGroupProvider =
    FutureProvider.family<List<QuickProduct>, int?>((ref, parentId) async {
      final db = GetIt.I<AppDatabase>();

      final items = parentId == null
          ? (await db.quickProductDao.findAllByParents())
                .where((qp) => qp.ucode != null)
                .toList()
          : await db.quickProductDao.findAllByParentId(parentId);

      final result = <QuickProduct>[];
      for (final qp in items) {
        if (qp.ucode == null) continue;

        final price = await db.productPriceDao.findByUcode(qp.ucode!);
        final info = await db.productInfoDao.findByIdAndNotDeleted(qp.ucode!);
        if (info == null) continue;

        result.add(
          QuickProduct(
            id: qp.ucode!,
            name: qp.name ?? info.name,
            price: price?.sellingPrice ?? Decimal.zero,
          ),
        );
      }
      return result;
    });

final quickProductsProvider = FutureProvider<List<QuickProduct>>((ref) async {
  final db = GetIt.I<AppDatabase>();
  final quickProducts = await db.quickProductDao.findAllByParents();

  final result = <QuickProduct>[];
  for (final qp in quickProducts) {
    if (qp.ucode == null) continue;

    final price = await db.productPriceDao.findByUcode(qp.ucode!);
    final info = await db.productInfoDao.findByIdAndNotDeleted(qp.ucode!);
    if (info == null) continue;

    result.add(
      QuickProduct(
        id: qp.ucode!,
        name: qp.name ?? info.name,
        price: price?.sellingPrice ?? Decimal.zero,
      ),
    );
  }
  return result;
});

class QuickProductsGrid extends ConsumerStatefulWidget {
  const QuickProductsGrid({
    this.crossAxisCount = 3,
    this.onClose,
    this.compact = false,
    super.key,
  });

  final int crossAxisCount;
  final VoidCallback? onClose;
  final bool compact;

  @override
  ConsumerState<QuickProductsGrid> createState() => _QuickProductsGridState();
}

class _QuickProductsGridState extends ConsumerState<QuickProductsGrid> {
  int? _selectedCategoryId;

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(quickProductCategoriesProvider);
    final productsAsync = ref.watch(
      quickProductsByGroupProvider(_selectedCategoryId),
    );

    return Container(
      padding: EdgeInsets.all(widget.compact ? 8 : AppTheme.spacing),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.borderRadius),
        border: Border.all(color: Theme.of(context).colorScheme.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: widget.compact ? MainAxisSize.max : MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(Icons.grid_view, size: 20, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(
                AppLocalizations.of(context)!.quickProductTitle,
                style: AppTextStyles.h3,
              ),
              const Spacer(),
              if (widget.onClose != null)
                IconButton(
                  onPressed: widget.onClose,
                  icon: const Icon(TeleposIcons.close),
                  iconSize: 20,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                ),
            ],
          ),

          categoriesAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
            data: (categories) {
              if (categories.isEmpty) {
                return const SizedBox(height: AppTheme.spacing);
              }
              return _CategoryChips(
                categories: categories,
                selectedId: _selectedCategoryId,
                onSelected: (id) => setState(() => _selectedCategoryId = id),
              );
            },
          ),

          productsAsync.when(
            loading: () {
              const loader = Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator(),
                ),
              );
              return widget.compact ? const Expanded(child: loader) : loader;
            },
            error: (e, _) => widget.compact
                ? Expanded(
                    child: Center(
                      child: Text(
                        '$e',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  )
                : Center(
                    child: Text(
                      '$e',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
            data: (products) {
              if (products.isEmpty) {
                final empty = Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      AppLocalizations.of(context)!.catalogNoProducts,
                      style: context.styles.caption,
                    ),
                  ),
                );
                return widget.compact ? Expanded(child: empty) : empty;
              }
              final grid = GridView.builder(
                shrinkWrap: !widget.compact,
                physics: widget.compact
                    ? const AlwaysScrollableScrollPhysics()
                    : const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: widget.crossAxisCount,
                  crossAxisSpacing: 4,
                  mainAxisSpacing: 4,
                  childAspectRatio: widget.compact ? 1.4 : 1,
                ),
                itemCount: products.length,
                itemBuilder: (context, index) {
                  final product = products[index];
                  return _QuickProductButton(
                    product: product,
                    compact: widget.compact,
                    onTap: () {
                      ref
                          .read(saleControllerProvider.notifier)
                          .addProduct(
                            ProductSearchResult(
                              id: product.id,
                              name: product.name,
                              price: product.price,
                            ),
                          );
                    },
                  );
                },
              );
              return widget.compact ? Expanded(child: grid) : grid;
            },
          ),
        ],
      ),
    );
  }
}

class _CategoryChips extends StatelessWidget {
  const _CategoryChips({
    required this.categories,
    required this.selectedId,
    required this.onSelected,
  });

  final List<QuickProductCategory> categories;
  final int? selectedId;
  final ValueChanged<int?> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(l10n.catalogAllCategories),
              selected: selectedId == null,
              onSelected: (_) => onSelected(null),
            ),
          ),
          ...categories.map(
            (cat) => Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(cat.name),
                selected: selectedId == cat.id,
                onSelected: (_) => onSelected(cat.id),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickProductButton extends StatelessWidget {
  const _QuickProductButton({
    required this.product,
    required this.onTap,
    this.compact = false,
  });

  final QuickProduct product;
  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final color = product.color ?? AppColors.primary;

    if (compact) {
      return Material(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(6),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  product.name,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${product.price}',
                  style: TextStyle(
                    fontSize: 10,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Material(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(AppTheme.borderRadius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.borderRadius),
        child: Container(
          padding: const EdgeInsets.all(AppTheme.spacingSmall),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(product.icon ?? Icons.inventory_2, size: 28, color: color),
              const SizedBox(height: 4),

              Text(
                product.name,
                style: AppTextStyles.body.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),

              Text('${product.price}', style: context.styles.caption),
            ],
          ),
        ),
      ),
    );
  }
}

class QuickProductsDialog extends ConsumerStatefulWidget {
  const QuickProductsDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const QuickProductsDialog(),
    );
  }

  @override
  ConsumerState<QuickProductsDialog> createState() =>
      _QuickProductsDialogState();
}

class _QuickProductsDialogState extends ConsumerState<QuickProductsDialog> {
  int? _selectedCategoryId;

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(quickProductCategoriesProvider);
    final productsAsync = ref.watch(
      quickProductsByGroupProvider(_selectedCategoryId),
    );

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppTheme.borderRadiusLarge),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.outline,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(AppTheme.spacing),
            child: Row(
              children: [
                const Icon(Icons.grid_view, size: 20, color: AppColors.primary),
                const SizedBox(width: 8),
                Text(
                  AppLocalizations.of(context)!.quickProductTitle,
                  style: AppTextStyles.h3,
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(TeleposIcons.close),
                ),
              ],
            ),
          ),

          categoriesAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
            data: (categories) {
              if (categories.isEmpty) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.spacing,
                ),
                child: _CategoryChips(
                  categories: categories,
                  selectedId: _selectedCategoryId,
                  onSelected: (id) => setState(() => _selectedCategoryId = id),
                ),
              );
            },
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppTheme.spacing,
              0,
              AppTheme.spacing,
              AppTheme.spacing,
            ),
            child: productsAsync.when(
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator(),
                ),
              ),
              error: (e, _) => Center(
                child: Text(
                  '$e',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
              data: (products) {
                if (products.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        AppLocalizations.of(context)!.catalogNoProducts,
                        style: context.styles.caption,
                      ),
                    ),
                  );
                }
                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: AppTheme.spacingSmall,
                    mainAxisSpacing: AppTheme.spacingSmall,
                    childAspectRatio: 1,
                  ),
                  itemCount: products.length,
                  itemBuilder: (context, index) {
                    final product = products[index];
                    return _QuickProductButton(
                      product: product,
                      onTap: () {
                        ref
                            .read(saleControllerProvider.notifier)
                            .addProduct(
                              ProductSearchResult(
                                id: product.id,
                                name: product.name,
                                price: product.price,
                              ),
                            );
                        Navigator.of(context).pop();
                      },
                    );
                  },
                );
              },
            ),
          ),

          SizedBox(height: MediaQuery.of(context).padding.bottom),
        ],
      ),
    );
  }
}

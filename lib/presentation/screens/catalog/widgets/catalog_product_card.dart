import 'package:flutter/material.dart';
import 'package:telepos/app/theme/app_colors.dart';
import 'package:telepos/app/theme/app_theme.dart';
import 'package:telepos/app/theme/telepos_icons.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/presentation/controllers/catalog/catalog_controller.dart';

class CatalogProductCard extends StatelessWidget {
  const CatalogProductCard({
    required this.item,
    required this.onTap,
    required this.onToggleQuick,
    required this.onDelete,
    required this.onRestore,
    this.onPrintLabel,
    super.key,
  });

  final CatalogItem item;
  final VoidCallback onTap;
  final VoidCallback onToggleQuick;
  final VoidCallback onDelete;
  final VoidCallback onRestore;
  final VoidCallback? onPrintLabel;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.borderRadius),
        side: BorderSide(
          color: item.isDeleted
              ? Theme.of(context).colorScheme.error.withValues(alpha: 0.3)
              : Theme.of(context).colorScheme.outline,
        ),
      ),
      color: item.isDeleted
          ? Theme.of(context).colorScheme.error.withValues(alpha: 0.05)
          : Theme.of(context).colorScheme.surface,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.borderRadius),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              _TypeBadge(type: item.type),
              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.name,
                            style: AppTextStyles.body.copyWith(
                              fontWeight: FontWeight.w600,
                              decoration: item.isDeleted
                                  ? TextDecoration.lineThrough
                                  : null,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (item.isQuickProduct)
                          const Padding(
                            padding: EdgeInsets.only(left: 4),
                            child: Icon(
                              Icons.flash_on,
                              size: 16,
                              color: AppColors.warning,
                            ),
                          ),
                        if (item.isDeleted)
                          Padding(
                            padding: const EdgeInsets.only(left: 4),
                            child: Text(
                              l10n.catalogDeleted,
                              style: context.styles.caption.copyWith(
                                color: Theme.of(context).colorScheme.error,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text('${item.barcode}', style: context.styles.caption),
                  ],
                ),
              ),

              if (item.type != 4 && item.type != 5) ...[
                const SizedBox(width: 8),
                SizedBox(
                  width: 60,
                  child: Text(
                    '${item.quantity ?? 0}',
                    style: AppTextStyles.body.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
              ],

              const SizedBox(width: 8),
              SizedBox(
                width: 80,
                child: Text(
                  '${item.sellingPrice}',
                  style: AppTextStyles.body.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                  textAlign: TextAlign.right,
                ),
              ),

              const SizedBox(width: 4),
              PopupMenuButton<String>(
                padding: EdgeInsets.zero,
                iconSize: 20,
                onSelected: (value) {
                  switch (value) {
                    case 'edit':
                      onTap();
                    case 'quick':
                      onToggleQuick();
                    case 'print':
                      onPrintLabel?.call();
                    case 'delete':
                      onDelete();
                    case 'restore':
                      onRestore();
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        const Icon(Icons.edit, size: 18),
                        const SizedBox(width: 8),
                        Text(l10n.catalogEditProduct),
                      ],
                    ),
                  ),
                  if (onPrintLabel != null && !item.isDeleted)
                    PopupMenuItem(
                      value: 'print',
                      child: Row(
                        children: [
                          const Icon(Icons.label_outline, size: 18),
                          const SizedBox(width: 8),
                          Text(l10n.catalogPrintLabel),
                        ],
                      ),
                    ),
                  PopupMenuItem(
                    value: 'quick',
                    child: Row(
                      children: [
                        Icon(
                          item.isQuickProduct
                              ? Icons.flash_off
                              : Icons.flash_on,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          item.isQuickProduct
                              ? l10n.catalogRemoveFromQuick
                              : l10n.catalogAddToQuick,
                        ),
                      ],
                    ),
                  ),
                  if (item.isDeleted)
                    PopupMenuItem(
                      value: 'restore',
                      child: Row(
                        children: [
                          const Icon(
                            Icons.restore,
                            size: 18,
                            color: AppColors.success,
                          ),
                          const SizedBox(width: 8),
                          Text(l10n.catalogRestoreProduct),
                        ],
                      ),
                    )
                  else
                    PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(
                            Icons.delete,
                            size: 18,
                            color: Theme.of(context).colorScheme.error,
                          ),
                          const SizedBox(width: 8),
                          Text(l10n.catalogDeleteProduct),
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

class _TypeBadge extends StatelessWidget {
  const _TypeBadge({required this.type});

  final int type;

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (type) {
      1 => (Icons.scale, AppColors.info),
      2 => (Icons.inventory, Theme.of(context).colorScheme.onSurfaceVariant),
      3 => (Icons.all_inbox, AppColors.warning),
      4 => (Icons.build, AppColors.primary),
      5 => (Icons.handyman, AppColors.info),
      6 => (Icons.restaurant, Colors.deepOrange),
      _ => (Icons.shopping_bag, AppColors.success),
    };

    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, size: 20, color: color),
    );
  }
}

class CatalogProductRow {
  const CatalogProductRow._();

  static DataRow build({
    required BuildContext context,
    required CatalogItem item,
    required VoidCallback onTap,
    required VoidCallback onToggleQuick,
    required VoidCallback onDelete,
    required VoidCallback onRestore,
    VoidCallback? onPrintLabel,
  }) {
    final l10n = AppLocalizations.of(context)!;

    final typeLabel = switch (item.type) {
      0 => l10n.catalogTypeNormal,
      1 => l10n.catalogTypeWeight,
      2 => l10n.catalogTypeInner,
      3 => l10n.catalogTypePackage,
      4 => l10n.catalogTypeService,
      5 => l10n.catalogTypeConsumable,
      6 => l10n.catalogTypeDish,
      _ => '?',
    };

    return DataRow(
      color: WidgetStateProperty.resolveWith((states) {
        if (item.isDeleted)
          return Theme.of(context).colorScheme.error.withValues(alpha: 0.05);
        return null;
      }),
      cells: [
        DataCell(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Flexible, а не голый Text: `DataTable` при нехватке ширины
              // сжимает колонки, и название товара обязано сжиматься вместе с
              // колонкой. Без этого ячейка переполнялась, как только окно
              // становилось уже — и держалось оно лишь на том, что окна уже
              // никто не открывал. Найдено, когда левая колонка оболочки
              // забрала 260 точек: переполнение на 9.4 точки, семь
              // сценариев каталога.
              Flexible(
                child: Text(
                  item.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    decoration: item.isDeleted
                        ? TextDecoration.lineThrough
                        : null,
                  ),
                ),
              ),
              if (item.isQuickProduct)
                const Padding(
                  padding: EdgeInsets.only(left: 4),
                  child: Icon(
                    Icons.flash_on,
                    size: 14,
                    color: AppColors.warning,
                  ),
                ),
            ],
          ),
          onTap: onTap,
        ),
        DataCell(Text('${item.barcode}')),
        DataCell(Text(typeLabel)),
        DataCell(
          Text(
            '${item.sellingPrice}',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        DataCell(
          Text(
            item.type != 4 && item.type != 5 ? '${item.quantity ?? 0}' : '-',
          ),
        ),
        DataCell(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: Icon(
                  item.isQuickProduct ? Icons.flash_off : Icons.flash_on,
                  size: 18,
                ),
                onPressed: onToggleQuick,
                tooltip: item.isQuickProduct
                    ? l10n.catalogRemoveFromQuick
                    : l10n.catalogAddToQuick,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
              if (onPrintLabel != null && !item.isDeleted)
                IconButton(
                  icon: const Icon(Icons.label_outline, size: 18),
                  onPressed: onPrintLabel,
                  tooltip: l10n.catalogPrintLabel,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                ),
              if (item.isDeleted)
                IconButton(
                  icon: const Icon(
                    Icons.restore,
                    size: 18,
                    color: AppColors.success,
                  ),
                  onPressed: onRestore,
                  tooltip: l10n.catalogRestoreProduct,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                )
              else
                IconButton(
                  icon: Icon(
                    TeleposIcons.delete,
                    size: 18,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  onPressed: onDelete,
                  tooltip: l10n.catalogDeleteProduct,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

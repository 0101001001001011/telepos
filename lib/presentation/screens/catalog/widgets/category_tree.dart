import 'package:flutter/material.dart';
import 'package:telepos/app/theme/app_colors.dart';
import 'package:telepos/app/theme/app_semantic_colors.dart';
import 'package:telepos/app/theme/app_theme.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/presentation/controllers/catalog/catalog_controller.dart';

class CategoryTree extends StatelessWidget {
  const CategoryTree({
    required this.categories,
    required this.selectedCategoryId,
    required this.onCategorySelected,
    required this.isExpanded,
    required this.onToggleExpanded,
    this.onManageCategories,
    super.key,
  });

  final List<CategoryInfo> categories;
  final int? selectedCategoryId;
  final ValueChanged<int?> onCategorySelected;
  final bool isExpanded;
  final VoidCallback onToggleExpanded;
  final VoidCallback? onManageCategories;

  int get _totalProductCount =>
      categories.fold<int>(0, (sum, c) => sum + c.productCount);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    final roots = categories.where((c) => c.parentId == null).toList();

    final expandedWidth = 250.0;
    final collapsedWidth = 56.0;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      width: isExpanded ? expandedWidth : collapsedWidth,
      decoration: BoxDecoration(
        color: context.semantic.canvas,
        border: Border(
          right: BorderSide(color: Theme.of(context).colorScheme.outline),
        ),
      ),
      clipBehavior: Clip.hardEdge,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(l10n),
          Divider(height: 1, color: Theme.of(context).colorScheme.outline),

          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 4),
              children: [
                _CategoryTile(
                  label: l10n.catalogAllCategories,
                  icon: Icons.inventory_2_outlined,
                  isSelected: selectedCategoryId == null,
                  isExpanded: isExpanded,
                  productCount: _totalProductCount,
                  onTap: () => onCategorySelected(null),
                ),

                if (roots.isEmpty && isExpanded)
                  Padding(
                    padding: const EdgeInsets.all(AppTheme.spacing),
                    child: Text(
                      l10n.catalogNoCategories,
                      style: context.styles.caption,
                    ),
                  )
                else
                  ...roots.map((cat) => _buildCategoryTree(cat, 0)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(AppLocalizations l10n) {
    return SizedBox(
      height: 52,
      child: isExpanded
          ? Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.catalogCategories,
                      style: AppTextStyles.h3,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (onManageCategories != null)
                    IconButton(
                      icon: const Icon(Icons.settings, size: 18),
                      onPressed: onManageCategories,
                      tooltip: l10n.catalogManageCategories,
                      splashRadius: 18,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 32,
                        minHeight: 32,
                      ),
                    ),
                  IconButton(
                    icon: const Icon(Icons.chevron_left, size: 20),
                    onPressed: onToggleExpanded,
                    tooltip: l10n.catCollapse,
                    splashRadius: 18,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                  ),
                ],
              ),
            )
          : Center(
              child: IconButton(
                icon: const Icon(Icons.chevron_right, size: 20),
                onPressed: onToggleExpanded,
                tooltip: l10n.catalogCategories,
                splashRadius: 18,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
            ),
    );
  }

  Widget _buildCategoryTree(CategoryInfo cat, int depth) {
    final children = categories.where((c) => c.parentId == cat.id).toList();
    final hasChildren = children.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _CategoryTile(
          label: cat.name,
          icon: selectedCategoryId == cat.id
              ? Icons.folder_open
              : (hasChildren ? Icons.folder_outlined : Icons.label_outline),
          isSelected: selectedCategoryId == cat.id,
          isExpanded: isExpanded,
          indent: depth,
          productCount: cat.productCount,
          onTap: () => onCategorySelected(cat.id),
        ),
        ...children.map((child) => _buildCategoryTree(child, depth + 1)),
      ],
    );
  }
}

class _CategoryTile extends StatefulWidget {
  const _CategoryTile({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.isExpanded,
    required this.onTap,
    this.indent = 0,
    this.productCount = 0,
  });

  final String label;
  final IconData icon;
  final bool isSelected;
  final bool isExpanded;
  final VoidCallback onTap;
  final int indent;
  final int productCount;

  @override
  State<_CategoryTile> createState() => _CategoryTileState();
}

class _CategoryTileState extends State<_CategoryTile> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final isSelected = widget.isSelected;
    final isExpanded = widget.isExpanded;

    final backgroundColor = isSelected
        ? AppColors.primary.withValues(alpha: 0.1)
        : _hovering
        ? context.semantic.canvas
        : Colors.transparent;

    if (!isExpanded) {
      return Tooltip(
        message: '${widget.label} (${widget.productCount})',
        waitDuration: const Duration(milliseconds: 300),
        child: MouseRegion(
          onEnter: (_) => setState(() => _hovering = true),
          onExit: (_) => setState(() => _hovering = false),
          child: InkWell(
            onTap: widget.onTap,
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                color: backgroundColor,
                border: isSelected
                    ? const Border(
                        left: BorderSide(color: AppColors.primary, width: 4),
                      )
                    : null,
              ),
              alignment: Alignment.center,
              child: Icon(
                widget.icon,
                size: 20,
                color: isSelected
                    ? AppColors.primary
                    : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      );
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: InkWell(
        onTap: widget.onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 48),
          decoration: BoxDecoration(
            color: backgroundColor,
            border: isSelected
                ? const Border(
                    left: BorderSide(color: AppColors.primary, width: 4),
                  )
                : null,
          ),
          padding: EdgeInsets.only(
            left: isSelected
                ? 12.0 + widget.indent * 16.0
                : 16.0 + widget.indent * 16.0,
            right: 12,
            top: 12,
            bottom: 12,
          ),
          child: Row(
            children: [
              Icon(
                widget.icon,
                size: 18,
                color: isSelected
                    ? AppColors.primary
                    : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  widget.label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isSelected
                        ? FontWeight.w600
                        : FontWeight.normal,
                    color: isSelected
                        ? AppColors.primary
                        : Theme.of(context).colorScheme.onSurface,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.primary.withValues(alpha: 0.15)
                      : context.semantic.canvas,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${widget.productCount}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: isSelected
                        ? AppColors.primary
                        : Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:telepos/app/theme/app_colors.dart';
import 'package:telepos/app/theme/app_semantic_colors.dart';
import 'package:telepos/app/theme/app_theme.dart';
import 'package:telepos/app/theme/telepos_icons.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/l10n/app_localizations.dart';

const _categoryColors = [
  Color(0xFF1ABC9C),
  Color(0xFF3498DB),
  Color(0xFFE74C3C),
  Color(0xFFF39C12),
  Color(0xFF9B59B6),
  Color(0xFF2ECC71),
  Color(0xFFE91E63),
  Color(0xFF00BCD4),
];

class _MenuCategoryItem {
  _MenuCategoryItem({
    required this.quickProduct,
    required this.itemCount,
    required this.colorIndex,
  });

  final QuickProduct quickProduct;
  final int itemCount;
  final int colorIndex;

  String get displayName => quickProduct.name ?? 'Category #${quickProduct.id}';
  Color get color => _categoryColors[colorIndex % _categoryColors.length];
}

class MenuCategoryEditorDialog extends StatefulWidget {
  const MenuCategoryEditorDialog({super.key});

  static Future<bool?> show(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (context) => const MenuCategoryEditorDialog(),
    );
  }

  @override
  State<MenuCategoryEditorDialog> createState() =>
      _MenuCategoryEditorDialogState();
}

class _MenuCategoryEditorDialogState extends State<MenuCategoryEditorDialog> {
  final _db = GetIt.I<AppDatabase>();

  List<_MenuCategoryItem> _categories = [];
  bool _isLoading = true;
  bool _hasChanges = false;

  bool _showAddForm = false;
  final _addNameController = TextEditingController();

  int? _editingId;
  final _editNameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  @override
  void dispose() {
    _addNameController.dispose();
    _editNameController.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    setState(() => _isLoading = true);

    final roots = await _db.quickProductDao.findAllByParents(limit: 10000);
    final folders = roots.where((qp) => qp.ucode == null).toList();

    final items = <_MenuCategoryItem>[];
    for (var i = 0; i < folders.length; i++) {
      final folder = folders[i];
      final count = await _db.quickProductDao.countByParentActive(folder.id);
      items.add(
        _MenuCategoryItem(
          quickProduct: folder,
          itemCount: count,
          colorIndex: i,
        ),
      );
    }

    setState(() {
      _categories = items;
      _isLoading = false;
    });
  }

  Future<void> _addCategory() async {
    final name = _addNameController.text.trim();
    if (name.isEmpty) return;

    await _db.quickProductDao.createCategory(name: name);

    _addNameController.clear();
    _hasChanges = true;

    setState(() => _showAddForm = false);
    await _loadCategories();
  }

  Future<void> _saveEdit(int id) async {
    final name = _editNameController.text.trim();
    if (name.isEmpty) return;

    await _db.quickProductDao.updateCategoryName(id, name);

    _hasChanges = true;
    setState(() => _editingId = null);
    await _loadCategories();
  }

  Future<void> _deleteCategory(_MenuCategoryItem item) async {
    if (item.itemCount > 0) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.catalogCategoryHasProducts),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
      return;
    }

    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.globalDelete),
        content: Text(
          '${l10n.catalogConfirmDeleteCategory} "${item.displayName}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.globalCancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: AppColors.white,
            ),
            child: Text(l10n.globalDelete),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _db.quickProductDao.removeQuickProduct(item.quickProduct.id);
      _hasChanges = true;
      await _loadCategories();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    final screenSize = MediaQuery.sizeOf(context);
    return Dialog(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: math.min(500.0, screenSize.width - 48),
          maxHeight: math.min(600.0, screenSize.height - 80),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(AppTheme.spacing),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: Theme.of(context).colorScheme.outline,
                  ),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.restaurant_menu, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Text(l10n.catalogMenuCategories, style: AppTextStyles.h3),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(TeleposIcons.close),
                    onPressed: () => Navigator.of(context).pop(_hasChanges),
                    constraints: const BoxConstraints(
                      minWidth: AppTheme.minButtonSize,
                      minHeight: AppTheme.minButtonSize,
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _categories.isEmpty
                  ? Center(
                      child: Text(
                        l10n.catalogNoCategories,
                        style: AppTextStyles.body.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    )
                  : ReorderableListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      itemCount: _categories.length,
                      onReorder: _onReorder,
                      itemBuilder: (context, index) =>
                          _buildCategoryRow(_categories[index], index),
                    ),
            ),

            if (_showAddForm) _buildAddForm(l10n),

            Container(
              padding: const EdgeInsets.all(AppTheme.spacing),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: Theme.of(context).colorScheme.outline),
                ),
              ),
              child: SizedBox(
                width: double.infinity,
                height: AppTheme.buttonHeightLarge,
                child: ElevatedButton.icon(
                  onPressed: () {
                    setState(() => _showAddForm = !_showAddForm);
                  },
                  icon: Icon(
                    _showAddForm ? TeleposIcons.close : TeleposIcons.add,
                  ),
                  label: Text(
                    _showAddForm ? l10n.globalCancel : l10n.catalogAddCategory,
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _showAddForm
                        ? Theme.of(context).colorScheme.onSurfaceVariant
                        : AppColors.success,
                    foregroundColor: AppColors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryRow(_MenuCategoryItem item, int index) {
    final isEditing = _editingId == item.quickProduct.id;

    return Container(
      key: ValueKey(item.quickProduct.id),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).colorScheme.outline,
            width: 0.5,
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Row(
          children: [
            Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: item.color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 12),

            Expanded(
              child: isEditing
                  ? TextField(
                      controller: _editNameController,
                      autofocus: true,
                      style: AppTextStyles.body,
                      decoration: const InputDecoration(
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 8,
                        ),
                        border: OutlineInputBorder(),
                      ),
                      onSubmitted: (_) => _saveEdit(item.quickProduct.id),
                    )
                  : Text(
                      item.displayName,
                      style: AppTextStyles.body,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
            ),

            const SizedBox(width: 8),

            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: context.semantic.canvas,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text('${item.itemCount}', style: context.styles.caption),
            ),

            const SizedBox(width: 4),

            if (isEditing) ...[
              IconButton(
                icon: const Icon(
                  TeleposIcons.check,
                  size: 20,
                  color: AppColors.success,
                ),
                onPressed: () => _saveEdit(item.quickProduct.id),
                constraints: const BoxConstraints(
                  minWidth: AppTheme.minButtonSize,
                  minHeight: AppTheme.minButtonSize,
                ),
              ),
              IconButton(
                icon: Icon(
                  TeleposIcons.close,
                  size: 20,
                  color: Theme.of(context).colorScheme.error,
                ),
                onPressed: () => setState(() => _editingId = null),
                constraints: const BoxConstraints(
                  minWidth: AppTheme.minButtonSize,
                  minHeight: AppTheme.minButtonSize,
                ),
              ),
            ] else ...[
              IconButton(
                icon: const Icon(Icons.edit_outlined, size: 20),
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                onPressed: () {
                  setState(() {
                    _editingId = item.quickProduct.id;
                    _editNameController.text = item.displayName;
                  });
                },
                constraints: const BoxConstraints(
                  minWidth: AppTheme.minButtonSize,
                  minHeight: AppTheme.minButtonSize,
                ),
              ),
              IconButton(
                icon: const Icon(TeleposIcons.delete, size: 20),
                color: item.itemCount > 0
                    ? AppColors.textDisabled
                    : Theme.of(context).colorScheme.error,
                onPressed: item.itemCount > 0
                    ? null
                    : () => _deleteCategory(item),
                constraints: const BoxConstraints(
                  minWidth: AppTheme.minButtonSize,
                  minHeight: AppTheme.minButtonSize,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAddForm(AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacing),
      decoration: BoxDecoration(
        color: context.semantic.canvas,
        border: Border(
          top: BorderSide(color: Theme.of(context).colorScheme.outline),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.catalogAddCategory,
            style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _addNameController,
            autofocus: true,
            decoration: InputDecoration(
              labelText: l10n.catalogCategoryName,
              border: const OutlineInputBorder(),
              isDense: true,
            ),
            onSubmitted: (_) => _addCategory(),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            height: AppTheme.buttonHeight,
            child: ElevatedButton(
              onPressed: _addCategory,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.white,
              ),
              child: Text(l10n.globalSave),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _onReorder(int oldIndex, int newIndex) async {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    setState(() {
      final item = _categories.removeAt(oldIndex);
      _categories.insert(newIndex, item);
    });

    for (var i = 0; i < _categories.length; i++) {
      await _db.quickProductDao.reorder(_categories[i].quickProduct.id, i);
    }
    _hasChanges = true;
  }
}

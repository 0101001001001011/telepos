import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:telepos/app/theme/app_colors.dart';
import 'package:telepos/app/theme/app_semantic_colors.dart';
import 'package:telepos/app/theme/app_theme.dart';
import 'package:telepos/app/theme/telepos_icons.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/l10n/app_localizations.dart';

class _CategoryNode {
  _CategoryNode({
    required this.category,
    required this.productCount,
    this.depth = 0,
  });

  final Category category;
  final int productCount;
  final int depth;

  String get displayName => category.name ?? 'Category #${category.id}';
}

class CategoryEditorDialog extends StatefulWidget {
  const CategoryEditorDialog({super.key});

  static Future<bool?> show(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (context) => const CategoryEditorDialog(),
    );
  }

  @override
  State<CategoryEditorDialog> createState() => _CategoryEditorDialogState();
}

class _CategoryEditorDialogState extends State<CategoryEditorDialog> {
  final _db = GetIt.I<AppDatabase>();

  List<_CategoryNode> _flatNodes = [];
  bool _isLoading = true;
  bool _hasChanges = false;

  bool _showAddForm = false;
  final _addNameController = TextEditingController();
  int? _addParentId;

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

    final allCategories = await _db.categoryDao.findAll(limit: 10000);

    final roots = allCategories.where((c) => c.parentId == null).toList();

    final orderedList = <_CategoryNode>[];
    for (final root in roots) {
      await _flattenInto(orderedList, root, 0, allCategories);
    }

    final allIds = allCategories.map((c) => c.id).toSet();
    final orphans = allCategories
        .where((c) => c.parentId != null && !allIds.contains(c.parentId))
        .toList();
    for (final orphan in orphans) {
      await _flattenInto(orderedList, orphan, 0, allCategories);
    }

    setState(() {
      _flatNodes = orderedList;
      _isLoading = false;
    });
  }

  Future<void> _flattenInto(
    List<_CategoryNode> result,
    Category cat,
    int depth,
    List<Category> all,
  ) async {
    final count = await _db.productInfoDao.countFiltered(categoryId: cat.id);
    final children = all.where((c) => c.parentId == cat.id).toList();

    result.add(_CategoryNode(category: cat, productCount: count, depth: depth));

    for (final child in children) {
      await _flattenInto(result, child, depth + 1, all);
    }
  }

  Future<void> _addCategory() async {
    final name = _addNameController.text.trim();
    if (name.isEmpty) return;

    final all = await _db.categoryDao.findAll(limit: 10000);
    final maxId = all.isEmpty
        ? 0
        : all.map((c) => c.id).reduce((a, b) => a > b ? a : b);
    final newId = maxId + 1;

    await _db.categoryDao.upsertCategory(
      id: newId,
      parentId: _addParentId,
      name: name,
      createTime: DateTime.now(),
      editTime: DateTime.now(),
    );

    _addNameController.clear();
    _addParentId = null;
    _hasChanges = true;

    setState(() => _showAddForm = false);
    await _loadCategories();
  }

  Future<void> _saveEdit(int id) async {
    final name = _editNameController.text.trim();
    if (name.isEmpty) return;

    final existing = await _db.categoryDao.findById(id);
    if (existing == null) return;

    await _db.categoryDao.upsertCategory(
      id: id,
      parentId: existing.parentId,
      name: name,
      globalCategory: existing.globalCategory,
      createTime: existing.createTime,
      editTime: DateTime.now(),
    );

    _hasChanges = true;
    setState(() => _editingId = null);
    await _loadCategories();
  }

  Future<void> _deleteCategory(_CategoryNode node) async {
    if (node.productCount > 0) {
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

    final children = await _db.categoryDao.findChildren(node.category.id);
    if (children.isNotEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Категория содержит подкатегории'),
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
          '${l10n.catalogConfirmDeleteCategory} "${node.displayName}"?',
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
      await _db.categoryDao.deleteCategory(node.category.id);
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
                  const Icon(Icons.folder_outlined, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      l10n.catalogManageCategories,
                      style: AppTextStyles.h3,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
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
                  : _flatNodes.isEmpty
                  ? Center(
                      child: Text(
                        l10n.catalogNoCategories,
                        style: AppTextStyles.body.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      itemCount: _flatNodes.length,
                      itemBuilder: (context, index) =>
                          _buildCategoryRow(_flatNodes[index]),
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

  Widget _buildCategoryRow(_CategoryNode node) {
    final isEditing = _editingId == node.category.id;

    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).colorScheme.outline,
            width: 0.5,
          ),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.only(
          left: 16.0 + node.depth * 24.0,
          right: 8,
          top: 4,
          bottom: 4,
        ),
        child: Row(
          children: [
            const Icon(
              Icons.drag_handle,
              size: 20,
              color: AppColors.textDisabled,
            ),
            const SizedBox(width: 8),

            Icon(
              node.depth == 0
                  ? Icons.folder_outlined
                  : Icons.subdirectory_arrow_right,
              size: 20,
              color: AppColors.primary,
            ),
            const SizedBox(width: 8),

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
                      onSubmitted: (_) => _saveEdit(node.category.id),
                    )
                  : Text(
                      node.displayName,
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
              child: Text(
                '${node.productCount}',
                style: context.styles.caption,
              ),
            ),

            const SizedBox(width: 4),

            if (isEditing) ...[
              IconButton(
                icon: const Icon(
                  TeleposIcons.check,
                  size: 20,
                  color: AppColors.success,
                ),
                onPressed: () => _saveEdit(node.category.id),
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
                    _editingId = node.category.id;
                    _editNameController.text = node.displayName;
                  });
                },
                constraints: const BoxConstraints(
                  minWidth: AppTheme.minButtonSize,
                  minHeight: AppTheme.minButtonSize,
                ),
              ),
              IconButton(
                icon: const Icon(TeleposIcons.delete, size: 20),
                color: node.productCount > 0
                    ? AppColors.textDisabled
                    : Theme.of(context).colorScheme.error,
                onPressed: node.productCount > 0
                    ? null
                    : () => _deleteCategory(node),
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
    final rootCategories = _flatNodes.where((n) => n.depth == 0).toList();

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
          DropdownButtonFormField<int?>(
            value: _addParentId,
            decoration: InputDecoration(
              labelText: l10n.catalogParentCategory,
              border: const OutlineInputBorder(),
              isDense: true,
            ),
            items: [
              DropdownMenuItem<int?>(
                value: null,
                child: Text(l10n.catalogRootCategory),
              ),
              ...rootCategories.map(
                (node) => DropdownMenuItem<int?>(
                  value: node.category.id,
                  child: Text(node.displayName),
                ),
              ),
            ],
            onChanged: (value) {
              setState(() => _addParentId = value);
            },
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
}

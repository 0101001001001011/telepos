import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';
import 'package:telepos/app/theme/app_colors.dart';
import 'package:telepos/app/theme/app_theme.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/presentation/controllers/catalog/catalog_controller.dart';

class QuickProductDialog extends ConsumerStatefulWidget {
  const QuickProductDialog({required this.item, super.key});

  final CatalogItem item;

  static Future<bool?> show(BuildContext context, {required CatalogItem item}) {
    return showDialog<bool>(
      context: context,
      builder: (context) => QuickProductDialog(item: item),
    );
  }

  @override
  ConsumerState<QuickProductDialog> createState() => _QuickProductDialogState();
}

class _QuickProductDialogState extends ConsumerState<QuickProductDialog> {
  int? _selectedParentId;
  List<QuickProduct> _categories = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    final db = GetIt.I<AppDatabase>();
    final roots = await db.quickProductDao.findAllByParents();
    final cats = roots.where((qp) => qp.ucode == null).toList();
    setState(() {
      _categories = cats;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return AlertDialog(
      title: Text(l10n.catalogAddToQuick),
      content: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(AppTheme.borderRadius),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.flash_on, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.item.name,
                          style: AppTextStyles.body.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          '${widget.item.sellingPrice}',
                          style: context.styles.caption,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppTheme.spacing),

            Text(
              l10n.catalogQuickProductCategory,
              style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),

            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else ...[
              RadioListTile<int?>(
                value: null,
                groupValue: _selectedParentId,
                onChanged: (v) => setState(() => _selectedParentId = v),
                title: Text(l10n.catalogAllCategories),
                contentPadding: EdgeInsets.zero,
                dense: true,
              ),
              ..._categories.map(
                (cat) => RadioListTile<int?>(
                  value: cat.id,
                  groupValue: _selectedParentId,
                  onChanged: (v) => setState(() => _selectedParentId = v),
                  title: Text(cat.name ?? '#${cat.id}'),
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l10n.globalCancel),
        ),
        ElevatedButton(
          onPressed: () async {
            final db = GetIt.I<AppDatabase>();
            await db.quickProductDao.addQuickProduct(
              ucode: widget.item.ucode,
              parentId: _selectedParentId,
              orderName: widget.item.name,
            );
            if (context.mounted) Navigator.of(context).pop(true);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: AppColors.white,
          ),
          child: Text(l10n.globalAdd),
        ),
      ],
    );
  }
}

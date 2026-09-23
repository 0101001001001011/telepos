import 'dart:convert';
import 'package:telepos/app/theme/app_semantic_colors.dart';
import 'package:telepos/app/theme/telepos_icons.dart';
import 'package:telepos/core/platform/local_file.dart';
import 'dart:math' as math;

import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get_it/get_it.dart';
import 'package:image_picker/image_picker.dart';
import 'package:telepos/app/theme/app_colors.dart';
import 'package:telepos/app/theme/app_theme.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/domain/entities/dish/dish_ingredient_entity.dart';
import 'package:telepos/domain/entities/dish/dish_costing_entity.dart';
import 'package:telepos/presentation/common/utils/till_money.dart';

class DishCalculationDialog extends StatefulWidget {
  const DishCalculationDialog({
    required this.dishUcode,
    required this.dishName,
    super.key,
  });

  final int dishUcode;
  final String dishName;

  static Future<void> show(
    BuildContext context, {
    required int dishUcode,
    required String dishName,
  }) {
    final screenSize = MediaQuery.of(context).size;
    final isCompact = screenSize.width < 600;

    if (isCompact) {
      return showDialog(
        context: context,
        useSafeArea: false,
        builder: (_) => Dialog.fullscreen(
          child: DishCalculationDialog(
            dishUcode: dishUcode,
            dishName: dishName,
          ),
        ),
      );
    }

    return showDialog(
      context: context,
      builder: (_) =>
          DishCalculationDialog(dishUcode: dishUcode, dishName: dishName),
    );
  }

  @override
  State<DishCalculationDialog> createState() => _DishCalculationDialogState();
}

class _DishCalculationDialogState extends State<DishCalculationDialog>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<DishIngredientEntity> _ingredients = [];
  Decimal _sellingPrice = Decimal.zero;
  bool _isLoading = true;
  int _servingsPerRecipe = 1;

  final _searchController = TextEditingController();
  List<ProductInfo> _searchResults = [];
  bool _isSearching = false;
  bool _showSearch = false;

  String? _dishPhotoPath;
  final _imagePicker = ImagePicker();

  List<Map<String, dynamic>> _versionHistory = [];

  bool _photoExpanded = true;
  bool _kbjuExpanded = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
    _loadPhoto();
    _loadVersionHistory();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final db = GetIt.I<AppDatabase>();
      final rows = await db.dishIngredientDao.findIngredientsWithPrices(
        widget.dishUcode,
      );

      final ingredients = rows.map((row) {
        return DishIngredientEntity(
          id: row.read<int>('id'),
          dishUcode: row.read<int>('dish_ucode'),
          ingredientUcode: row.read<int>('ingredient_ucode'),
          grossQuantity: Decimal.parse(
            row.read<double>('gross_quantity').toString(),
          ),
          netQuantity: Decimal.parse(
            row.read<double>('net_quantity').toString(),
          ),
          coldLossPercent: Decimal.parse(
            row.read<double>('cold_loss_percent').toString(),
          ),
          hotLossPercent: Decimal.parse(
            row.read<double>('hot_loss_percent').toString(),
          ),
          sortOrder: row.read<int>('sort_order'),
          ingredientName: row.read<String?>('ingredient_name'),
          purchasePrice: row.read<double?>('purchase_price') != null
              ? Decimal.parse(row.read<double>('purchase_price').toString())
              : null,
          ingredientMeasure: row.read<int?>('ingredient_measure'),
          calories: _tryReadDouble(row, 'calories'),
          proteins: _tryReadDouble(row, 'proteins'),
          fats: _tryReadDouble(row, 'fats'),
          carbs: _tryReadDouble(row, 'carbohydrates'),
        );
      }).toList();

      final priceRow = await db.productPriceDao.findByUcode(widget.dishUcode);
      final sellingPrice = priceRow?.sellingPrice ?? Decimal.zero;

      setState(() {
        _ingredients = ingredients;
        _sellingPrice = sellingPrice;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  double? _tryReadDouble(dynamic row, String column) {
    try {
      return row.read<double?>(column);
    } catch (_) {
      return null;
    }
  }

  Future<void> _loadPhoto() async {
    try {
      final db = GetIt.I<AppDatabase>();
      final photos = await db.dishPhotoDao.findByDish(widget.dishUcode);
      if (photos.isNotEmpty) {
        final path = photos.last.filePath;
        if (localFileExists(path)) {
          setState(() => _dishPhotoPath = path);
        }
      }
    } catch (_) {}
  }

  Future<void> _loadVersionHistory() async {
    try {
      final db = GetIt.I<AppDatabase>();
      final versions = await db.dishRecipeVersionDao.findByDish(
        widget.dishUcode,
      );

      final authorNames = <int, String>{};
      for (final id in versions.map((v) => v.changedBy).toSet()) {
        if (id == 0) continue;
        final user = await db.userDao.findById(id);
        final name = user?.name;
        if (name != null && name.isNotEmpty) authorNames[id] = name;
      }

      setState(() {
        _versionHistory = versions.map((v) {
          return {
            'version': v.versionNumber,
            'date': _formatTimestamp(v.changedAt),
            'author': authorNames[v.changedBy] ?? '',
            'summary': v.changeSummary,
            'snapshot': v.recipeSnapshot,
          };
        }).toList();
      });
    } catch (_) {}
  }

  String _formatTimestamp(int unixSeconds) {
    final dt = DateTime.fromMillisecondsSinceEpoch(
      unixSeconds * 1000,
    ).toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${dt.year}-${two(dt.month)}-${two(dt.day)} '
        '${two(dt.hour)}:${two(dt.minute)}';
  }

  DishCostingEntity get _costing => DishCostingEntity(
    dishUcode: widget.dishUcode,
    dishName: widget.dishName,
    ingredients: _ingredients,
    sellingPrice: _sellingPrice,
    servingsPerRecipe: _servingsPerRecipe,
  );

  bool get _hasKbjuData => _ingredients.any(
    (i) =>
        i.calories != null ||
        i.proteins != null ||
        i.fats != null ||
        i.carbs != null,
  );

  double get _totalCalories => _ingredients.fold(0.0, (sum, i) {
    return sum + i.caloriesPerServing;
  });

  double get _totalProteins => _ingredients.fold(0.0, (sum, i) {
    return sum + i.proteinsPerServing;
  });

  double get _totalFats => _ingredients.fold(0.0, (sum, i) {
    return sum + i.fatsPerServing;
  });

  double get _totalCarbs => _ingredients.fold(0.0, (sum, i) {
    return sum + i.carbsPerServing;
  });

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isCompact = screenSize.width < 600;

    if (isCompact) {
      return Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              _buildTabBar(),
              Expanded(child: _buildTabContent()),
              _buildBottomBar(),
            ],
          ),
        ),
      );
    }

    final dialogWidth = (screenSize.width * 0.9).clamp(
      1000.0,
      screenSize.width,
    );
    final dialogHeight = (screenSize.height * 0.9).clamp(
      700.0,
      screenSize.height,
    );

    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: dialogWidth,
        height: dialogHeight,
        child: Column(
          children: [
            _buildHeader(),
            _buildTabBar(),
            Expanded(child: _buildTabContent()),
            _buildBottomBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildTabBar() {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Theme.of(context).colorScheme.outline),
        ),
      ),
      child: TabBar(
        controller: _tabController,
        labelColor: AppColors.primary,
        unselectedLabelColor: Theme.of(context).colorScheme.onSurfaceVariant,
        indicatorColor: AppColors.primary,
        indicatorWeight: 3,
        labelStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        unselectedLabelStyle: const TextStyle(fontSize: 15),
        tabs: [
          Tab(
            height: 52,
            icon: const Icon(Icons.receipt_long, size: 20),
            text: l10n.dishTabRecipe,
          ),
          Tab(
            height: 52,
            icon: const Icon(Icons.calculate, size: 20),
            text: l10n.dishTabCosting,
          ),
          Tab(
            height: 52,
            icon: const Icon(Icons.analytics, size: 20),
            text: l10n.dishTabYield,
          ),
        ],
      ),
    );
  }

  Widget _buildTabContent() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    return TabBarView(
      controller: _tabController,
      children: [_buildRecipeTab(), _buildCostingTab(), _buildYieldTab()],
    );
  }

  Widget _buildHeader() {
    final l10n = AppLocalizations.of(context)!;
    final costing = _costing;
    final profit = costing.sellingPrice - costing.dishCost;
    final isProfit = profit > Decimal.zero;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: selectedSurfaceOf(context),
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(
                Icons.restaurant_menu,
                color: AppColors.primary,
                size: 28,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  widget.dishName,
                  style: AppTextStyles.h2.copyWith(fontSize: 22),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              SizedBox(
                height: 48,
                child: OutlinedButton.icon(
                  onPressed: _showVersionHistoryDialog,
                  icon: const Icon(Icons.history, size: 20),
                  label: Text(l10n.dishVersions),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Theme.of(
                      context,
                    ).colorScheme.onSurfaceVariant,
                    side: BorderSide(
                      color: Theme.of(context).colorScheme.outline,
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                height: 48,
                width: 48,
                child: IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(TeleposIcons.close, size: 24),
                  style: IconButton.styleFrom(
                    foregroundColor: Theme.of(
                      context,
                    ).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
          if (!_isLoading && _ingredients.isNotEmpty) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                _summaryChip(
                  label: l10n.dishCostLabel,
                  value:
                      '${costing.dishCost.toStringAsFixed(2)} ${tillCurrencySymbol()}',
                  icon: Icons.calculate,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 8),
                _summaryChip(
                  label: l10n.dishPriceLabel,
                  value:
                      '${costing.sellingPrice.toStringAsFixed(2)} ${tillCurrencySymbol()}',
                  icon: Icons.sell,
                  color: AppColors.info,
                ),
                const SizedBox(width: 8),
                _summaryChip(
                  label: l10n.dishProfitLabel,
                  value: '${profit.toStringAsFixed(2)} ${tillCurrencySymbol()}',
                  icon: isProfit ? Icons.trending_up : Icons.trending_down,
                  color: isProfit
                      ? AppColors.success
                      : Theme.of(context).colorScheme.error,
                ),
                const SizedBox(width: 8),
                _summaryChip(
                  label: l10n.dishMarkupLabel,
                  value: '${costing.markupPercent.toStringAsFixed(1)}%',
                  icon: Icons.percent,
                  color: AppColors.warning,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _summaryChip({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(AppTheme.borderRadius),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: context.styles.caption.copyWith(fontSize: 11),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecipeTab() {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      children: [
        Expanded(
          child: _ingredients.isEmpty && !_showSearch
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.receipt_long,
                        size: 64,
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        l10n.dishNoIngredients,
                        style: AppTextStyles.h3.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        l10n.dishNoIngredientsHint,
                        style: AppTextStyles.body.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        height: 48,
                        child: ElevatedButton.icon(
                          onPressed: () => setState(() => _showSearch = true),
                          icon: const Icon(TeleposIcons.add, size: 22),
                          label: Text(
                            l10n.dishAddIngredient,
                            style: const TextStyle(fontSize: 16),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: AppColors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SingleChildScrollView(child: _buildIngredientsTable()),
                ),
        ),
        if (_showSearch) _buildSearchPanel(),
        _buildRecipeBottomRow(),
      ],
    );
  }

  Widget _buildIngredientsTable() {
    final l10n = AppLocalizations.of(context)!;
    return DataTable(
      columnSpacing: 16,
      horizontalMargin: 16,
      headingRowHeight: 48,
      dataRowMinHeight: 52,
      dataRowMaxHeight: 60,
      columns: [
        DataColumn(
          label: Text(
            l10n.dishColIngredient,
            style: context.styles.tableHeader,
          ),
        ),
        DataColumn(
          label: Text(l10n.dishColGross, style: context.styles.tableHeader),
          numeric: true,
        ),
        DataColumn(
          label: Text(l10n.dishColColdLoss, style: context.styles.tableHeader),
          numeric: true,
        ),
        DataColumn(
          label: Text(l10n.dishColNet, style: context.styles.tableHeader),
          numeric: true,
        ),
        DataColumn(
          label: Text(l10n.dishColHotLoss, style: context.styles.tableHeader),
          numeric: true,
        ),
        DataColumn(
          label: Text(l10n.dishColYield, style: context.styles.tableHeader),
          numeric: true,
        ),
        DataColumn(
          label: Text(l10n.dishColCost, style: context.styles.tableHeader),
          numeric: true,
        ),
        // Не const: стили теперь производны от AppTypography через copyWith,
        // а значит вычисляются, а не задаются литералом.
        DataColumn(label: Text('', style: context.styles.tableHeader)),
      ],
      rows: [
        ..._ingredients.asMap().entries.map((entry) {
          final i = entry.value;
          return DataRow(
            cells: [
              DataCell(
                SizedBox(
                  width: 160,
                  child: Text(
                    i.ingredientName ?? '#${i.ingredientUcode}',
                    style: AppTextStyles.body.copyWith(fontSize: 15),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              DataCell(
                _editableCell(
                  i.grossQuantity.toString(),
                  (val) => _updateIngredient(i, gross: Decimal.tryParse(val)),
                ),
              ),
              DataCell(
                _editableCell(
                  i.coldLossPercent.toString(),
                  (val) =>
                      _updateIngredient(i, coldLoss: Decimal.tryParse(val)),
                ),
              ),
              DataCell(
                Text(
                  i.netQuantity.toStringAsFixed(3),
                  style: AppTextStyles.body.copyWith(fontSize: 15),
                ),
              ),
              DataCell(
                _editableCell(
                  i.hotLossPercent.toString(),
                  (val) => _updateIngredient(i, hotLoss: Decimal.tryParse(val)),
                ),
              ),
              DataCell(
                Text(
                  i.finalYield.toStringAsFixed(3),
                  style: AppTextStyles.body.copyWith(fontSize: 15),
                ),
              ),
              DataCell(
                Text(
                  i.ingredientCost.toStringAsFixed(2),
                  style: AppTextStyles.body.copyWith(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              DataCell(
                SizedBox(
                  width: 48,
                  height: 48,
                  child: IconButton(
                    onPressed: () => _deleteIngredient(i),
                    icon: Icon(
                      TeleposIcons.delete,
                      size: 22,
                      color: Theme.of(context).colorScheme.error,
                    ),
                    tooltip: l10n.dishDeleteIngredient,
                    padding: EdgeInsets.zero,
                  ),
                ),
              ),
            ],
          );
        }),
        if (_ingredients.isNotEmpty)
          DataRow(
            color: WidgetStatePropertyAll(
              selectedSurfaceOf(context).withValues(alpha: 0.5),
            ),
            cells: [
              DataCell(
                Text(
                  l10n.dishTotal,
                  style: AppTextStyles.body.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ),
              const DataCell(Text('')),
              const DataCell(Text('')),
              const DataCell(Text('')),
              const DataCell(Text('')),
              DataCell(
                Text(
                  _costing.totalYield.toStringAsFixed(3),
                  style: AppTextStyles.body.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ),
              DataCell(
                Text(
                  _costing.dishCost.toStringAsFixed(2),
                  style: AppTextStyles.body.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: AppColors.primary,
                  ),
                ),
              ),
              const DataCell(Text('')),
            ],
          ),
      ],
    );
  }

  Widget _editableCell(String value, ValueChanged<String> onSubmitted) {
    return SizedBox(
      width: 80,
      child: TextField(
        controller: TextEditingController(text: value),
        style: const TextStyle(fontSize: 16),
        decoration: const InputDecoration(
          isDense: true,
          contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          border: UnderlineInputBorder(),
        ),
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
        onSubmitted: onSubmitted,
      ),
    );
  }

  Future<void> _updateIngredient(
    DishIngredientEntity ingredient, {
    Decimal? gross,
    Decimal? coldLoss,
    Decimal? hotLoss,
  }) async {
    final newGross = gross ?? ingredient.grossQuantity;
    final newColdLoss = coldLoss ?? ingredient.coldLossPercent;
    final newHotLoss = hotLoss ?? ingredient.hotLossPercent;

    final multiplier =
        ((Decimal.fromInt(100) - newColdLoss) / Decimal.fromInt(100))
            .toDecimal();
    final net = newGross * multiplier;

    final db = GetIt.I<AppDatabase>();
    await db.dishIngredientDao.updateIngredient(
      ingredient.id!,
      DishIngredientsCompanion(
        grossQuantity: Value(newGross),
        netQuantity: Value(net),
        coldLossPercent: Value(newColdLoss),
        hotLossPercent: Value(newHotLoss),
      ),
    );
    await _loadData();
  }

  Future<void> _deleteIngredient(DishIngredientEntity ingredient) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.dishDeleteIngredientTitle),
        content: Text(
          l10n.dishDeleteIngredientConfirm(ingredient.ingredientName ?? ''),
        ),
        actions: [
          SizedBox(
            height: 48,
            child: TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(l10n.globalCancel),
            ),
          ),
          SizedBox(
            height: 48,
            child: TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error,
              ),
              child: Text(l10n.globalDelete),
            ),
          ),
        ],
      ),
    );
    if (confirmed == true && ingredient.id != null) {
      final db = GetIt.I<AppDatabase>();
      await db.dishIngredientDao.deleteById(ingredient.id!);
      await _loadData();
    }
  }

  Widget _buildSearchPanel() {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.semantic.canvas,
        border: Border(
          top: BorderSide(
            color: Theme.of(context).colorScheme.outline,
            width: 2,
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 52,
            child: TextField(
              controller: _searchController,
              autofocus: true,
              style: const TextStyle(fontSize: 16),
              decoration: InputDecoration(
                hintText: l10n.dishSearchIngredientHint,
                hintStyle: const TextStyle(fontSize: 16),
                prefixIcon: const Icon(Icons.search, size: 24),
                suffixIcon: SizedBox(
                  width: 48,
                  height: 48,
                  child: IconButton(
                    icon: const Icon(TeleposIcons.close, size: 24),
                    onPressed: () {
                      setState(() {
                        _showSearch = false;
                        _searchResults = [];
                        _searchController.clear();
                      });
                    },
                  ),
                ),
                border: const OutlineInputBorder(),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
              ),
              onChanged: _onSearch,
            ),
          ),
          if (_isSearching)
            const Padding(
              padding: EdgeInsets.all(12),
              child: SizedBox(
                height: 24,
                width: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          if (_searchResults.isNotEmpty)
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 240),
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.only(top: 12),
                itemCount: _searchResults.length,
                separatorBuilder: (_, __) => const SizedBox(height: 6),
                itemBuilder: (ctx, idx) {
                  final p = _searchResults[idx];
                  return _buildSearchResultCard(p);
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSearchResultCard(ProductInfo product) {
    final l10n = AppLocalizations.of(context)!;
    return Material(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(AppTheme.borderRadius),
      child: InkWell(
        onTap: () => _showAddIngredientDialog(product),
        borderRadius: BorderRadius.circular(AppTheme.borderRadius),
        child: Container(
          constraints: const BoxConstraints(minHeight: 56),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTheme.borderRadius),
            border: Border.all(color: Theme.of(context).colorScheme.outline),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: selectedSurfaceOf(context),
                  borderRadius: BorderRadius.circular(
                    AppTheme.borderRadiusSmall,
                  ),
                ),
                child: const Icon(
                  Icons.inventory_2,
                  size: 20,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      style: AppTextStyles.body.copyWith(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      product.barcode != 0
                          ? l10n.dishCodeWithBarcode(
                              product.ucode,
                              product.barcode,
                            )
                          : l10n.dishCodeOnly(product.ucode),
                      style: context.styles.caption.copyWith(fontSize: 13),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.add_circle_outline,
                size: 24,
                color: AppColors.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _onSearch(String query) async {
    if (query.length < 2) {
      setState(() => _searchResults = []);
      return;
    }
    setState(() => _isSearching = true);
    try {
      final db = GetIt.I<AppDatabase>();
      final products = await db.productInfoDao.findByNamePart('%$query%');
      final filtered = products
          .where((p) => p.type != 6 && !p.isDeleted)
          .take(20)
          .toList();
      setState(() {
        _searchResults = filtered;
        _isSearching = false;
      });
    } catch (_) {
      setState(() => _isSearching = false);
    }
  }

  Future<void> _showAddIngredientDialog(ProductInfo product) async {
    final l10n = AppLocalizations.of(context)!;
    final grossCtrl = TextEditingController(text: '1');
    final coldLossCtrl = TextEditingController(text: '0');
    final hotLossCtrl = TextEditingController(text: '0');
    double seasonCoefficient = 1.0;

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final baseColdLoss = double.tryParse(coldLossCtrl.text) ?? 0;
          final effectiveColdLoss = baseColdLoss * seasonCoefficient;

          return AlertDialog(
            title: Text(l10n.dishAddTitle(product.name)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    height: 52,
                    child: TextField(
                      controller: grossCtrl,
                      style: const TextStyle(fontSize: 16),
                      decoration: InputDecoration(
                        labelText: l10n.dishGrossQty,
                        labelStyle: const TextStyle(fontSize: 16),
                        border: const OutlineInputBorder(),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
                      ],
                      autofocus: true,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 52,
                    child: TextField(
                      controller: coldLossCtrl,
                      style: const TextStyle(fontSize: 16),
                      decoration: InputDecoration(
                        labelText: l10n.dishColdLossLabel,
                        labelStyle: const TextStyle(fontSize: 16),
                        border: const OutlineInputBorder(),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
                      ],
                      onChanged: (_) => setDialogState(() {}),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 52,
                    child: TextField(
                      controller: hotLossCtrl,
                      style: const TextStyle(fontSize: 16),
                      decoration: InputDecoration(
                        labelText: l10n.dishHotLossLabel,
                        labelStyle: const TextStyle(fontSize: 16),
                        border: const OutlineInputBorder(),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacing),

                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: context.semantic.canvas,
                      borderRadius: BorderRadius.circular(
                        AppTheme.borderRadius,
                      ),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.dishSeasonCoefficient,
                          style: AppTextStyles.body.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        DropdownButton<double>(
                          value: seasonCoefficient,
                          isExpanded: true,
                          items: [
                            DropdownMenuItem(
                              value: 1.0,
                              child: Text(l10n.dishSeasonStandard),
                            ),
                            DropdownMenuItem(
                              value: 1.15,
                              child: Text(l10n.dishSeasonWinter),
                            ),
                            DropdownMenuItem(
                              value: 0.95,
                              child: Text(l10n.dishSeasonSummer),
                            ),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              setDialogState(() => seasonCoefficient = val);
                            }
                          },
                        ),
                        if (seasonCoefficient != 1.0 && baseColdLoss > 0)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              l10n.dishEffectiveColdLoss(
                                effectiveColdLoss.toStringAsFixed(1),
                              ),
                              style: AppTextStyles.body.copyWith(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              SizedBox(
                height: 48,
                child: TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: Text(
                    l10n.globalCancel,
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              ),
              SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(ctx).pop(true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                  ),
                  child: Text(
                    l10n.globalAdd,
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );

    if (result == true) {
      final gross = Decimal.tryParse(grossCtrl.text) ?? Decimal.fromInt(1);
      final baseColdLoss = Decimal.tryParse(coldLossCtrl.text) ?? Decimal.zero;
      final seasonDecimal = Decimal.parse(seasonCoefficient.toString());
      final coldLoss = (baseColdLoss * seasonDecimal).round(scale: 3);
      final hotLoss = Decimal.tryParse(hotLossCtrl.text) ?? Decimal.zero;
      final netMultiplier =
          ((Decimal.fromInt(100) - coldLoss) / Decimal.fromInt(100))
              .toDecimal();
      final net = gross * netMultiplier;

      final db = GetIt.I<AppDatabase>();
      await db.dishIngredientDao.insertIngredient(
        DishIngredientsCompanion(
          dishUcode: Value(widget.dishUcode),
          ingredientUcode: Value(product.ucode),
          grossQuantity: Value(gross),
          netQuantity: Value(net),
          coldLossPercent: Value(coldLoss),
          hotLossPercent: Value(hotLoss),
          sortOrder: Value(_ingredients.length),
        ),
      );

      setState(() {
        _showSearch = false;
        _searchResults = [];
        _searchController.clear();
      });
      await _loadData();
    }

    grossCtrl.dispose();
    coldLossCtrl.dispose();
    hotLossCtrl.dispose();
  }

  Widget _buildRecipeBottomRow() {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: Theme.of(context).colorScheme.outline),
        ),
      ),
      child: Row(
        children: [
          if (_ingredients.isNotEmpty)
            Flexible(
              child: Text(
                l10n.dishTotalYieldSummary(
                  _costing.dishCost.toStringAsFixed(2),
                  _costing.totalYield.toStringAsFixed(3),
                ),
                style: AppTextStyles.body.copyWith(
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          const Spacer(),
          SizedBox(
            height: 48,
            child: OutlinedButton.icon(
              onPressed: _showGostNormsDialog,
              icon: const Icon(Icons.menu_book, size: 20),
              label: Text(
                l10n.dishGostNorms,
                style: const TextStyle(fontSize: 15),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.onSurfaceVariant,
                side: BorderSide(color: Theme.of(context).colorScheme.outline),
                padding: const EdgeInsets.symmetric(horizontal: 16),
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            height: 48,
            child: ElevatedButton.icon(
              onPressed: () => setState(() => _showSearch = !_showSearch),
              icon: const Icon(TeleposIcons.add, size: 22),
              label: Text(
                l10n.dishAddIngredient,
                style: const TextStyle(fontSize: 15),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showGostNormsDialog() async {
    List<Map<String, dynamic>> gostNorms = [];
    try {
      final db = GetIt.I<AppDatabase>();
      await db.gostLossNormDao.seedInitialData();
      final norms = await db.gostLossNormDao.findAll();
      norms.sort((a, b) => a.productName.compareTo(b.productName));
      gostNorms = norms.map((n) {
        return {
          'id': n.id,
          'productName': n.productName,
          'coldLoss': n.coldLossPercent.toDouble(),
          'hotLoss': n.hotLossPercent.toDouble(),
          'gostCode': '',
        };
      }).toList();
    } catch (_) {}

    if (!mounted) return;

    final l10n = AppLocalizations.of(context)!;
    final searchCtrl = TextEditingController();

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final query = searchCtrl.text.toLowerCase();
          final filtered = query.isEmpty
              ? gostNorms
              : gostNorms
                    .where(
                      (n) => (n['productName'] as String)
                          .toLowerCase()
                          .contains(query),
                    )
                    .toList();

          return AlertDialog(
            title: Text(l10n.dishGostNormsTitle),
            content: SizedBox(
              width: math.min(500.0, MediaQuery.sizeOf(ctx).width - 80),
              height: math.min(450.0, MediaQuery.sizeOf(ctx).height - 160),
              child: Column(
                children: [
                  SizedBox(
                    height: 52,
                    child: TextField(
                      controller: searchCtrl,
                      style: const TextStyle(fontSize: 16),
                      decoration: InputDecoration(
                        hintText: l10n.dishSearchProductHint,
                        hintStyle: const TextStyle(fontSize: 16),
                        prefixIcon: const Icon(Icons.search, size: 24),
                        border: const OutlineInputBorder(),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                      ),
                      onChanged: (_) => setDialogState(() {}),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: gostNorms.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.menu_book,
                                  size: 48,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  l10n.dishReferenceEmpty,
                                  style: AppTextStyles.body.copyWith(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  l10n.dishGostNotLoaded,
                                  style: context.styles.caption,
                                ),
                              ],
                            ),
                          )
                        : ListView.separated(
                            itemCount: filtered.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 4),
                            itemBuilder: (_, idx) {
                              final norm = filtered[idx];
                              return Material(
                                color: context.semantic.canvas,
                                borderRadius: BorderRadius.circular(
                                  AppTheme.borderRadius,
                                ),
                                child: InkWell(
                                  onTap: () {
                                    Navigator.of(ctx).pop(norm);
                                  },
                                  borderRadius: BorderRadius.circular(
                                    AppTheme.borderRadius,
                                  ),
                                  child: Container(
                                    constraints: const BoxConstraints(
                                      minHeight: 56,
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 12,
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                norm['productName'] as String,
                                                style: AppTextStyles.body
                                                    .copyWith(fontSize: 15),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                '${l10n.dishGostLossLine((norm['coldLoss'] as double).toStringAsFixed(1), (norm['hotLoss'] as double).toStringAsFixed(1))}'
                                                '${(norm['gostCode'] as String).isNotEmpty ? '  (${norm['gostCode']})' : ''}',
                                                style: context.styles.caption
                                                    .copyWith(fontSize: 13),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Icon(
                                          Icons.chevron_right,
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.onSurfaceVariant,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
            actions: [
              SizedBox(
                height: 48,
                child: TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: Text(
                    l10n.globalClose,
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );

    searchCtrl.dispose();
  }

  Widget _buildCostingTab() {
    final l10n = AppLocalizations.of(context)!;
    final costing = _costing;
    final profit = costing.sellingPrice - costing.dishCost;
    final isProfit = profit > Decimal.zero;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          _buildCollapsibleSection(
            title: l10n.dishPhotoSection,
            icon: Icons.camera_alt,
            isExpanded: _photoExpanded,
            onToggle: () => setState(() => _photoExpanded = !_photoExpanded),
            child: _buildPhotoContent(),
          ),

          const SizedBox(height: 16),

          if (costing.hasMissingPrices)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.warningLight,
                borderRadius: BorderRadius.circular(AppTheme.borderRadius),
                border: Border.all(color: AppColors.warning),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.warning_amber,
                    color: AppColors.warning,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      l10n.dishMissingPricesWarning,
                      style: AppTextStyles.body.copyWith(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: isProfit
                  ? AppColors.success.withValues(alpha: 0.08)
                  : Theme.of(context).colorScheme.error.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(AppTheme.borderRadius),
              border: Border.all(
                color: isProfit
                    ? AppColors.success.withValues(alpha: 0.3)
                    : Theme.of(
                        context,
                      ).colorScheme.error.withValues(alpha: 0.3),
                width: 2,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  isProfit ? Icons.trending_up : Icons.trending_down,
                  color: isProfit
                      ? AppColors.success
                      : Theme.of(context).colorScheme.error,
                  size: 36,
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isProfit
                          ? l10n.dishProfitPerServing
                          : l10n.dishLossPerServing,
                      style: AppTextStyles.body.copyWith(
                        color: isProfit
                            ? AppColors.success
                            : Theme.of(context).colorScheme.error,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${profit.toStringAsFixed(2)} ${tillCurrencySymbol()}',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: isProfit
                            ? AppColors.success
                            : Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth > 500) {
                return Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _costingCard(
                            label: l10n.dishCostOfDish,
                            value:
                                '${costing.dishCost.toStringAsFixed(2)} ${tillCurrencySymbol()}',
                            icon: Icons.calculate,
                            valueStyle: AppTextStyles.h2.copyWith(
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _costingCard(
                            label: l10n.dishSellingPrice,
                            value:
                                '${costing.sellingPrice.toStringAsFixed(2)} ${tillCurrencySymbol()}',
                            icon: Icons.sell,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _costingCard(
                            label: l10n.dishMarkupLabel,
                            value:
                                '${costing.markupPercent.toStringAsFixed(1)}%',
                            icon: Icons.trending_up,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _costingCard(
                            label: l10n.dishMargin,
                            value:
                                '${costing.marginPercent.toStringAsFixed(1)}%',
                            icon: Icons.pie_chart,
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              }
              return Column(
                children: [
                  _costingCard(
                    label: l10n.dishCostOfDish,
                    value:
                        '${costing.dishCost.toStringAsFixed(2)} ${tillCurrencySymbol()}',
                    icon: Icons.calculate,
                    valueStyle: AppTextStyles.h2.copyWith(
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _costingCard(
                    label: l10n.dishSellingPrice,
                    value:
                        '${costing.sellingPrice.toStringAsFixed(2)} ${tillCurrencySymbol()}',
                    icon: Icons.sell,
                  ),
                  const SizedBox(height: 12),
                  _costingCard(
                    label: l10n.dishMarkupLabel,
                    value: '${costing.markupPercent.toStringAsFixed(1)}%',
                    icon: Icons.trending_up,
                  ),
                  const SizedBox(height: 12),
                  _costingCard(
                    label: l10n.dishMargin,
                    value: '${costing.marginPercent.toStringAsFixed(1)}%',
                    icon: Icons.pie_chart,
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 12),

          _foodCostCard(costing.foodCostPercent),
        ],
      ),
    );
  }

  Widget _buildCollapsibleSection({
    required String title,
    required IconData icon,
    required bool isExpanded,
    required VoidCallback onToggle,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.borderRadius),
        border: Border.all(color: Theme.of(context).colorScheme.outline),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Material(
            color: context.semantic.canvas,
            child: InkWell(
              onTap: onToggle,
              child: Container(
                constraints: const BoxConstraints(minHeight: 52),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    Icon(icon, size: 22, color: AppColors.primary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        title,
                        style: AppTextStyles.body.copyWith(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    AnimatedRotation(
                      turns: isExpanded ? 0.5 : 0.0,
                      duration: const Duration(milliseconds: 200),
                      child: Icon(
                        Icons.keyboard_arrow_down,
                        size: 24,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: Padding(
              padding: const EdgeInsets.all(16),
              child: child,
            ),
            secondChild: const SizedBox.shrink(),
            crossFadeState: isExpanded
                ? CrossFadeState.showFirst
                : CrossFadeState.showSecond,
            duration: const Duration(milliseconds: 250),
            sizeCurve: Curves.easeInOut,
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoContent() {
    final l10n = AppLocalizations.of(context)!;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_dishPhotoPath != null)
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(AppTheme.borderRadius),
                child: localImage(
                  _dishPhotoPath!,
                  width: 120,
                  height: 120,
                  fit: BoxFit.cover,
                ),
              ),
              Positioned(
                top: 4,
                right: 4,
                child: SizedBox(
                  width: 32,
                  height: 32,
                  child: IconButton(
                    onPressed: _deletePhoto,
                    icon: const Icon(Icons.cancel, size: 24),
                    color: Theme.of(context).colorScheme.error,
                    padding: EdgeInsets.zero,
                    style: IconButton.styleFrom(
                      // Полупрозрачная подложка кнопки поверх фотографии.
                      // Прозрачность оставлена, цвет взят ролью: на тёмной
                      // теме белый кружок бил по глазам и спорил со снимком.
                      backgroundColor: Theme.of(
                        context,
                      ).colorScheme.surface.withValues(alpha: 0.8),
                    ),
                  ),
                ),
              ),
            ],
          )
        else
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: context.semantic.canvas,
              borderRadius: BorderRadius.circular(AppTheme.borderRadius),
              border: Border.all(
                color: Theme.of(context).colorScheme.outline,
                style: BorderStyle.solid,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.camera_alt,
                  size: 40,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(height: 4),
                Text(
                  l10n.dishNoPhoto,
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.dishPhotoSection,
                style: AppTextStyles.body.copyWith(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _dishPhotoPath != null
                    ? l10n.dishPhotoLoaded
                    : l10n.dishPhotoAddHint,
                style: context.styles.caption.copyWith(fontSize: 13),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  SizedBox(
                    height: 48,
                    child: OutlinedButton.icon(
                      onPressed: () => _pickPhoto(ImageSource.camera),
                      icon: const Icon(Icons.camera_alt, size: 20),
                      label: Text(
                        l10n.dishCamera,
                        style: const TextStyle(fontSize: 15),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                      ),
                    ),
                  ),
                  SizedBox(
                    height: 48,
                    child: OutlinedButton.icon(
                      onPressed: () => _pickPhoto(ImageSource.gallery),
                      icon: const Icon(Icons.photo_library, size: 20),
                      label: Text(
                        l10n.dishGallery,
                        style: const TextStyle(fontSize: 15),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _pickPhoto(ImageSource source) async {
    try {
      final picked = await _imagePicker.pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );
      if (picked != null) {
        setState(() => _dishPhotoPath = picked.path);
        _savePhotoPath(picked.path);
      }
    } catch (e) {
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.dishPhotoLoadError)));
      }
    }
  }

  Future<void> _savePhotoPath(String path) async {
    try {
      final db = GetIt.I<AppDatabase>();
      final existing = await db.dishPhotoDao.findByDish(widget.dishUcode);
      for (final p in existing) {
        await db.dishPhotoDao.deleteById(p.id);
      }
      await db.dishPhotoDao.insertPhoto(
        DishPhotosCompanion(
          dishUcode: Value(widget.dishUcode),
          filePath: Value(path),
          createdAt: Value(DateTime.now().millisecondsSinceEpoch ~/ 1000),
        ),
      );
    } catch (_) {}
  }

  Future<void> _deletePhoto() async {
    setState(() => _dishPhotoPath = null);
    try {
      final db = GetIt.I<AppDatabase>();
      final existing = await db.dishPhotoDao.findByDish(widget.dishUcode);
      for (final p in existing) {
        await db.dishPhotoDao.deleteById(p.id);
      }
    } catch (_) {}
  }

  Widget _costingCard({
    required String label,
    required String value,
    required IconData icon,
    TextStyle? valueStyle,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.borderRadius),
        border: Border.all(color: Theme.of(context).colorScheme.outline),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            size: 28,
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: AppTextStyles.body.copyWith(fontSize: 14)),
              const SizedBox(height: 4),
              Text(
                value,
                style: valueStyle ?? AppTextStyles.h3.copyWith(fontSize: 20),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _foodCostCard(double foodCostPercent) {
    final l10n = AppLocalizations.of(context)!;
    Color barColor;
    String statusLabel;
    if (foodCostPercent < 30) {
      barColor = AppColors.success;
      statusLabel = l10n.dishFoodCostExcellent;
    } else if (foodCostPercent <= 40) {
      barColor = AppColors.warning;
      statusLabel = l10n.dishFoodCostNormal;
    } else {
      barColor = Theme.of(context).colorScheme.error;
      statusLabel = l10n.dishFoodCostHigh;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.borderRadius),
        border: Border.all(color: Theme.of(context).colorScheme.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.restaurant,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                size: 28,
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.dishFoodCost,
                    style: AppTextStyles.body.copyWith(fontSize: 14),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${foodCostPercent.toStringAsFixed(1)}%',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: barColor,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: barColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: barColor.withValues(alpha: 0.3)),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: barColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: (foodCostPercent / 100).clamp(0.0, 1.0),
              minHeight: 12,
              valueColor: AlwaysStoppedAnimation<Color>(barColor),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('0%', style: context.styles.caption.copyWith(fontSize: 12)),
              Text(
                '30%',
                style: context.styles.caption.copyWith(
                  fontSize: 12,
                  color: AppColors.success,
                ),
              ),
              Text(
                '40%',
                style: context.styles.caption.copyWith(
                  fontSize: 12,
                  color: AppColors.warning,
                ),
              ),
              Text(
                '100%',
                style: context.styles.caption.copyWith(fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildYieldTab() {
    final l10n = AppLocalizations.of(context)!;
    final costing = _costing;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(AppTheme.borderRadius),
              border: Border.all(color: Theme.of(context).colorScheme.outline),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.room_service,
                  size: 28,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 16),
                Text(
                  l10n.dishServingsCount,
                  style: AppTextStyles.body.copyWith(fontSize: 16),
                ),
                const SizedBox(width: 16),
                SizedBox(
                  width: 100,
                  height: 52,
                  child: TextField(
                    controller: TextEditingController(
                      text: '$_servingsPerRecipe',
                    ),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 14,
                      ),
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    onChanged: (val) {
                      final n = int.tryParse(val);
                      if (n != null && n > 0) {
                        setState(() => _servingsPerRecipe = n);
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(AppTheme.borderRadius),
              border: Border.all(color: Theme.of(context).colorScheme.outline),
            ),
            child: Column(
              children: [
                _yieldRow(
                  icon: Icons.calculate,
                  label: l10n.dishCostPerServing,
                  value:
                      '${costing.costPerServing.toStringAsFixed(2)} ${tillCurrencySymbol()}',
                ),
                const Divider(height: 1),
                _yieldRow(
                  icon: Icons.sell,
                  label: l10n.dishPricePerServing,
                  value:
                      '${costing.pricePerServing.toStringAsFixed(2)} ${tillCurrencySymbol()}',
                ),
                const Divider(height: 1),
                _yieldRow(
                  icon: Icons.output,
                  label: l10n.dishTotalYield,
                  value: costing.totalYield.toStringAsFixed(3),
                ),
                const Divider(height: 1),
                _yieldRow(
                  icon: Icons.list,
                  label: l10n.dishIngredientsCount,
                  value: '${_ingredients.length}',
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          _buildCollapsibleSection(
            title: l10n.dishKbjuSection,
            icon: Icons.local_fire_department,
            isExpanded: _kbjuExpanded,
            onToggle: () => setState(() => _kbjuExpanded = !_kbjuExpanded),
            child: _buildKbjuContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildKbjuContent() {
    final l10n = AppLocalizations.of(context)!;
    if (!_hasKbjuData) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.semantic.canvas,
          borderRadius: BorderRadius.circular(AppTheme.borderRadius),
        ),
        child: Row(
          children: [
            Icon(
              TeleposIcons.info,
              size: 22,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 12),
            Text(
              l10n.dishKbjuEmpty,
              style: AppTextStyles.body.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 15,
              ),
            ),
          ],
        ),
      );
    }
    return _buildKbjuCards();
  }

  Widget _buildKbjuCards() {
    final l10n = AppLocalizations.of(context)!;
    final perServingCalories = _servingsPerRecipe > 0
        ? _totalCalories / _servingsPerRecipe
        : _totalCalories;
    final perServingProteins = _servingsPerRecipe > 0
        ? _totalProteins / _servingsPerRecipe
        : _totalProteins;
    final perServingFats = _servingsPerRecipe > 0
        ? _totalFats / _servingsPerRecipe
        : _totalFats;
    final perServingCarbs = _servingsPerRecipe > 0
        ? _totalCarbs / _servingsPerRecipe
        : _totalCarbs;

    return Column(
      children: [
        Row(
          children: [
            _kbjuCard(
              label: l10n.dishKbjuCalories,
              value: l10n.dishKcalValue(perServingCalories.toStringAsFixed(1)),
              color: const Color(0xFFFF9800),
            ),
            const SizedBox(width: 12),
            _kbjuCard(
              label: l10n.dishKbjuProteins,
              value: l10n.dishGramValue(perServingProteins.toStringAsFixed(1)),
              color: const Color(0xFFF44336),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _kbjuCard(
              label: l10n.dishKbjuFats,
              value: l10n.dishGramValue(perServingFats.toStringAsFixed(1)),
              color: const Color(0xFFFFC107),
            ),
            const SizedBox(width: 12),
            _kbjuCard(
              label: l10n.dishKbjuCarbs,
              value: l10n.dishGramValue(perServingCarbs.toStringAsFixed(1)),
              color: const Color(0xFF2196F3),
            ),
          ],
        ),
      ],
    );
  }

  Widget _kbjuCard({
    required String label,
    required String value,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(AppTheme.borderRadius),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 4,
              width: double.infinity,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: color,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _yieldRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      constraints: const BoxConstraints(minHeight: 56),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(
            icon,
            size: 24,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 16),
          Text(label, style: AppTextStyles.body.copyWith(fontSize: 16)),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showVersionHistoryDialog() async {
    final l10n = AppLocalizations.of(context)!;
    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            title: Text(l10n.dishVersionHistory),
            content: SizedBox(
              width: math.min(500.0, MediaQuery.sizeOf(ctx).width - 80),
              height: math.min(450.0, MediaQuery.sizeOf(ctx).height - 160),
              child: Column(
                children: [
                  Expanded(
                    child: _versionHistory.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.history,
                                  size: 48,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  l10n.dishNoVersions,
                                  style: AppTextStyles.body.copyWith(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            itemCount: _versionHistory.length,
                            itemBuilder: (_, idx) {
                              final v = _versionHistory[idx];
                              return Card(
                                margin: const EdgeInsets.only(bottom: 8),
                                child: ListTile(
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 8,
                                  ),
                                  onTap: () => _showVersionSnapshot(v),
                                  leading: CircleAvatar(
                                    radius: 20,
                                    backgroundColor: selectedSurfaceOf(context),
                                    child: Text(
                                      'v${v['version']}',
                                      style: context.styles.caption.copyWith(
                                        color: AppColors.primary,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  title: Text(
                                    l10n.dishVersionN(v['version'].toString()),
                                    style: AppTextStyles.body.copyWith(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 15,
                                    ),
                                  ),
                                  subtitle: Text(
                                    '${v['date']}'
                                    '${(v['author'] as String).isNotEmpty ? ' - ${v['author']}' : ''}'
                                    '${(v['summary'] as String).isNotEmpty ? '\n${v['summary']}' : ''}',
                                    style: context.styles.caption.copyWith(
                                      fontSize: 13,
                                    ),
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        tooltip: l10n.dishViewComposition,
                                        icon: const Icon(
                                          Icons.visibility_outlined,
                                          size: 22,
                                        ),
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onSurfaceVariant,
                                        onPressed: () =>
                                            _showVersionSnapshot(v),
                                      ),
                                      IconButton(
                                        tooltip: l10n.dishRestoreThisVersion,
                                        icon: const Icon(
                                          Icons.restore,
                                          size: 22,
                                        ),
                                        color: AppColors.primary,
                                        onPressed: () async {
                                          final restored =
                                              await _restoreVersion(v);
                                          if (restored && ctx.mounted) {
                                            setDialogState(() {});
                                          }
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        await _saveVersion();
                        if (ctx.mounted) {
                          setDialogState(() {});
                        }
                      },
                      icon: const Icon(TeleposIcons.save, size: 20),
                      label: Text(
                        l10n.dishSaveVersion,
                        style: const TextStyle(fontSize: 16),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: AppColors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              SizedBox(
                height: 48,
                child: TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: Text(
                    l10n.globalClose,
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  List<Map<String, dynamic>> _decodeSnapshot(String snapshotJson) {
    if (snapshotJson.isEmpty) return [];
    try {
      final decoded = jsonDecode(snapshotJson);
      if (decoded is List) {
        return decoded
            .whereType<Map>()
            .map((e) => e.map((k, val) => MapEntry(k.toString(), val)))
            .toList();
      }
    } catch (_) {}
    return [];
  }

  Future<void> _showVersionSnapshot(Map<String, dynamic> version) async {
    final l10n = AppLocalizations.of(context)!;
    final items = _decodeSnapshot(version['snapshot'] as String);

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.dishVersionComposition(version['version'].toString())),
        content: SizedBox(
          width: math.min(500.0, MediaQuery.sizeOf(ctx).width - 80),
          height: math.min(400.0, MediaQuery.sizeOf(ctx).height - 160),
          child: items.isEmpty
              ? Center(
                  child: Text(
                    l10n.dishSnapshotUnavailable,
                    style: AppTextStyles.body.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                )
              : ListView.separated(
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, idx) {
                    final it = items[idx];
                    return ListTile(
                      dense: true,
                      title: Text(
                        (it['name'] ?? '').toString(),
                        style: AppTextStyles.body.copyWith(fontSize: 15),
                      ),
                      subtitle: Text(
                        l10n.dishSnapshotIngredientLine(
                          (it['gross'] ?? '-').toString(),
                          (it['coldLoss'] ?? '-').toString(),
                          (it['hotLoss'] ?? '-').toString(),
                          (it['yield'] ?? '-').toString(),
                        ),
                        style: context.styles.caption.copyWith(fontSize: 13),
                      ),
                    );
                  },
                ),
        ),
        actions: [
          SizedBox(
            height: 48,
            child: TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(
                l10n.globalClose,
                style: const TextStyle(fontSize: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<bool> _restoreVersion(Map<String, dynamic> version) async {
    final l10n = AppLocalizations.of(context)!;
    final items = _decodeSnapshot(version['snapshot'] as String);

    final restorable =
        items.isNotEmpty && items.every((e) => e['ingredientUcode'] != null);

    if (!restorable) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.dishVersionNotRestorable)));
      }
      return false;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.dishRestoreVersionTitle),
        content: Text(
          l10n.dishRestoreVersionConfirm(version['version'].toString()),
        ),
        actions: [
          SizedBox(
            height: 48,
            child: TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(l10n.globalCancel),
            ),
          ),
          SizedBox(
            height: 48,
            child: ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.white,
              ),
              child: Text(l10n.dishRestore),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return false;

    try {
      final db = GetIt.I<AppDatabase>();
      await db.dishIngredientDao.deleteByDish(widget.dishUcode);
      var sortOrder = 0;
      for (final it in items) {
        final ingredientUcode = (it['ingredientUcode'] as num).toInt();
        final gross = Decimal.tryParse('${it['gross']}') ?? Decimal.zero;
        final coldLoss = Decimal.tryParse('${it['coldLoss']}') ?? Decimal.zero;
        final hotLoss = Decimal.tryParse('${it['hotLoss']}') ?? Decimal.zero;
        final net =
            Decimal.tryParse('${it['net']}') ??
            (gross *
                    ((Decimal.fromInt(100) - coldLoss) / Decimal.fromInt(100))
                        .toDecimal())
                .round(scale: 3);
        await db.dishIngredientDao.insertIngredient(
          DishIngredientsCompanion(
            dishUcode: Value(widget.dishUcode),
            ingredientUcode: Value(ingredientUcode),
            grossQuantity: Value(gross),
            netQuantity: Value(net),
            coldLossPercent: Value(coldLoss),
            hotLossPercent: Value(hotLoss),
            sortOrder: Value(sortOrder++),
          ),
        );
      }
      await _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              l10n.dishVersionRestored(version['version'].toString()),
            ),
          ),
        );
      }
      return true;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.dishRestoreError)));
      }
      return false;
    }
  }

  Future<void> _saveVersion() async {
    final snapshot = _ingredients
        .map(
          (i) => {
            'ingredientUcode': i.ingredientUcode,
            'name': i.ingredientName ?? '#${i.ingredientUcode}',
            'gross': i.grossQuantity.toString(),
            'coldLoss': i.coldLossPercent.toString(),
            'hotLoss': i.hotLossPercent.toString(),
            'net': i.netQuantity.toString(),
            'yield': i.finalYield.toString(),
          },
        )
        .toList();
    final json = jsonEncode(snapshot);

    final nextVersion = _versionHistory.isEmpty
        ? 1
        : (_versionHistory.first['version'] as int) + 1;
    final nowSeconds = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    try {
      final db = GetIt.I<AppDatabase>();
      final changedBy = await _resolveCurrentUserId(db);
      final summary = mounted
          ? AppLocalizations.of(context)!.dishVersionSummary(
              _ingredients.length,
              _costing.dishCost.toStringAsFixed(2),
            )
          : 'Ингредиентов: ${_ingredients.length}, '
                'себестоимость: ${_costing.dishCost.toStringAsFixed(2)}';
      await db.dishRecipeVersionDao.insertVersion(
        DishRecipeVersionsCompanion(
          dishUcode: Value(widget.dishUcode),
          versionNumber: Value(nextVersion),
          changeSummary: Value(summary),
          changedBy: Value(changedBy),
          changedAt: Value(nowSeconds),
          recipeSnapshot: Value(json),
        ),
      );
      await _loadVersionHistory();
    } catch (e) {
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.dishSaveVersionError)));
      }
    }
  }

  Future<int> _resolveCurrentUserId(AppDatabase db) async {
    try {
      final shift = await db.shiftDao.findOpenedShift();
      if (shift != null) return shift.userId;
      final lastUser = await db.userDao.findLast();
      if (lastUser != null) return lastUser.id;
    } catch (_) {}
    return 0;
  }

  Widget _buildBottomBar() {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: Theme.of(context).colorScheme.outline),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          SizedBox(
            height: 48,
            child: OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                side: BorderSide(color: Theme.of(context).colorScheme.outline),
              ),
              child: Text(
                l10n.globalClose,
                style: const TextStyle(fontSize: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

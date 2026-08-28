import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:telepos/app/theme/app_colors.dart';
import 'package:telepos/app/theme/app_semantic_colors.dart';
import 'package:telepos/app/theme/app_theme.dart';
import 'package:telepos/app/theme/app_tokens.dart';
import 'package:telepos/app/theme/telepos_icons.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/presentation/controllers/catalog/catalog_controller.dart';
import 'package:telepos/core/constants/enums/operating_mode.dart';
import 'package:telepos/presentation/controllers/app/app_state_controller.dart';
import 'package:telepos/presentation/screens/catalog/dialogs/category_editor_dialog.dart';
import 'package:telepos/presentation/screens/catalog/dialogs/menu_category_editor_dialog.dart';
import 'package:telepos/presentation/screens/catalog/dialogs/print_price_tag_dialog.dart';
import 'package:telepos/presentation/screens/catalog/dialogs/product_form_dialog.dart';
import 'package:telepos/presentation/screens/catalog/dialogs/quick_product_dialog.dart';
import 'package:telepos/presentation/common/widgets/scroll_assist.dart';
import 'package:telepos/presentation/screens/catalog/widgets/catalog_filter_bar.dart';
import 'package:telepos/presentation/screens/catalog/widgets/catalog_product_card.dart';
import 'package:telepos/presentation/screens/catalog/widgets/category_tree.dart';

class CatalogScreen extends ConsumerStatefulWidget {
  const CatalogScreen({super.key});

  @override
  ConsumerState<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends ConsumerState<CatalogScreen> {
  final _searchController = TextEditingController();

  final _listScrollController = ScrollController();
  final _tableScrollController = ScrollController();

  final _filterNameController = TextEditingController();
  final _filterBarcodeController = TextEditingController();
  final _filterTypeController = TextEditingController();
  final _filterPriceController = TextEditingController();
  final _filterQuantityController = TextEditingController();

  bool? _sidebarExpanded;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.invalidate(catalogControllerProvider);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _listScrollController.dispose();
    _tableScrollController.dispose();
    _filterNameController.dispose();
    _filterBarcodeController.dispose();
    _filterTypeController.dispose();
    _filterPriceController.dispose();
    _filterQuantityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isDesktop = screenWidth >= 900;
    final isTablet = screenWidth >= 600 && screenWidth < 900;
    final l10n = AppLocalizations.of(context)!;
    final catalogState = ref.watch(catalogControllerProvider);

    _sidebarExpanded ??= isDesktop;

    return Scaffold(
      appBar: isDesktop
          ? null
          : AppBar(
              title: Text(l10n.catalogTitle),
              foregroundColor: Theme.of(context).colorScheme.onSurface,
              elevation: 0,
            ),
      body: isDesktop
          ? _buildDesktopLayout(catalogState, l10n)
          : isTablet
          ? _buildTabletLayout(catalogState, l10n)
          : _buildMobileLayout(catalogState, l10n),
      floatingActionButton: isDesktop
          ? null
          : FloatingActionButton(
              onPressed: () => _showCreateDialog(context),
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.white,
              child: const Icon(TeleposIcons.add),
            ),
    );
  }

  Widget _buildDesktopLayout(CatalogState catalogState, AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
          child: Row(
            children: [
              Text(l10n.catalogTitle, style: AppTextStyles.h2),
              const Spacer(),
              OutlinedButton.icon(
                onPressed: () => _importCsv(context),
                icon: const Icon(Icons.upload_file, size: 18),
                label: Text(l10n.catalogImport),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.onSurface,
                  side: BorderSide(
                    color: Theme.of(context).colorScheme.outline,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: () => _exportCsv(context),
                icon: const Icon(Icons.download, size: 18),
                label: Text(l10n.catalogExportCsv),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.onSurface,
                  side: BorderSide(
                    color: Theme.of(context).colorScheme.outline,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: () => _showCategoryEditor(context),
                icon: const Icon(Icons.folder_outlined, size: 18),
                label: Text(l10n.catalogCategories),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.onSurface,
                  side: BorderSide(
                    color: Theme.of(context).colorScheme.outline,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: () => _showCreateDialog(context),
                icon: const Icon(TeleposIcons.add),
                label: Text(l10n.catalogAddProduct),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.white,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            children: [
              SizedBox(
                width: 320,
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: l10n.catalogSearchHint,
                    prefixIcon: const Icon(Icons.search),
                    border: const OutlineInputBorder(),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                    isDense: true,
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(TeleposIcons.close, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              ref
                                  .read(catalogControllerProvider.notifier)
                                  .searchProducts('');
                            },
                          )
                        : null,
                  ),
                  onSubmitted: (v) => ref
                      .read(catalogControllerProvider.notifier)
                      .searchProducts(v),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: CatalogFilterBar(
                  selectedType: catalogState.selectedType,
                  onTypeChanged: (t) => ref
                      .read(catalogControllerProvider.notifier)
                      .filterByType(t),
                  includeDeleted: catalogState.includeDeleted,
                  onToggleDeleted: () => ref
                      .read(catalogControllerProvider.notifier)
                      .toggleShowDeleted(),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (catalogState.categories.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(right: 16),
                    child: CategoryTree(
                      categories: catalogState.categories,
                      selectedCategoryId: catalogState.selectedCategoryId,
                      onCategorySelected: (id) => ref
                          .read(catalogControllerProvider.notifier)
                          .filterByCategory(id),
                      isExpanded: _sidebarExpanded!,
                      onToggleExpanded: () {
                        setState(() {
                          _sidebarExpanded = !_sidebarExpanded!;
                        });
                      },
                      onManageCategories: () => _showCategoryEditor(context),
                    ),
                  ),

                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(
                        AppTheme.borderRadius,
                      ),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                    ),
                    child: catalogState.isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : catalogState.items.isEmpty
                        ? _buildEmptyState(l10n)
                        : _buildDataTable(catalogState, l10n),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTabletLayout(CatalogState catalogState, AppLocalizations l10n) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(AppTheme.spacing),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: l10n.catalogSearchHint,
              prefixIcon: const Icon(Icons.search),
              border: const OutlineInputBorder(),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12),
              isDense: true,
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(TeleposIcons.close, size: 18),
                      onPressed: () {
                        _searchController.clear();
                        ref
                            .read(catalogControllerProvider.notifier)
                            .searchProducts('');
                      },
                    )
                  : null,
            ),
            onSubmitted: (v) =>
                ref.read(catalogControllerProvider.notifier).searchProducts(v),
          ),
        ),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacing),
          child: CatalogFilterBar(
            selectedType: catalogState.selectedType,
            onTypeChanged: (t) =>
                ref.read(catalogControllerProvider.notifier).filterByType(t),
            includeDeleted: catalogState.includeDeleted,
            onToggleDeleted: () => ref
                .read(catalogControllerProvider.notifier)
                .toggleShowDeleted(),
          ),
        ),

        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.spacing,
            vertical: 4,
          ),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _exportCsv(context),
                  icon: const Icon(Icons.download, size: 16),
                  label: Text(
                    l10n.catalogExportCsv,
                    style: context.styles.caption,
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.onSurface,
                    side: BorderSide(
                      color: Theme.of(context).colorScheme.outline,
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _importCsv(context),
                  icon: const Icon(Icons.upload_file, size: 16),
                  label: Text(
                    l10n.catalogImport,
                    style: context.styles.caption,
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.onSurface,
                    side: BorderSide(
                      color: Theme.of(context).colorScheme.outline,
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
              ),
            ],
          ),
        ),

        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (catalogState.categories.isNotEmpty)
                CategoryTree(
                  categories: catalogState.categories,
                  selectedCategoryId: catalogState.selectedCategoryId,
                  onCategorySelected: (id) => ref
                      .read(catalogControllerProvider.notifier)
                      .filterByCategory(id),
                  isExpanded: _sidebarExpanded!,
                  onToggleExpanded: () {
                    setState(() {
                      _sidebarExpanded = !_sidebarExpanded!;
                    });
                  },
                  onManageCategories: () => _showCategoryEditor(context),
                ),

              Expanded(
                child: catalogState.isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : catalogState.items.isEmpty
                    ? _buildEmptyState(l10n)
                    : ScrollAssist(
                        controller: _listScrollController,
                        child: ListView.builder(
                          controller: _listScrollController,
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppTheme.spacing,
                          ),
                          itemCount:
                              catalogState.items.length +
                              (catalogState.totalPages > 1 ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index == catalogState.items.length) {
                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                ),
                                child: _buildPagination(catalogState, l10n),
                              );
                            }
                            final item = catalogState.items[index];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: CatalogProductCard(
                                item: item,
                                onTap: () => _showEditDialog(context, item),
                                onToggleQuick: () => _toggleQuick(item),
                                onDelete: () => _confirmDelete(item),
                                onRestore: () => _restoreProduct(item),
                                onPrintLabel: () => _printLabel(item),
                              ),
                            );
                          },
                        ),
                      ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDataTable(CatalogState catalogState, AppLocalizations l10n) {
    final displayItems = catalogState.filteredItems;

    return Column(
      children: [
        Expanded(
          child: ScrollAssist(
            controller: _tableScrollController,
            child: SingleChildScrollView(
              controller: _tableScrollController,
              // Прокрутка вбок, а не растяжение на всю ширину.
              //
              // Было `SizedBox(width: double.infinity)`: таблица обязана была
              // влезть в окно, и при нехватке места `DataTable` сжимал
              // колонки. Название сжималось молча, а колонка действий — нет:
              // три кнопки по 32 точки не сжимаются, последняя уходила за
              // край ячейки, и нажать «Удалить» становилось нельзя. Тест
              // ловил это как промах тапа, а кассир — как неработающую
              // кнопку.
              //
              // `minWidth` оставляет прежний вид, пока места хватает: таблица
              // по-прежнему занимает всю ширину и вбок не прокручивается.
              child: LayoutBuilder(
                builder: (context, constraints) => SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minWidth: constraints.maxWidth),
                    child: DataTable(
                      sortColumnIndex: _sortColumnIndex(
                        catalogState.sortColumn,
                      ),
                      sortAscending: catalogState.sortAscending,
                      // Промежуток между колонками 24 вместо материальных 56.
                      //
                      // Пять полей фильтра по 120 точек плюс шесть промежутков
                      // по 56 давали таблицу шире, чем окно каталога после
                      // того, как левая колонка оболочки забрала 260 точек, —
                      // и колонка действий уезжала за правый край. Двадцать
                      // четыре возвращают таблицу в окно и заодно попадают в
                      // плотность редизайна; прокрутка вбок остаётся на
                      // случай по-настоящему узкого окна.
                      columnSpacing: AppTokens.space24,
                      headingRowColor: WidgetStateProperty.all(
                        context.semantic.canvas,
                      ),
                      columns: [
                        DataColumn(
                          label: Text(l10n.catalogProductName),
                          onSort: (_, asc) => ref
                              .read(catalogControllerProvider.notifier)
                              .sort('name', asc),
                        ),
                        DataColumn(
                          label: Text(l10n.catalogBarcode),
                          onSort: (_, asc) => ref
                              .read(catalogControllerProvider.notifier)
                              .sort('barcode', asc),
                        ),
                        DataColumn(
                          label: Text(l10n.catalogType),
                          onSort: (_, asc) => ref
                              .read(catalogControllerProvider.notifier)
                              .sort('type', asc),
                        ),
                        DataColumn(
                          label: Text(l10n.catalogPrice),
                          numeric: true,
                          onSort: (_, asc) => ref
                              .read(catalogControllerProvider.notifier)
                              .sort('price', asc),
                        ),
                        DataColumn(
                          label: Text(l10n.catalogQuantity),
                          numeric: true,
                          onSort: (_, asc) => ref
                              .read(catalogControllerProvider.notifier)
                              .sort('quantity', asc),
                        ),
                        const DataColumn(label: SizedBox.shrink()),
                      ],
                      rows: [
                        _buildFilterRow(l10n),
                        ...displayItems.map(
                          (item) => CatalogProductRow.build(
                            context: context,
                            item: item,
                            onTap: () => _showEditDialog(context, item),
                            onToggleQuick: () => _toggleQuick(item),
                            onDelete: () => _confirmDelete(item),
                            onRestore: () => _restoreProduct(item),
                            onPrintLabel: () => _printLabel(item),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        if (catalogState.totalPages > 1) _buildPagination(catalogState, l10n),
      ],
    );
  }

  int? _sortColumnIndex(String column) {
    return switch (column) {
      'name' => 0,
      'barcode' => 1,
      'type' => 2,
      'price' => 3,
      'quantity' => 4,
      _ => null,
    };
  }

  DataRow _buildFilterRow(AppLocalizations l10n) {
    return DataRow(
      color: WidgetStateProperty.all(AppColors.white),
      cells: [
        DataCell(
          _buildFilterField(
            _filterNameController,
            'name',
            l10n.catalogFilterColumn,
          ),
        ),
        DataCell(
          _buildFilterField(
            _filterBarcodeController,
            'barcode',
            l10n.catalogFilterColumn,
          ),
        ),
        DataCell(
          _buildFilterField(
            _filterTypeController,
            'type',
            l10n.catalogFilterColumn,
          ),
        ),
        DataCell(
          _buildFilterField(
            _filterPriceController,
            'price',
            l10n.catalogFilterColumn,
          ),
        ),
        DataCell(
          _buildFilterField(
            _filterQuantityController,
            'quantity',
            l10n.catalogFilterColumn,
          ),
        ),
        const DataCell(SizedBox.shrink()),
      ],
    );
  }

  Widget _buildFilterField(
    TextEditingController controller,
    String column,
    String hint,
  ) {
    return SizedBox(
      width: 120,
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: context.styles.caption,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 8,
            vertical: 6,
          ),
          border: const OutlineInputBorder(),
          suffixIcon: controller.text.isNotEmpty
              ? GestureDetector(
                  onTap: () {
                    controller.clear();
                    ref
                        .read(catalogControllerProvider.notifier)
                        .setColumnFilter(column, '');
                  },
                  child: const Icon(TeleposIcons.close, size: 14),
                )
              : null,
        ),
        style: context.styles.caption,
        onChanged: (value) {
          ref
              .read(catalogControllerProvider.notifier)
              .setColumnFilter(column, value);
        },
      ),
    );
  }

  Widget _buildMobileLayout(CatalogState catalogState, AppLocalizations l10n) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(AppTheme.spacing),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: l10n.catalogSearchHint,
              prefixIcon: const Icon(Icons.search),
              border: const OutlineInputBorder(),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12),
              isDense: true,
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(TeleposIcons.close, size: 18),
                      onPressed: () {
                        _searchController.clear();
                        ref
                            .read(catalogControllerProvider.notifier)
                            .searchProducts('');
                      },
                    )
                  : null,
            ),
            onSubmitted: (v) =>
                ref.read(catalogControllerProvider.notifier).searchProducts(v),
          ),
        ),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacing),
          child: CatalogFilterBar(
            selectedType: catalogState.selectedType,
            onTypeChanged: (t) =>
                ref.read(catalogControllerProvider.notifier).filterByType(t),
            includeDeleted: catalogState.includeDeleted,
            onToggleDeleted: () => ref
                .read(catalogControllerProvider.notifier)
                .toggleShowDeleted(),
          ),
        ),

        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.spacing,
            vertical: 4,
          ),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _exportCsv(context),
                  icon: const Icon(Icons.download, size: 16),
                  label: Text(
                    l10n.catalogExportCsv,
                    style: context.styles.caption,
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.onSurface,
                    side: BorderSide(
                      color: Theme.of(context).colorScheme.outline,
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _importCsv(context),
                  icon: const Icon(Icons.upload_file, size: 16),
                  label: Text(
                    l10n.catalogImport,
                    style: context.styles.caption,
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.onSurface,
                    side: BorderSide(
                      color: Theme.of(context).colorScheme.outline,
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
              ),
            ],
          ),
        ),

        if (catalogState.categories.isNotEmpty)
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.spacing,
                vertical: 8,
              ),
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(l10n.catalogAllCategories),
                    selected: catalogState.selectedCategoryId == null,
                    onSelected: (_) => ref
                        .read(catalogControllerProvider.notifier)
                        .filterByCategory(null),
                  ),
                ),
                ...catalogState.categories.map(
                  (cat) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(cat.name),
                      selected: catalogState.selectedCategoryId == cat.id,
                      onSelected: (_) => ref
                          .read(catalogControllerProvider.notifier)
                          .filterByCategory(cat.id),
                    ),
                  ),
                ),
              ],
            ),
          ),

        Expanded(
          child: catalogState.isLoading
              ? const Center(child: CircularProgressIndicator())
              : catalogState.items.isEmpty
              ? _buildEmptyState(l10n)
              : ScrollAssist(
                  controller: _listScrollController,
                  child: ListView.builder(
                    controller: _listScrollController,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.spacing,
                    ),
                    itemCount:
                        catalogState.items.length +
                        (catalogState.totalPages > 1 ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == catalogState.items.length) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: _buildPagination(catalogState, l10n),
                        );
                      }
                      final item = catalogState.items[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: CatalogProductCard(
                          item: item,
                          onTap: () => _showEditDialog(context, item),
                          onToggleQuick: () => _toggleQuick(item),
                          onDelete: () => _confirmDelete(item),
                          onRestore: () => _restoreProduct(item),
                          onPrintLabel: () => _printLabel(item),
                        ),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(AppLocalizations l10n) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.inventory_2_outlined,
            size: 64,
            color: AppColors.textDisabled,
          ),
          const SizedBox(height: 16),
          Text(
            l10n.catalogNoProducts,
            style: AppTextStyles.body.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPagination(CatalogState catalogState, AppLocalizations l10n) {
    final notifier = ref.read(catalogControllerProvider.notifier);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: Theme.of(context).colorScheme.outline),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            tooltip: l10n.catalogPageFirst,
            icon: const Icon(Icons.first_page),
            onPressed: catalogState.hasPrevPage ? notifier.firstPage : null,
          ),
          IconButton(
            tooltip: l10n.catalogPagePrev,
            icon: const Icon(Icons.chevron_left),
            onPressed: catalogState.hasPrevPage ? notifier.prevPage : null,
          ),
          const SizedBox(width: 8),
          InkWell(
            onTap: catalogState.totalPages > 1
                ? () => _showGoToPageDialog(catalogState, l10n)
                : null,
            borderRadius: BorderRadius.circular(6),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: Text(
                '${catalogState.currentPage + 1} / ${catalogState.totalPages}',
                style: AppTextStyles.body.copyWith(
                  fontWeight: FontWeight.w600,
                  color: catalogState.totalPages > 1
                      ? AppColors.primary
                      : Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          Text('(${catalogState.totalCount})', style: context.styles.caption),
          const SizedBox(width: 8),
          IconButton(
            tooltip: l10n.catalogPageNext,
            icon: const Icon(Icons.chevron_right),
            onPressed: catalogState.hasNextPage ? notifier.nextPage : null,
          ),
          IconButton(
            tooltip: l10n.catalogPageLast,
            icon: const Icon(Icons.last_page),
            onPressed: catalogState.hasNextPage ? notifier.lastPage : null,
          ),
        ],
      ),
    );
  }

  Future<void> _showGoToPageDialog(
    CatalogState catalogState,
    AppLocalizations l10n,
  ) async {
    final controller = TextEditingController(
      text: '${catalogState.currentPage + 1}',
    );
    final total = catalogState.totalPages;
    final page = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.catalogGoToPage),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: l10n.catalogPageOf(total),
            border: const OutlineInputBorder(),
          ),
          onSubmitted: (v) => Navigator.of(ctx).pop(int.tryParse(v.trim())),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(l10n.globalCancel),
          ),
          ElevatedButton(
            onPressed: () =>
                Navigator.of(ctx).pop(int.tryParse(controller.text.trim())),
            child: Text(l10n.globalOk),
          ),
        ],
      ),
    );
    if (page != null && page >= 1) {
      await ref.read(catalogControllerProvider.notifier).goToPage(page - 1);
    }
  }

  Future<void> _showCategoryEditor(BuildContext context) async {
    final changed = await CategoryEditorDialog.show(context);
    if (changed == true) {
      ref.invalidate(catalogControllerProvider);
    }

    if (!context.mounted) return;
    final mode = ref.read(operatingModeProvider);
    if (mode == OperatingMode.restaurant) {
      final menuChanged = await MenuCategoryEditorDialog.show(context);
      if (menuChanged == true) {
        ref.invalidate(catalogControllerProvider);
      }
    }
  }

  Future<void> _showCreateDialog(BuildContext context) async {
    final result = await ProductFormDialog.show(context);
    if (result == null) return;
    if (!context.mounted) return;

    final l10n = AppLocalizations.of(context)!;
    final success = await ref
        .read(catalogControllerProvider.notifier)
        .createProduct(
          name: result.name,
          barcode: result.barcode,
          type: result.type,
          measure: result.measure,
          sellingPrice: result.sellingPrice,
          wholesalePrice: result.wholesalePrice,
          categoryId: result.categoryId,
          description: result.description,
          imagePath: result.imagePath,
          vatRate: result.vatRate,
          ntin: result.ntin,
          isMarkable: result.isMarkable,
          brand: result.brand,
          manufacturer: result.manufacturer,
          countryOfOrigin: result.countryOfOrigin,
        );

    if (context.mounted && success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.catalogProductCreated),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  Future<void> _showEditDialog(BuildContext context, CatalogItem item) async {
    final result = await ProductFormDialog.show(context, item: item);
    if (result == null) return;
    if (!context.mounted) return;

    final l10n = AppLocalizations.of(context)!;
    final success = await ref
        .read(catalogControllerProvider.notifier)
        .editProduct(
          ucode: item.ucode,
          name: result.name,
          price: result.sellingPrice,
          wholesalePrice: result.wholesalePrice,
          type: result.type,
          measure: result.measure,
          categoryId: result.categoryId,
          description: result.description,
          imagePath: result.imagePath,
          vatRate: result.vatRate,
          vatRateSet: true,
          ntin: result.ntin,
          isMarkable: result.isMarkable,
          brand: result.brand,
          manufacturer: result.manufacturer,
          countryOfOrigin: result.countryOfOrigin,
        );

    if (context.mounted && success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.catalogProductUpdated),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  Future<void> _toggleQuick(CatalogItem item) async {
    if (item.isQuickProduct) {
      await ref
          .read(catalogControllerProvider.notifier)
          .toggleQuickProduct(item.ucode, item.name);
    } else {
      if (!context.mounted) return;
      final added = await QuickProductDialog.show(context, item: item);
      if (added == true) {
        await ref.read(catalogControllerProvider.notifier).loadProducts();
      }
    }

    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          item.isQuickProduct
              ? l10n.catalogRemoveFromQuick
              : l10n.catalogAddToQuick,
        ),
      ),
    );
  }

  Future<void> _confirmDelete(CatalogItem item) async {
    final l10n = AppLocalizations.of(context)!;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.catalogDeleteProduct),
        content: Text(l10n.catalogConfirmDelete(item.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.globalCancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
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
      final success = await ref
          .read(catalogControllerProvider.notifier)
          .deleteProduct(item.ucode);

      if (mounted && success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.catalogProductDeleted),
            backgroundColor: AppColors.warning,
          ),
        );
      }
    }
  }

  Future<void> _printLabel(CatalogItem item) async {
    await PrintPriceTagDialog.show(
      context,
      products: [
        PriceTagProduct(
          name: item.name,
          barcode: item.barcode.toString(),
          price: item.sellingPrice,
          sku: item.ucode.toString(),
        ),
      ],
    );
  }

  Future<void> _restoreProduct(CatalogItem item) async {
    final l10n = AppLocalizations.of(context)!;

    final success = await ref
        .read(catalogControllerProvider.notifier)
        .restoreProduct(item.ucode);

    if (mounted && success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.catalogProductRestored),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  Future<void> _exportCsv(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;

    final filePath = await ref
        .read(catalogControllerProvider.notifier)
        .exportCsv();

    if (!context.mounted) return;

    if (filePath != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.catalogExportSuccess(filePath)),
          backgroundColor: AppColors.success,
          duration: const Duration(seconds: 5),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.catalogExportFailed),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  Future<void> _importCsv(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;

    final result = await ref
        .read(catalogControllerProvider.notifier)
        .importCsv();

    if (!context.mounted) return;

    if (result.total == 0 && result.errors.isEmpty) {
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.catalogImportResults),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.catalogImportImported(result.imported)),
            Text(l10n.catalogImportUpdated(result.updated)),
            Text(l10n.catalogImportSkipped(result.skipped)),
            if (result.errors.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                l10n.catalogImportErrors,
                style: AppTextStyles.body.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
              const SizedBox(height: 4),
              SizedBox(
                height: 100,
                child: SingleChildScrollView(
                  child: Text(
                    result.errors.take(10).join('\n'),
                    style: context.styles.caption,
                  ),
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.globalOk),
          ),
        ],
      ),
    );
  }
}

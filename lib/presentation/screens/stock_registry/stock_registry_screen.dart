import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:telepos/app/router/app_routes.dart';
import 'package:telepos/app/theme/app_colors.dart';
import 'package:telepos/app/theme/app_semantic_colors.dart';
import 'package:telepos/app/theme/app_theme.dart';
import 'package:telepos/app/theme/telepos_icons.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/presentation/common/widgets/scroll_assist.dart';
import 'package:telepos/presentation/controllers/stock_registry/stock_registry_controller.dart';

class StockRegistryScreen extends ConsumerWidget {
  const StockRegistryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(stockRegistryControllerProvider);
    final screenWidth = MediaQuery.sizeOf(context).width;

    if (state.isLoading && state.items.isEmpty) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (state.error != null && state.items.isEmpty) {
      return _ErrorState(error: state.error!);
    }

    if (screenWidth >= 900) {
      return _DesktopLayout(state: state);
    } else if (screenWidth >= 600) {
      return _TabletLayout(state: state);
    } else {
      return _MobileLayout(state: state);
    }
  }
}

class _ErrorState extends ConsumerWidget {
  const _ErrorState({required this.error});

  final String error;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(stockRegistryControllerProvider.notifier);
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                TeleposIcons.error,
                size: 64,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(height: 16),
              Text(
                l10n.stockRegistryLoadError,
                style: AppTextStyles.h3.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                error,
                style: AppTextStyles.body.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () => notifier.refresh(),
                icon: const Icon(Icons.refresh),
                label: Text(l10n.globalRetry),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DesktopLayout extends ConsumerWidget {
  const _DesktopLayout({required this.state});

  final StockRegistryState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Column(
        children: [
          _StockRegistryFilters(state: state),

          Expanded(
            child: Container(
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                boxShadow: const [
                  BoxShadow(
                    color: AppColors.shadowLight,
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  _buildTableHeader(context, ref),
                  Expanded(
                    child: state.items.isEmpty
                        ? _buildEmptyState(context)
                        : _StockRegistryTable(items: state.items, state: state),
                  ),
                  _StockRegistryPagination(state: state),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 72),
        child: _CreateActionsFab(expanded: true),
      ),
    );
  }

  Widget _buildTableHeader(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(stockRegistryControllerProvider.notifier);
    final l10n = AppLocalizations.of(context)!;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: context.semantic.canvas,
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      child: Row(
        children: [
          Text(l10n.stockRegistryTitle, style: AppTextStyles.h3),
          const Spacer(),
          if (state.hasActiveFilters)
            TextButton.icon(
              onPressed: () => notifier.clearFilters(),
              icon: const Icon(TeleposIcons.close, size: 18),
              label: Text(l10n.stockRegistryResetFilters),
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: () => notifier.refresh(),
            icon: const Icon(Icons.refresh),
            tooltip: l10n.globalRefresh,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.inventory_outlined,
            size: 64,
            color: AppColors.textDisabled,
          ),
          const SizedBox(height: 16),
          Text(
            l10n.stockRegistryEmpty,
            style: AppTextStyles.h3.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            state.hasActiveFilters
                ? l10n.stockRegistryEmptyFiltered
                : l10n.stockRegistryEmptyCreate,
            style: AppTextStyles.body.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _TabletLayout extends ConsumerWidget {
  const _TabletLayout({required this.state});

  final StockRegistryState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Column(
        children: [
          _StockRegistryFilters(state: state, compact: true),
          Expanded(
            child: Container(
              margin: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  Expanded(
                    child: state.items.isEmpty
                        ? _buildEmptyState(context)
                        : _StockRegistryTable(
                            items: state.items,
                            state: state,
                            compact: true,
                          ),
                  ),
                  _StockRegistryPagination(state: state, compact: true),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 72),
        child: _CreateActionsFab(expanded: false),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.inventory_outlined,
            size: 48,
            color: AppColors.textDisabled,
          ),
          const SizedBox(height: 12),
          Text(
            AppLocalizations.of(context)!.stockRegistryEmpty,
            style: AppTextStyles.body.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _MobileLayout extends ConsumerStatefulWidget {
  const _MobileLayout({required this.state});

  final StockRegistryState state;

  @override
  ConsumerState<_MobileLayout> createState() => _MobileLayoutState();
}

class _MobileLayoutState extends ConsumerState<_MobileLayout> {
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final notifier = ref.read(stockRegistryControllerProvider.notifier);
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.stockRegistryAppBarTitle),
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        elevation: 0,
        actions: [
          if (state.hasActiveFilters)
            IconButton(
              onPressed: () => notifier.clearFilters(),
              icon: const Icon(Icons.filter_alt_off),
              tooltip: l10n.stockRegistryResetFilters,
            ),
          IconButton(
            onPressed: () => _showFiltersSheet(context),
            icon: Badge(
              isLabelVisible: state.hasActiveFilters,
              child: const Icon(Icons.filter_list),
            ),
            tooltip: l10n.stockRegistryFilters,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: state.items.isEmpty
                ? _buildEmptyState(context)
                : ScrollAssist(
                    controller: _scrollController,
                    child: ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(12),
                      itemCount: state.items.length,
                      itemBuilder: (context, index) {
                        final item = state.items[index];
                        return _StockRegistryCard(item: item);
                      },
                    ),
                  ),
          ),
          _StockRegistryPagination(state: state, compact: true),
        ],
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 72),
        child: _CreateActionsFab(expanded: false),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.inventory_outlined,
            size: 48,
            color: AppColors.textDisabled,
          ),
          const SizedBox(height: 12),
          Text(
            AppLocalizations.of(context)!.stockRegistryEmpty,
            style: AppTextStyles.body.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  void _showFiltersSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) {
          return SingleChildScrollView(
            controller: scrollController,
            padding: const EdgeInsets.all(16),
            child: _StockRegistryFilters(state: widget.state, mobile: true),
          );
        },
      ),
    );
  }
}

class _StockRegistryFilters extends ConsumerStatefulWidget {
  const _StockRegistryFilters({
    required this.state,
    this.compact = false,
    this.mobile = false,
  });

  final StockRegistryState state;
  final bool compact;
  final bool mobile;

  @override
  ConsumerState<_StockRegistryFilters> createState() =>
      _StockRegistryFiltersState();
}

class _StockRegistryFiltersState extends ConsumerState<_StockRegistryFilters> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final notifier = ref.read(stockRegistryControllerProvider.notifier);
    final l10n = AppLocalizations.of(context)!;

    if (_searchController.text != (widget.state.searchQuery ?? '')) {
      _searchController.text = widget.state.searchQuery ?? '';
    }

    if (widget.mobile) {
      return _buildMobileLayout(context, notifier, l10n);
    }
    if (widget.compact) {
      return _buildCompactLayout(context, notifier, l10n);
    }
    return _buildFullLayout(context, notifier, l10n);
  }

  Widget _buildFullLayout(
    BuildContext context,
    StockRegistryNotifier notifier,
    AppLocalizations l10n,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Theme.of(context).colorScheme.surface,
      child: Row(
        children: [
          _buildDateRangePicker(context, notifier, l10n),
          const SizedBox(width: 16),
          _buildTypeFilter(notifier, l10n),
          const SizedBox(width: 16),
          Expanded(child: _buildSearchField(notifier, l10n)),
        ],
      ),
    );
  }

  Widget _buildCompactLayout(
    BuildContext context,
    StockRegistryNotifier notifier,
    AppLocalizations l10n,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: Theme.of(context).colorScheme.surface,
      child: Row(
        children: [
          IconButton(
            onPressed: () => _showDatePicker(context, notifier),
            icon: Badge(
              isLabelVisible:
                  widget.state.dateFrom != null || widget.state.dateTo != null,
              child: const Icon(Icons.date_range),
            ),
            tooltip: l10n.stockRegistryPeriod,
          ),
          PopupMenuButton<StockOperationType?>(
            icon: Badge(
              isLabelVisible: widget.state.typeFilter != null,
              child: const Icon(Icons.filter_alt),
            ),
            tooltip: l10n.stockRegistryOperationType,
            onSelected: notifier.setFilter,
            itemBuilder: (ctx) => [
              PopupMenuItem(value: null, child: Text(l10n.globalAll)),
              PopupMenuItem(
                value: StockOperationType.supply,
                child: Text(l10n.stockOpSupply),
              ),
              PopupMenuItem(
                value: StockOperationType.movement,
                child: Text(l10n.stockOpMovement),
              ),
              PopupMenuItem(
                value: StockOperationType.supplierReturn,
                child: Text(l10n.stockOpSupplierReturn),
              ),
            ],
          ),
          const SizedBox(width: 8),
          Expanded(
            child: SizedBox(
              height: 40,
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: l10n.globalSearch,
                  prefixIcon: const Icon(Icons.search, size: 20),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(TeleposIcons.close, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            notifier.setSearchQuery(null);
                          },
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: context.semantic.canvas,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                ),
                onChanged: (value) {
                  notifier.setSearchQuery(value.isEmpty ? null : value);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileLayout(
    BuildContext context,
    StockRegistryNotifier notifier,
    AppLocalizations l10n,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(l10n.stockRegistryFilters, style: AppTextStyles.h3),
            IconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(TeleposIcons.close),
            ),
          ],
        ),
        const Divider(),
        const SizedBox(height: 16),

        TextField(
          controller: _searchController,
          decoration: InputDecoration(
            labelText: l10n.globalSearch,
            hintText: l10n.stockRegistrySearchHint,
            prefixIcon: const Icon(Icons.search),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
          onChanged: (value) {
            notifier.setSearchQuery(value.isEmpty ? null : value);
          },
        ),
        const SizedBox(height: 16),

        Text(l10n.stockRegistryPeriod, style: AppTextStyles.body),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => _selectDate(context, true, notifier),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: Text(
                  widget.state.dateFrom != null
                      ? _formatDate(widget.state.dateFrom!)
                      : l10n.stockRegistryDateFrom,
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Text('\u2014'),
            ),
            Expanded(
              child: OutlinedButton(
                onPressed: () => _selectDate(context, false, notifier),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: Text(
                  widget.state.dateTo != null
                      ? _formatDate(widget.state.dateTo!)
                      : l10n.stockRegistryDateTo,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        Text(l10n.stockRegistryOperationType, style: AppTextStyles.body),
        const SizedBox(height: 8),
        SegmentedButton<StockOperationType?>(
          segments: [
            ButtonSegment(value: null, label: Text(l10n.globalAll)),
            ButtonSegment(
              value: StockOperationType.supply,
              label: Text(l10n.stockOpSupply),
            ),
            ButtonSegment(
              value: StockOperationType.movement,
              label: Text(l10n.stockOpMovementShort),
            ),
            ButtonSegment(
              value: StockOperationType.supplierReturn,
              label: Text(l10n.stockOpReturnShort),
            ),
          ],
          selected: {widget.state.typeFilter},
          onSelectionChanged: (set) {
            notifier.setFilter(set.first);
          },
        ),
        const SizedBox(height: 24),

        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () {
                  notifier.clearFilters();
                  Navigator.of(context).pop();
                },
                child: Text(l10n.globalReset),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.white,
                ),
                child: Text(l10n.globalApply),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDateRangePicker(
    BuildContext context,
    StockRegistryNotifier notifier,
    AppLocalizations l10n,
  ) {
    final hasDateFilter =
        widget.state.dateFrom != null || widget.state.dateTo != null;

    return OutlinedButton.icon(
      onPressed: () => _showDatePicker(context, notifier),
      icon: const Icon(Icons.date_range, size: 18),
      label: Text(
        hasDateFilter
            ? '${widget.state.dateFrom != null ? _formatDate(widget.state.dateFrom!) : '...'} \u2014 ${widget.state.dateTo != null ? _formatDate(widget.state.dateTo!) : '...'}'
            : l10n.stockRegistryPeriod,
      ),
      style: OutlinedButton.styleFrom(
        foregroundColor: hasDateFilter
            ? AppColors.primary
            : Theme.of(context).colorScheme.onSurfaceVariant,
        side: BorderSide(
          color: hasDateFilter ? AppColors.primary : context.semantic.canvas,
        ),
      ),
    );
  }

  Widget _buildTypeFilter(
    StockRegistryNotifier notifier,
    AppLocalizations l10n,
  ) {
    return SegmentedButton<StockOperationType?>(
      segments: [
        ButtonSegment(value: null, label: Text(l10n.globalAll)),
        ButtonSegment(
          value: StockOperationType.supply,
          icon: const Icon(Icons.inventory_2, size: 16),
          label: Text(l10n.stockOpSupply),
        ),
        ButtonSegment(
          value: StockOperationType.movement,
          icon: const Icon(Icons.swap_horiz, size: 16),
          label: Text(l10n.stockOpMovement),
        ),
        ButtonSegment(
          value: StockOperationType.supplierReturn,
          icon: const Icon(Icons.assignment_return, size: 16),
          label: Text(l10n.stockOpReturnShort),
        ),
      ],
      selected: {widget.state.typeFilter},
      onSelectionChanged: (set) {
        notifier.setFilter(set.first);
      },
    );
  }

  Widget _buildSearchField(
    StockRegistryNotifier notifier,
    AppLocalizations l10n,
  ) {
    return TextField(
      controller: _searchController,
      decoration: InputDecoration(
        hintText: l10n.stockRegistrySearchHint,
        prefixIcon: const Icon(Icons.search),
        suffixIcon: _searchController.text.isNotEmpty
            ? IconButton(
                icon: const Icon(TeleposIcons.close),
                onPressed: () {
                  _searchController.clear();
                  notifier.setSearchQuery(null);
                },
              )
            : null,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      ),
      onChanged: (value) {
        notifier.setSearchQuery(value.isEmpty ? null : value);
      },
    );
  }

  Future<void> _showDatePicker(
    BuildContext context,
    StockRegistryNotifier notifier,
  ) async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange:
          widget.state.dateFrom != null && widget.state.dateTo != null
          ? DateTimeRange(
              start: widget.state.dateFrom!,
              end: widget.state.dateTo!,
            )
          : null,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(primary: AppColors.primary),
          ),
          child: child!,
        );
      },
    );
    if (range != null) {
      notifier.setDateRange(range.start, range.end);
    }
  }

  Future<void> _selectDate(
    BuildContext context,
    bool isFrom,
    StockRegistryNotifier notifier,
  ) async {
    final initialDate = isFrom
        ? widget.state.dateFrom ?? DateTime.now()
        : widget.state.dateTo ?? DateTime.now();

    final date = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );

    if (date != null) {
      if (isFrom) {
        notifier.setDateRange(date, widget.state.dateTo);
      } else {
        notifier.setDateRange(widget.state.dateFrom, date);
      }
    }
  }

  String _formatDate(DateTime date) {
    final d = date.day.toString().padLeft(2, '0');
    final m = date.month.toString().padLeft(2, '0');
    return '$d.$m.${date.year}';
  }
}

class _StockRegistryTable extends ConsumerWidget {
  const _StockRegistryTable({
    required this.items,
    required this.state,
    this.compact = false,
  });

  final List<StockRegistryItem> items;
  final StockRegistryState state;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(stockRegistryControllerProvider.notifier);
    final l10n = AppLocalizations.of(context)!;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minWidth: MediaQuery.sizeOf(context).width - 32,
        ),
        child: DataTable(
          columnSpacing: compact ? 16 : 24,
          horizontalMargin: compact ? 12 : 16,
          headingRowHeight: compact ? 48 : 56,
          dataRowMinHeight: compact ? 44 : 52,
          dataRowMaxHeight: compact ? 52 : 60,
          showCheckboxColumn: false,
          sortColumnIndex: _getSortColumnIndex(state.sortColumn),
          sortAscending: state.sortAscending,
          columns: [
            DataColumn(
              label: const Icon(Icons.category, size: 18),
              tooltip: l10n.stockRegistryColType,
            ),
            DataColumn(
              label: Text(l10n.stockRegistryColNumber),
              onSort: (_, ascending) => notifier.sortBy('id', ascending),
            ),
            DataColumn(
              label: Text(l10n.globalDate),
              onSort: (_, ascending) => notifier.sortBy('date', ascending),
            ),
            DataColumn(label: Text(l10n.stockRegistryColCounterparty)),
            DataColumn(
              label: Text(l10n.globalAmount),
              numeric: true,
              onSort: (_, ascending) => notifier.sortBy('amount', ascending),
            ),
            DataColumn(
              label: Text(l10n.stockRegistryColProducts),
              numeric: true,
            ),
            DataColumn(label: Text(l10n.stockRegistryColStatus)),
          ],
          rows: items.map((item) => _buildRow(context, item)).toList(),
        ),
      ),
    );
  }

  DataRow _buildRow(BuildContext context, StockRegistryItem item) {
    final (typeIcon, typeColor) = _typeIconAndColor(item.type);
    final l10n = AppLocalizations.of(context)!;

    return DataRow(
      onSelectChanged: (_) => _showDetails(context, item),
      color: WidgetStateProperty.all(typeColor.withValues(alpha: 0.03)),
      cells: [
        DataCell(
          Tooltip(
            message: _typeLabel(l10n, item.type),
            child: Icon(typeIcon, size: 20, color: typeColor),
          ),
        ),
        DataCell(
          Text(
            item.formattedId,
            style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w500),
          ),
        ),
        DataCell(Text(_formatDateTime(item.date), style: AppTextStyles.body)),
        DataCell(
          Text(
            _getCounterparty(item),
            style: AppTextStyles.body,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        DataCell(
          Text(
            item.amount.toStringAsFixed(2),
            style: AppTextStyles.body.copyWith(
              fontWeight: FontWeight.w600,
              color: typeColor,
            ),
          ),
        ),
        DataCell(Text('${item.productCount ?? 0}', style: AppTextStyles.body)),
        DataCell(_buildSyncBadge(context, l10n, item.state)),
      ],
    );
  }

  String _getCounterparty(StockRegistryItem item) {
    return switch (item.type) {
      StockOperationType.supply => item.supplierName ?? '-',
      StockOperationType.movement =>
        '${item.fromLocation ?? "?"} \u2192 ${item.toLocation ?? "?"}',
      StockOperationType.supplierReturn => item.supplierName ?? '-',
    };
  }

  Widget _buildSyncBadge(
    BuildContext context,
    AppLocalizations l10n,
    int syncState,
  ) {
    final (label, color) = switch (syncState) {
      0 => (
        l10n.stockSyncDraft,
        Theme.of(context).colorScheme.onSurfaceVariant,
      ),
      1 => (l10n.stockSyncPending, AppColors.warning),
      2 => (l10n.stockSyncSending, AppColors.info),
      3 => (l10n.stockSyncSynced, AppColors.success),
      _ => ('?', Theme.of(context).colorScheme.onSurfaceVariant),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: AppTextStyles.body.copyWith(
          fontSize: 12,
          color: color,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  (IconData, Color) _typeIconAndColor(StockOperationType type) {
    return switch (type) {
      StockOperationType.supply => (Icons.inventory_2, AppColors.success),
      StockOperationType.movement => (Icons.swap_horiz, AppColors.info),
      StockOperationType.supplierReturn => (
        Icons.assignment_return,
        AppColors.warning,
      ),
    };
  }

  String _typeLabel(AppLocalizations l10n, StockOperationType type) {
    return switch (type) {
      StockOperationType.supply => l10n.stockOpSupply,
      StockOperationType.movement => l10n.stockOpMovement,
      StockOperationType.supplierReturn => l10n.stockOpSupplierReturn,
    };
  }

  int? _getSortColumnIndex(String column) {
    return switch (column) {
      'id' => 1,
      'date' => 2,
      'amount' => 4,
      _ => null,
    };
  }

  String _formatDateTime(DateTime time) {
    final d = time.day.toString().padLeft(2, '0');
    final m = time.month.toString().padLeft(2, '0');
    final h = time.hour.toString().padLeft(2, '0');
    final min = time.minute.toString().padLeft(2, '0');
    return '$d.$m.${time.year} $h:$min';
  }

  void _showDetails(BuildContext context, StockRegistryItem item) {
    showDialog<void>(
      context: context,
      builder: (ctx) {
        final l10n = AppLocalizations.of(ctx)!;
        return AlertDialog(
          title: Text(item.formattedId),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.stockRegistryDetailType(_typeLabel(l10n, item.type))),
              Text(l10n.stockRegistryDetailDate(_formatDateTime(item.date))),
              Text(
                l10n.stockRegistryDetailCounterparty(_getCounterparty(item)),
              ),
              Text(
                l10n.stockRegistryDetailAmount(item.amount.toStringAsFixed(2)),
              ),
              Text(l10n.stockRegistryDetailProducts(item.productCount ?? 0)),
              if (item.comment != null)
                Text(l10n.stockRegistryDetailComment(item.comment!)),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(l10n.globalClose),
            ),
          ],
        );
      },
    );
  }
}

class _StockRegistryPagination extends ConsumerWidget {
  const _StockRegistryPagination({required this.state, this.compact = false});

  final StockRegistryState state;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(stockRegistryControllerProvider.notifier);

    if (state.totalCount == 0) {
      return const SizedBox.shrink();
    }

    if (compact) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        color: Theme.of(context).colorScheme.surface,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              onPressed: state.canGoPrevious
                  ? () => notifier.goToPrevious()
                  : null,
              icon: const Icon(Icons.chevron_left),
              iconSize: 24,
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: context.semantic.canvas,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${state.currentPage} / ${state.totalPages}',
                style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w500),
              ),
            ),
            IconButton(
              onPressed: state.canGoNext ? () => notifier.goToNext() : null,
              icon: const Icon(Icons.chevron_right),
              iconSize: 24,
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.semantic.canvas,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(12)),
      ),
      child: Row(
        children: [
          Text(
            AppLocalizations.of(context)!.stockRegistryPaginationRange(
              state.startIndex,
              state.endIndex,
              state.totalCount,
            ),
            style: AppTextStyles.body.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const Spacer(),
          Row(
            children: [
              IconButton(
                onPressed: state.canGoPrevious
                    ? () => notifier.goToFirst()
                    : null,
                icon: const Icon(Icons.first_page),
                iconSize: 20,
              ),
              IconButton(
                onPressed: state.canGoPrevious
                    ? () => notifier.goToPrevious()
                    : null,
                icon: const Icon(Icons.chevron_left),
                iconSize: 24,
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '${state.currentPage} / ${state.totalPages}',
                  style: AppTextStyles.body.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              IconButton(
                onPressed: state.canGoNext ? () => notifier.goToNext() : null,
                icon: const Icon(Icons.chevron_right),
                iconSize: 24,
              ),
              IconButton(
                onPressed: state.canGoNext ? () => notifier.goToLast() : null,
                icon: const Icon(Icons.last_page),
                iconSize: 20,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StockRegistryCard extends StatelessWidget {
  const _StockRegistryCard({required this.item});

  final StockRegistryItem item;

  @override
  Widget build(BuildContext context) {
    final (typeIcon, typeColor) = switch (item.type) {
      StockOperationType.supply => (Icons.inventory_2, AppColors.success),
      StockOperationType.movement => (Icons.swap_horiz, AppColors.info),
      StockOperationType.supplierReturn => (
        Icons.assignment_return,
        AppColors.warning,
      ),
    };

    final l10n = AppLocalizations.of(context)!;
    final typeLabel = switch (item.type) {
      StockOperationType.supply => l10n.stockOpSupply,
      StockOperationType.movement => l10n.stockOpMovement,
      StockOperationType.supplierReturn => l10n.stockOpReturnShort,
    };

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => _showDetails(context),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: typeColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(typeIcon, color: typeColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          item.formattedId,
                          style: AppTextStyles.body.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: typeColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            typeLabel,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: typeColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_getCounterpartyForCard(item)} \u2022 ${_formatDateTime(item.date)}',
                      style: AppTextStyles.body.copyWith(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    item.amount.toStringAsFixed(2),
                    style: AppTextStyles.body.copyWith(
                      fontWeight: FontWeight.w600,
                      color: typeColor,
                    ),
                  ),
                  Text(
                    l10n.stockRegistryProductsShort(item.productCount ?? 0),
                    style: AppTextStyles.body.copyWith(
                      fontSize: 11,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getCounterpartyForCard(StockRegistryItem item) {
    return switch (item.type) {
      StockOperationType.supply => item.supplierName ?? '-',
      StockOperationType.movement =>
        '${item.fromLocation ?? "?"} \u2192 ${item.toLocation ?? "?"}',
      StockOperationType.supplierReturn => item.supplierName ?? '-',
    };
  }

  String _formatDateTime(DateTime time) {
    final d = time.day.toString().padLeft(2, '0');
    final m = time.month.toString().padLeft(2, '0');
    final h = time.hour.toString().padLeft(2, '0');
    final min = time.minute.toString().padLeft(2, '0');
    return '$d.$m.${time.year} $h:$min';
  }

  void _showDetails(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) {
        final l10n = AppLocalizations.of(ctx)!;
        final typeLabel = switch (item.type) {
          StockOperationType.supply => l10n.stockOpSupply,
          StockOperationType.movement => l10n.stockOpMovement,
          StockOperationType.supplierReturn => l10n.stockOpSupplierReturn,
        };
        return AlertDialog(
          title: Text(item.formattedId),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.stockRegistryDetailType(typeLabel)),
              Text(l10n.stockRegistryDetailDate(_formatDateTime(item.date))),
              Text(
                l10n.stockRegistryDetailCounterparty(
                  _getCounterpartyForCard(item),
                ),
              ),
              Text(
                l10n.stockRegistryDetailAmount(item.amount.toStringAsFixed(2)),
              ),
              Text(l10n.stockRegistryDetailProducts(item.productCount ?? 0)),
              if (item.comment != null)
                Text(l10n.stockRegistryDetailComment(item.comment!)),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(l10n.globalClose),
            ),
          ],
        );
      },
    );
  }
}

class _CreateActionsFab extends ConsumerWidget {
  const _CreateActionsFab({required this.expanded});

  final bool expanded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FloatingActionButton.extended(
      onPressed: () => _showCreateMenu(context, ref),
      backgroundColor: AppColors.primary,
      foregroundColor: AppColors.white,
      icon: const Icon(TeleposIcons.add),
      label: expanded
          ? Text(AppLocalizations.of(context)!.globalCreate)
          : const SizedBox.shrink(),
    );
  }

  void _showCreateMenu(BuildContext context, WidgetRef ref) {
    final router = GoRouter.of(context);
    final l10n = AppLocalizations.of(context)!;

    void invalidateRegistry() {
      ref.invalidate(stockRegistryControllerProvider);
    }

    showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetCtx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.outline,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              _CreateMenuItem(
                icon: Icons.inventory_2,
                color: AppColors.success,
                title: l10n.stockCreateSupplyTitle,
                subtitle: l10n.stockCreateSupplySubtitle,
                onTap: () {
                  Navigator.of(sheetCtx).pop();
                  invalidateRegistry();
                  router.go(AppRoutes.supply);
                },
              ),
              _CreateMenuItem(
                icon: Icons.swap_horiz,
                color: AppColors.info,
                title: l10n.stockOpMovement,
                subtitle: l10n.stockCreateMovementSubtitle,
                onTap: () {
                  Navigator.of(sheetCtx).pop();
                  invalidateRegistry();
                  router.go(AppRoutes.movement);
                },
              ),
              _CreateMenuItem(
                icon: Icons.assignment_return,
                color: AppColors.warning,
                title: l10n.stockOpSupplierReturn,
                subtitle: l10n.stockCreateReturnSubtitle,
                onTap: () {
                  Navigator.of(sheetCtx).pop();
                  invalidateRegistry();
                  router.go(AppRoutes.supplierReturn);
                },
              ),
              _CreateMenuItem(
                icon: Icons.remove_circle_outline,
                color: Theme.of(context).colorScheme.error,
                title: l10n.writeoffTitle,
                subtitle: l10n.stockCreateWriteoffSubtitle,
                onTap: () {
                  Navigator.of(sheetCtx).pop();
                  invalidateRegistry();
                  router.push(AppRoutes.writeoff);
                },
              ),
              _CreateMenuItem(
                icon: Icons.fact_check_outlined,
                color: AppColors.info,
                title: l10n.inventoryTitle,
                subtitle: l10n.stockCreateInventorySubtitle,
                onTap: () {
                  Navigator.of(sheetCtx).pop();
                  invalidateRegistry();
                  router.push(AppRoutes.inventory);
                },
              ),
              _CreateMenuItem(
                icon: Icons.playlist_add_check,
                color: AppColors.primary,
                title: 'Заявка поставщику',
                subtitle: 'Дозаказ товаров с низким остатком',
                onTap: () {
                  Navigator.of(sheetCtx).pop();
                  router.go(AppRoutes.supplierOrder);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

class _CreateMenuItem extends StatelessWidget {
  const _CreateMenuItem({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: color, size: 28),
      ),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontSize: 13,
        ),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      onTap: onTap,
    );
  }
}

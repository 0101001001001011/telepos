import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:telepos/app/theme/app_colors.dart';
import 'package:telepos/app/theme/app_semantic_colors.dart';
import 'package:telepos/app/theme/app_theme.dart';
import 'package:telepos/app/theme/telepos_icons.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/presentation/controllers/history/history_controller.dart';

class HistoryFilters extends ConsumerStatefulWidget {
  const HistoryFilters({super.key, this.compact = false, this.mobile = false});

  final bool compact;
  final bool mobile;

  @override
  ConsumerState<HistoryFilters> createState() => _HistoryFiltersState();
}

class _HistoryFiltersState extends ConsumerState<HistoryFilters> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(historyControllerProvider);
    final notifier = ref.read(historyControllerProvider.notifier);

    if (_searchController.text != (state.searchQuery ?? '')) {
      _searchController.text = state.searchQuery ?? '';
    }

    if (widget.mobile) {
      return _buildMobileLayout(context, state, notifier);
    }

    if (widget.compact) {
      return _buildCompactLayout(context, state, notifier);
    }

    return _buildFullLayout(context, state, notifier);
  }

  Widget _buildFullLayout(
    BuildContext context,
    HistoryState state,
    HistoryNotifier notifier,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Theme.of(context).colorScheme.surface,
      // Оба фильтра — `Flexible`, а не жёсткие.
      //
      // Обнаружено при переводе проверок на тему приложения: под стандартной
      // темой Flutter кнопки ниже и уже, и строка укладывалась; под настоящей
      // темой (минимальная высота кнопки 48, свои отступы у сегментов) она
      // переполнялась на 32 точки, как только в выборе периода появлялась
      // вторая дата вместо слова «Период». `Expanded` у поиска забирал
      // остаток, которого уже не было, — отсюда переполнение, а не обрезка.
      child: Row(
        children: [
          Flexible(child: _buildDateRangePicker(context, state, notifier)),
          const SizedBox(width: 16),

          Flexible(child: _buildTypeFilter(state, notifier)),
          const SizedBox(width: 16),

          Expanded(child: _buildSearchField(notifier)),
        ],
      ),
    );
  }

  Widget _buildCompactLayout(
    BuildContext context,
    HistoryState state,
    HistoryNotifier notifier,
  ) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: Theme.of(context).colorScheme.surface,
      child: Row(
        children: [
          IconButton(
            onPressed: () => _showDatePicker(context, state, notifier),
            icon: Badge(
              isLabelVisible: state.dateFrom != null || state.dateTo != null,
              child: const Icon(Icons.date_range),
            ),
            tooltip: l10n.historyPeriod,
          ),

          PopupMenuButton<HistoryItemType?>(
            icon: Badge(
              isLabelVisible: state.typeFilter != null,
              child: const Icon(Icons.filter_alt),
            ),
            tooltip: l10n.historyOperationType,
            onSelected: notifier.setTypeFilter,
            itemBuilder: (ctx) {
              final dl10n = AppLocalizations.of(ctx)!;
              return [
                PopupMenuItem(value: null, child: Text(dl10n.globalAll)),
                PopupMenuItem(
                  value: HistoryItemType.sale,
                  child: Text(dl10n.historyFilterSales),
                ),
                PopupMenuItem(
                  value: HistoryItemType.refund,
                  child: Text(dl10n.historyFilterRefunds),
                ),
                PopupMenuItem(
                  value: HistoryItemType.serviceOrder,
                  child: Text(dl10n.serviceQueueTitle),
                ),
                const PopupMenuItem(
                  value: HistoryItemType.restaurantOrder,
                  child: Text('Ресторан'),
                ),
              ];
            },
          ),

          const SizedBox(width: 8),

          Expanded(
            child: SizedBox(
              height: 40,
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: l10n.historySearchShort,
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
    HistoryState state,
    HistoryNotifier notifier,
  ) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(l10n.historyFilters, style: AppTextStyles.h3),
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
            hintText: l10n.historySearchHint,
            prefixIcon: const Icon(Icons.search),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
          onChanged: (value) {
            notifier.setSearchQuery(value.isEmpty ? null : value);
          },
        ),
        const SizedBox(height: 16),

        Text(l10n.historyPeriod, style: AppTextStyles.body),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _DateButton(
                label: state.dateFrom != null
                    ? _formatDate(state.dateFrom!)
                    : l10n.historyDateFrom,
                onTap: () => _selectDate(context, true, state, notifier),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Text('—'),
            ),
            Expanded(
              child: _DateButton(
                label: state.dateTo != null
                    ? _formatDate(state.dateTo!)
                    : l10n.historyDateTo,
                onTap: () => _selectDate(context, false, state, notifier),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        Text(l10n.historyOperationType, style: AppTextStyles.body),
        const SizedBox(height: 8),
        SegmentedButton<HistoryItemType?>(
          segments: [
            ButtonSegment(value: null, label: Text(l10n.globalAll)),
            ButtonSegment(
              value: HistoryItemType.sale,
              label: Text(l10n.historyFilterSales),
            ),
            ButtonSegment(
              value: HistoryItemType.refund,
              label: Text(l10n.historyFilterRefunds),
            ),
            ButtonSegment(
              value: HistoryItemType.serviceOrder,
              label: Text(l10n.serviceQueueTitle),
            ),
            const ButtonSegment(
              value: HistoryItemType.restaurantOrder,
              label: Text('Ресторан'),
            ),
          ],
          selected: {state.typeFilter},
          onSelectionChanged: (set) {
            notifier.setTypeFilter(set.first);
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
                child: Text(l10n.historyReset),
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
                child: Text(l10n.historyApply),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDateRangePicker(
    BuildContext context,
    HistoryState state,
    HistoryNotifier notifier,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final hasDateFilter = state.dateFrom != null || state.dateTo != null;

    return OutlinedButton.icon(
      onPressed: () => _showDatePicker(context, state, notifier),
      icon: const Icon(Icons.date_range, size: 18),
      label: Text(
        hasDateFilter
            ? '${state.dateFrom != null ? _formatDate(state.dateFrom!) : '...'} — ${state.dateTo != null ? _formatDate(state.dateTo!) : '...'}'
            : l10n.historyPeriod,
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

  Widget _buildTypeFilter(HistoryState state, HistoryNotifier notifier) {
    final l10n = AppLocalizations.of(context)!;
    return SegmentedButton<HistoryItemType?>(
      segments: [
        ButtonSegment(value: null, label: Text(l10n.globalAll)),
        ButtonSegment(
          value: HistoryItemType.sale,
          icon: const Icon(Icons.shopping_cart, size: 16),
          label: Text(l10n.historyFilterSales),
        ),
        ButtonSegment(
          value: HistoryItemType.refund,
          icon: const Icon(Icons.assignment_return, size: 16),
          label: Text(l10n.historyFilterRefunds),
        ),
        ButtonSegment(
          value: HistoryItemType.serviceOrder,
          icon: const Icon(Icons.build, size: 16),
          label: Text(l10n.serviceQueueTitle),
        ),
        const ButtonSegment(
          value: HistoryItemType.restaurantOrder,
          icon: Icon(Icons.restaurant, size: 16),
          label: Text('Ресторан'),
        ),
      ],
      selected: {state.typeFilter},
      onSelectionChanged: (set) {
        notifier.setTypeFilter(set.first);
      },
    );
  }

  Widget _buildSearchField(HistoryNotifier notifier) {
    final l10n = AppLocalizations.of(context)!;
    return TextField(
      controller: _searchController,
      decoration: InputDecoration(
        hintText: l10n.historySearchFull,
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
    HistoryState state,
    HistoryNotifier notifier,
  ) async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: state.dateFrom != null && state.dateTo != null
          ? DateTimeRange(start: state.dateFrom!, end: state.dateTo!)
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
    HistoryState state,
    HistoryNotifier notifier,
  ) async {
    final initialDate = isFrom
        ? state.dateFrom ?? DateTime.now()
        : state.dateTo ?? DateTime.now();

    final date = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );

    if (date != null) {
      if (isFrom) {
        notifier.setDateRange(date, state.dateTo);
      } else {
        notifier.setDateRange(state.dateFrom, date);
      }
    }
  }

  String _formatDate(DateTime date) {
    final d = date.day.toString().padLeft(2, '0');
    final m = date.month.toString().padLeft(2, '0');
    return '$d.$m.${date.year}';
  }
}

class _DateButton extends StatelessWidget {
  const _DateButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 12),
      ),
      child: Text(label),
    );
  }
}

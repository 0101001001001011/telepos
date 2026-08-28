import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:telepos/app/theme/app_colors.dart';
import 'package:telepos/app/theme/app_semantic_colors.dart';
import 'package:telepos/app/theme/app_theme.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/presentation/controllers/history/history_controller.dart';

class HistoryPagination extends ConsumerWidget {
  const HistoryPagination({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(historyControllerProvider);
    final notifier = ref.read(historyControllerProvider.notifier);

    if (state.totalCount == 0) {
      return const SizedBox.shrink();
    }

    if (compact) {
      return _buildCompactLayout(context, state, notifier);
    }

    return _buildFullLayout(context, state, notifier);
  }

  Widget _buildFullLayout(
    BuildContext context,
    HistoryState state,
    HistoryNotifier notifier,
  ) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.semantic.canvas,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(12)),
      ),
      child: Row(
        children: [
          Text(
            l10n.historyRecordsRange(
              state.startIndex.toString(),
              state.endIndex.toString(),
              state.totalCount.toString(),
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
                tooltip: l10n.historyFirstPage,
                iconSize: 20,
              ),

              IconButton(
                onPressed: state.canGoPrevious
                    ? () => notifier.goToPrevious()
                    : null,
                icon: const Icon(Icons.chevron_left),
                tooltip: l10n.historyPrevious,
                iconSize: 24,
              ),

              ..._buildPageNumbers(state, notifier),

              IconButton(
                onPressed: state.canGoNext ? () => notifier.goToNext() : null,
                icon: const Icon(Icons.chevron_right),
                tooltip: l10n.historyNextPage,
                iconSize: 24,
              ),

              IconButton(
                onPressed: state.canGoNext ? () => notifier.goToLast() : null,
                icon: const Icon(Icons.last_page),
                tooltip: l10n.historyLastPage,
                iconSize: 20,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCompactLayout(
    BuildContext context,
    HistoryState state,
    HistoryNotifier notifier,
  ) {
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

  List<Widget> _buildPageNumbers(HistoryState state, HistoryNotifier notifier) {
    final pages = <Widget>[];
    final current = state.currentPage;
    final total = state.totalPages;

    var start = (current - 2).clamp(1, total);
    var end = (current + 2).clamp(1, total);

    if (end - start < 4) {
      if (start == 1) {
        end = (start + 4).clamp(1, total);
      } else if (end == total) {
        start = (end - 4).clamp(1, total);
      }
    }

    if (start > 1) {
      pages.add(
        _PageButton(
          page: 1,
          isActive: current == 1,
          onTap: () => notifier.loadPage(1),
        ),
      );
      if (start > 2) {
        pages.add(const _Ellipsis());
      }
    }

    for (var i = start; i <= end; i++) {
      pages.add(
        _PageButton(
          page: i,
          isActive: current == i,
          onTap: () => notifier.loadPage(i),
        ),
      );
    }

    if (end < total) {
      if (end < total - 1) {
        pages.add(const _Ellipsis());
      }
      pages.add(
        _PageButton(
          page: total,
          isActive: current == total,
          onTap: () => notifier.loadPage(total),
        ),
      );
    }

    return pages;
  }
}

class _PageButton extends StatelessWidget {
  const _PageButton({
    required this.page,
    required this.isActive,
    required this.onTap,
  });

  final int page;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Material(
        color: isActive ? AppColors.primary : Colors.transparent,
        borderRadius: BorderRadius.circular(4),
        child: InkWell(
          onTap: isActive ? null : onTap,
          borderRadius: BorderRadius.circular(4),
          child: Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            child: Text(
              page.toString(),
              style: AppTextStyles.body.copyWith(
                color: isActive
                    ? AppColors.white
                    : Theme.of(context).colorScheme.onSurface,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Ellipsis extends StatelessWidget {
  const _Ellipsis();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        '...',
        style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
      ),
    );
  }
}

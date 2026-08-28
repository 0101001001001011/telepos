import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:telepos/app/theme/app_colors.dart';
import 'package:telepos/app/theme/app_semantic_colors.dart';
import 'package:telepos/app/theme/app_theme.dart';
import 'package:telepos/app/theme/telepos_icons.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/presentation/controllers/history/history_controller.dart';
import 'package:telepos/presentation/screens/history/widgets/history_details_dialog.dart';
import 'package:telepos/presentation/screens/history/widgets/history_filters.dart';
import 'package:telepos/presentation/screens/history/widgets/history_pagination.dart';
import 'package:telepos/presentation/screens/history/widgets/history_table.dart';

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(historyControllerProvider);
    final screenWidth = MediaQuery.sizeOf(context).width;

    if (state.isLoading && state.items.isEmpty) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
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

class _HistoryErrorState extends ConsumerWidget {
  const _HistoryErrorState({this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final notifier = ref.read(historyControllerProvider.notifier);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              TeleposIcons.error,
              size: compact ? 48 : 64,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              l10n.errorLoadFailedGeneric,
              textAlign: TextAlign.center,
              style: AppTextStyles.h3.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: () => notifier.refresh(),
              icon: const Icon(Icons.refresh, size: 18),
              label: Text(l10n.historyRefresh),
            ),
          ],
        ),
      ),
    );
  }
}

class _DesktopLayout extends ConsumerWidget {
  const _DesktopLayout({required this.state});

  final HistoryState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Column(
        children: [
          const HistoryFilters(),

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
                    child: state.error != null && state.items.isEmpty
                        ? const _HistoryErrorState()
                        : state.items.isEmpty
                        ? _buildEmptyState()
                        : HistoryTable(items: state.items),
                  ),

                  const HistoryPagination(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTableHeader(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final notifier = ref.read(historyControllerProvider.notifier);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: context.semantic.canvas,
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      child: Row(
        children: [
          Text(l10n.historyOperations, style: AppTextStyles.h3),
          const Spacer(),
          if (state.hasActiveFilters)
            TextButton.icon(
              onPressed: () => notifier.clearFilters(),
              icon: const Icon(TeleposIcons.close, size: 18),
              label: Text(l10n.historyClearFilters),
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: () => notifier.refresh(),
            icon: const Icon(Icons.refresh),
            tooltip: l10n.historyRefresh,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Builder(
      builder: (context) {
        final l10n = AppLocalizations.of(context)!;
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.receipt_long_outlined,
                size: 64,
                color: AppColors.textDisabled,
              ),
              const SizedBox(height: 16),
              Text(
                l10n.historyNoRecords,
                style: AppTextStyles.h3.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                state.hasActiveFilters
                    ? l10n.historyChangeFilters
                    : l10n.historyEmpty,
                style: AppTextStyles.body.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _TabletLayout extends ConsumerWidget {
  const _TabletLayout({required this.state});

  final HistoryState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Column(
        children: [
          const HistoryFilters(compact: true),

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
                    child: state.error != null && state.items.isEmpty
                        ? const _HistoryErrorState(compact: true)
                        : state.items.isEmpty
                        ? _buildEmptyState()
                        : HistoryTable(items: state.items, compact: true),
                  ),
                  const HistoryPagination(compact: true),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Builder(
      builder: (context) {
        final l10n = AppLocalizations.of(context)!;
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.receipt_long_outlined,
                size: 48,
                color: AppColors.textDisabled,
              ),
              const SizedBox(height: 12),
              Text(
                l10n.historyNoRecords,
                style: AppTextStyles.body.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _MobileLayout extends ConsumerWidget {
  const _MobileLayout({required this.state});

  final HistoryState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final notifier = ref.read(historyControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.historyTitle),
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        elevation: 0,
        actions: [
          if (state.hasActiveFilters)
            IconButton(
              onPressed: () => notifier.clearFilters(),
              icon: const Icon(Icons.filter_alt_off),
              tooltip: l10n.historyClearFilters,
            ),
          IconButton(
            onPressed: () => _showFiltersSheet(context),
            icon: Badge(
              isLabelVisible: state.hasActiveFilters,
              child: const Icon(Icons.filter_list),
            ),
            tooltip: l10n.historyFilters,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: state.error != null && state.items.isEmpty
                ? const _HistoryErrorState(compact: true)
                : state.items.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: state.items.length,
                    itemBuilder: (context, index) {
                      final item = state.items[index];
                      return _HistoryCard(item: item);
                    },
                  ),
          ),

          const HistoryPagination(compact: true),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Builder(
      builder: (context) {
        final l10n = AppLocalizations.of(context)!;
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.receipt_long_outlined,
                size: 48,
                color: AppColors.textDisabled,
              ),
              const SizedBox(height: 12),
              Text(
                l10n.historyNoRecords,
                style: AppTextStyles.body.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        );
      },
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
            child: const HistoryFilters(mobile: true),
          );
        },
      ),
    );
  }
}

class _HistoryCard extends ConsumerWidget {
  const _HistoryCard({required this.item});

  final HistoryItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isSale = item.type == HistoryItemType.sale;
    final color = isSale ? AppColors.success : AppColors.warning;

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
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(
                  isSale ? Icons.shopping_cart : Icons.assignment_return,
                  color: color,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          item.formattedReceiptNo,
                          style: AppTextStyles.body.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 8),
                        _buildSyncBadge(context),
                        const SizedBox(width: 4),
                        _buildOfdBadge(context),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatDateTime(item.time),
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
                    '${item.typePrefix}${item.amount.toStringAsFixed(2)}',
                    style: AppTextStyles.body.copyWith(
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
                  Text(
                    _getPaymentTypeLabel(context, item.paymentType),
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

  Widget _buildSyncBadge(BuildContext context) {
    final (icon, color) = switch (item.syncState) {
      HistorySyncState.synced => (Icons.cloud_done, AppColors.success),
      HistorySyncState.pendingSync => (Icons.cloud_upload, AppColors.warning),
      HistorySyncState.beingSent => (Icons.cloud_sync, AppColors.info),
      HistorySyncState.deferred => (
        Icons.pause_circle,
        Theme.of(context).colorScheme.onSurfaceVariant,
      ),
      HistorySyncState.inProgress => (
        Icons.edit,
        Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    };

    return Icon(icon, size: 14, color: color);
  }

  Widget _buildOfdBadge(BuildContext context) {
    final (icon, color) = switch (item.ofdState) {
      HistoryOfdState.fiscalized => (Icons.verified, AppColors.success),
      HistoryOfdState.error => (
        TeleposIcons.error,
        Theme.of(context).colorScheme.error,
      ),
      HistoryOfdState.notFiscalized => (
        Icons.receipt,
        Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    };

    return Icon(icon, size: 14, color: color);
  }

  String _formatDateTime(DateTime time) {
    final d = time.day.toString().padLeft(2, '0');
    final m = time.month.toString().padLeft(2, '0');
    final h = time.hour.toString().padLeft(2, '0');
    final min = time.minute.toString().padLeft(2, '0');
    return '$d.$m.${time.year} $h:$min';
  }

  String _getPaymentTypeLabel(BuildContext context, HistoryPaymentType type) {
    final l10n = AppLocalizations.of(context)!;
    return switch (type) {
      HistoryPaymentType.cash => l10n.historyPaymentCash,
      HistoryPaymentType.card => l10n.historyPaymentCard,
      HistoryPaymentType.mixed => l10n.historyPaymentMixed,
      HistoryPaymentType.bonus => l10n.historyPaymentBonus,
      HistoryPaymentType.debt => l10n.historyPaymentDebt,
      HistoryPaymentType.discount => l10n.historyPaymentWithDiscount,
    };
  }

  void _showDetails(BuildContext context) {
    showHistoryDetailsDialog(context, item);
  }
}

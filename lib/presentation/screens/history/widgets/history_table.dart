import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:telepos/app/theme/app_colors.dart';
import 'package:telepos/app/theme/app_theme.dart';
import 'package:telepos/app/theme/telepos_icons.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/presentation/controllers/history/history_controller.dart';
import 'package:telepos/presentation/screens/history/widgets/history_details_dialog.dart';
import 'package:telepos/core/locale/till_conventions.dart';

class HistoryTable extends ConsumerWidget {
  const HistoryTable({super.key, required this.items, this.compact = false});

  final List<HistoryItem> items;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(historyControllerProvider);
    final notifier = ref.read(historyControllerProvider.notifier);

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
              label: const Icon(Icons.sync, size: 18),
              tooltip: l10n.historySyncStatus,
            ),

            DataColumn(
              label: Text(l10n.historyReceiptColumn),
              onSort: (_, ascending) => notifier.sortBy('receiptNo', ascending),
            ),

            DataColumn(
              label: Text(l10n.globalDate),
              onSort: (_, ascending) => notifier.sortBy('time', ascending),
            ),

            DataColumn(
              label: Text(l10n.globalAmount),
              numeric: true,
              onSort: (_, ascending) => notifier.sortBy('amount', ascending),
            ),

            DataColumn(label: Text(l10n.historyPayment)),

            DataColumn(
              label: const Icon(Icons.receipt_long, size: 18),
              tooltip: l10n.historyFiscalization,
            ),
          ],
          rows: items.map((item) => _buildRow(context, item)).toList(),
        ),
      ),
    );
  }

  DataRow _buildRow(BuildContext context, HistoryItem item) {
    final isService = item.type == HistoryItemType.serviceOrder;
    final isRestaurant = item.type == HistoryItemType.restaurantOrder;
    final isSale = item.type == HistoryItemType.sale;
    final typeColor = isService
        ? AppColors.primary
        : isRestaurant
        ? Colors.deepOrange
        : isSale
        ? AppColors.success
        : AppColors.warning;

    return DataRow(
      onSelectChanged: (_) => _showDetails(context, item),
      color: isService
          ? WidgetStateProperty.all(AppColors.primary.withValues(alpha: 0.03))
          : isRestaurant
          ? WidgetStateProperty.all(Colors.deepOrange.withValues(alpha: 0.03))
          : null,
      cells: [
        DataCell(
          isService
              ? _buildServiceStatusIcon(item.orderStatus)
              : _buildSyncIcon(context, item.syncState),
        ),

        DataCell(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isService
                    ? Icons.build
                    : isRestaurant
                    ? Icons.restaurant
                    : isSale
                    ? Icons.shopping_cart
                    : Icons.assignment_return,
                size: 16,
                color: typeColor,
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    item.formattedReceiptNo,
                    style: AppTextStyles.body.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (isService && item.customerName != null)
                    Text(
                      item.customerName!,
                      style: context.styles.caption.copyWith(fontSize: 11),
                    ),
                ],
              ),
            ],
          ),
        ),

        DataCell(Text(_formatDateTime(item.time), style: AppTextStyles.body)),

        DataCell(
          Text(
            '${item.typePrefix}${item.amount.toStringAsFixed(2)}',
            style: AppTextStyles.body.copyWith(
              fontWeight: FontWeight.w600,
              color: typeColor,
            ),
          ),
        ),

        DataCell(
          isService
              ? _buildServiceStatusBadge(context, item.orderStatus)
              : isRestaurant
              ? _buildRestaurantTypeBadge(context, item.orderType)
              : _buildPaymentTypeBadge(context, item.paymentType),
        ),

        DataCell(
          isService || isRestaurant
              ? Text(
                  item.deviceDescription ?? '-',
                  style: context.styles.caption,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                )
              : _buildOfdIcon(context, item.ofdState),
        ),
      ],
    );
  }

  Widget _buildServiceStatusIcon(int? status) {
    final (icon, color) = switch (status) {
      0 => (Icons.inbox, Colors.blue),
      1 => (Icons.build, Colors.orange),
      2 => (TeleposIcons.checkCircle, Colors.green),
      3 => (Icons.lock, Colors.grey),
      4 => (Icons.cancel, Colors.red),
      _ => (Icons.help_outline, Colors.grey),
    };
    return Icon(icon, size: 18, color: color);
  }

  Widget _buildRestaurantTypeBadge(BuildContext context, int? orderType) {
    final l10n = AppLocalizations.of(context)!;
    final (label, color) = switch (orderType) {
      0 => (l10n.restaurantOrderDineIn, Colors.deepOrange),
      1 => (l10n.restaurantOrderTakeout, Colors.blue),
      2 => (l10n.restaurantOrderDelivery, Colors.green),
      _ => ('?', Colors.grey),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildServiceStatusBadge(BuildContext context, int? status) {
    final l10n = AppLocalizations.of(context)!;
    final (label, color) = switch (status) {
      0 => (l10n.serviceStatusIntake, Colors.blue),
      1 => (l10n.serviceStatusInProgress, Colors.orange),
      2 => (l10n.serviceStatusCompleted, Colors.green),
      3 => (l10n.serviceStatusClosed, Colors.grey),
      4 => (l10n.serviceStatusCancelled, Colors.red),
      _ => ('?', Colors.grey),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildSyncIcon(BuildContext context, HistorySyncState syncState) {
    final l10n = AppLocalizations.of(context)!;
    final (icon, color, tooltip) = switch (syncState) {
      HistorySyncState.synced => (
        Icons.cloud_done,
        AppColors.success,
        l10n.historySyncSyncedFull,
      ),
      HistorySyncState.pendingSync => (
        Icons.cloud_upload,
        AppColors.warning,
        l10n.historySyncPendingFull,
      ),
      HistorySyncState.beingSent => (
        Icons.cloud_sync,
        AppColors.info,
        l10n.historySyncSendingFull,
      ),
      HistorySyncState.deferred => (
        Icons.pause_circle,
        Theme.of(context).colorScheme.onSurfaceVariant,
        l10n.historySyncDeferredFull,
      ),
      HistorySyncState.inProgress => (
        Icons.edit,
        Theme.of(context).colorScheme.onSurfaceVariant,
        l10n.historySyncInProgressFull,
      ),
    };

    return Tooltip(
      message: tooltip,
      child: Icon(icon, size: 20, color: color),
    );
  }

  Widget _buildPaymentTypeBadge(BuildContext context, HistoryPaymentType type) {
    final l10n = AppLocalizations.of(context)!;
    final (label, color) = switch (type) {
      HistoryPaymentType.cash => (l10n.historyPaymentCash, AppColors.success),
      HistoryPaymentType.card => (l10n.historyPaymentCard, AppColors.info),
      HistoryPaymentType.mixed => (
        l10n.historyPaymentMixed,
        AppColors.paymentMixed,
      ),
      HistoryPaymentType.bonus => (l10n.historyPaymentBonus, AppColors.warning),
      HistoryPaymentType.debt => (
        l10n.historyPaymentDebt,
        Theme.of(context).colorScheme.error,
      ),
      HistoryPaymentType.discount => (
        l10n.historyPaymentDiscount,
        AppColors.primary,
      ),
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

  Widget _buildOfdIcon(BuildContext context, HistoryOfdState ofdState) {
    final l10n = AppLocalizations.of(context)!;
    final (icon, color, tooltip) = switch (ofdState) {
      HistoryOfdState.fiscalized => (
        Icons.verified,
        AppColors.success,
        l10n.historyOfdFiscalized,
      ),
      HistoryOfdState.error => (
        TeleposIcons.error,
        Theme.of(context).colorScheme.error,
        l10n.historyOfdError,
      ),
      HistoryOfdState.notFiscalized => (
        Icons.receipt,
        Theme.of(context).colorScheme.onSurfaceVariant,
        l10n.historyOfdNotFiscalized,
      ),
    };

    return Tooltip(
      message: tooltip,
      child: Icon(icon, size: 20, color: color),
    );
  }

  int? _getSortColumnIndex(String column) {
    return switch (column) {
      'receiptNo' => 1,
      'time' => 2,
      'amount' => 3,
      _ => null,
    };
  }

  String _formatDateTime(DateTime time) {
    return TillConventions.current.formatDateTime(time);
  }

  void _showDetails(BuildContext context, HistoryItem item) {
    showHistoryDetailsDialog(context, item);
  }
}

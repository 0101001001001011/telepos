import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:telepos/app/router/app_routes.dart';
import 'package:telepos/app/theme/app_colors.dart';
import 'package:telepos/app/theme/app_semantic_colors.dart';
import 'package:telepos/app/theme/app_theme.dart';
import 'package:telepos/app/theme/telepos_icons.dart';
import 'package:telepos/core/constants/enums/service_order_status.dart';
import 'package:telepos/domain/entities/service/service_order_entity.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/presentation/controllers/service/service_queue_controller.dart';
import 'package:telepos/presentation/screens/service/widgets/service_order_card.dart';
import 'package:telepos/presentation/screens/service/widgets/service_search_bar.dart';
import 'package:telepos/presentation/screens/service/widgets/service_status_filter_bar.dart';

class ServiceQueueScreen extends ConsumerStatefulWidget {
  const ServiceQueueScreen({super.key});

  @override
  ConsumerState<ServiceQueueScreen> createState() => _ServiceQueueScreenState();
}

class _ServiceQueueScreenState extends ConsumerState<ServiceQueueScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(serviceQueueProvider.notifier).refresh();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(serviceQueueProvider);
    final notifier = ref.read(serviceQueueProvider.notifier);
    final isWide = MediaQuery.of(context).size.width > 900;

    return Scaffold(
      body: Column(
        children: [
          _buildHeader(l10n, state, isWide),

          ServiceSearchBar(
            onSearch: (query) {
              if (query.isEmpty) {
                notifier.refresh();
              } else {
                notifier.searchOrders(query);
              }
            },
            onScanQr: () => _scanQr(notifier),
          ),

          ServiceStatusFilterBar(
            selectedStatus: state.statusFilter,
            onStatusChanged: notifier.setStatusFilter,
            orders: state.orders,
          ),

          const SizedBox(height: 4),

          Expanded(
            child: state.isLoading
                ? const Center(child: CircularProgressIndicator())
                : state.filteredOrders.isEmpty
                ? _buildEmptyState(l10n)
                : isWide
                ? _buildDesktopLayout(state, l10n)
                : _buildMobileList(state.filteredOrders),
          ),
        ],
      ),

      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go(AppRoutes.serviceIntake),
        icon: const Icon(TeleposIcons.add),
        label: Text(l10n.serviceOrderCreated),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.white,
      ),
    );
  }

  Widget _buildHeader(
    AppLocalizations l10n,
    ServiceQueueState state,
    bool isWide,
  ) {
    final activeCount = state.orders.where((o) => o.isActive).length;
    final inProgressCount = state.orders.where((o) => o.isInProgress).length;
    final completedCount = state.orders.where((o) => o.isCompleted).length;

    return Container(
      padding: EdgeInsets.fromLTRB(
        isWide ? 24 : 16,
        MediaQuery.of(context).padding.top + 12,
        isWide ? 24 : 16,
        8,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).colorScheme.outline,
            width: 0.5,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(l10n.serviceQueueTitle, style: AppTextStyles.h2),
              const Spacer(),
              OutlinedButton.icon(
                onPressed: () => context.go(AppRoutes.serviceCatalog),
                icon: const Icon(Icons.list_alt, size: 16),
                label: Text(
                  l10n.serviceCatalogTitle,
                  style: const TextStyle(fontSize: 12),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.onSurface,
                  side: BorderSide(
                    color: Theme.of(context).colorScheme.outline,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
          ),

          if (state.orders.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                _StatChip(
                  icon: Icons.folder_open,
                  label: l10n.serviceQueueActive,
                  count: activeCount,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 12),
                _StatChip(
                  icon: Icons.build,
                  label: l10n.serviceStatusInProgress,
                  count: inProgressCount,
                  color: Colors.orange,
                ),
                const SizedBox(width: 12),
                _StatChip(
                  icon: TeleposIcons.checkCircle,
                  label: l10n.serviceStatusCompleted,
                  count: completedCount,
                  color: Colors.green,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyState(AppLocalizations l10n) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.06),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.inbox_outlined,
              size: 40,
              color: AppColors.textDisabled,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            l10n.serviceQueueEmpty,
            style: AppTextStyles.body.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: () => context.go(AppRoutes.serviceIntake),
            icon: const Icon(TeleposIcons.add, size: 18),
            label: Text(l10n.serviceOrderCreated),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileList(List<ServiceOrderEntity> orders) {
    return RefreshIndicator(
      onRefresh: ref.read(serviceQueueProvider.notifier).refresh,
      child: ListView.builder(
        padding: const EdgeInsets.only(bottom: 80),
        itemCount: orders.length,
        itemBuilder: (context, index) {
          return AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: ServiceOrderCard(
              key: ValueKey(orders[index].id),
              order: orders[index],
              needsApproval: ref
                  .read(serviceQueueProvider)
                  .ordersNeedingApproval
                  .contains(orders[index].id),
              onTap: () => _navigateToDetail(orders[index].id),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDesktopLayout(ServiceQueueState state, AppLocalizations l10n) {
    final orders = state.filteredOrders;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 80),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(AppTheme.borderRadius),
          border: Border.all(color: Theme.of(context).colorScheme.outline),
        ),
        child: Column(
          children: [
            Expanded(
              child: RefreshIndicator(
                onRefresh: ref.read(serviceQueueProvider.notifier).refresh,
                child: SingleChildScrollView(
                  child: SizedBox(
                    width: double.infinity,
                    child: DataTable(
                      headingRowColor: WidgetStateProperty.all(
                        context.semantic.canvas,
                      ),
                      showCheckboxColumn: false,
                      columnSpacing: 16,
                      columns: [
                        DataColumn(label: Text('#', style: _headerStyle)),
                        DataColumn(
                          label: Text(
                            l10n.serviceClientName,
                            style: _headerStyle,
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            l10n.serviceIntakeItems,
                            style: _headerStyle,
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            l10n.serviceMarkType,
                            style: _headerStyle,
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            l10n.serviceEstimatedDate,
                            style: _headerStyle,
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            l10n.serviceEstimatedAmount,
                            style: _headerStyle,
                          ),
                          numeric: true,
                        ),
                        const DataColumn(label: SizedBox.shrink()),
                      ],
                      rows: orders.map((order) {
                        final intakeDate = DateTime.fromMillisecondsSinceEpoch(
                          order.intakeTime * 1000,
                        );
                        final dateStr =
                            '${intakeDate.day.toString().padLeft(2, '0')}.'
                            '${intakeDate.month.toString().padLeft(2, '0')}.'
                            '${intakeDate.year}';

                        final statusColor = _statusColor(order.status);
                        final statusLabel = _statusLabel(order.status, l10n);
                        final statusIcon = _statusIcon(order.status);

                        return DataRow(
                          onSelectChanged: (_) => _navigateToDetail(order.id),
                          color: WidgetStateProperty.resolveWith((states) {
                            if (order.isInProgress) {
                              return Colors.orange.withValues(alpha: 0.03);
                            }
                            if (order.isCompleted) {
                              return Colors.green.withValues(alpha: 0.03);
                            }
                            return null;
                          }),
                          cells: [
                            DataCell(
                              Text(
                                order.orderNumber,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontFamily: 'TeleposMono',
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            DataCell(
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  CircleAvatar(
                                    radius: 12,
                                    backgroundColor: AppColors.primary
                                        .withValues(alpha: 0.08),
                                    child: Text(
                                      _initials(order.clientDisplayName),
                                      style: const TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Flexible(
                                    child: Text(
                                      order.clientDisplayName,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            DataCell(
                              Text(
                                order.deviceDescription ?? '-',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            DataCell(
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: statusColor.withValues(
                                        alpha: 0.12,
                                      ),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          statusIcon,
                                          size: 12,
                                          color: statusColor,
                                        ),
                                        const SizedBox(width: 3),
                                        Text(
                                          statusLabel,
                                          style: TextStyle(
                                            color: statusColor,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (state.ordersNeedingApproval.contains(
                                    order.id,
                                  )) ...[
                                    const SizedBox(width: 4),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.amber.withValues(
                                          alpha: 0.15,
                                        ),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.notifications_active,
                                            size: 12,
                                            color: Colors.amber.shade800,
                                          ),
                                          const SizedBox(width: 2),
                                          Text(
                                            '!',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                              color: Colors.amber.shade800,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            DataCell(
                              Text(
                                dateStr,
                                style: TextStyle(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            DataCell(
                              Text(
                                order.estimatedAmount?.toString() ?? '-',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            DataCell(
                              Icon(
                                Icons.chevron_right,
                                size: 16,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  TextStyle get _headerStyle =>
      context.styles.caption.copyWith(fontWeight: FontWeight.w700);

  void _navigateToDetail(int orderId) {
    context.go(AppRoutes.serviceDetail.replaceFirst(':orderId', '$orderId'));
  }

  Future<void> _scanQr(ServiceQueueNotifier notifier) async {
    final code = await _promptScanInput();
    if (!mounted || code == null) return;
    final trimmed = code.trim();
    if (trimmed.isEmpty) return;

    final parts = trimmed.split(':');
    if (parts.length >= 4 &&
        parts[0].toUpperCase() == 'TELEPOS' &&
        parts[1].toUpperCase() == 'SO') {
      final orderId = int.tryParse(parts[2]);
      if (orderId != null) {
        _navigateToDetail(orderId);
        return;
      }
    }

    await notifier.searchOrders(trimmed);
  }

  Future<String?> _promptScanInput() async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) {
        final l10n = AppLocalizations.of(ctx)!;
        return AlertDialog(
          title: Text(l10n.serviceScanQrTitle),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: InputDecoration(
              hintText: l10n.serviceScanQrHint,
              prefixIcon: const Icon(Icons.qr_code_scanner),
            ),
            onSubmitted: (value) => Navigator.of(ctx).pop(value),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(MaterialLocalizations.of(ctx).cancelButtonLabel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(controller.text),
              child: Text(MaterialLocalizations.of(ctx).okButtonLabel),
            ),
          ],
        );
      },
    );
  }

  String _initials(String name) {
    final parts = name.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  Color _statusColor(ServiceOrderStatus status) {
    return switch (status) {
      ServiceOrderStatus.intake => Colors.blue,
      ServiceOrderStatus.inProgress => Colors.orange,
      ServiceOrderStatus.completed => Colors.green,
      ServiceOrderStatus.closed => Colors.grey,
      ServiceOrderStatus.cancelled => Colors.red,
    };
  }

  String _statusLabel(ServiceOrderStatus status, AppLocalizations l10n) {
    return switch (status) {
      ServiceOrderStatus.intake => l10n.serviceStatusIntake,
      ServiceOrderStatus.inProgress => l10n.serviceStatusInProgress,
      ServiceOrderStatus.completed => l10n.serviceStatusCompleted,
      ServiceOrderStatus.closed => l10n.serviceStatusClosed,
      ServiceOrderStatus.cancelled => l10n.serviceStatusCancelled,
    };
  }

  IconData _statusIcon(ServiceOrderStatus status) {
    return switch (status) {
      ServiceOrderStatus.intake => Icons.inbox,
      ServiceOrderStatus.inProgress => Icons.build,
      ServiceOrderStatus.completed => TeleposIcons.checkCircle,
      ServiceOrderStatus.closed => TeleposIcons.lock,
      ServiceOrderStatus.cancelled => Icons.cancel_outlined,
    };
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.icon,
    required this.label,
    required this.count,
    required this.color,
  });

  final IconData icon;
  final String label;
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(
          '$count',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 14,
            color: color,
          ),
        ),
        const SizedBox(width: 3),
        Text(label, style: context.styles.caption.copyWith(fontSize: 11)),
      ],
    );
  }
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:telepos/app/theme/app_colors.dart';
import 'package:telepos/app/theme/telepos_icons.dart';
import 'package:telepos/core/constants/enums/order_type.dart';
import 'package:telepos/core/errors/safe_error_text.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/domain/entities/restaurant/restaurant_order_entity.dart';
import 'package:telepos/domain/usecases/restaurant/create_table_order_use_case.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/presentation/controllers/restaurant/orders_controller.dart';
import 'package:telepos/presentation/common/utils/error_localizer.dart';

class OrdersScreen extends ConsumerStatefulWidget {
  const OrdersScreen({super.key});

  @override
  ConsumerState<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends ConsumerState<OrdersScreen> {
  Timer? _refreshTimer;
  final Map<int?, String> _tableNames = {};
  final Map<int?, String> _waiterNames = {};

  @override
  void initState() {
    super.initState();
    _loadLookups();
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      ref.read(ordersProvider.notifier).loadOrders();
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadLookups() async {
    try {
      final db = GetIt.I<AppDatabase>();
      final tables = await db.restaurantTableDao.getActive();
      final users = await db.userDao.findAll();
      if (!mounted) return;
      setState(() {
        for (final t in tables) {
          _tableNames[t.id] = t.name;
        }
        for (final u in users) {
          _waiterNames[u.id] = u.name ?? '';
        }
      });
    } catch (e) {
      debugPrint('[OrdersScreen] Failed to load lookups: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(ordersProvider);

    ref.listen<OrdersState>(ordersProvider, (prev, next) {
      if (next.error != null && next.error != prev?.error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ErrorLocalizer.localize(context, next.error!)),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    });

    return Scaffold(
      body: Column(
        children: [
          _buildFilterTabs(state, l10n),

          Expanded(
            child: state.isLoading && state.orders.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : state.filteredOrders.isEmpty
                ? _buildEmptyState(l10n)
                : RefreshIndicator(
                    onRefresh: () =>
                        ref.read(ordersProvider.notifier).loadOrders(),
                    child: ListView.separated(
                      padding: const EdgeInsets.all(12),
                      itemCount: state.filteredOrders.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) =>
                          _buildOrderCard(state.filteredOrders[index], l10n),
                    ),
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showNewOrderMenu(context, l10n),
        child: const Icon(TeleposIcons.add),
      ),
    );
  }

  Widget _buildFilterTabs(OrdersState state, AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildFilterChip(
              label: l10n.globalAll,
              count: state.orders.length,
              selected: state.filterType == null,
              onSelected: () =>
                  ref.read(ordersProvider.notifier).setFilterType(null),
            ),
            const SizedBox(width: 8),
            _buildFilterChip(
              label: l10n.restaurantOrderDineIn,
              count: state.countByType(OrderType.dineIn),
              selected: state.filterType == OrderType.dineIn,
              color: const Color(0xFF4CAF50),
              onSelected: () => ref
                  .read(ordersProvider.notifier)
                  .setFilterType(
                    state.filterType == OrderType.dineIn
                        ? null
                        : OrderType.dineIn,
                  ),
            ),
            const SizedBox(width: 8),
            _buildFilterChip(
              label: l10n.restaurantOrderTakeout,
              count: state.countByType(OrderType.takeout),
              selected: state.filterType == OrderType.takeout,
              color: const Color(0xFFFFA000),
              onSelected: () => ref
                  .read(ordersProvider.notifier)
                  .setFilterType(
                    state.filterType == OrderType.takeout
                        ? null
                        : OrderType.takeout,
                  ),
            ),
            const SizedBox(width: 8),
            _buildFilterChip(
              label: l10n.restaurantOrderDelivery,
              count: state.countByType(OrderType.delivery),
              selected: state.filterType == OrderType.delivery,
              color: const Color(0xFF2196F3),
              onSelected: () => ref
                  .read(ordersProvider.notifier)
                  .setFilterType(
                    state.filterType == OrderType.delivery
                        ? null
                        : OrderType.delivery,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required int count,
    required bool selected,
    required VoidCallback onSelected,
    Color? color,
  }) {
    return ChoiceChip(
      label: Text('$label ($count)'),
      selected: selected,
      onSelected: (_) => onSelected(),
      selectedColor: color?.withValues(alpha: 0.2),
    );
  }

  Widget _buildEmptyState(AppLocalizations l10n) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.receipt_long,
            size: 64,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 16),
          Text(
            l10n.restaurantOrdersEmpty,
            style: TextStyle(
              fontSize: 16,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderCard(RestaurantOrderEntity order, AppLocalizations l10n) {
    final elapsedMinutes =
        ((DateTime.now().millisecondsSinceEpoch ~/ 1000 - order.openTime) / 60)
            .round();
    final dotColor = _getOrderTypeColor(order.orderType);
    final tableName = _tableNames[order.tableId];
    final waiterName = _waiterNames[order.waiterId];

    String title;
    if (order.isDineIn && tableName != null) {
      title = tableName;
    } else if (order.isTakeout) {
      title = l10n.restaurantTakeoutNumber(order.id);
    } else {
      title = l10n.restaurantDeliveryNumber(order.id);
    }

    return Card(
      elevation: 1,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          if (order.tableId != null) {
            context.go('/tables/${order.tableId}');
          } else {
            context.go('/orders/${order.id}');
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 10,
                height: 10,
                margin: const EdgeInsets.only(top: 5),
                decoration: BoxDecoration(
                  color: dotColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          l10n.restaurantOrderGuests(order.partySize),
                          style: TextStyle(
                            fontSize: 13,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                        ),
                        if (waiterName != null && waiterName.isNotEmpty) ...[
                          Text(
                            ' · ',
                            style: TextStyle(
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                          ),
                          Text(
                            l10n.restaurantOrderWaiter(waiterName),
                            style: TextStyle(
                              fontSize: 13,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (order.note != null && order.note!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        order.note!,
                        style: TextStyle(
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),

              Text(
                l10n.restaurantOrderElapsed(elapsedMinutes),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: elapsedMinutes > 60
                      ? Theme.of(context).colorScheme.error
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getOrderTypeColor(OrderType type) {
    return switch (type) {
      OrderType.dineIn => const Color(0xFF4CAF50),
      OrderType.takeout => const Color(0xFFFFA000),
      OrderType.delivery => const Color(0xFF2196F3),
    };
  }

  void _showNewOrderMenu(BuildContext context, AppLocalizations l10n) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                l10n.restaurantCreateOrder,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.shopping_bag, color: Color(0xFFFFA000)),
              title: Text(l10n.restaurantOrderTakeout),
              onTap: () {
                Navigator.pop(ctx);
                _createTakeoutOrDelivery(l10n, OrderType.takeout);
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.delivery_dining,
                color: Color(0xFF2196F3),
              ),
              title: Text(l10n.restaurantOrderDelivery),
              onTap: () {
                Navigator.pop(ctx);
                _createTakeoutOrDelivery(l10n, OrderType.delivery);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _createTakeoutOrDelivery(
    AppLocalizations l10n,
    OrderType type,
  ) async {
    final partySizeCtrl = TextEditingController(text: '1');
    final noteCtrl = TextEditingController();

    if (!mounted) return;

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          type == OrderType.takeout
              ? l10n.restaurantOrderTakeout
              : l10n.restaurantOrderDelivery,
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: partySizeCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  labelText: l10n.restaurantPartySize,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: noteCtrl,
                decoration: InputDecoration(
                  labelText: l10n.restaurantNote,
                  border: const OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.globalCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.restaurantOpenOrder),
          ),
        ],
      ),
    );

    if (result == true && mounted) {
      try {
        final partySize = int.tryParse(partySizeCtrl.text)?.clamp(1, 50) ?? 1;
        await GetIt.I<CreateTableOrderUseCase>().create(
          tableId: null,
          partySize: partySize,
          orderType: type,
          note: noteCtrl.text.trim().isNotEmpty ? noteCtrl.text.trim() : null,
        );
        ref.read(ordersProvider.notifier).loadOrders();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                ErrorLocalizer.localize(
                  context,
                  'error.save_failed:${safeErrorText(e)}',
                ),
              ),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
      }
    }
  }
}

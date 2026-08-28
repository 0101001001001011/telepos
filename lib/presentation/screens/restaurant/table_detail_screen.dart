import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:telepos/app/router/app_routes.dart';
import 'package:telepos/app/theme/app_colors.dart';
import 'package:telepos/app/theme/telepos_icons.dart';
import 'package:telepos/core/constants/enums/order_type.dart';
import 'package:telepos/core/constants/enums/table_status.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/domain/services/receipt_print_service.dart';
import 'package:telepos/domain/usecases/restaurant/calculate_service_charge_use_case.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/presentation/controllers/restaurant/table_map_controller.dart';
import 'package:telepos/presentation/controllers/payment/payment_controller.dart';
import 'package:telepos/presentation/controllers/restaurant/table_order_controller.dart';
import 'package:telepos/presentation/controllers/sale/sale_controller.dart';
import 'package:telepos/presentation/common/utils/error_localizer.dart';
import 'package:telepos/presentation/screens/restaurant/dialogs/split_bill_dialog.dart';
import 'package:telepos/presentation/screens/restaurant/dialogs/split_payment_dialog.dart';
import 'package:telepos/presentation/screens/restaurant/dialogs/table_merge_dialog.dart';
import 'package:telepos/presentation/screens/restaurant/dialogs/table_transfer_dialog.dart';
import 'package:telepos/presentation/screens/restaurant/dialogs/modifier_dialog.dart';
import 'package:telepos/presentation/screens/restaurant/widgets/guest_selector.dart';
import 'package:telepos/presentation/screens/restaurant/widgets/menu_product_grid.dart';
import 'package:telepos/presentation/screens/restaurant/widgets/menu_search_bar.dart';
import 'package:telepos/presentation/screens/restaurant/widgets/menu_sidebar.dart';
import 'package:telepos/presentation/common/widgets/keyboards/num_pad.dart';
import 'package:telepos/presentation/screens/restaurant/widgets/order_action_bar.dart';
import 'package:telepos/presentation/screens/restaurant/widgets/order_items_panel.dart';

class _IikoColors {
  _IikoColors._();

  static const orderPanelBg = Color(0xFF1A1A2E);
  static const orderPanelAccent = Color(0xFF0F3460);
  static const orderHeaderBg = Color(0xFF0F0F23);
  static const orderTextPrimary = Color(0xFFE8E8F0);
  static const orderTextSecondary = Color(0xFF9898B8);
  static const orderTextMuted = Color(0xFF6B6B8D);
  static const orderDivider = Color(0xFF2A2A4A);
  static const guestTabActive = Color(0xFF3A7BFF);

  static const menuBg = Color(0xFFF8F9FB);
}

class TableDetailScreen extends ConsumerStatefulWidget {
  const TableDetailScreen({this.tableId, this.orderId, super.key});

  final int? tableId;
  final int? orderId;

  @override
  ConsumerState<TableDetailScreen> createState() => _TableDetailScreenState();
}

class _TableDetailScreenState extends ConsumerState<TableDetailScreen> {
  Timer? _elapsedTimer;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      final notifier = ref.read(tableOrderProvider.notifier);
      if (widget.tableId != null) {
        notifier.setTableId(widget.tableId!);
      } else if (widget.orderId != null) {
        notifier.setOrderId(widget.orderId!);
      }
    });
    _elapsedTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => setState(() {}),
    );
  }

  @override
  void dispose() {
    _elapsedTimer?.cancel();
    super.dispose();
  }

  Future<void> _onProductTap(MenuProductItem product) async {
    final notifier = ref.read(tableOrderProvider.notifier);
    final groups = await notifier.getModifiersForProduct(product.ucode);

    if (groups.isEmpty) {
      await notifier.addProductToOrder(product);
      return;
    }

    if (!mounted) return;
    final selectedModifiers = await ModifierDialog.show(
      context: context,
      productName: product.name,
      basePrice: product.price,
      groups: groups,
    );

    if (selectedModifiers == null) return;

    await notifier.addProductWithModifiers(product, selectedModifiers);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(tableOrderProvider);

    ref.listen<TableOrderState>(tableOrderProvider, (prev, next) {
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
      backgroundColor: _IikoColors.menuBg,
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : state.hasOrder
          ? _buildOrderForm(state, l10n)
          : _buildNoOrderView(state, l10n),
    );
  }

  Widget _buildNoOrderView(TableOrderState state, AppLocalizations l10n) {
    final tableName =
        state.tableName ??
        (widget.orderId != null
            ? l10n.restaurantOrderNumber(widget.orderId!)
            : '#${widget.tableId}');

    return Container(
      color: _IikoColors.orderPanelBg,
      child: Column(
        children: [
          _buildDarkHeader(tableName, state, l10n),
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.receipt_long,
                    size: 64,
                    color: _IikoColors.orderTextMuted,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    l10n.restaurantNoOrder,
                    style: TextStyle(
                      fontSize: 18,
                      color: _IikoColors.orderTextSecondary,
                    ),
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    icon: const Icon(TeleposIcons.add),
                    label: Text(l10n.restaurantOpenOrder),
                    style: FilledButton.styleFrom(
                      backgroundColor: _IikoColors.guestTabActive,
                      minimumSize: const Size(200, 48),
                    ),
                    onPressed: () => _showCreateOrderDialog(l10n),
                  ),
                  const SizedBox(height: 32),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildStatusButton(
                        label: l10n.restaurantSetFree,
                        icon: TeleposIcons.checkCircle,
                        color: AppColors.success,
                        status: TableStatus.free,
                        currentStatus: state.tableStatus,
                      ),
                      const SizedBox(width: 12),
                      _buildStatusButton(
                        label: l10n.restaurantSetReserved,
                        icon: Icons.bookmark_outline,
                        color: const Color(0xFFFFA000),
                        status: TableStatus.reserved,
                        currentStatus: state.tableStatus,
                      ),
                      const SizedBox(width: 12),
                      _buildStatusButton(
                        label: l10n.restaurantSetDirty,
                        icon: Icons.cleaning_services,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        status: TableStatus.dirty,
                        currentStatus: state.tableStatus,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDarkHeader(
    String title,
    TableOrderState state,
    AppLocalizations l10n,
  ) {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: const BoxDecoration(
        color: _IikoColors.orderHeaderBg,
        border: Border(
          bottom: BorderSide(color: _IikoColors.orderDivider, width: 1),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(
              Icons.arrow_back,
              color: _IikoColors.orderTextPrimary,
            ),
            onPressed: () {
              if (widget.tableId != null) {
                context.go(AppRoutes.tables);
              } else {
                context.go(AppRoutes.orders);
              }
            },
          ),
          const SizedBox(width: 4),
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: _IikoColors.orderTextPrimary,
            ),
          ),
          if (state.tableZone != null) ...[
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: _IikoColors.orderPanelAccent,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                state.tableZone!,
                style: const TextStyle(
                  fontSize: 11,
                  color: _IikoColors.orderTextSecondary,
                ),
              ),
            ),
          ],
          const Spacer(),
          if (state.tableStatus != null)
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: _statusColor(state.tableStatus!),
                shape: BoxShape.circle,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatusButton({
    required String label,
    required IconData icon,
    required Color color,
    required TableStatus status,
    required TableStatus? currentStatus,
  }) {
    final isActive = currentStatus == status;
    return OutlinedButton.icon(
      icon: Icon(
        icon,
        size: 18,
        color: isActive ? _IikoColors.orderPanelBg : color,
      ),
      label: Text(
        label,
        style: TextStyle(color: isActive ? _IikoColors.orderPanelBg : color),
      ),
      style: OutlinedButton.styleFrom(
        backgroundColor: isActive ? color : null,
        side: BorderSide(color: color),
      ),
      onPressed: isActive
          ? null
          : () => ref.read(tableOrderProvider.notifier).setStatus(status),
    );
  }

  Widget _buildOrderForm(TableOrderState state, AppLocalizations l10n) {
    final isWide = MediaQuery.of(context).size.width >= 600;

    if (isWide) {
      return _buildDesktopLayout(state, l10n);
    } else {
      return _buildMobileLayout(state, l10n);
    }
  }

  Widget _buildDesktopLayout(TableOrderState state, AppLocalizations l10n) {
    final tableName =
        state.tableName ??
        (widget.orderId != null
            ? l10n.restaurantOrderNumber(widget.orderId!)
            : '#${widget.tableId}');

    final elapsed = state.order != null
        ? DateTime.now().difference(
            DateTime.fromMillisecondsSinceEpoch(state.order!.openTime),
          )
        : null;
    final elapsedStr = elapsed != null
        ? '${elapsed.inHours.toString().padLeft(2, '0')}:${(elapsed.inMinutes % 60).toString().padLeft(2, '0')}'
        : null;

    return Row(
      children: [
        SizedBox(
          width: MediaQuery.of(context).size.width * 0.35,
          child: Container(
            color: _IikoColors.orderPanelBg,
            child: Column(
              children: [
                _buildOrderHeader(tableName, elapsedStr, state, l10n),
                _buildGuestTabs(state, l10n),
                Container(height: 1, color: _IikoColors.orderDivider),
                Expanded(
                  child: OrderItemsPanel(
                    items: state.filteredItems,
                    guestCount: state.guestCount,
                    selectedGuest: state.selectedGuest,
                    onRemove: (id) =>
                        ref.read(tableOrderProvider.notifier).removeItem(id),
                    onUpdateQuantity: (id, qty) => ref
                        .read(tableOrderProvider.notifier)
                        .updateQuantity(id, qty),
                  ),
                ),
                OrderActionBar(
                  total: state.total ?? Decimal.zero,
                  itemCount: state.items.length,
                  onPayment: () => _goToPayment(state),
                  onTransfer: () => _showTransferDialog(state, l10n),
                  onSplitBill: () => _showSplitBillDialog(state, l10n),
                  onMerge: () => _showMergeDialog(state, l10n),
                  onPrint: () => _printPreCheck(state, l10n),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: Container(
            color: _IikoColors.menuBg,
            child: Column(
              children: [
                _buildMenuHeader(state, l10n),
                Expanded(
                  child: state.searchQuery.isNotEmpty
                      ? _buildSearchResults(state)
                      : MenuProductGrid(
                          products: state.menuProducts,
                          isLoading: state.isLoadingMenu,
                          onProductTap: _onProductTap,
                        ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOrderHeader(
    String tableName,
    String? elapsed,
    TableOrderState state,
    AppLocalizations l10n,
  ) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      decoration: const BoxDecoration(
        color: _IikoColors.orderHeaderBg,
        border: Border(
          bottom: BorderSide(color: _IikoColors.orderDivider, width: 1),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(
              Icons.arrow_back,
              color: _IikoColors.orderTextPrimary,
              size: 20,
            ),
            visualDensity: VisualDensity.compact,
            onPressed: () {
              if (widget.tableId != null) {
                context.go(AppRoutes.tables);
              } else {
                context.go(AppRoutes.orders);
              }
            },
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  tableName,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: _IikoColors.orderTextPrimary,
                    letterSpacing: 0.3,
                  ),
                ),
                if (elapsed != null || state.tableZone != null)
                  Row(
                    children: [
                      if (elapsed != null) ...[
                        Icon(
                          Icons.access_time,
                          size: 12,
                          color: _IikoColors.orderTextMuted,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          elapsed,
                          style: const TextStyle(
                            fontSize: 12,
                            color: _IikoColors.orderTextMuted,
                          ),
                        ),
                      ],
                      if (elapsed != null && state.tableZone != null)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: Text(
                            ' / ',
                            style: TextStyle(
                              color: _IikoColors.orderTextMuted,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      if (state.tableZone != null)
                        Text(
                          state.tableZone!,
                          style: const TextStyle(
                            fontSize: 12,
                            color: _IikoColors.orderTextMuted,
                          ),
                        ),
                    ],
                  ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: _IikoColors.orderPanelAccent,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.people_outline,
                  size: 14,
                  color: _IikoColors.orderTextSecondary,
                ),
                const SizedBox(width: 5),
                Text(
                  '${state.guestCount}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _IikoColors.orderTextPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGuestTabs(TableOrderState state, AppLocalizations l10n) {
    final notifier = ref.read(tableOrderProvider.notifier);
    return Container(
      height: 44,
      color: _IikoColors.orderPanelBg,
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: GuestSelector(
        guestCount: state.guestCount,
        selectedGuest: state.selectedGuest,
        onSelectGuest: notifier.selectGuest,
        onAddGuest: () => notifier.setGuestCount(state.guestCount + 1),
      ),
    );
  }

  Widget _buildMenuHeader(TableOrderState state, AppLocalizations l10n) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
          child: MenuSearchBar(
            onSearch: (q) =>
                ref.read(tableOrderProvider.notifier).searchProducts(q),
          ),
        ),
        if (state.searchQuery.isEmpty)
          SizedBox(
            height: 48,
            child: MenuSidebar(
              categories: state.menuCategories,
              selectedCategoryId: state.selectedCategoryId,
              onSelectCategory: (id) =>
                  ref.read(tableOrderProvider.notifier).selectCategory(id),
            ),
          ),
      ],
    );
  }

  Widget _buildSearchResults(TableOrderState state) {
    if (state.isSearching) {
      return const Center(child: CircularProgressIndicator());
    }
    return MenuProductGrid(
      products: state.searchResults,
      isLoading: false,
      onProductTap: _onProductTap,
    );
  }

  Widget _buildMobileLayout(TableOrderState state, AppLocalizations l10n) {
    final tableName =
        state.tableName ??
        (widget.orderId != null
            ? l10n.restaurantOrderNumber(widget.orderId!)
            : '#${widget.tableId}');

    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          _buildOrderHeader(tableName, null, state, l10n),
          Container(
            color: _IikoColors.orderPanelBg,
            child: TabBar(
              labelColor: _IikoColors.guestTabActive,
              unselectedLabelColor: _IikoColors.orderTextSecondary,
              indicatorColor: _IikoColors.guestTabActive,
              dividerColor: _IikoColors.orderDivider,
              tabs: [
                Tab(text: l10n.restaurantOrderTab),
                Tab(text: l10n.restaurantMenuTab),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                Container(
                  color: _IikoColors.orderPanelBg,
                  child: Column(
                    children: [
                      _buildGuestTabs(state, l10n),
                      Container(height: 1, color: _IikoColors.orderDivider),
                      Expanded(
                        child: OrderItemsPanel(
                          items: state.filteredItems,
                          guestCount: state.guestCount,
                          selectedGuest: state.selectedGuest,
                          onRemove: (id) => ref
                              .read(tableOrderProvider.notifier)
                              .removeItem(id),
                          onUpdateQuantity: (id, qty) => ref
                              .read(tableOrderProvider.notifier)
                              .updateQuantity(id, qty),
                        ),
                      ),
                      OrderActionBar(
                        total: state.total ?? Decimal.zero,
                        itemCount: state.items.length,
                        onPayment: () => _goToPayment(state),
                        onTransfer: () => _showTransferDialog(state, l10n),
                        onSplitBill: () => _showSplitBillDialog(state, l10n),
                        onMerge: () => _showMergeDialog(state, l10n),
                        onPrint: () => _printPreCheck(state, l10n),
                      ),
                    ],
                  ),
                ),
                Container(
                  color: _IikoColors.menuBg,
                  child: Column(
                    children: [
                      _buildMenuHeader(state, l10n),
                      Expanded(
                        child: state.searchQuery.isNotEmpty
                            ? _buildSearchResults(state)
                            : MenuProductGrid(
                                products: state.menuProducts,
                                isLoading: state.isLoadingMenu,
                                onProductTap: _onProductTap,
                              ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _goToPayment(TableOrderState state) async {
    final order = state.order;
    if (order == null || order.receiptNo == null || order.posId == null) return;
    if (state.items.isEmpty) return;

    try {
      final chargeUseCase = GetIt.I<CalculateServiceChargeUseCase>();
      await chargeUseCase.applyToSale(order.receiptNo!, order.posId!);
    } catch (e) {
      debugPrint('[TableDetail] Service charge failed: $e');
    }

    if (!mounted) return;

    final saleNotifier = ref.read(saleControllerProvider.notifier);
    await saleNotifier.loadFromRestaurantOrder(
      receiptNo: order.receiptNo!,
      posId: order.posId!,
    );

    if (!mounted) return;

    final tip = await _promptForTips(state);
    if (tip == null || !mounted) return;
    await ref.read(tableOrderProvider.notifier).setTips(tip);

    if (!mounted) return;

    final total = state.total ?? Decimal.zero;
    final pc = ref.read(paymentControllerProvider.notifier);

    if (state.hasSplit && total > Decimal.zero) {
      final guests = state.guestsToCharge;
      final methods = await SplitPaymentDialog.show(
        context,
        guests: guests,
        amountForGuest: state.amountForGuest,
        total: total,
      );
      if (methods == null || !mounted) return;

      final split = SplitPaymentDialog.aggregate(
        guests,
        state.amountForGuest,
        methods,
        total,
      );
      final cardAmount = split.card;

      pc.initialize(total);
      if (cardAmount <= Decimal.zero) {
        pc.setPaymentType(PaymentType.cash);
      } else if (cardAmount >= total) {
        pc.setPaymentType(PaymentType.card);
      } else {
        pc.setPaymentType(PaymentType.mixed);
        pc.setCardAmount(cardAmount);
      }
    } else {
      pc.initialize(total);
    }

    final result = await context.push<bool>(AppRoutes.payment);

    if (result == true && mounted) {
      final orderNotifier = ref.read(tableOrderProvider.notifier);
      await orderNotifier.closeOrder();

      ref.invalidate(tableMapProvider);

      if (mounted) {
        context.go(AppRoutes.tables);
      }
    }
  }

  Future<Decimal?> _promptForTips(TableOrderState state) async {
    final l10n = AppLocalizations.of(context)!;
    final tipCtrl = TextEditingController(
      text: state.tips != null && state.tips! > Decimal.zero
          ? '${state.tips}'
          : '',
    );

    void confirm(BuildContext ctx) {
      final raw = tipCtrl.text.trim().replaceAll(',', '.');
      final parsed = raw.isEmpty ? Decimal.zero : Decimal.tryParse(raw);
      Navigator.pop(ctx, parsed ?? Decimal.zero);
    }

    return showDialog<Decimal>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          void onKey(String d) =>
              setSheet(() => tipCtrl.text = tipCtrl.text + d);
          void onDot() {
            if (tipCtrl.text.contains('.')) return;
            final base = tipCtrl.text.isEmpty ? '0' : tipCtrl.text;
            setSheet(() => tipCtrl.text = '$base.');
          }

          void onBackspace() {
            if (tipCtrl.text.isEmpty) return;
            setSheet(
              () => tipCtrl.text = tipCtrl.text.substring(
                0,
                tipCtrl.text.length - 1,
              ),
            );
          }

          return AlertDialog(
            title: Text(l10n.restTips),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    key: const Key('restaurant.tips.field'),
                    controller: tipCtrl,
                    readOnly: true,
                    showCursor: true,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                    ],
                    decoration: InputDecoration(
                      labelText: l10n.restTips,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  NumPad(
                    buttonSize: 48,
                    spacing: 8,
                    showEnter: true,
                    onKeyPressed: onKey,
                    onBackspace: onBackspace,
                    onClear: () => setSheet(() => tipCtrl.clear()),
                    onEnter: () => confirm(ctx),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: 168,
                    child: OutlinedButton(
                      onPressed: onDot,
                      child: const Text('.', style: TextStyle(fontSize: 20)),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                key: const Key('restaurant.tips.cancel'),
                onPressed: () => Navigator.pop(ctx),
                child: Text(l10n.globalCancel),
              ),
              TextButton(
                key: const Key('restaurant.tips.skip'),
                onPressed: () => Navigator.pop(ctx, Decimal.zero),
                child: Text(l10n.restNoTips),
              ),
              FilledButton(
                key: const Key('restaurant.tips.confirm'),
                onPressed: () => confirm(ctx),
                child: Text(l10n.globalConfirm),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _printPreCheck(
    TableOrderState state,
    AppLocalizations l10n,
  ) async {
    if (state.items.isEmpty) return;

    try {
      final db = GetIt.I<AppDatabase>();
      final thisPos = await db.thisPosDao.get();
      final storeName = thisPos?.companyName ?? '';

      String waiterName = '';
      if (state.order?.waiterId != null) {
        final user = await db.userDao.findById(state.order!.waiterId!);
        waiterName = user?.name ?? '#${state.order!.waiterId}';
      }

      final products = state.items
          .map(
            (item) => ReceiptProductLine(
              name: item.name,
              quantity: item.quantity,
              price: item.price,
              total: item.lineTotal,
            ),
          )
          .toList();

      final preCheckData = PreCheckData(
        tableName: state.tableName ?? '#${state.tableId}',
        zoneName: state.tableZone,
        waiterName: waiterName,
        guestCount: state.guestCount,
        products: products,
        totalAmount: state.total ?? Decimal.zero,
        dateTime: DateTime.now(),
        storeName: storeName,
      );

      final printService = GetIt.I<ReceiptPrintService>();
      // Задание принято — пречек будет; отказ очереди — единственная неудача.
      final success = !(await printService.printPreCheck(
        preCheckData,
      )).isRejected;

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success
                  ? l10n.restaurantPreCheckPrinted
                  : l10n.restaurantPreCheckFailed,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.restaurantPreCheckFailed),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _showCreateOrderDialog(AppLocalizations l10n) async {
    final partySizeCtrl = TextEditingController(text: '1');
    OrderType selectedType = OrderType.dineIn;
    int? selectedWaiterId;
    final noteCtrl = TextEditingController();

    List<User> users = [];
    try {
      users = await GetIt.I<AppDatabase>().userDao.findAll();
    } catch (e) {
      debugPrint('[TableDetail] Failed to load users: $e');
    }

    if (!mounted) return;

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(l10n.restaurantCreateOrder),
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
                DropdownButtonFormField<OrderType>(
                  value: selectedType,
                  decoration: InputDecoration(
                    labelText: l10n.restaurantOrderType,
                    border: const OutlineInputBorder(),
                  ),
                  items: [
                    DropdownMenuItem(
                      value: OrderType.dineIn,
                      child: Text(l10n.restaurantOrderDineIn),
                    ),
                    DropdownMenuItem(
                      value: OrderType.takeout,
                      child: Text(l10n.restaurantOrderTakeout),
                    ),
                    DropdownMenuItem(
                      value: OrderType.delivery,
                      child: Text(l10n.restaurantOrderDelivery),
                    ),
                  ],
                  onChanged: (v) => setDialogState(() => selectedType = v!),
                ),
                const SizedBox(height: 12),
                if (users.isNotEmpty)
                  DropdownButtonFormField<int>(
                    value: selectedWaiterId,
                    decoration: InputDecoration(
                      labelText: l10n.restaurantWaiter,
                      border: const OutlineInputBorder(),
                    ),
                    items: users
                        .map(
                          (u) => DropdownMenuItem(
                            value: u.id,
                            child: Text(u.name ?? '#${u.id}'),
                          ),
                        )
                        .toList(),
                    onChanged: (v) =>
                        setDialogState(() => selectedWaiterId = v),
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
      ),
    );

    if (result == true) {
      final partySize = int.tryParse(partySizeCtrl.text)?.clamp(1, 50) ?? 1;
      await ref
          .read(tableOrderProvider.notifier)
          .createOrder(
            partySize: partySize,
            orderType: selectedType,
            waiterId: selectedWaiterId,
            note: noteCtrl.text.trim().isNotEmpty ? noteCtrl.text.trim() : null,
          );
      ref.invalidate(tableMapProvider);
    }
  }

  Future<void> _showTransferDialog(
    TableOrderState state,
    AppLocalizations l10n,
  ) async {
    if (state.orderId == null || widget.tableId == null) return;
    final newTableId = await showDialog<int>(
      context: context,
      builder: (_) => TableTransferDialog(
        currentTableId: widget.tableId!,
        currentTableName: state.tableName ?? '#${widget.tableId}',
        orderId: state.orderId!,
      ),
    );

    if (newTableId != null && mounted) {
      await ref.read(tableOrderProvider.notifier).transferTo(newTableId);
      ref.invalidate(tableMapProvider);
      if (mounted) context.go('/tables/$newTableId');
    }
  }

  Future<void> _showMergeDialog(
    TableOrderState state,
    AppLocalizations l10n,
  ) async {
    if (state.orderId == null || widget.tableId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.restaurantMergeNeedTarget)));
      return;
    }
    final merged = await showDialog<bool>(
      context: context,
      builder: (_) => TableMergeDialog(
        targetTableId: widget.tableId!,
        targetTableName: state.tableName ?? '#${widget.tableId}',
        targetOrderId: state.orderId!,
      ),
    );

    if (merged == true && mounted) {
      await ref.read(tableOrderProvider.notifier).reload();
      ref.invalidate(tableMapProvider);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.restaurantMergeDone)));
      }
    }
  }

  Future<void> _showSplitBillDialog(
    TableOrderState state,
    AppLocalizations l10n,
  ) async {
    if (state.orderId == null) return;
    final result = await showDialog<SplitBillResult>(
      context: context,
      builder: (_) => SplitBillDialog(
        orderId: state.orderId!,
        items: state.items,
        total: state.total ?? Decimal.zero,
        guestCount: state.guestCount,
      ),
    );

    if (result == null || !mounted) return;

    await ref
        .read(tableOrderProvider.notifier)
        .applySplitResult(
          mode: result.mode,
          splitCount: result.splitCount,
          amountPerGuest: result.amountPerGuest,
        );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.isEven
                ? l10n.restaurantSplitPerGuest('${result.amountPerGuest}')
                : l10n.restaurantSplitByItems,
          ),
        ),
      );
    }
  }

  Color _statusColor(TableStatus status) {
    return switch (status) {
      TableStatus.free => const Color(0xFF4CAF50),
      TableStatus.occupied => const Color(0xFFE53935),
      TableStatus.reserved => const Color(0xFFFFA000),
      TableStatus.dirty => const Color(0xFF757575),
    };
  }
}

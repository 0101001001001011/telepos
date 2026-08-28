import 'package:decimal/decimal.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';
import 'package:telepos/core/constants/enums/order_type.dart';
import 'package:telepos/core/constants/enums/table_status.dart';
import 'package:telepos/core/errors/safe_error_text.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/domain/entities/restaurant/guest_split_entry.dart';
import 'package:telepos/domain/entities/restaurant/restaurant_order_entity.dart';
import 'package:telepos/domain/entities/restaurant/table_order_item.dart';
import 'package:telepos/domain/usecases/restaurant/add_items_to_order_use_case.dart';
import 'package:telepos/domain/usecases/restaurant/selected_modifier.dart';
import 'package:telepos/presentation/screens/restaurant/dialogs/modifier_dialog.dart';
import 'package:telepos/domain/usecases/restaurant/close_table_order_use_case.dart';
import 'package:telepos/domain/usecases/restaurant/create_table_order_use_case.dart';
import 'package:telepos/domain/usecases/restaurant/get_open_orders_use_case.dart';
import 'package:telepos/domain/usecases/restaurant/table_status_use_case.dart';
import 'package:telepos/domain/usecases/restaurant/transfer_table_use_case.dart';
import 'package:telepos/presentation/controllers/history/history_controller.dart';
import 'package:telepos/presentation/controllers/shift/shift_controller.dart';

@immutable
class MenuProductItem {
  const MenuProductItem({
    required this.ucode,
    required this.name,
    required this.price,
    this.barcode,
  });

  final int ucode;
  final String name;
  final Decimal price;
  final String? barcode;
}

@immutable
class TableOrderState {
  const TableOrderState({
    this.tableId,
    this.orderId,
    this.order,
    this.tableName,
    this.tableZone,
    this.tableStatus,
    this.items = const [],
    this.total,
    this.isLoading = false,
    this.error,
    this.selectedGuest = 0,
    this.guestCount = 1,
    this.menuCategories = const [],
    this.selectedCategoryId,
    this.menuProducts = const [],
    this.isLoadingMenu = false,
    this.searchQuery = '',
    this.searchResults = const [],
    this.isSearching = false,
    this.guestSplits = const [],
    this.splitMode,
    this.amountPerGuest,
    this.paidGuests = const {},
    this.tips,
  });

  final int? tableId;
  final int? orderId;
  final RestaurantOrderEntity? order;
  final String? tableName;
  final String? tableZone;
  final TableStatus? tableStatus;
  final List<TableOrderItem> items;
  final Decimal? total;
  final bool isLoading;
  final String? error;

  final int selectedGuest;
  final int guestCount;

  final List<QuickProduct> menuCategories;
  final int? selectedCategoryId;
  final List<MenuProductItem> menuProducts;
  final bool isLoadingMenu;

  final String searchQuery;
  final List<MenuProductItem> searchResults;
  final bool isSearching;

  final List<GuestSplitEntry> guestSplits;

  final String? splitMode;

  final Decimal? amountPerGuest;

  final Set<int> paidGuests;

  final Decimal? tips;

  bool get hasOrder => order != null;

  bool get hasSplit => splitMode != null;

  List<TableOrderItem> get filteredItems {
    if (selectedGuest == 0) return items;
    return items
        .where((i) => i.guestNumber == selectedGuest || i.guestNumber == 0)
        .toList();
  }

  Decimal amountForGuest(int guestNumber) {
    if (splitMode == 'even') {
      return amountPerGuest ?? Decimal.zero;
    }
    if (splitMode == 'by_items') {
      var sum = Decimal.zero;
      for (final item in items) {
        if (item.guestNumber == guestNumber) {
          sum += item.lineTotal;
        }
      }
      return sum;
    }
    return total ?? Decimal.zero;
  }

  List<int> get guestsToCharge {
    if (splitMode == 'even') {
      return [for (var g = 1; g <= guestCount; g++) g];
    }
    if (splitMode == 'by_items') {
      final guests = <int>{};
      for (final item in items) {
        if (item.guestNumber > 0) guests.add(item.guestNumber);
      }
      final list = guests.toList()..sort();
      return list;
    }
    return const [];
  }

  bool get allGuestsPaid {
    final guests = guestsToCharge;
    if (guests.isEmpty) return false;
    return guests.every(paidGuests.contains);
  }

  TableOrderState copyWith({
    int? tableId,
    int? orderId,
    bool clearOrderId = false,
    RestaurantOrderEntity? order,
    bool clearOrder = false,
    String? tableName,
    String? tableZone,
    TableStatus? tableStatus,
    List<TableOrderItem>? items,
    Decimal? total,
    bool clearTotal = false,
    bool? isLoading,
    String? error,
    bool clearError = false,
    int? selectedGuest,
    int? guestCount,
    List<QuickProduct>? menuCategories,
    int? selectedCategoryId,
    bool clearCategoryId = false,
    List<MenuProductItem>? menuProducts,
    bool? isLoadingMenu,
    String? searchQuery,
    List<MenuProductItem>? searchResults,
    bool? isSearching,
    List<GuestSplitEntry>? guestSplits,
    String? splitMode,
    bool clearSplit = false,
    Decimal? amountPerGuest,
    bool clearAmountPerGuest = false,
    Set<int>? paidGuests,
    Decimal? tips,
    bool clearTips = false,
  }) {
    return TableOrderState(
      tableId: tableId ?? this.tableId,
      orderId: clearOrderId ? null : (orderId ?? this.orderId),
      order: clearOrder ? null : (order ?? this.order),
      tableName: tableName ?? this.tableName,
      tableZone: tableZone ?? this.tableZone,
      tableStatus: tableStatus ?? this.tableStatus,
      items: items ?? this.items,
      total: clearTotal ? null : (total ?? this.total),
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      selectedGuest: selectedGuest ?? this.selectedGuest,
      guestCount: guestCount ?? this.guestCount,
      menuCategories: menuCategories ?? this.menuCategories,
      selectedCategoryId: clearCategoryId
          ? null
          : (selectedCategoryId ?? this.selectedCategoryId),
      menuProducts: menuProducts ?? this.menuProducts,
      isLoadingMenu: isLoadingMenu ?? this.isLoadingMenu,
      searchQuery: searchQuery ?? this.searchQuery,
      searchResults: searchResults ?? this.searchResults,
      isSearching: isSearching ?? this.isSearching,
      guestSplits: guestSplits ?? this.guestSplits,
      splitMode: clearSplit ? null : (splitMode ?? this.splitMode),
      amountPerGuest: (clearSplit || clearAmountPerGuest)
          ? null
          : (amountPerGuest ?? this.amountPerGuest),
      paidGuests: clearSplit ? const {} : (paidGuests ?? this.paidGuests),
      tips: clearTips ? null : (tips ?? this.tips),
    );
  }
}

class TableOrderNotifier extends Notifier<TableOrderState> {
  @override
  TableOrderState build() {
    return const TableOrderState();
  }

  void setTableId(int tableId) {
    state = state.copyWith(tableId: tableId);
    Future.microtask(() => _loadAll(tableId));
  }

  void setOrderId(int orderId) {
    state = state.copyWith(orderId: orderId);
    Future.microtask(() => _loadByOrderId(orderId));
  }

  Future<void> _loadAll(int tableId) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final db = GetIt.I<AppDatabase>();

      final table = await db.restaurantTableDao.findById(tableId);
      if (state.tableId != tableId) return;
      if (table != null) {
        state = state.copyWith(
          tableName: table.name,
          tableZone: table.zone,
          tableStatus: TableStatus.values[table.status],
        );
      }

      final order = await GetIt.I<GetOpenOrdersUseCase>().getByTable(tableId);
      if (state.tableId != tableId) return;
      if (order != null) {
        state = state.copyWith(
          order: order,
          orderId: order.id,
          guestCount: order.partySize,
        );
        await _loadItems(order);
      } else {
        state = state.copyWith(
          clearOrder: true,
          clearOrderId: true,
          items: const [],
          clearTotal: true,
          isLoading: false,
        );
      }

      await _loadMenuCategories();

      if (state.tableId != tableId) return;
      state = state.copyWith(isLoading: false);
    } catch (e) {
      if (state.tableId != tableId) return;
      state = state.copyWith(
        error: 'error.load_failed:${safeErrorText(e)}',
        isLoading: false,
      );
    }
  }

  Future<void> _loadByOrderId(int orderId) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final db = GetIt.I<AppDatabase>();
      final order = await db.restaurantOrderDao.findById(orderId);
      if (order == null) {
        state = state.copyWith(
          error: 'Order $orderId not found',
          isLoading: false,
        );
        return;
      }

      final entity = RestaurantOrderEntity(
        id: order.id,
        tableId: order.tableId,
        receiptNo: order.receiptNo,
        posId: order.posId,
        partySize: order.partySize,
        orderType: OrderType.values[order.orderType],
        openTime: order.openTime,
        closeTime: order.closeTime,
        waiterId: order.waiterId,
        note: order.note,
      );

      state = state.copyWith(
        order: entity,
        orderId: order.id,
        guestCount: order.partySize,
      );

      await _loadItems(entity);
      await _loadMenuCategories();

      state = state.copyWith(isLoading: false);
    } catch (e) {
      state = state.copyWith(
        error: 'error.load_failed:${safeErrorText(e)}',
        isLoading: false,
      );
    }
  }

  Future<void> _loadItems(RestaurantOrderEntity order) async {
    final db = GetIt.I<AppDatabase>();
    if (order.receiptNo == null || order.posId == null) return;

    final saleProducts = await db.saleProductDao.findBySale(
      order.receiptNo!,
      order.posId!,
    );

    final guestSplitRows = await db.guestSplitDao.getByOrder(order.id);
    final splits = <GuestSplitEntry>[];
    final bySaleProductId = <int, int>{};
    final byUcode = <int, int>{};
    var hasFractionalShare = false;
    for (final gs in guestSplitRows) {
      splits.add(
        GuestSplitEntry(
          id: gs.id,
          orderId: gs.orderId,
          guestNumber: gs.guestNumber,
          saleProductId: gs.saleProductId,
          shareQuantity: gs.shareQuantity,
        ),
      );
      if (gs.shareQuantity < Decimal.one) {
        hasFractionalShare = true;
        bySaleProductId[gs.saleProductId] = gs.guestNumber;
      } else {
        byUcode[gs.saleProductId] = gs.guestNumber;
      }
    }

    final items = <TableOrderItem>[];
    for (final sp in saleProducts) {
      final product = await db.productInfoDao.findByUcode(sp.ucode);
      final guestNumber = byUcode[sp.ucode] ?? bySaleProductId[sp.id] ?? 0;
      items.add(
        TableOrderItem(
          productId: sp.ucode,
          name: product?.name ?? '#${sp.ucode}',
          quantity: sp.quantity,
          price: sp.price,
          saleProductId: sp.id,
          guestNumber: guestNumber,
          barcode: product?.barcode.toString(),
        ),
      );
    }

    var total = Decimal.zero;
    for (final item in items) {
      total += item.lineTotal;
    }

    if (splits.isEmpty) {
      state = state.copyWith(
        items: items,
        total: total,
        guestSplits: const [],
        clearSplit: true,
      );
    } else if (hasFractionalShare && byUcode.isEmpty) {
      final guestCount = splits.map((s) => s.guestNumber).toSet().length;
      final perGuest =
          state.amountPerGuest ??
          (guestCount > 0 ? _evenShare(total, guestCount) : total);
      state = state.copyWith(
        items: items,
        total: total,
        guestSplits: splits,
        splitMode: 'even',
        amountPerGuest: perGuest,
      );
    } else {
      state = state.copyWith(
        items: items,
        total: total,
        guestSplits: splits,
        splitMode: 'by_items',
      );
    }
  }

  Decimal _evenShare(Decimal total, int guestCount) {
    if (guestCount <= 0) return total;
    final hundred = Decimal.fromInt(100);
    final totalCents = (total * hundred).toBigInt();
    final baseCents = totalCents ~/ BigInt.from(guestCount);
    return (Decimal.fromBigInt(baseCents) / hundred).toDecimal();
  }

  Future<void> _loadMenuCategories() async {
    final db = GetIt.I<AppDatabase>();
    try {
      final categories = await db.quickProductDao.findAllByParents(limit: 200);
      state = state.copyWith(menuCategories: categories);
    } catch (e) {
      debugPrint('[TableOrder] Failed to load menu categories: $e');
    }
  }

  void selectGuest(int guestNumber) {
    state = state.copyWith(selectedGuest: guestNumber);
  }

  void setGuestCount(int count) {
    state = state.copyWith(guestCount: count.clamp(1, 50));
  }

  Future<void> applySplitResult({
    required String mode,
    required int splitCount,
    required Decimal amountPerGuest,
  }) async {
    state = state.copyWith(
      splitMode: mode,
      amountPerGuest: mode == 'even' ? amountPerGuest : null,
      clearAmountPerGuest: mode != 'even',
      guestCount: splitCount > state.guestCount ? splitCount : state.guestCount,
      paidGuests: const {},
    );
    if (state.order != null) {
      await _loadItems(state.order!);
    }
  }

  void markGuestPaid(int guestNumber) {
    if (guestNumber <= 0) return;
    final updated = {...state.paidGuests, guestNumber};
    state = state.copyWith(paidGuests: updated);
  }

  void clearSplit() {
    state = state.copyWith(clearSplit: true);
  }

  Future<void> setTips(Decimal? amount) async {
    final orderId = state.orderId;
    if (orderId == null) return;
    final normalized = (amount != null && amount > Decimal.zero)
        ? amount
        : null;
    try {
      final db = GetIt.I<AppDatabase>();
      await db.restaurantOrderDao.updateTips(orderId, normalized);
      state = state.copyWith(tips: normalized, clearTips: normalized == null);
    } catch (e) {
      state = state.copyWith(error: 'error.save_failed:${safeErrorText(e)}');
    }
  }

  Future<void> selectCategory(int? categoryId) async {
    if (categoryId == null) {
      state = state.copyWith(clearCategoryId: true, menuProducts: const []);
      return;
    }

    state = state.copyWith(selectedCategoryId: categoryId, isLoadingMenu: true);

    try {
      final db = GetIt.I<AppDatabase>();
      final quickProducts = await db.quickProductDao.findAllByParentId(
        categoryId,
        limit: 200,
      );

      final menuItems = <MenuProductItem>[];
      for (final qp in quickProducts) {
        if (qp.ucode == null) continue;
        final price = await db.productPriceDao.findByUcode(qp.ucode!);
        final product = await db.productInfoDao.findByUcode(qp.ucode!);
        menuItems.add(
          MenuProductItem(
            ucode: qp.ucode!,
            name: product?.name ?? qp.name ?? '#${qp.ucode}',
            price: price?.sellingPrice ?? Decimal.zero,
            barcode: product?.barcode.toString(),
          ),
        );
      }

      state = state.copyWith(menuProducts: menuItems, isLoadingMenu: false);
    } catch (e) {
      state = state.copyWith(isLoadingMenu: false);
      debugPrint('[TableOrder] Failed to load products: $e');
    }
  }

  Future<void> searchProducts(String query) async {
    state = state.copyWith(searchQuery: query);

    if (query.length < 2) {
      state = state.copyWith(searchResults: const [], isSearching: false);
      return;
    }

    state = state.copyWith(isSearching: true);
    try {
      final db = GetIt.I<AppDatabase>();
      final products = await db.productInfoDao.findByNamePart('%$query%');

      final results = <MenuProductItem>[];
      for (final p in products.take(50)) {
        final price = await db.productPriceDao.findByUcode(p.ucode);
        results.add(
          MenuProductItem(
            ucode: p.ucode,
            name: p.name,
            price: price?.sellingPrice ?? Decimal.zero,
            barcode: p.barcode.toString(),
          ),
        );
      }

      if (state.searchQuery != query) return;
      state = state.copyWith(searchResults: results, isSearching: false);
    } catch (e) {
      state = state.copyWith(isSearching: false);
    }
  }

  Future<List<ModifierGroupWithOptions>> getModifiersForProduct(
    int ucode,
  ) async {
    final db = GetIt.I<AppDatabase>();
    final groups = await db.modifierDao.getGroupsForDish(ucode);
    final result = <ModifierGroupWithOptions>[];
    for (final group in groups) {
      final options = await db.modifierDao.getOptionsByGroup(group.id);
      result.add(ModifierGroupWithOptions(group: group, options: options));
    }
    return result;
  }

  Future<void> addProductWithModifiers(
    MenuProductItem product,
    List<SelectedModifier> modifiers,
  ) async {
    if (state.orderId == null) return;
    try {
      final adjustments = modifiers.fold<double>(
        0,
        (sum, m) => sum + m.priceAdjustment,
      );
      final finalPrice =
          product.price + Decimal.parse(adjustments.toStringAsFixed(3));

      final useCase = GetIt.I<AddItemsToOrderUseCase>();
      final saleProductId = await useCase.addItem(
        orderId: state.orderId!,
        productUcode: product.ucode,
        quantity: Decimal.one,
        price: finalPrice,
        guestNumber: state.selectedGuest,
        modifiers: modifiers,
      );

      final modifierNames = <String>[];
      final db = GetIt.I<AppDatabase>();
      for (final mod in modifiers) {
        final options = await db.modifierDao.getOptionsByGroup(mod.groupId);
        final opt = options.where((o) => o.id == mod.optionId).firstOrNull;
        if (opt != null) {
          modifierNames.add(opt.name);
        }
      }

      final displayName = modifierNames.isEmpty
          ? product.name
          : '${product.name} (${modifierNames.join(', ')})';

      final newItem = TableOrderItem(
        productId: product.ucode,
        name: displayName,
        quantity: Decimal.one,
        price: finalPrice,
        saleProductId: saleProductId,
        guestNumber: state.selectedGuest,
        barcode: product.barcode,
      );

      final updatedItems = [...state.items, newItem];
      final total = updatedItems.fold(
        Decimal.zero,
        (sum, i) => sum + i.lineTotal,
      );

      state = state.copyWith(items: updatedItems, total: total);
    } catch (e) {
      state = state.copyWith(error: 'error.save_failed:${safeErrorText(e)}');
    }
  }

  Future<void> addProductToOrder(MenuProductItem product) async {
    if (state.orderId == null) return;
    try {
      final useCase = GetIt.I<AddItemsToOrderUseCase>();
      final saleProductId = await useCase.addItem(
        orderId: state.orderId!,
        productUcode: product.ucode,
        quantity: Decimal.one,
        price: product.price,
        guestNumber: state.selectedGuest,
      );

      final newItem = TableOrderItem(
        productId: product.ucode,
        name: product.name,
        quantity: Decimal.one,
        price: product.price,
        saleProductId: saleProductId,
        guestNumber: state.selectedGuest,
        barcode: product.barcode,
      );

      final updatedItems = [...state.items, newItem];
      final total = updatedItems.fold(
        Decimal.zero,
        (sum, i) => sum + i.lineTotal,
      );

      state = state.copyWith(items: updatedItems, total: total);
    } catch (e) {
      state = state.copyWith(error: 'error.save_failed:${safeErrorText(e)}');
    }
  }

  Future<void> removeItem(int saleProductId) async {
    if (state.orderId == null) return;
    try {
      final useCase = GetIt.I<AddItemsToOrderUseCase>();
      await useCase.removeItem(state.orderId!, saleProductId);

      final updatedItems = state.items
          .where((i) => i.saleProductId != saleProductId)
          .toList();
      final total = updatedItems.fold(
        Decimal.zero,
        (sum, i) => sum + i.lineTotal,
      );

      state = state.copyWith(items: updatedItems, total: total);
    } catch (e) {
      state = state.copyWith(error: 'error.delete_failed:${safeErrorText(e)}');
    }
  }

  Future<void> updateQuantity(int saleProductId, Decimal newQty) async {
    if (newQty <= Decimal.zero) {
      await removeItem(saleProductId);
      return;
    }

    try {
      final useCase = GetIt.I<AddItemsToOrderUseCase>();
      await useCase.updateItemQuantity(saleProductId, newQty);

      final updatedItems = state.items.map((i) {
        if (i.saleProductId == saleProductId) {
          return i.copyWith(quantity: newQty);
        }
        return i;
      }).toList();
      final total = updatedItems.fold(
        Decimal.zero,
        (sum, i) => sum + i.lineTotal,
      );

      state = state.copyWith(items: updatedItems, total: total);
    } catch (e) {
      state = state.copyWith(error: 'error.save_failed:${safeErrorText(e)}');
    }
  }

  Future<void> createOrder({
    required int partySize,
    required OrderType orderType,
    int? waiterId,
    String? note,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await GetIt.I<CreateTableOrderUseCase>().create(
        tableId: state.tableId,
        partySize: partySize,
        orderType: orderType,
        waiterId: waiterId,
        note: note,
      );
      if (state.tableId != null) {
        await _loadAll(state.tableId!);
      }
    } catch (e) {
      state = state.copyWith(
        error: 'error.save_failed:${safeErrorText(e)}',
        isLoading: false,
      );
    }
  }

  Future<void> closeOrder() async {
    if (state.orderId == null) return;
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await GetIt.I<CloseTableOrderUseCase>().close(state.orderId!);
      ref.invalidate(historyControllerProvider);
      ref.invalidate(shiftControllerProvider);
      if (state.tableId != null) {
        await _loadAll(state.tableId!);
      }
    } catch (e) {
      state = state.copyWith(
        error: 'error.save_failed:${safeErrorText(e)}',
        isLoading: false,
      );
    }
  }

  Future<void> transferTo(int newTableId) async {
    if (state.orderId == null) return;
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await GetIt.I<TransferTableUseCase>().transfer(
        state.orderId!,
        newTableId,
      );
      if (state.tableId != null) {
        await _loadAll(state.tableId!);
      }
    } catch (e) {
      state = state.copyWith(
        error: 'error.save_failed:${safeErrorText(e)}',
        isLoading: false,
      );
    }
  }

  Future<void> setStatus(TableStatus status) async {
    if (state.tableId == null) return;
    try {
      final useCase = GetIt.I<TableStatusUseCase>();
      switch (status) {
        case TableStatus.free:
          await useCase.setFree(state.tableId!);
        case TableStatus.occupied:
          await useCase.setOccupied(state.tableId!);
        case TableStatus.reserved:
          await useCase.setReserved(state.tableId!);
        case TableStatus.dirty:
          await useCase.setDirty(state.tableId!);
      }
      state = state.copyWith(tableStatus: status);
    } catch (e) {
      state = state.copyWith(error: 'error.save_failed:${safeErrorText(e)}');
    }
  }

  Future<void> reload() async {
    if (state.tableId != null) {
      await _loadAll(state.tableId!);
    } else if (state.orderId != null) {
      await _loadByOrderId(state.orderId!);
    }
  }
}

final tableOrderProvider =
    NotifierProvider<TableOrderNotifier, TableOrderState>(
      TableOrderNotifier.new,
    );

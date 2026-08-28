import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart' hide Column;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';
import 'package:telepos/core/errors/safe_error_text.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/domain/usecases/product/search_product_info_use_case.dart'
    as domain;
import 'package:telepos/domain/usecases/refund/refund_initiation_use_case.dart';
import 'package:telepos/domain/usecases/refund/refund_use_case.dart';
import 'package:telepos/presentation/controllers/app/app_state_controller.dart';
import 'package:telepos/presentation/controllers/shift/shift_controller.dart';
import 'package:telepos/presentation/controllers/history/history_controller.dart';

enum RefundMode { byReceipt, withoutReceipt }

enum RefundReason { defective, notSuitable, cashierError, other }

@immutable
class RefundItem {
  // ignore: prefer_const_constructors_in_immutables - Decimal не поддерживает const
  RefundItem({
    required this.id,
    required this.productId,
    required this.name,
    required this.price,
    required this.quantity,
    required this.maxQuantity,
    this.barcode,
    this.originalSaleId,
    this.isSelected = false,
    RefundReason? reason,
  }) : reason = reason ?? RefundReason.other;

  final String id;

  final int productId;

  final String name;

  final Decimal price;

  final Decimal quantity;

  final Decimal maxQuantity;

  final String? barcode;

  final String? originalSaleId;

  final bool isSelected;

  final RefundReason reason;

  Decimal get total => price * quantity;

  RefundItem copyWith({
    String? id,
    int? productId,
    String? name,
    Decimal? price,
    Decimal? quantity,
    Decimal? maxQuantity,
    String? barcode,
    String? originalSaleId,
    bool? isSelected,
    RefundReason? reason,
  }) {
    return RefundItem(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      name: name ?? this.name,
      price: price ?? this.price,
      quantity: quantity ?? this.quantity,
      maxQuantity: maxQuantity ?? this.maxQuantity,
      barcode: barcode ?? this.barcode,
      originalSaleId: originalSaleId ?? this.originalSaleId,
      isSelected: isSelected ?? this.isSelected,
      reason: reason ?? this.reason,
    );
  }
}

@immutable
class ReceiptInfo {
  const ReceiptInfo({
    required this.receiptNo,
    required this.posId,
    required this.date,
    required this.total,
    this.posName,
    this.customerLocalId,
  });

  final int receiptNo;
  final int posId;
  final DateTime date;
  final Decimal total;
  final String? posName;

  final int? customerLocalId;
}

@immutable
class RefundState {
  const RefundState({
    this.mode = RefundMode.byReceipt,
    this.items = const [],
    this.selectedItemId,
    this.receiptInfo,
    this.searchQuery = '',
    this.searchResults = const [],
    this.isSearching = false,
    this.isLoading = false,
    this.error,
  });

  final RefundMode mode;

  final List<RefundItem> items;

  final String? selectedItemId;

  final ReceiptInfo? receiptInfo;

  final String searchQuery;

  final List<RefundSearchResult> searchResults;

  final bool isSearching;

  final bool isLoading;

  final String? error;

  int get selectedCount => items.where((i) => i.isSelected).length;

  bool get allSelected => items.isNotEmpty && items.every((i) => i.isSelected);

  bool get noneSelected => items.every((i) => !i.isSelected);

  Decimal get selectedTotal => items
      .where((i) => i.isSelected)
      .fold(Decimal.zero, (sum, item) => sum + item.total);

  Decimal get total =>
      items.fold(Decimal.zero, (sum, item) => sum + item.total);

  RefundItem? get selectedItem {
    if (selectedItemId == null) return null;
    try {
      return items.firstWhere((i) => i.id == selectedItemId);
    } catch (_) {
      return null;
    }
  }

  bool get hasItems => items.isNotEmpty;

  bool get canRefund => items.any((i) => i.isSelected);

  RefundState copyWith({
    RefundMode? mode,
    List<RefundItem>? items,
    String? selectedItemId,
    bool clearSelectedItemId = false,
    ReceiptInfo? receiptInfo,
    bool clearReceiptInfo = false,
    String? searchQuery,
    List<RefundSearchResult>? searchResults,
    bool? isSearching,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return RefundState(
      mode: mode ?? this.mode,
      items: items ?? this.items,
      selectedItemId: clearSelectedItemId
          ? null
          : (selectedItemId ?? this.selectedItemId),
      receiptInfo: clearReceiptInfo ? null : (receiptInfo ?? this.receiptInfo),
      searchQuery: searchQuery ?? this.searchQuery,
      searchResults: searchResults ?? this.searchResults,
      isSearching: isSearching ?? this.isSearching,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

@immutable
class RefundSearchResult {
  const RefundSearchResult({
    required this.id,
    required this.name,
    required this.price,
    this.barcode,
  });

  final int id;
  final String name;
  final Decimal price;
  final String? barcode;
}

class RefundNotifier extends Notifier<RefundState> {
  int _nextItemId = 1;
  Timer? _searchDebounce;

  @override
  RefundState build() {
    ref.onDispose(() {
      _searchDebounce?.cancel();
    });
    return const RefundState();
  }

  void setMode(RefundMode mode) {
    _searchDebounce?.cancel();
    state = RefundState(mode: mode);
    _nextItemId = 1;
  }

  Future<void> loadReceipt(int receiptNo, int posId) async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final db = GetIt.I<AppDatabase>();

      final sales =
          await (db.select(db.sales)..where(
                (s) => s.receiptNo.equals(receiptNo) & s.posId.equals(posId),
              ))
              .get();

      if (sales.isEmpty) {
        state = state.copyWith(
          isLoading: false,
          error: 'error.receipt_not_found:$receiptNo',
        );
        return;
      }

      final sale = sales.first;

      final thisPos = await db.thisPosDao.get();
      String? posName;
      if (thisPos != null && thisPos.id == posId) {
        posName = thisPos.cashBoxName;
      }

      final receiptInfo = ReceiptInfo(
        receiptNo: receiptNo,
        posId: posId,
        date: DateTime.fromMillisecondsSinceEpoch(sale.time * 1000),
        total: sale.amount,
        posName: posName,
        customerLocalId: sale.customerLocalId,
      );

      final saleProducts = await db.saleProductDao.findBySale(receiptNo, posId);

      final items = <RefundItem>[];
      for (final sp in saleProducts) {
        final productInfo = await db.productInfoDao.findByUcode(sp.ucode);
        final productName = productInfo?.name ?? 'Product ${sp.ucode}';

        final barcode = productInfo?.barcode.toString();

        items.add(
          RefundItem(
            id: 'refund_${_nextItemId++}',
            productId: sp.ucode,
            name: productName,
            price: sp.price,
            quantity: sp.quantity,
            maxQuantity: sp.quantity,
            barcode: barcode,
            originalSaleId: 'sale_$receiptNo',
            isSelected: true,
          ),
        );
      }

      state = state.copyWith(
        receiptInfo: receiptInfo,
        items: items,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'error.load_failed:${safeErrorText(e)}',
      );
    }
  }

  Future<void> search(String query) async {
    _searchDebounce?.cancel();

    if (query.isEmpty) {
      state = state.copyWith(
        searchQuery: '',
        searchResults: [],
        isSearching: false,
      );
      return;
    }

    state = state.copyWith(searchQuery: query, isSearching: true);

    _searchDebounce = Timer(const Duration(milliseconds: 300), () async {
      try {
        final searchUseCase = GetIt.I<domain.SearchProductInfoUseCase>();
        final db = GetIt.I<AppDatabase>();

        final domainResults = await searchUseCase.search(
          query: query,
          limit: 50,
        );

        final results = <RefundSearchResult>[];
        for (final r in domainResults) {
          final price = await db.productPriceDao.findByUcode(r.ucode);
          final priceValue = price?.sellingPrice ?? Decimal.zero;

          results.add(
            RefundSearchResult(
              id: r.ucode,
              name: r.name,
              price: priceValue,
              barcode: r.barcode.toString(),
            ),
          );
        }

        state = state.copyWith(searchResults: results, isSearching: false);
      } catch (e) {
        state = state.copyWith(
          isSearching: false,
          error: 'error.search_failed:${safeErrorText(e)}',
        );
      }
    });
  }

  void addProduct(RefundSearchResult product, {Decimal? quantity}) {
    final existingIndex = state.items.indexWhere(
      (i) => i.productId == product.id,
    );

    if (existingIndex >= 0) {
      final existing = state.items[existingIndex];
      final newQuantity = existing.quantity + (quantity ?? Decimal.one);
      final updated = existing.copyWith(
        quantity: newQuantity,
        maxQuantity: newQuantity,
      );
      final newItems = [...state.items];
      newItems[existingIndex] = updated;
      state = state.copyWith(items: newItems);
    } else {
      final item = RefundItem(
        id: 'refund_${_nextItemId++}',
        productId: product.id,
        name: product.name,
        price: product.price,
        quantity: quantity ?? Decimal.one,
        maxQuantity: quantity ?? Decimal.fromInt(999),
        barcode: product.barcode,
        isSelected: true,
      );
      state = state.copyWith(items: [...state.items, item]);
    }

    state = state.copyWith(searchQuery: '', searchResults: []);
  }

  void selectItem(String? itemId) {
    state = state.copyWith(
      selectedItemId: itemId,
      clearSelectedItemId: itemId == null,
    );
  }

  void toggleItemSelection(String itemId) {
    final index = state.items.indexWhere((i) => i.id == itemId);
    if (index < 0) return;

    final item = state.items[index];
    final updated = item.copyWith(isSelected: !item.isSelected);
    final newItems = [...state.items];
    newItems[index] = updated;
    state = state.copyWith(items: newItems);
  }

  void selectAll() {
    final newItems = state.items
        .map((i) => i.copyWith(isSelected: true))
        .toList();
    state = state.copyWith(items: newItems);
  }

  void deselectAll() {
    final newItems = state.items
        .map((i) => i.copyWith(isSelected: false))
        .toList();
    state = state.copyWith(items: newItems);
  }

  void updateQuantity(String itemId, Decimal quantity) {
    final index = state.items.indexWhere((i) => i.id == itemId);
    if (index < 0) return;

    final item = state.items[index];

    final newQuantity = quantity > item.maxQuantity
        ? item.maxQuantity
        : quantity;

    if (newQuantity <= Decimal.zero) {
      final newItems = state.items.where((i) => i.id != itemId).toList();
      state = state.copyWith(items: newItems, clearSelectedItemId: true);
      return;
    }

    final updated = item.copyWith(quantity: newQuantity);
    final newItems = [...state.items];
    newItems[index] = updated;
    state = state.copyWith(items: newItems);
  }

  void setReason(String itemId, RefundReason reason) {
    final index = state.items.indexWhere((i) => i.id == itemId);
    if (index < 0) return;

    final updated = state.items[index].copyWith(reason: reason);
    final newItems = [...state.items];
    newItems[index] = updated;
    state = state.copyWith(items: newItems);
  }

  void removeItem(String itemId) {
    final newItems = state.items.where((i) => i.id != itemId).toList();
    state = state.copyWith(
      items: newItems,
      clearSelectedItemId: state.selectedItemId == itemId,
    );
  }

  void removeSelectedItem() {
    if (state.selectedItemId == null) return;
    removeItem(state.selectedItemId!);
  }

  void clear() {
    _searchDebounce?.cancel();
    state = RefundState(mode: state.mode);
    _nextItemId = 1;
  }

  Future<bool> processRefund() async {
    if (!state.canRefund) return false;

    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final refundInitUseCase = GetIt.I<RefundInitiationUseCase>();
      final refundUseCase = GetIt.I<RefundUseCase>();

      final userId = ref.read(currentUserIdProvider);
      if (userId == null) {
        state = state.copyWith(isLoading: false, error: 'error.not_authorized');
        return false;
      }

      final refund = await refundInitUseCase.initiate(
        saleReceiptNo: state.receiptInfo?.receiptNo,
        salePosId: state.receiptInfo?.posId,
      );

      final refundLocalId = refund.localId as int;

      final selectedItems = state.items.where((i) => i.isSelected).toList();
      final products = selectedItems.map((item) {
        return RefundProductEntry(
          ucode: item.productId,
          quantity: item.quantity,
          price: item.price,
          inSalePrice: state.mode == RefundMode.byReceipt ? item.price : null,
          inSaleQuantity: state.mode == RefundMode.byReceipt
              ? item.maxQuantity
              : null,
        );
      }).toList();

      await refundUseCase.perform(
        refundLocalId: refundLocalId,
        amount: state.selectedTotal,
        userId: userId,
        saleReceiptNo: state.receiptInfo?.receiptNo,
        salePosId: state.receiptInfo?.posId,
        customerLocalId: state.receiptInfo?.customerLocalId,
        products: products,
      );

      ref.invalidate(shiftControllerProvider);
      ref.invalidate(historyControllerProvider);

      state = state.copyWith(isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'error.save_failed:${safeErrorText(e)}',
      );
      return false;
    }
  }
}

final refundControllerProvider = NotifierProvider<RefundNotifier, RefundState>(
  RefundNotifier.new,
);

final refundSelectedTotalProvider = Provider<Decimal>((ref) {
  return ref.watch(refundControllerProvider.select((s) => s.selectedTotal));
});

final canRefundProvider = Provider<bool>((ref) {
  return ref.watch(refundControllerProvider.select((s) => s.canRefund));
});

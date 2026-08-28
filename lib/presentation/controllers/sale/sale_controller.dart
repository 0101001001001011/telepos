import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';
import 'package:telepos/core/errors/safe_error_text.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/domain/services/shift_service.dart';
import 'package:telepos/domain/usecases/product/find_by_barcode_use_case.dart';
import 'package:telepos/domain/usecases/product/search_product_info_use_case.dart'
    as domain;
import 'package:telepos/domain/usecases/sale/deferred_sale_service.dart';
import 'package:telepos/domain/usecases/sale/sale_initiation_use_case.dart';
import 'package:telepos/domain/usecases/sale/sale_round_option_use_case.dart';
import 'package:telepos/domain/usecases/sale/sale_use_case.dart';
import 'package:telepos/domain/usecases/wms/batch_tracking_use_case.dart';
import 'package:telepos/domain/usecases/wms/wms_config_use_case.dart';
import 'package:telepos/core/logging/app_talker.dart';
import 'package:telepos/presentation/controllers/app/app_state_controller.dart';
import 'package:telepos/presentation/controllers/catalog/catalog_controller.dart';
import 'package:telepos/presentation/controllers/history/history_controller.dart';
import 'package:telepos/presentation/controllers/shift/shift_controller.dart';
import 'package:telepos/presentation/controllers/stock_registry/stock_registry_controller.dart';

const kShiftOverAgeError = 'error.shift_over_age';

const kShiftOverAgeMessage = 'смена открыта более 24ч — закройте смену';

enum SaleMode { retail, wholesale }

@immutable
class SaleItem {
  SaleItem({
    required this.id,
    required this.productId,
    required this.name,
    required this.price,
    required this.quantity,
    Decimal? discount,
    this.discountPercent,
    this.barcode,
    this.mark,
    this.promoApplied = false,
    this.measure = 0,
  }) : discount = discount ?? Decimal.zero;

  final String id;

  final int productId;

  final String name;

  final Decimal price;

  final Decimal quantity;

  final Decimal discount;

  final Decimal? discountPercent;

  final String? barcode;

  final String? mark;

  final bool promoApplied;

  final int measure;

  bool get isWeightProduct => measure != 0;

  Decimal get subtotal => price * quantity;

  Decimal get total => subtotal - discount;

  Decimal get effectiveDiscountPercent {
    if (discountPercent != null) return discountPercent!;
    if (subtotal == Decimal.zero) return Decimal.zero;
    final percentValue = (discount * Decimal.fromInt(100)) / subtotal;
    return Decimal.parse(
      percentValue.toDecimal(scaleOnInfinitePrecision: 2).toString(),
    );
  }

  SaleItem copyWith({
    String? id,
    int? productId,
    String? name,
    Decimal? price,
    Decimal? quantity,
    Decimal? discount,
    Decimal? discountPercent,
    bool clearDiscountPercent = false,
    String? barcode,
    String? mark,
    bool? promoApplied,
    int? measure,
  }) {
    return SaleItem(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      name: name ?? this.name,
      price: price ?? this.price,
      quantity: quantity ?? this.quantity,
      discount: discount ?? this.discount,
      discountPercent: clearDiscountPercent
          ? null
          : (discountPercent ?? this.discountPercent),
      barcode: barcode ?? this.barcode,
      mark: mark ?? this.mark,
      promoApplied: promoApplied ?? this.promoApplied,
      measure: measure ?? this.measure,
    );
  }
}

@immutable
class SaleState {
  const SaleState({
    this.receiptNo,
    this.posId,
    this.items = const [],
    this.selectedItemId,
    this.searchQuery = '',
    this.searchResults = const [],
    this.isSearching = false,
    this.mode = SaleMode.retail,
    this.agentId,
    this.agentName,
    this.isDeferred = false,
    this.deferredSaleId,
    this.error,
    this.warning,
    this.discountsRoundType = 0,
    this.weightProductRoundType = 0,
  });

  final int? receiptNo;

  final int? posId;

  final List<SaleItem> items;

  final String? selectedItemId;

  final String searchQuery;

  final List<ProductSearchResult> searchResults;

  final bool isSearching;

  final SaleMode mode;

  final int? agentId;

  final String? agentName;

  final bool isDeferred;

  final String? deferredSaleId;

  final String? error;

  final String? warning;

  final int discountsRoundType;

  final int weightProductRoundType;

  Decimal roundedUnitPrice(SaleItem item) {
    if (discountsRoundType == 0 && weightProductRoundType == 0) {
      return item.price;
    }
    return GetIt.I<SaleRoundOptionUseCase>().roundPrice(
      price: item.price,
      isWeightProduct: item.isWeightProduct,
      hasDiscount: item.discount > Decimal.zero,
      weightProductRoundType: weightProductRoundType,
      discountsRoundType: discountsRoundType,
    );
  }

  Decimal roundedLineTotal(SaleItem item) =>
      roundedUnitPrice(item) * item.quantity - item.discount;

  int get itemCount => items.length;

  Decimal get totalQuantity =>
      items.fold(Decimal.zero, (sum, item) => sum + item.quantity);

  Decimal get subtotal =>
      items.fold(Decimal.zero, (sum, item) => sum + item.subtotal);

  Decimal get totalDiscount =>
      items.fold(Decimal.zero, (sum, item) => sum + item.discount);

  Decimal get total =>
      items.fold(Decimal.zero, (sum, item) => sum + roundedLineTotal(item));

  SaleItem? get selectedItem {
    if (selectedItemId == null) return null;
    try {
      return items.firstWhere((i) => i.id == selectedItemId);
    } catch (_) {
      return null;
    }
  }

  bool get isEmpty => items.isEmpty;

  bool get isNotEmpty => items.isNotEmpty;

  bool get hasError => error != null;

  SaleState copyWith({
    int? receiptNo,
    int? posId,
    List<SaleItem>? items,
    String? selectedItemId,
    bool clearSelectedItemId = false,
    String? searchQuery,
    List<ProductSearchResult>? searchResults,
    bool? isSearching,
    SaleMode? mode,
    int? agentId,
    bool clearAgentId = false,
    String? agentName,
    bool clearAgentName = false,
    bool? isDeferred,
    String? deferredSaleId,
    bool clearDeferredSaleId = false,
    String? error,
    bool clearError = false,
    String? warning,
    bool clearWarning = false,
    int? discountsRoundType,
    int? weightProductRoundType,
  }) {
    return SaleState(
      receiptNo: receiptNo ?? this.receiptNo,
      posId: posId ?? this.posId,
      items: items ?? this.items,
      selectedItemId: clearSelectedItemId
          ? null
          : (selectedItemId ?? this.selectedItemId),
      searchQuery: searchQuery ?? this.searchQuery,
      searchResults: searchResults ?? this.searchResults,
      isSearching: isSearching ?? this.isSearching,
      mode: mode ?? this.mode,
      agentId: clearAgentId ? null : (agentId ?? this.agentId),
      agentName: clearAgentName ? null : (agentName ?? this.agentName),
      isDeferred: isDeferred ?? this.isDeferred,
      deferredSaleId: clearDeferredSaleId
          ? null
          : (deferredSaleId ?? this.deferredSaleId),
      error: clearError ? null : (error ?? this.error),
      warning: clearWarning ? null : (warning ?? this.warning),
      discountsRoundType: discountsRoundType ?? this.discountsRoundType,
      weightProductRoundType:
          weightProductRoundType ?? this.weightProductRoundType,
    );
  }
}

@immutable
class ProductSearchResult {
  const ProductSearchResult({
    required this.id,
    required this.name,
    required this.price,
    this.barcode,
    this.stock,
    this.isDeleted = false,
    this.measure = 0,
  });

  final int id;
  final String name;
  final Decimal price;
  final String? barcode;
  final Decimal? stock;

  final int measure;

  final bool isDeleted;
}

class SaleNotifier extends Notifier<SaleState> {
  int _nextItemId = 1;
  Timer? _searchDebounce;

  List<Promotion> _promotions = const [];

  @override
  SaleState build() {
    ref.onDispose(() {
      _searchDebounce?.cancel();
    });
    Future.microtask(() => _initSale());
    return const SaleState();
  }

  Future<bool> _ensureShiftNotOverAge() async {
    try {
      final shiftService = GetIt.I<ShiftService>();
      final overAge = await shiftService.isShiftOverAge();
      if (overAge) {
        state = state.copyWith(error: kShiftOverAgeError);
        talker.warning('Sale blocked: $kShiftOverAgeMessage');
        return false;
      }
      return true;
    } catch (e) {
      talker.warning('Sale: _ensureShiftNotOverAge error: $e');
      return true;
    }
  }

  Future<void> _initSale() async {
    if (!await _ensureShiftNotOverAge()) return;
    try {
      try {
        _promotions = await GetIt.I<AppDatabase>().promotionDao.getEnabled();
      } catch (_) {
        _promotions = const [];
      }

      try {
        final thisPos = await GetIt.I<AppDatabase>().thisPosDao.get();
        if (thisPos != null) {
          state = state.copyWith(
            discountsRoundType: thisPos.discountsRoundType,
            weightProductRoundType: thisPos.weightProductRoundType,
          );
        }
      } catch (_) {}
      final useCase = GetIt.I<SaleInitiationUseCase>();
      final currentUserId = ref.read(appStateProvider).userId;
      final sale = await useCase.initiate(
        isWholesale: state.mode == SaleMode.wholesale,
        userId: currentUserId,
      );

      if (sale != null) {
        state = state.copyWith(receiptNo: sale.receiptNo, posId: sale.posId);
        ref.read(appStateProvider.notifier).setShiftOpened(true);
        ref.invalidate(shiftControllerProvider);
      }
    } catch (e) {
      state = state.copyWith(error: 'error.save_failed:${safeErrorText(e)}');
    }
  }

  Future<void> startNewSale() async {
    state = const SaleState();
    _nextItemId = 1;
    await _initSale();
  }

  Future<bool> completeSale({
    required List<PaymentEntry> payments,
    required Decimal change,
    String? customerBin,
    bool? selectiveOfd,
    List<CustomFieldEntry>? customFields,
    WithdrawalEntry? withdrawal,
  }) async {
    if (state.receiptNo == null || state.posId == null) {
      await _initSale();
      if (state.receiptNo == null || state.posId == null) {
        state = state.copyWith(error: 'error.sale_not_initialized');
        return false;
      }
    }
    if (state.isEmpty) {
      state = state.copyWith(error: 'error.receipt_empty');
      return false;
    }

    if (!await _ensureShiftNotOverAge()) return false;

    try {
      final db = GetIt.I<AppDatabase>();
      final saleUseCase = GetIt.I<SaleUseCase>();

      final receiptNo = state.receiptNo!;
      final posId = state.posId!;

      final markableUcodes = <int, bool>{};
      for (final item in state.items) {
        if (markableUcodes.containsKey(item.productId)) continue;
        final info = await db.productInfoDao.findByUcode(item.productId);
        markableUcodes[item.productId] = info?.isMarkable ?? false;
      }
      for (final item in state.items) {
        final requiresMark = markableUcodes[item.productId] ?? false;
        if (requiresMark && (item.mark == null || item.mark!.trim().isEmpty)) {
          state = state.copyWith(error: 'error.mark_required:${item.name}');
          return false;
        }
      }

      final thisPosCfg = await db.thisPosDao.get();
      if (thisPosCfg?.blockOversell ?? false) {
        final qtyByProduct = <int, Decimal>{};
        for (final item in state.items) {
          qtyByProduct[item.productId] =
              (qtyByProduct[item.productId] ?? Decimal.zero) + item.quantity;
        }
        for (final entry in qtyByProduct.entries) {
          final info = await db.productInfoDao.findByUcode(entry.key);
          if (info == null) continue;
          final stock = info.quantity ?? Decimal.zero;
          if (entry.value > stock) {
            state = state.copyWith(
              error: 'error.insufficient_stock:${info.name}',
            );
            return false;
          }
        }
      }

      if (!(thisPosCfg?.allowBigAmount ?? false)) {
        final bigAmountLimit = Decimal.parse('1000000');
        if (state.total > bigAmountLimit) {
          state = state.copyWith(error: 'error.big_amount_blocked');
          return false;
        }
      }

      await saleUseCase.reverseSaleStock(receiptNo: receiptNo, posId: posId);

      await db.saleProductDao.deleteBySale(receiptNo, posId);
      await db.paymentDao.deleteBySale(receiptNo, posId);

      for (final item in state.items) {
        final lineTotal = state.roundedLineTotal(item);
        final effectivePrice = item.quantity > Decimal.zero
            ? (lineTotal / item.quantity).toDecimal(scaleOnInfinitePrecision: 3)
            : state.roundedUnitPrice(item);
        final saleProductId = await db
            .into(db.saleProducts)
            .insert(
              SaleProductsCompanion.insert(
                receiptNo: Value(receiptNo),
                posId: Value(posId),
                ucode: item.productId,
                barcode: Value(int.tryParse(item.barcode ?? '')),
                quantity: item.quantity,
                price: effectivePrice,
                priceBefore: state.roundedUnitPrice(item),
              ),
            );

        final mark = item.mark;
        if (mark != null && mark.trim().isNotEmpty) {
          await db.saleProductDao.insertMark(saleProductId, mark.trim());
        }
      }

      await ((db.update(db.sales))..where(
            (s) => s.receiptNo.equals(receiptNo) & s.posId.equals(posId),
          ))
          .write(SalesCompanion(amount: Value(state.total)));

      final resolvedSelectiveOfd =
          selectiveOfd ?? await _resolveSelectiveOfdDefault();

      await saleUseCase.perform(
        receiptNo: receiptNo,
        posId: posId,
        amount: state.total,
        payments: payments,
        change: change,
        selectiveOfd: resolvedSelectiveOfd,
        customerBin: customerBin,
        agentLocalId: state.agentId,
        customFields: customFields,
        withdrawal: withdrawal,
      );

      ref.invalidate(shiftControllerProvider);
      ref.invalidate(historyControllerProvider);
      ref.invalidate(catalogControllerProvider);
      ref.invalidate(stockRegistryControllerProvider);

      return true;
    } catch (e, stack) {
      talker.error('completeSale error: $e', e, stack);
      state = state.copyWith(error: 'error.save_failed:${safeErrorText(e)}');
      return false;
    }
  }

  Future<bool> _resolveSelectiveOfdDefault() async {
    try {
      final db = GetIt.I<AppDatabase>();
      final thisPos = await db.thisPosDao.get();
      if (thisPos == null) return false;
      if (!thisPos.sendToOfd) return false;
      return thisPos.ofdSyncType == 1;
    } catch (_) {
      return false;
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

        final isNumeric = int.tryParse(query) != null;
        final effectiveQuery = isNumeric ? query : '%$query%';

        final domainResults = await searchUseCase.search(
          query: effectiveQuery,
          limit: 50,
        );

        final results = <ProductSearchResult>[];
        for (final r in domainResults) {
          final price = await db.productPriceDao.findByUcode(r.ucode);
          final priceValue = price?.sellingPrice ?? Decimal.zero;

          final productInfo = await db.productInfoDao.findByUcode(r.ucode);

          results.add(
            ProductSearchResult(
              id: r.ucode,
              name: r.name,
              price: priceValue,
              barcode: r.barcode.toString(),
              stock: productInfo?.quantity,
              isDeleted: productInfo?.isDeleted ?? r.isDeleted,
              measure: productInfo?.measure ?? r.measure,
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

  Future<bool> addByBarcode(String barcode) async {
    if (barcode.isEmpty) return false;

    try {
      final findUseCase = GetIt.I<FindByBarcodeUseCase>();
      final result = await findUseCase.find(barcode.trim());

      if (result == null) {
        state = state.copyWith(error: 'error.product_not_found:$barcode');
        return false;
      }

      if (result.isDeleted) {
        final db = GetIt.I<AppDatabase>();
        await db.productInfoDao.restoreProduct(result.ucode);
      }

      addProduct(
        ProductSearchResult(
          id: result.ucode,
          name: result.name,
          price: result.price,
          barcode: result.barcode.toString(),
          stock: null,
          measure: result.measure,
        ),
      );
      return true;
    } catch (e) {
      talker.error('addByBarcode error: $e');
      state = state.copyWith(error: 'error.search_failed:${safeErrorText(e)}');
      return false;
    }
  }

  void clearWarning() {
    if (state.warning != null) state = state.copyWith(clearWarning: true);
  }

  Future<void> _checkExpiryWarning(int ucode, String name) async {
    try {
      if (!GetIt.I.isRegistered<BatchTrackingUseCase>()) return;
      var strategy = 'FEFO';
      try {
        if (GetIt.I.isRegistered<WmsConfigUseCase>()) {
          strategy = await GetIt.I<WmsConfigUseCase>().pickingStrategy();
        }
      } catch (_) {}
      final picked = await GetIt.I<BatchTrackingUseCase>()
          .suggestBatchForPicking(ucode, strategy);
      final exp = picked?.expiryDate;
      if (exp == null) return;
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      if (exp < now) state = state.copyWith(warning: name);
    } catch (_) {}
  }

  void addProduct(ProductSearchResult product, {Decimal? quantity}) {
    if (product.isDeleted) {
      GetIt.I<AppDatabase>().productInfoDao.restoreProduct(product.id);
    }

    if (state.receiptNo == null) {
      _initSale();
    }

    _checkExpiryWarning(product.id, product.name);

    final existingIndex = state.items.indexWhere(
      (i) => i.productId == product.id,
    );

    if (existingIndex >= 0) {
      final existing = state.items[existingIndex];
      final newQuantity = existing.quantity + (quantity ?? Decimal.one);
      final updated = existing.copyWith(quantity: newQuantity);
      final newItems = [...state.items];
      newItems[existingIndex] = updated;
      state = state.copyWith(
        items: _applyPromotions(newItems),
        selectedItemId: existing.id,
        clearError: true,
      );
    } else {
      final item = SaleItem(
        id: 'item_${_nextItemId++}',
        productId: product.id,
        name: product.name,
        price: product.price,
        quantity: quantity ?? Decimal.one,
        barcode: product.barcode,
        measure: product.measure,
      );
      state = state.copyWith(
        items: _applyPromotions([...state.items, item]),
        selectedItemId: item.id,
        clearError: true,
      );
    }

    state = state.copyWith(searchQuery: '', searchResults: []);
  }

  void selectItem(String? itemId) {
    state = state.copyWith(
      selectedItemId: itemId,
      clearSelectedItemId: itemId == null,
    );
  }

  void updateQuantity(Decimal quantity) {
    if (state.selectedItem == null) return;
    if (quantity <= Decimal.zero) {
      removeSelectedItem();
      return;
    }

    final index = state.items.indexWhere((i) => i.id == state.selectedItemId);
    if (index < 0) return;

    final updated = state.items[index].copyWith(quantity: quantity);
    final newItems = [...state.items];
    newItems[index] = updated;
    state = state.copyWith(items: _applyPromotions(newItems));
  }

  List<SaleItem> _applyPromotions(List<SaleItem> items) {
    if (_promotions.isEmpty) return items;

    var working = items
        .map(
          (it) => it.promoApplied
              ? it.copyWith(discount: Decimal.zero, promoApplied: false)
              : it,
        )
        .toList();

    final qtyByProduct = <int, Decimal>{};
    for (final it in working) {
      qtyByProduct[it.productId] =
          (qtyByProduct[it.productId] ?? Decimal.zero) + it.quantity;
    }

    final freeUnits = <int, int>{};
    for (final promo in _promotions) {
      final have = qtyByProduct[promo.triggerUcode] ?? Decimal.zero;
      final need = Decimal.fromInt(promo.triggerQty);
      if (promo.triggerQty <= 0 || have < need) continue;
      final times = (have.toBigInt() ~/ BigInt.from(promo.triggerQty)).toInt();
      if (times <= 0) continue;
      freeUnits[promo.rewardUcode] =
          (freeUnits[promo.rewardUcode] ?? 0) + times * promo.rewardQty;
    }
    if (freeUnits.isEmpty) return working;

    return working.map((it) {
      var free = freeUnits[it.productId] ?? 0;
      if (free <= 0) return it;
      if (it.discountPercent != null || it.discount > Decimal.zero) return it;
      final lineQty = it.quantity.toBigInt().toInt();
      final applied = free > lineQty ? lineQty : free;
      freeUnits[it.productId] = free - applied;
      final discount = it.price * Decimal.fromInt(applied);
      final effective = discount > it.subtotal ? it.subtotal : discount;
      return it.copyWith(discount: effective, promoApplied: true);
    }).toList();
  }

  void incrementQuantity() {
    if (state.selectedItem == null) return;
    updateQuantity(state.selectedItem!.quantity + Decimal.one);
  }

  void decrementQuantity() {
    if (state.selectedItem == null) return;
    updateQuantity(state.selectedItem!.quantity - Decimal.one);
  }

  void setDiscountPercent(Decimal percent) {
    if (state.selectedItem == null) return;
    if (percent < Decimal.zero) return;
    if (percent > Decimal.fromInt(100)) return;

    final index = state.items.indexWhere((i) => i.id == state.selectedItemId);
    if (index < 0) return;

    final item = state.items[index];
    final discountAmount = (item.subtotal * percent / Decimal.fromInt(100))
        .toDecimal();

    final effectiveDiscount = discountAmount > item.subtotal
        ? item.subtotal
        : discountAmount;

    final updated = item.copyWith(
      discount: effectiveDiscount,
      discountPercent: percent,
      promoApplied: false,
    );
    final newItems = [...state.items];
    newItems[index] = updated;
    state = state.copyWith(items: newItems);
  }

  void setDiscountAmount(Decimal amount) {
    if (state.selectedItem == null) return;
    if (amount < Decimal.zero) return;

    final index = state.items.indexWhere((i) => i.id == state.selectedItemId);
    if (index < 0) return;

    final item = state.items[index];

    final effectiveAmount = amount > item.subtotal ? item.subtotal : amount;

    final updated = item.copyWith(
      discount: effectiveAmount,
      clearDiscountPercent: true,
      promoApplied: false,
    );
    final newItems = [...state.items];
    newItems[index] = updated;
    state = state.copyWith(items: newItems);
  }

  void updatePrice(Decimal price) {
    if (state.selectedItem == null) return;
    if (price < Decimal.zero) return;

    final index = state.items.indexWhere((i) => i.id == state.selectedItemId);
    if (index < 0) return;

    final updated = state.items[index].copyWith(price: price);
    final newItems = [...state.items];
    newItems[index] = updated;
    state = state.copyWith(items: newItems);
  }

  Future<bool> canEditPrice() async {
    try {
      final db = GetIt.I<AppDatabase>();
      final thisPos = await db.thisPosDao.get();
      return thisPos?.editPrice ?? true;
    } catch (_) {
      return true;
    }
  }

  void setMark(String mark) {
    if (state.selectedItem == null) return;

    final index = state.items.indexWhere((i) => i.id == state.selectedItemId);
    if (index < 0) return;

    final updated = state.items[index].copyWith(mark: mark);
    final newItems = [...state.items];
    newItems[index] = updated;
    state = state.copyWith(items: newItems);
  }

  void removeSelectedItem() {
    if (state.selectedItemId == null) return;

    final newItems = state.items
        .where((i) => i.id != state.selectedItemId)
        .toList();
    state = state.copyWith(items: newItems, clearSelectedItemId: true);
  }

  void clearSale() {
    _searchDebounce?.cancel();
    state = const SaleState();
    _nextItemId = 1;
  }

  Future<void> deferSale() async {
    if (state.isEmpty) return;

    final receiptNo = state.receiptNo;
    if (receiptNo == null) return;

    try {
      final deferredService = GetIt.I<DeferredSaleService>();

      final db = GetIt.I<AppDatabase>();
      final posId = state.posId ?? 0;

      await db.batch((batch) {
        for (final item in state.items) {
          final lineTotal = state.roundedLineTotal(item);
          final effectivePrice = item.quantity > Decimal.zero
              ? (lineTotal / item.quantity).toDecimal(
                  scaleOnInfinitePrecision: 3,
                )
              : state.roundedUnitPrice(item);
          batch.insert(
            db.saleProducts,
            SaleProductsCompanion.insert(
              receiptNo: Value(receiptNo),
              posId: Value(posId),
              ucode: item.productId,
              barcode: Value(int.tryParse(item.barcode ?? '')),
              quantity: item.quantity,
              price: effectivePrice,
              priceBefore: state.roundedUnitPrice(item),
            ),
          );
        }
      });

      await (db.update(db.sales)..where(
            (s) => s.receiptNo.equals(receiptNo) & s.posId.equals(posId),
          ))
          .write(SalesCompanion(amount: Value(state.total)));

      await deferredService.deferSale(receiptNo: receiptNo);

      _searchDebounce?.cancel();
      _nextItemId = 1;
      state = const SaleState();
      await _initSale();
    } catch (e) {
      state = state.copyWith(error: 'error.save_failed:${safeErrorText(e)}');
    }
  }

  Future<void> loadDeferredSale(int receiptNo) async {
    try {
      final deferredService = GetIt.I<DeferredSaleService>();
      final db = GetIt.I<AppDatabase>();

      final sale = await deferredService.undeferSale(receiptNo: receiptNo);
      if (sale == null) {
        state = state.copyWith(error: 'error.deferred_not_found');
        return;
      }

      final thisPos = await db.thisPosDao.get();
      final posId = thisPos?.id ?? 0;

      final products = await deferredService.getProducts(
        receiptNo: receiptNo,
        posId: posId,
      );

      final items = <SaleItem>[];
      for (final p in products) {
        final productInfo = await db.productInfoDao.findByUcode(p.ucode);
        items.add(
          SaleItem(
            id: 'item_${_nextItemId++}',
            productId: p.ucode,
            name: p.name,
            price: p.price is Decimal ? p.price : Decimal.parse('${p.price}'),
            quantity: p.quantity is Decimal
                ? p.quantity
                : Decimal.parse('${p.quantity}'),
            measure: productInfo?.measure ?? 0,
          ),
        );
      }

      state = state.copyWith(
        items: items,
        deferredSaleId: receiptNo.toString(),
        isDeferred: false,
      );
    } catch (e) {
      state = state.copyWith(error: 'error.load_failed:${safeErrorText(e)}');
    }
  }

  Future<void> loadFromRestaurantOrder({
    required int receiptNo,
    required int posId,
  }) async {
    try {
      final db = GetIt.I<AppDatabase>();

      final saleProducts = await db.saleProductDao.findBySale(receiptNo, posId);

      final items = <SaleItem>[];
      for (final sp in saleProducts) {
        final productInfo = await db.productInfoDao.findByUcode(sp.ucode);
        final price = sp.price is Decimal
            ? sp.price as Decimal
            : Decimal.parse('${sp.price}');
        final qty = sp.quantity is Decimal
            ? sp.quantity as Decimal
            : Decimal.parse('${sp.quantity}');

        items.add(
          SaleItem(
            id: 'item_${_nextItemId++}',
            productId: sp.ucode,
            name: productInfo?.name ?? '#${sp.ucode}',
            price: price,
            quantity: qty,
            barcode: sp.barcode.toString(),
            measure: productInfo?.measure ?? 0,
          ),
        );
      }

      state = state.copyWith(receiptNo: receiptNo, posId: posId, items: items);
    } catch (e) {
      talker.error('loadFromRestaurantOrder error: $e');
      state = state.copyWith(error: 'error.load_failed:${safeErrorText(e)}');
    }
  }

  void toggleMode() {
    state = state.copyWith(
      mode: state.mode == SaleMode.retail
          ? SaleMode.wholesale
          : SaleMode.retail,
    );
  }

  void setAgent(int id, String name) {
    state = state.copyWith(agentId: id, agentName: name);
  }

  void clearAgent() {
    state = state.copyWith(clearAgentId: true, clearAgentName: true);
  }
}

final saleControllerProvider = NotifierProvider<SaleNotifier, SaleState>(
  SaleNotifier.new,
);

final selectedSaleItemProvider = Provider<SaleItem?>((ref) {
  return ref.watch(saleControllerProvider.select((s) => s.selectedItem));
});

final saleTotalProvider = Provider<Decimal>((ref) {
  return ref.watch(saleControllerProvider.select((s) => s.total));
});

import 'package:decimal/decimal.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';
import 'package:telepos/core/errors/safe_error_text.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/domain/usecases/inventory/create_inventory_use_case.dart';
import 'package:telepos/presentation/controllers/catalog/catalog_controller.dart';
import 'package:telepos/presentation/controllers/stock_registry/stock_registry_controller.dart';

@immutable
class InventoryProductItem {
  const InventoryProductItem({
    required this.ucode,
    required this.name,
    required this.expectedQty,
    required this.actualQty,
    required this.price,
    this.barcode,
  });

  final int ucode;
  final String name;
  final Decimal expectedQty;
  final Decimal actualQty;
  final Decimal price;
  final String? barcode;

  Decimal get difference => actualQty - expectedQty;
  bool get hasDiscrepancy => difference != Decimal.zero;

  InventoryProductItem copyWith({Decimal? actualQty}) => InventoryProductItem(
    ucode: ucode,
    name: name,
    expectedQty: expectedQty,
    actualQty: actualQty ?? this.actualQty,
    price: price,
    barcode: barcode,
  );
}

@immutable
class InventoryState {
  const InventoryState({
    this.inventoryId,
    this.products = const [],
    this.comment = '',
    this.isActive = false,
    this.isLoading = false,
    this.isSaving = false,
    this.isFullCount = false,
    this.error,
  });

  final int? inventoryId;
  final List<InventoryProductItem> products;
  final String comment;
  final bool isActive;
  final bool isLoading;
  final bool isSaving;

  final bool isFullCount;
  final String? error;

  int get productCount => products.length;
  int get discrepancyCount => products.where((p) => p.hasDiscrepancy).length;
  bool get canComplete =>
      isActive && products.isNotEmpty && !isLoading && !isSaving;

  InventoryState copyWith({
    int? inventoryId,
    List<InventoryProductItem>? products,
    String? comment,
    bool? isActive,
    bool? isLoading,
    bool? isSaving,
    bool? isFullCount,
    String? error,
    bool clearError = false,
  }) => InventoryState(
    inventoryId: inventoryId ?? this.inventoryId,
    products: products ?? this.products,
    comment: comment ?? this.comment,
    isActive: isActive ?? this.isActive,
    isLoading: isLoading ?? this.isLoading,
    isSaving: isSaving ?? this.isSaving,
    isFullCount: isFullCount ?? this.isFullCount,
    error: clearError ? null : (error ?? this.error),
  );
}

class InventoryNotifier extends Notifier<InventoryState> {
  @override
  InventoryState build() => const InventoryState();

  AppDatabase get _db => GetIt.I<AppDatabase>();

  void setFullCount(bool isFullCount) {
    if (state.isActive) return;
    state = state.copyWith(isFullCount: isFullCount);
  }

  Future<void> startNew({String? comment, bool? isFullCount}) async {
    final fullCount = isFullCount ?? state.isFullCount;
    state = state.copyWith(
      isLoading: true,
      isFullCount: fullCount,
      clearError: true,
    );

    try {
      final useCase = GetIt.I<CreateInventoryUseCase>();
      final inventoryId = await useCase.create(
        comment: comment,
        isFullCount: fullCount,
      );

      state = state.copyWith(
        inventoryId: inventoryId,
        isActive: true,
        comment: comment ?? '',
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'error.save_failed:${safeErrorText(e)}',
      );
    }
  }

  Future<void> scanProduct(String barcode) async {
    if (state.inventoryId == null) return;
    state = state.copyWith(clearError: true);

    try {
      final product = await _db.productInfoDao.findByBarcode(barcode);
      if (product == null) {
        state = state.copyWith(error: 'error.product_not_found:$barcode');
        return;
      }

      final priceRow = await _db.productPriceDao.findByUcode(product.ucode);
      final price = priceRow?.sellingPrice ?? Decimal.zero;

      final expectedQty = product.quantity ?? Decimal.zero;

      final existingIdx = state.products.indexWhere(
        (p) => p.ucode == product.ucode,
      );

      if (existingIdx >= 0) {
        final existing = state.products[existingIdx];
        final updated = existing.copyWith(
          actualQty: existing.actualQty + Decimal.one,
        );
        final newProducts = [...state.products];
        newProducts[existingIdx] = updated;
        state = state.copyWith(products: newProducts);
      } else {
        final newItem = InventoryProductItem(
          ucode: product.ucode,
          name: product.name,
          expectedQty: expectedQty,
          actualQty: Decimal.one,
          price: price,
          barcode: product.barcode.toString(),
        );
        state = state.copyWith(products: [...state.products, newItem]);
      }

      final useCase = GetIt.I<CreateInventoryUseCase>();
      final item = state.products.firstWhere((p) => p.ucode == product.ucode);
      await useCase.upsertProduct(
        inventoryId: state.inventoryId!,
        ucode: item.ucode,
        expectedQty: item.expectedQty,
        actualQty: item.actualQty,
        price: item.price,
      );
    } catch (e) {
      state = state.copyWith(error: 'error.unknown:${safeErrorText(e)}');
    }
  }

  Future<void> setActualQty(int ucode, Decimal qty) async {
    final idx = state.products.indexWhere((p) => p.ucode == ucode);
    if (idx < 0 || state.inventoryId == null) return;

    final updated = state.products[idx].copyWith(actualQty: qty);
    final newProducts = [...state.products];
    newProducts[idx] = updated;
    state = state.copyWith(products: newProducts);

    try {
      final useCase = GetIt.I<CreateInventoryUseCase>();
      await useCase.upsertProduct(
        inventoryId: state.inventoryId!,
        ucode: updated.ucode,
        expectedQty: updated.expectedQty,
        actualQty: updated.actualQty,
        price: updated.price,
      );
    } catch (_) {}
  }

  Future<CreateInventoryResult> complete() async {
    if (!state.canComplete || state.inventoryId == null) {
      return CreateInventoryResult.failed('error.inventory_cannot_complete');
    }

    state = state.copyWith(isSaving: true, clearError: true);

    try {
      final useCase = GetIt.I<CreateInventoryUseCase>();
      final result = await useCase.complete(state.inventoryId!);

      state = state.copyWith(isSaving: false, isActive: !result.success);

      ref.invalidate(catalogControllerProvider);
      ref.invalidate(stockRegistryControllerProvider);

      return result;
    } catch (e) {
      state = state.copyWith(
        isSaving: false,
        error: 'error.save_failed:${safeErrorText(e)}',
      );
      return CreateInventoryResult.failed('error.unknown:${safeErrorText(e)}');
    }
  }

  void reset() {
    state = const InventoryState();
  }
}

final inventoryControllerProvider =
    NotifierProvider<InventoryNotifier, InventoryState>(InventoryNotifier.new);

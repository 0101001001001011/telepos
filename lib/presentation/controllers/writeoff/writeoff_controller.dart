import 'package:decimal/decimal.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';
import 'package:telepos/core/errors/safe_error_text.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/domain/usecases/writeoff/create_writeoff_use_case.dart';
import 'package:telepos/presentation/controllers/catalog/catalog_controller.dart';
import 'package:telepos/presentation/controllers/inventory/inventory_controller.dart';
import 'package:telepos/presentation/controllers/stock_registry/stock_registry_controller.dart';

@immutable
class WriteoffProductItem {
  const WriteoffProductItem({
    required this.ucode,
    required this.name,
    required this.quantity,
    required this.price,
    this.barcode,
  });

  final int ucode;
  final String name;
  final Decimal quantity;
  final Decimal price;
  final String? barcode;

  Decimal get amount => quantity * price;

  WriteoffProductItem copyWith({Decimal? quantity, Decimal? price}) =>
      WriteoffProductItem(
        ucode: ucode,
        name: name,
        quantity: quantity ?? this.quantity,
        price: price ?? this.price,
        barcode: barcode,
      );
}

@immutable
class WriteoffState {
  const WriteoffState({
    this.reason = WriteoffReason.breakage,
    this.products = const [],
    this.comment = '',
    this.isLoading = false,
    this.isSaving = false,
    this.error,
  });

  final WriteoffReason reason;
  final List<WriteoffProductItem> products;
  final String comment;
  final bool isLoading;
  final bool isSaving;
  final String? error;

  Decimal get totalAmount =>
      products.fold<Decimal>(Decimal.zero, (sum, p) => sum + p.amount);

  int get productCount => products.length;

  bool get canSave => products.isNotEmpty && !isLoading && !isSaving;

  WriteoffState copyWith({
    WriteoffReason? reason,
    List<WriteoffProductItem>? products,
    String? comment,
    bool? isLoading,
    bool? isSaving,
    String? error,
    bool clearError = false,
  }) => WriteoffState(
    reason: reason ?? this.reason,
    products: products ?? this.products,
    comment: comment ?? this.comment,
    isLoading: isLoading ?? this.isLoading,
    isSaving: isSaving ?? this.isSaving,
    error: clearError ? null : (error ?? this.error),
  );
}

class WriteoffNotifier extends Notifier<WriteoffState> {
  @override
  WriteoffState build() => const WriteoffState();

  AppDatabase get _db => GetIt.I<AppDatabase>();

  void setReason(WriteoffReason reason) {
    state = state.copyWith(reason: reason);
  }

  void setComment(String comment) {
    state = state.copyWith(comment: comment);
  }

  Future<void> addProductByBarcode(String barcode) async {
    state = state.copyWith(clearError: true);

    try {
      final product = await _db.productInfoDao.findByBarcode(barcode);
      if (product == null) {
        state = state.copyWith(error: 'error.product_not_found:$barcode');
        return;
      }

      final priceRow = await _db.productPriceDao.findByUcode(product.ucode);
      final price = priceRow?.sellingPrice ?? Decimal.zero;

      final existingIdx = state.products.indexWhere(
        (p) => p.ucode == product.ucode,
      );

      if (existingIdx >= 0) {
        final existing = state.products[existingIdx];
        final updated = existing.copyWith(
          quantity: existing.quantity + Decimal.one,
        );
        final newProducts = [...state.products];
        newProducts[existingIdx] = updated;
        state = state.copyWith(products: newProducts);
      } else {
        final newItem = WriteoffProductItem(
          ucode: product.ucode,
          name: product.name,
          quantity: Decimal.one,
          price: price,
          barcode: product.barcode.toString(),
        );
        state = state.copyWith(products: [...state.products, newItem]);
      }
    } catch (e) {
      state = state.copyWith(error: 'error.search_failed:${safeErrorText(e)}');
    }
  }

  void updateQuantity(int ucode, Decimal quantity) {
    if (quantity <= Decimal.zero) {
      removeProduct(ucode);
      return;
    }

    final idx = state.products.indexWhere((p) => p.ucode == ucode);
    if (idx < 0) return;

    final updated = state.products[idx].copyWith(quantity: quantity);
    final newProducts = [...state.products];
    newProducts[idx] = updated;
    state = state.copyWith(products: newProducts);
  }

  void removeProduct(int ucode) {
    state = state.copyWith(
      products: state.products.where((p) => p.ucode != ucode).toList(),
    );
  }

  Future<CreateWriteoffResult> save() async {
    if (!state.canSave) {
      return CreateWriteoffResult.failed('error.no_products');
    }

    state = state.copyWith(isSaving: true, clearError: true);

    try {
      final useCase = GetIt.I<CreateWriteoffUseCase>();
      final result = await useCase.create(
        reason: state.reason,
        products: state.products
            .map(
              (p) => WriteoffProductEntry(
                ucode: p.ucode,
                quantity: p.quantity,
                price: p.price,
                productName: p.name,
              ),
            )
            .toList(),
        comment: state.comment.isNotEmpty ? state.comment : null,
      );

      state = state.copyWith(isSaving: false);

      ref.invalidate(catalogControllerProvider);
      ref.invalidate(stockRegistryControllerProvider);
      ref.invalidate(inventoryControllerProvider);

      return result;
    } catch (e) {
      state = state.copyWith(
        isSaving: false,
        error: 'error.save_failed:${safeErrorText(e)}',
      );
      return CreateWriteoffResult.failed('error.unknown:${safeErrorText(e)}');
    }
  }

  void reset() {
    state = const WriteoffState();
  }
}

final writeoffControllerProvider =
    NotifierProvider<WriteoffNotifier, WriteoffState>(WriteoffNotifier.new);

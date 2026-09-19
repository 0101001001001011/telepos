import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:telepos/presentation/controllers/app/stock_revision.dart';
import 'package:get_it/get_it.dart';
import 'package:talker/talker.dart';
import 'package:telepos/core/errors/safe_error_text.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/domain/usecases/product/find_by_barcode_use_case.dart';

@immutable
class MovementProductInfo {
  const MovementProductInfo({
    required this.ucode,
    required this.quantity,
    required this.price,
    this.productName,
    this.barcode,
  });

  final int ucode;
  final String? productName;
  final Decimal quantity;
  final Decimal price;
  final String? barcode;

  Decimal get amount => quantity * price;

  MovementProductInfo copyWith({
    int? ucode,
    String? productName,
    Decimal? quantity,
    Decimal? price,
    String? barcode,
  }) {
    return MovementProductInfo(
      ucode: ucode ?? this.ucode,
      productName: productName ?? this.productName,
      quantity: quantity ?? this.quantity,
      price: price ?? this.price,
      barcode: barcode ?? this.barcode,
    );
  }
}

@immutable
class MovementSaveResult {
  const MovementSaveResult({
    required this.success,
    this.movementId,
    this.totalAmount,
    this.productCount,
    this.errorMessage,
  });

  final bool success;
  final int? movementId;
  final Decimal? totalAmount;
  final int? productCount;
  final String? errorMessage;

  factory MovementSaveResult.saved({
    required int movementId,
    required Decimal totalAmount,
    required int productCount,
  }) => MovementSaveResult(
    success: true,
    movementId: movementId,
    totalAmount: totalAmount,
    productCount: productCount,
  );

  factory MovementSaveResult.failed(String message) =>
      MovementSaveResult(success: false, errorMessage: message);
}

@immutable
class MovementState {
  const MovementState({
    this.fromLocation = '',
    this.toLocation = '',
    this.products = const [],
    this.comment = '',
    this.isLoading = false,
    this.isSaving = false,
    this.error,
  });

  final String fromLocation;

  final String toLocation;

  final List<MovementProductInfo> products;

  final String comment;

  final bool isLoading;

  final bool isSaving;

  final String? error;

  Decimal? get totalAmount {
    if (products.isEmpty) return null;
    return products.fold<Decimal>(Decimal.zero, (sum, p) => sum + p.amount);
  }

  int get productCount => products.length;

  bool get canSave =>
      fromLocation.isNotEmpty &&
      toLocation.isNotEmpty &&
      products.isNotEmpty &&
      !isLoading &&
      !isSaving;

  bool get hasError => error != null;

  MovementState copyWith({
    String? fromLocation,
    String? toLocation,
    List<MovementProductInfo>? products,
    String? comment,
    bool? isLoading,
    bool? isSaving,
    String? error,
    bool clearError = false,
  }) {
    return MovementState(
      fromLocation: fromLocation ?? this.fromLocation,
      toLocation: toLocation ?? this.toLocation,
      products: products ?? this.products,
      comment: comment ?? this.comment,
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class MovementNotifier extends Notifier<MovementState> {
  Talker get _logger => GetIt.I<Talker>();
  AppDatabase get _db => GetIt.I<AppDatabase>();

  @override
  MovementState build() {
    return const MovementState();
  }

  void setFromLocation(String value) {
    state = state.copyWith(fromLocation: value, clearError: true);
  }

  void setToLocation(String value) {
    state = state.copyWith(toLocation: value, clearError: true);
  }

  void setComment(String comment) {
    state = state.copyWith(comment: comment);
  }

  void clearError() {
    state = state.copyWith(clearError: true);
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

      await addProduct(
        ucode: result.ucode,
        quantity: Decimal.one,
        price: result.minPrice ?? result.price,
      );
      return true;
    } catch (e) {
      _logger.error('addByBarcode error: $e');
      state = state.copyWith(error: 'error.search_failed:${safeErrorText(e)}');
      return false;
    }
  }

  Future<void> addProduct({
    required int ucode,
    required Decimal quantity,
    required Decimal price,
  }) async {
    state = state.copyWith(clearError: true);

    try {
      final productInfo = await _db.productInfoDao.findByUcode(ucode);

      final existingIndex = state.products.indexWhere((p) => p.ucode == ucode);

      List<MovementProductInfo> updatedProducts;

      if (existingIndex >= 0) {
        final existing = state.products[existingIndex];
        final newQuantity = existing.quantity + quantity;
        final updated = existing.copyWith(quantity: newQuantity, price: price);
        updatedProducts = [...state.products];
        updatedProducts[existingIndex] = updated;
      } else {
        final newItem = MovementProductInfo(
          ucode: ucode,
          productName: productInfo?.name,
          quantity: quantity,
          price: price,
          barcode: productInfo?.barcode.toString(),
        );
        updatedProducts = [...state.products, newItem];
      }

      state = state.copyWith(products: updatedProducts);

      _logger.debug(
        'Movement product added: $ucode, qty: $quantity, price: $price',
      );
    } catch (e) {
      _logger.error('Failed to add product: $e');
      state = state.copyWith(error: 'error.save_failed:${safeErrorText(e)}');
    }
  }

  void updateProduct({
    required int ucode,
    required Decimal quantity,
    required Decimal price,
  }) {
    final index = state.products.indexWhere((p) => p.ucode == ucode);
    if (index < 0) {
      state = state.copyWith(error: 'error.product_not_found');
      return;
    }

    if (quantity <= Decimal.zero) {
      removeProduct(ucode);
      return;
    }

    final updatedProducts = [...state.products];
    updatedProducts[index] = state.products[index].copyWith(
      quantity: quantity,
      price: price,
    );

    state = state.copyWith(products: updatedProducts, clearError: true);

    _logger.debug(
      'Movement product updated: $ucode, qty: $quantity, price: $price',
    );
  }

  void removeProduct(int ucode) {
    final updatedProducts = state.products
        .where((p) => p.ucode != ucode)
        .toList();

    state = state.copyWith(products: updatedProducts, clearError: true);

    _logger.debug('Movement product removed: $ucode');
  }

  Future<MovementSaveResult> save() async {
    if (!state.canSave) {
      return MovementSaveResult.failed('error.validation');
    }

    state = state.copyWith(isSaving: true, clearError: true);

    try {
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final totalAmount = state.totalAmount ?? Decimal.zero;

      final thisPos = await _db.thisPosDao.get();
      final userId = thisPos?.id;

      final movementId = await _db
          .into(_db.movements)
          .insert(
            MovementsCompanion.insert(
              userId: Value(userId ?? 0),
              editTime: Value(now),
              amount: Value(totalAmount),
              comment: Value(state.comment.isNotEmpty ? state.comment : ''),
              fromLocation: Value(state.fromLocation),
              toLocation: Value(state.toLocation),
              state: const Value(1),
            ),
          );

      for (final product in state.products) {
        await _db
            .into(_db.movementProducts)
            .insert(
              MovementProductsCompanion.insert(
                movementId: movementId,
                ucode: product.ucode,
                quantity: product.quantity,
                price: product.price,
                amount: product.amount,
              ),
            );
      }

      _logger.info(
        'Movement saved: id=$movementId, ${state.productCount} products, '
        'total: $totalAmount, ${state.fromLocation} -> ${state.toLocation}',
      );

      state = state.copyWith(isSaving: false);

      // Задача 36: одна дорога на «остатки изменились» — счётчик.
      ref.read(stockRevisionProvider.notifier).bump();

      return MovementSaveResult.saved(
        movementId: movementId,
        totalAmount: totalAmount,
        productCount: state.productCount,
      );
    } catch (e) {
      _logger.error('Failed to save movement: $e');
      state = state.copyWith(
        isSaving: false,
        error: 'error.save_failed:${safeErrorText(e)}',
      );
      // `safeErrorText` и здесь. Строкой выше состояние экрана уже очищено, а
      // это — тот же текст, уезжающий вторым путём: `MovementSaveResult`
      // возвращается вызывающему и попадает в `errorMessage` на экране.
      // Сторож (`no_raw_exception_on_wire_test.dart`) его не ловит: он ищет
      // именованный `error:`, а тут позиционный довод фабрики. Одна и та же
      // утечка в двух формах — вторую нашёл разбор, а не сторож, и это про
      // сторож, а не про эту строку.
      return MovementSaveResult.failed('error.save_failed:${safeErrorText(e)}');
    }
  }

  void cancel() {
    state = const MovementState();
    _logger.debug('Movement cancelled and reset');
  }

  void reset() {
    state = const MovementState();
    _logger.debug('Movement state reset');
  }
}

final movementControllerProvider =
    NotifierProvider<MovementNotifier, MovementState>(MovementNotifier.new);

import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';
import 'package:talker/talker.dart';
import 'package:telepos/core/errors/safe_error_text.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/usecases/cogs/apply_cogs_on_issue.dart'
    show resolveConfiguredCogsMethod;
import 'package:telepos/data/usecases/supplier_return/apply_supplier_return_cogs_use_case.dart';
import 'package:telepos/domain/usecases/cogs/calculate_cogs_use_case.dart';
import 'package:telepos/domain/usecases/product/find_by_barcode_use_case.dart';
import 'package:telepos/presentation/controllers/catalog/catalog_controller.dart';
import 'package:telepos/presentation/controllers/shift/shift_controller.dart';
import 'package:telepos/presentation/controllers/stock_registry/stock_registry_controller.dart';

@immutable
class SupplierItem {
  const SupplierItem({required this.id, required this.name, this.phone});

  final int id;
  final String name;
  final String? phone;
}

@immutable
class AccountItem {
  const AccountItem({
    required this.id,
    required this.name,
    required this.balance,
  });

  final int id;
  final String name;
  final Decimal balance;
}

@immutable
class ReturnProductInfo {
  const ReturnProductInfo({
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

  ReturnProductInfo copyWith({
    int? ucode,
    String? productName,
    Decimal? quantity,
    Decimal? price,
    String? barcode,
  }) {
    return ReturnProductInfo(
      ucode: ucode ?? this.ucode,
      productName: productName ?? this.productName,
      quantity: quantity ?? this.quantity,
      price: price ?? this.price,
      barcode: barcode ?? this.barcode,
    );
  }
}

@immutable
class SupplierReturnSaveResult {
  const SupplierReturnSaveResult({
    required this.success,
    this.returnId,
    this.totalAmount,
    this.productCount,
    this.cogs,
    this.errorMessage,
  });

  final bool success;
  final int? returnId;
  final Decimal? totalAmount;
  final int? productCount;

  final Decimal? cogs;
  final String? errorMessage;

  factory SupplierReturnSaveResult.saved({
    required int returnId,
    required Decimal totalAmount,
    required int productCount,
    Decimal? cogs,
  }) => SupplierReturnSaveResult(
    success: true,
    returnId: returnId,
    totalAmount: totalAmount,
    productCount: productCount,
    cogs: cogs,
  );

  factory SupplierReturnSaveResult.failed(String message) =>
      SupplierReturnSaveResult(success: false, errorMessage: message);
}

@immutable
class SupplierReturnState {
  const SupplierReturnState({
    this.supplierId,
    this.supplierName,
    this.accountId,
    this.accountName,
    this.products = const [],
    this.supplyId,
    this.comment = '',
    this.isLoading = false,
    this.isSaving = false,
    this.error,
  });

  final int? supplierId;

  final String? supplierName;

  final int? accountId;

  final String? accountName;

  final List<ReturnProductInfo> products;

  final int? supplyId;

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
      supplierId != null && products.isNotEmpty && !isLoading && !isSaving;

  bool get hasError => error != null;

  SupplierReturnState copyWith({
    int? supplierId,
    String? supplierName,
    int? accountId,
    String? accountName,
    List<ReturnProductInfo>? products,
    int? supplyId,
    String? comment,
    bool? isLoading,
    bool? isSaving,
    String? error,
    bool clearSupplier = false,
    bool clearAccount = false,
    bool clearSupplyId = false,
    bool clearError = false,
  }) {
    return SupplierReturnState(
      supplierId: clearSupplier ? null : (supplierId ?? this.supplierId),
      supplierName: clearSupplier ? null : (supplierName ?? this.supplierName),
      accountId: clearAccount ? null : (accountId ?? this.accountId),
      accountName: clearAccount ? null : (accountName ?? this.accountName),
      products: products ?? this.products,
      supplyId: clearSupplyId ? null : (supplyId ?? this.supplyId),
      comment: comment ?? this.comment,
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class SupplierReturnNotifier extends Notifier<SupplierReturnState> {
  Talker get _logger => GetIt.I<Talker>();
  AppDatabase get _db => GetIt.I<AppDatabase>();

  @override
  SupplierReturnState build() {
    return const SupplierReturnState();
  }

  Future<List<SupplierItem>> getSuppliers() async {
    try {
      final agents = await _db.agentDao.findByType(0);
      return agents
          .map(
            (a) => SupplierItem(
              id: a.localId,
              name: a.name ?? 'N/A',
              phone: a.phone?.toString(),
            ),
          )
          .toList();
    } catch (e) {
      _logger.error('Failed to get suppliers: $e');
      return [];
    }
  }

  Future<List<AccountItem>> getAccounts() async {
    try {
      final accounts = await _db.accountDao.findAll();
      return accounts
          .map(
            (a) => AccountItem(
              id: a.id,
              name: a.name ?? 'N/A',
              balance: a.value ?? Decimal.zero,
            ),
          )
          .toList();
    } catch (e) {
      _logger.error('Failed to get accounts: $e');
      return [];
    }
  }

  void clearError() {
    state = state.copyWith(clearError: true);
  }

  Future<void> selectSupplier(int agentId) async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final agent = await _db.agentDao.findById(agentId);

      if (agent == null) {
        state = state.copyWith(
          isLoading: false,
          error: 'error.supplier_not_found',
        );
        return;
      }

      state = state.copyWith(
        supplierId: agent.localId,
        supplierName: agent.name,
        isLoading: false,
      );

      _logger.debug('Supplier selected for return: ${agent.name}');
    } catch (e) {
      _logger.error('Failed to select supplier: $e');
      state = state.copyWith(
        isLoading: false,
        error: 'error.load_failed:${safeErrorText(e)}',
      );
    }
  }

  Future<void> selectAccount(int accountId) async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final account = await _db.accountDao.findById(accountId);

      if (account == null) {
        state = state.copyWith(
          isLoading: false,
          error: 'error.account_not_found',
        );
        return;
      }

      state = state.copyWith(
        accountId: account.id,
        accountName: account.name,
        isLoading: false,
      );

      _logger.debug('Account selected for return: ${account.name}');
    } catch (e) {
      _logger.error('Failed to select account: $e');
      state = state.copyWith(
        isLoading: false,
        error: 'error.load_failed:${safeErrorText(e)}',
      );
    }
  }

  void setSupplyId(int? supplyId) {
    state = state.copyWith(supplyId: supplyId, clearSupplyId: supplyId == null);
  }

  void setComment(String comment) {
    state = state.copyWith(comment: comment);
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

      List<ReturnProductInfo> updatedProducts;

      if (existingIndex >= 0) {
        final existing = state.products[existingIndex];
        final newQuantity = existing.quantity + quantity;
        final updated = existing.copyWith(quantity: newQuantity, price: price);
        updatedProducts = [...state.products];
        updatedProducts[existingIndex] = updated;
      } else {
        final newItem = ReturnProductInfo(
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
        'Return product added: $ucode, qty: $quantity, price: $price',
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
      'Return product updated: $ucode, qty: $quantity, price: $price',
    );
  }

  void removeProduct(int ucode) {
    final updatedProducts = state.products
        .where((p) => p.ucode != ucode)
        .toList();

    state = state.copyWith(products: updatedProducts, clearError: true);

    _logger.debug('Return product removed: $ucode');
  }

  Future<SupplierReturnSaveResult> save() async {
    if (!state.canSave) {
      return SupplierReturnSaveResult.failed('error.validation');
    }

    state = state.copyWith(isSaving: true, clearError: true);

    try {
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final totalAmount = state.totalAmount ?? Decimal.zero;

      final thisPos = await _db.thisPosDao.get();
      final userId = thisPos?.id;

      final returnId = await _db
          .into(_db.supplierReturns)
          .insert(
            SupplierReturnsCompanion.insert(
              userId: Value(userId ?? 0),
              supplierId: Value(state.supplierId!),
              editTime: Value(now),
              amount: Value(totalAmount),
              accountId: Value(state.accountId),
              comment: Value(state.comment.isNotEmpty ? state.comment : ''),
              supplyId: Value(state.supplyId),
              state: const Value(1),
            ),
          );

      for (final product in state.products) {
        await _db
            .into(_db.supplierReturnProducts)
            .insert(
              SupplierReturnProductsCompanion.insert(
                supplierReturnId: returnId,
                ucode: product.ucode,
                quantity: product.quantity,
                price: product.price,
                amount: product.amount,
              ),
            );
      }

      Decimal? returnCogs;
      try {
        final applier = ApplySupplierReturnCogsUseCase(
          cogsUseCase: GetIt.I<CalculateCogsUseCase>(),
          db: _db,
        );
        final cogsResult = await applier.apply(
          lines: [
            for (final p in state.products)
              SupplierReturnCogsLine(ucode: p.ucode, quantity: p.quantity),
          ],
          method: await resolveConfiguredCogsMethod(),
          persistNoteToReturnId: returnId,
        );
        returnCogs = cogsResult.totalCogs;
        _logger.info('Supplier return COGS recorded: $returnCogs');
      } catch (e) {
        _logger.error('Supplier return COGS failed (non-blocking): $e');
      }

      for (final product in state.products) {
        final current = await _db.productInfoDao.findByUcode(product.ucode);
        if (current != null) {
          final newQty = (current.quantity ?? Decimal.zero) - product.quantity;
          await _db.productInfoDao.updateQuantity(product.ucode, newQty);
        }
      }

      if (state.accountId != null) {
        final account = await _db.accountDao.findById(state.accountId!);
        if (account != null) {
          final currentBalance = account.value ?? Decimal.zero;
          final newBalance = currentBalance + totalAmount;
          await _db.accountDao.updateBalance(state.accountId!, newBalance);
          _logger.info(
            'Supplier return: account ${state.accountId} balance '
            '$currentBalance -> $newBalance (+$totalAmount)',
          );
        }
      }

      _logger.info(
        'Supplier return saved: id=$returnId, ${state.productCount} products, '
        'total: $totalAmount, supplier: ${state.supplierName}',
      );

      state = state.copyWith(isSaving: false);

      ref.invalidate(shiftControllerProvider);
      ref.invalidate(catalogControllerProvider);
      ref.invalidate(stockRegistryControllerProvider);

      return SupplierReturnSaveResult.saved(
        returnId: returnId,
        totalAmount: totalAmount,
        productCount: state.productCount,
        cogs: returnCogs,
      );
    } catch (e) {
      _logger.error('Failed to save supplier return: $e');
      state = state.copyWith(
        isSaving: false,
        error: 'error.save_failed:${safeErrorText(e)}',
      );
      return SupplierReturnSaveResult.failed(
        'error.save_failed:${safeErrorText(e)}',
      );
    }
  }

  void cancel() {
    state = const SupplierReturnState();
    _logger.debug('Supplier return cancelled and reset');
  }

  void reset() {
    state = const SupplierReturnState();
    _logger.debug('Supplier return state reset');
  }
}

final supplierReturnControllerProvider =
    NotifierProvider<SupplierReturnNotifier, SupplierReturnState>(
      SupplierReturnNotifier.new,
    );

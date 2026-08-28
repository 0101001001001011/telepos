import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';
import 'package:talker/talker.dart';
import 'package:telepos/core/errors/safe_error_text.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/domain/usecases/product/find_by_barcode_use_case.dart';
import 'package:telepos/domain/usecases/product/mark_up_use_case.dart';
import 'package:telepos/domain/usecases/supply/create_supply_use_case.dart';
import 'package:telepos/domain/usecases/supply/save_supply_use_case.dart';
import 'package:telepos/domain/usecases/wms/wms_config_use_case.dart';
import 'package:telepos/data/mappers/supply_mapper.dart';
import 'package:telepos/presentation/controllers/catalog/catalog_controller.dart';
import 'package:telepos/presentation/controllers/inventory/inventory_controller.dart';
import 'package:telepos/presentation/controllers/shift/shift_controller.dart';
import 'package:telepos/presentation/controllers/stock_registry/stock_registry_controller.dart';

export 'package:telepos/domain/usecases/supply/create_supply_use_case.dart'
    show SupplyPaymentType;

class SupplierItem {
  const SupplierItem({required this.id, required this.name, this.phone});

  final int id;
  final String name;
  final String? phone;
}

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

class ProductSearchResult {
  const ProductSearchResult({
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

class SupplyProductInfo {
  const SupplyProductInfo({
    required this.ucode,
    required this.quantity,
    required this.price,
    this.productName,
    this.barcode,
    this.serialNumbers,
  });

  final int ucode;
  final String? productName;
  final Decimal quantity;
  final Decimal price;
  final String? barcode;

  final List<String>? serialNumbers;

  Decimal get amount => quantity * price;

  SupplyProductInfo copyWith({
    int? ucode,
    String? productName,
    Decimal? quantity,
    Decimal? price,
    String? barcode,
    List<String>? serialNumbers,
  }) {
    return SupplyProductInfo(
      ucode: ucode ?? this.ucode,
      productName: productName ?? this.productName,
      quantity: quantity ?? this.quantity,
      price: price ?? this.price,
      barcode: barcode ?? this.barcode,
      serialNumbers: serialNumbers ?? this.serialNumbers,
    );
  }
}

class SupplyState {
  const SupplyState({
    this.supplierId,
    this.supplierName,
    this.paymentType = SupplyPaymentType.fullSupply,
    this.accountId,
    this.accountName,
    this.products = const [],
    this.comment = '',
    this.isLoading = false,
    this.isSaving = false,
    this.error,
  });

  final int? supplierId;

  final String? supplierName;

  final SupplyPaymentType paymentType;

  final int? accountId;

  final String? accountName;

  final List<SupplyProductInfo> products;

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
      supplierId != null &&
      products.isNotEmpty &&
      !isLoading &&
      !isSaving &&
      (paymentType == SupplyPaymentType.consignment || accountId != null);

  bool get hasError => error != null;

  SupplyState copyWith({
    int? supplierId,
    String? supplierName,
    SupplyPaymentType? paymentType,
    int? accountId,
    String? accountName,
    List<SupplyProductInfo>? products,
    String? comment,
    bool? isLoading,
    bool? isSaving,
    String? error,
    bool clearSupplier = false,
    bool clearAccount = false,
    bool clearError = false,
  }) {
    return SupplyState(
      supplierId: clearSupplier ? null : (supplierId ?? this.supplierId),
      supplierName: clearSupplier ? null : (supplierName ?? this.supplierName),
      paymentType: paymentType ?? this.paymentType,
      accountId: clearAccount ? null : (accountId ?? this.accountId),
      accountName: clearAccount ? null : (accountName ?? this.accountName),
      products: products ?? this.products,
      comment: comment ?? this.comment,
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

typedef SupplyNotifier = SupplyController;

class SupplyController extends Notifier<SupplyState> {
  Talker get _logger => GetIt.I<Talker>();
  AppDatabase get _db => GetIt.I<AppDatabase>();

  @override
  SupplyState build() {
    return const SupplyState();
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

  Future<ProductSearchResult?> findProductByBarcode(String barcode) async {
    try {
      final product = await _db.productInfoDao.findByBarcode(barcode);
      if (product != null) {
        final price = await _getProductPrice(product.ucode);
        return ProductSearchResult(
          ucode: product.ucode,
          name: product.name,
          price: price,
          barcode: product.barcode.toString(),
        );
      }

      final ucode = int.tryParse(barcode);
      if (ucode != null) {
        final byUcode = await _db.productInfoDao.findByUcode(ucode);
        if (byUcode != null) {
          final price = await _getProductPrice(byUcode.ucode);
          return ProductSearchResult(
            ucode: byUcode.ucode,
            name: byUcode.name,
            price: price,
            barcode: byUcode.barcode.toString(),
          );
        }
      }

      final refResult = await GetIt.I<FindByBarcodeUseCase>().find(
        barcode.trim(),
      );
      if (refResult != null) {
        return ProductSearchResult(
          ucode: refResult.ucode,
          name: refResult.name,
          price: refResult.price,
          barcode: refResult.barcode.toString(),
        );
      }

      return null;
    } catch (e) {
      _logger.error('Failed to find product by barcode: $e');
      return null;
    }
  }

  Future<Decimal> _getProductPrice(int ucode) async {
    try {
      final priceRow = await _db.productPriceDao.findByUcode(ucode);
      return priceRow?.sellingPrice ?? Decimal.zero;
    } catch (e) {
      _logger.warning('Failed to get product price: $e');
      return Decimal.zero;
    }
  }

  Future<bool> isSerialTrackingEnabled() async {
    try {
      if (!GetIt.I.isRegistered<WmsConfigUseCase>()) return false;
      return await GetIt.I<WmsConfigUseCase>().isModuleEnabled(
        'serialTracking',
      );
    } catch (e) {
      _logger.warning('Failed to read serialTracking flag: $e');
      return false;
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

      _logger.debug('Supplier selected: ${agent.name}');
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

      _logger.debug('Account selected: ${account.name}');
    } catch (e) {
      _logger.error('Failed to select account: $e');
      state = state.copyWith(
        isLoading: false,
        error: 'error.load_failed:${safeErrorText(e)}',
      );
    }
  }

  void setPaymentType(SupplyPaymentType type) {
    state = state.copyWith(paymentType: type, clearError: true);
    _logger.debug('Payment type set: $type');
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
    List<String>? serialNumbers,
  }) async {
    state = state.copyWith(clearError: true);

    try {
      final productInfo = await _db.productInfoDao.findByUcode(ucode);

      if (productInfo != null && productInfo.isDeleted) {
        await _db.productInfoDao.restoreProduct(productInfo.ucode);
      }

      final existingIndex = state.products.indexWhere((p) => p.ucode == ucode);

      List<SupplyProductInfo> updatedProducts;

      if (existingIndex >= 0) {
        final existing = state.products[existingIndex];
        final newQuantity = existing.quantity + quantity;
        final updated = existing.copyWith(
          quantity: newQuantity,
          price: price,
          serialNumbers: _mergeSerials(existing.serialNumbers, serialNumbers),
        );
        updatedProducts = [...state.products];
        updatedProducts[existingIndex] = updated;
      } else {
        final newItem = SupplyProductInfo(
          ucode: ucode,
          productName: productInfo?.name,
          quantity: quantity,
          price: price,
          barcode: productInfo?.barcode.toString(),
          serialNumbers: _mergeSerials(null, serialNumbers),
        );
        updatedProducts = [...state.products, newItem];
      }

      state = state.copyWith(products: updatedProducts);

      _logger.debug('Product added: $ucode, qty: $quantity, price: $price');
    } catch (e) {
      _logger.error('Failed to add product: $e');
      state = state.copyWith(error: 'error.save_failed:${safeErrorText(e)}');
    }
  }

  void updateProduct({
    required int ucode,
    required Decimal quantity,
    required Decimal price,
    List<String>? serialNumbers,
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
      serialNumbers: serialNumbers,
    );

    state = state.copyWith(products: updatedProducts, clearError: true);

    _logger.debug('Product updated: $ucode, qty: $quantity, price: $price');
  }

  List<String>? _mergeSerials(List<String>? a, List<String>? b) {
    final seen = <String>{};
    final out = <String>[];
    for (final list in [a, b]) {
      if (list == null) continue;
      for (final s in list) {
        final t = s.trim();
        if (t.isEmpty) continue;
        if (seen.add(t)) out.add(t);
      }
    }
    return out.isEmpty ? null : out;
  }

  void removeProduct(int ucode) {
    final updatedProducts = state.products
        .where((p) => p.ucode != ucode)
        .toList();

    state = state.copyWith(products: updatedProducts, clearError: true);

    _logger.debug('Product removed: $ucode');
  }

  Future<SaveSupplyResult> save() async {
    if (!state.canSave) {
      return SaveSupplyResult.failed('error.validation');
    }

    state = state.copyWith(isSaving: true, clearError: true);

    try {
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final totalAmount = state.totalAmount ?? Decimal.zero;

      final supplyId = await _db.supplyDao.insertSupply(
        SuppliesCompanion(
          supplierId: Value(state.supplierId),
          accountId: Value(
            state.paymentType == SupplyPaymentType.fullSupply
                ? state.accountId
                : null,
          ),
          paymentType: Value(
            state.paymentType == SupplyPaymentType.consignment ? 1 : 0,
          ),
          amount: Value(totalAmount),
          consignmentAmount: Value(
            state.paymentType == SupplyPaymentType.consignment
                ? totalAmount
                : null,
          ),
          editTime: Value(now),
          comment: Value(state.comment.isNotEmpty ? state.comment : null),
          state: const Value(1),
        ),
      );

      for (final product in state.products) {
        await _db.supplyProductDao.insertProduct(
          SupplyProductsCompanion(
            supplyId: Value(supplyId),
            ucode: Value(product.ucode),
            quantity: Value(product.quantity),
            price: Value(product.price),
            amount: Value(product.amount),
            serialNumbers: Value(
              SupplyProductMapper.encodeSerialNumbers(product.serialNumbers),
            ),
          ),
        );
      }

      for (final product in state.products) {
        final current = await _db.productInfoDao.findByUcode(product.ucode);
        if (current != null) {
          final newQty = (current.quantity ?? Decimal.zero) + product.quantity;
          await _db.productInfoDao.updateQuantity(product.ucode, newQty);
        }
      }

      final markUpUseCase = GetIt.I<MarkUpUseCase>();
      for (final product in state.products) {
        try {
          final markUp = await markUpUseCase.getMarkUpForProduct(product.ucode);
          if (markUp != null && markUp > Decimal.zero) {
            final existing = await _db.productPriceDao.findByUcode(
              product.ucode,
            );
            final currentSelling = existing?.sellingPrice;
            final isRealCost =
                currentSelling == null || product.price < currentSelling;
            if (!isRealCost) {
              _logger.info(
                'Auto-markup skipped (анти-компаундинг): ucode=${product.ucode} '
                'закуп ${product.price} ≥ розница $currentSelling',
              );
              continue;
            }
            final newSelling = markUpUseCase.applyMarkUp(product.price, markUp);
            final wholesale = existing?.wholesalePrice ?? newSelling;
            await _db.productPriceDao.updatePrices(
              product.ucode,
              newSelling,
              wholesale,
            );
            _logger.info(
              'Auto-markup: ucode=${product.ucode} закуп ${product.price} '
              '× (1+$markUp%) → розница $newSelling',
            );
          }
        } catch (e) {
          _logger.error(
            'Auto-markup failed (non-blocking) '
            'for ucode=${product.ucode}: $e',
          );
        }
      }

      if (state.paymentType == SupplyPaymentType.fullSupply &&
          state.accountId != null) {
        final account = await _db.accountDao.findById(state.accountId!);
        if (account != null) {
          final currentBalance = account.value ?? Decimal.zero;
          final newBalance = currentBalance - totalAmount;
          await _db.accountDao.updateBalance(state.accountId!, newBalance);
          _logger.info(
            'Supply: account ${state.accountId} balance '
            '$currentBalance → $newBalance (-$totalAmount)',
          );
        }
      }

      _logger.info(
        'Supply saved: id=$supplyId, ${state.productCount} products, '
        'total: $totalAmount',
      );

      state = state.copyWith(isSaving: false);

      ref.invalidate(shiftControllerProvider);
      ref.invalidate(catalogControllerProvider);
      ref.invalidate(stockRegistryControllerProvider);
      ref.invalidate(inventoryControllerProvider);

      return SaveSupplyResult.saved(
        supplyId: supplyId,
        totalAmount: totalAmount,
        productCount: state.productCount,
      );
    } catch (e) {
      _logger.error('Failed to save supply: $e');
      state = state.copyWith(
        isSaving: false,
        error: 'error.save_failed:${safeErrorText(e)}',
      );
      return SaveSupplyResult.failed('error.save_failed:${safeErrorText(e)}');
    }
  }

  void cancel() {
    state = const SupplyState();
    _logger.debug('Supply cancelled and reset');
  }

  void reset() {
    state = const SupplyState();
    _logger.debug('Supply state reset');
  }
}

final supplyControllerProvider =
    NotifierProvider<SupplyController, SupplyState>(SupplyController.new);

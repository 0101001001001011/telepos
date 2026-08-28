import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/domain/usecases/supply/supply_product_use_case.dart';

class SupplyProductUseCaseImpl implements SupplyProductUseCase {
  SupplyProductUseCaseImpl(this._db);

  final AppDatabase _db;

  @override
  Future<SupplyProductResult> addProduct({
    required int supplyId,
    required int ucode,
    required Decimal quantity,
    required Decimal price,
  }) async {
    try {
      if (quantity <= Decimal.zero) {
        return SupplyProductResult.failed('Количество должно быть больше 0');
      }
      if (price < Decimal.zero) {
        return SupplyProductResult.failed('Цена не может быть отрицательной');
      }

      final existing = await _db.supplyProductDao.findBySupplyIdAndUcode(
        supplyId,
        ucode,
      );

      final amount = quantity * price;

      if (existing != null) {
        final newQuantity = existing.quantity + quantity;
        final newAmount = newQuantity * price;

        await _db.supplyProductDao.updateProduct(
          existing.id,
          SupplyProductsCompanion(
            quantity: Value(newQuantity),
            price: Value(price),
            amount: Value(newAmount),
          ),
        );

        await _updateSupplyAmount(supplyId);

        return SupplyProductResult.updated(existing.id, newAmount);
      } else {
        final productId = await _db.supplyProductDao.insertProduct(
          SupplyProductsCompanion.insert(
            supplyId: supplyId,
            ucode: ucode,
            quantity: quantity,
            price: price,
            amount: amount,
          ),
        );

        await _updateSupplyAmount(supplyId);

        return SupplyProductResult.added(productId, amount);
      }
    } catch (e) {
      return SupplyProductResult.failed('Ошибка добавления товара: $e');
    }
  }

  @override
  Future<SupplyProductResult> removeProduct({
    required int supplyId,
    required int ucode,
  }) async {
    try {
      final existing = await _db.supplyProductDao.findBySupplyIdAndUcode(
        supplyId,
        ucode,
      );

      if (existing == null) {
        return SupplyProductResult.failed('Товар не найден в приёмке');
      }

      await _db.supplyProductDao.deleteProduct(existing.id);

      await _updateSupplyAmount(supplyId);

      return SupplyProductResult.removed();
    } catch (e) {
      return SupplyProductResult.failed('Ошибка удаления товара: $e');
    }
  }

  @override
  Future<SupplyProductResult> updateProduct({
    required int supplyId,
    required int ucode,
    required Decimal quantity,
    required Decimal price,
  }) async {
    try {
      if (quantity <= Decimal.zero) {
        return SupplyProductResult.failed('Количество должно быть больше 0');
      }
      if (price < Decimal.zero) {
        return SupplyProductResult.failed('Цена не может быть отрицательной');
      }

      final existing = await _db.supplyProductDao.findBySupplyIdAndUcode(
        supplyId,
        ucode,
      );

      if (existing == null) {
        return SupplyProductResult.failed('Товар не найден в приёмке');
      }

      final amount = quantity * price;

      await _db.supplyProductDao.updateProduct(
        existing.id,
        SupplyProductsCompanion(
          quantity: Value(quantity),
          price: Value(price),
          amount: Value(amount),
        ),
      );

      await _updateSupplyAmount(supplyId);

      return SupplyProductResult.updated(existing.id, amount);
    } catch (e) {
      return SupplyProductResult.failed('Ошибка обновления товара: $e');
    }
  }

  @override
  Future<List<SupplyProductInfo>> getProducts(int supplyId) async {
    final products = await _db.supplyProductDao.findBySupplyId(supplyId);

    final result = <SupplyProductInfo>[];
    for (final p in products) {
      final productInfo = await _db.productInfoDao.findByUcode(p.ucode);
      final productPrice = await _db.productPriceDao.findByUcode(p.ucode);

      result.add(
        SupplyProductInfo(
          id: p.id,
          supplyId: p.supplyId,
          ucode: p.ucode,
          quantity: p.quantity,
          price: p.price,
          amount: p.amount,
          productName: productInfo?.name,
          barcode: productPrice?.barcode.toString(),
        ),
      );
    }

    return result;
  }

  @override
  Future<Decimal> getTotalAmount(int supplyId) async {
    final products = await _db.supplyProductDao.findBySupplyId(supplyId);
    return products.fold<Decimal>(Decimal.zero, (sum, p) => sum + (p.amount));
  }

  Future<void> _updateSupplyAmount(int supplyId) async {
    final totalAmount = await getTotalAmount(supplyId);

    await _db.supplyDao.updateSupply(
      supplyId,
      SuppliesCompanion(amount: Value(totalAmount)),
    );
  }
}

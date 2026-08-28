import 'package:decimal/decimal.dart';

abstract class SupplyProductUseCase {
  Future<SupplyProductResult> addProduct({
    required int supplyId,
    required int ucode,
    required Decimal quantity,
    required Decimal price,
  });

  Future<SupplyProductResult> removeProduct({
    required int supplyId,
    required int ucode,
  });

  Future<SupplyProductResult> updateProduct({
    required int supplyId,
    required int ucode,
    required Decimal quantity,
    required Decimal price,
  });

  Future<List<SupplyProductInfo>> getProducts(int supplyId);

  Future<Decimal> getTotalAmount(int supplyId);
}

class SupplyProductResult {
  const SupplyProductResult({
    required this.success,
    this.productId,
    this.newAmount,
    this.errorMessage,
  });

  final bool success;
  final int? productId;
  final Decimal? newAmount;
  final String? errorMessage;

  factory SupplyProductResult.added(int id, Decimal amount) =>
      SupplyProductResult(success: true, productId: id, newAmount: amount);

  factory SupplyProductResult.updated(int id, Decimal amount) =>
      SupplyProductResult(success: true, productId: id, newAmount: amount);

  factory SupplyProductResult.removed() =>
      const SupplyProductResult(success: true);

  factory SupplyProductResult.failed(String message) =>
      SupplyProductResult(success: false, errorMessage: message);
}

class SupplyProductInfo {
  const SupplyProductInfo({
    required this.id,
    required this.supplyId,
    required this.ucode,
    required this.quantity,
    required this.price,
    required this.amount,
    this.productName,
    this.barcode,
  });

  final int id;
  final int supplyId;
  final int ucode;
  final Decimal quantity;
  final Decimal price;
  final Decimal amount;
  final String? productName;
  final String? barcode;
}

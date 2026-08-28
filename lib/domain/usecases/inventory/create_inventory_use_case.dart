import 'package:decimal/decimal.dart';

class InventoryProductEntry {
  const InventoryProductEntry({
    required this.ucode,
    required this.expectedQty,
    required this.actualQty,
    required this.price,
    this.productName,
  });

  final int ucode;
  final Decimal expectedQty;
  final Decimal actualQty;
  final Decimal price;
  final String? productName;

  Decimal get difference => actualQty - expectedQty;
  bool get hasDiscrepancy => difference != Decimal.zero;
}

class CreateInventoryResult {
  const CreateInventoryResult._({
    this.inventoryId,
    this.productCount = 0,
    this.discrepancyCount = 0,
    this.success = false,
    this.errorMessage,
  });

  factory CreateInventoryResult.saved({
    required int inventoryId,
    required int productCount,
    required int discrepancyCount,
  }) => CreateInventoryResult._(
    inventoryId: inventoryId,
    productCount: productCount,
    discrepancyCount: discrepancyCount,
    success: true,
  );

  factory CreateInventoryResult.failed(String message) =>
      CreateInventoryResult._(errorMessage: message);

  final int? inventoryId;
  final int productCount;
  final int discrepancyCount;
  final bool success;
  final String? errorMessage;
}

abstract class CreateInventoryUseCase {
  Future<int> create({String? comment, int? userId, bool isFullCount = false});

  Future<void> upsertProduct({
    required int inventoryId,
    required int ucode,
    required Decimal expectedQty,
    required Decimal actualQty,
    required Decimal price,
  });

  Future<CreateInventoryResult> complete(int inventoryId);
}

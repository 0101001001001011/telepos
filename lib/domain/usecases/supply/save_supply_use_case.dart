import 'package:decimal/decimal.dart';
import 'package:telepos/domain/usecases/supply/create_supply_use_case.dart';

abstract class SaveSupplyUseCase {
  Future<SaveSupplyResult> execute(int supplyId);

  Future<void> updateSupply({
    required int supplyId,
    int? supplierId,
    SupplyPaymentType? paymentType,
    int? accountId,
    String? comment,
  });
}

class SaveSupplyResult {
  const SaveSupplyResult({
    required this.success,
    this.supplyId,
    this.totalAmount,
    this.productCount,
    this.errorMessage,
  });

  final bool success;
  final int? supplyId;
  final Decimal? totalAmount;
  final int? productCount;
  final String? errorMessage;

  factory SaveSupplyResult.saved({
    required int supplyId,
    required Decimal totalAmount,
    required int productCount,
  }) => SaveSupplyResult(
    success: true,
    supplyId: supplyId,
    totalAmount: totalAmount,
    productCount: productCount,
  );

  factory SaveSupplyResult.failed(String message) =>
      SaveSupplyResult(success: false, errorMessage: message);
}

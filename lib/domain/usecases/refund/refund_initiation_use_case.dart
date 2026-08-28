abstract class RefundInitiationUseCase {
  Future<dynamic> getInProgress();

  Future<dynamic> initiate({
    int? saleReceiptNo,
    int? salePosId,
    int? saleId,
    int? saleWeightRoundType,
    int? saleDiscountsRoundType,
    int? customerLocalId,
    int? customerServerId,
  });
}

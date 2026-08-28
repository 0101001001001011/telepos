abstract class CanSaleBeRefundedUseCase {
  Future<bool> canBeRefunded({required int receiptNo, required int posId});
}

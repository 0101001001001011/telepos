import 'package:decimal/decimal.dart';

abstract class PurchaseWithCashUseCase {
  Future<int> execute({
    required int receiptNo,
    required int posId,
    required Decimal amount,
  });

  Future<int> executeForRefund({
    required int refundLocalId,
    required Decimal amount,
  });
}

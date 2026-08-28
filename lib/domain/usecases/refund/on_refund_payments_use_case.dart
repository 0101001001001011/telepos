import 'package:decimal/decimal.dart';

abstract class OnRefundPaymentsUseCase {
  Future<List<RefundPaymentEntry>> create({
    required int refundLocalId,
    required Decimal refundAmount,
    required int userId,
    int? saleReceiptNo,
    int? salePosId,
  });
}

class RefundPaymentEntry {
  const RefundPaymentEntry({
    required this.payeeAccountId,
    required this.amount,
  });

  final int payeeAccountId;

  final Decimal amount;
}

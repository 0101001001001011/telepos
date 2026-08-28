import 'package:decimal/decimal.dart';

abstract class RefundReceiptUseCase {
  Future<RefundReceipt> wrap({required int refundLocalId});
}

class RefundReceipt {
  const RefundReceipt({
    required this.localId,
    required this.amount,
    required this.time,
    required this.userId,
    this.saleReceiptNo,
    this.salePosId,
    this.saleId,
    this.customerLocalId,
    this.customerServerId,
    this.cashbackAmount,
    this.isOfd = false,
    this.state,
    this.withdrawalAmount,
  });

  final int localId;
  final Decimal amount;
  final int time;
  final int userId;
  final int? saleReceiptNo;
  final int? salePosId;
  final int? saleId;
  final int? customerLocalId;
  final int? customerServerId;
  final Decimal? cashbackAmount;
  final bool isOfd;
  final int? state;

  final Decimal? withdrawalAmount;
}

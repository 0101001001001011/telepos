import 'package:decimal/decimal.dart';

class PaymentEntity {
  const PaymentEntity({
    this.id,
    required this.userId,
    this.receiptNo,
    this.posId,
    this.refundLocalId,
    this.customerLocalId,
    required this.payeeAccountId,
    required this.amount,
    required this.time,
    this.state,
  });

  final int? id;

  final int userId;

  final int? receiptNo;

  final int? posId;

  final int? refundLocalId;

  final int? customerLocalId;

  final int payeeAccountId;

  final Decimal amount;

  final int time;

  final int? state;

  bool get isForSale => receiptNo != null && posId != null;

  bool get isForRefund => refundLocalId != null;

  PaymentEntity copyWith({
    int? id,
    int? userId,
    int? receiptNo,
    int? posId,
    int? refundLocalId,
    bool clearRefundLocalId = false,
    int? customerLocalId,
    int? payeeAccountId,
    Decimal? amount,
    int? time,
    int? state,
  }) {
    return PaymentEntity(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      receiptNo: receiptNo ?? this.receiptNo,
      posId: posId ?? this.posId,
      refundLocalId: clearRefundLocalId
          ? null
          : (refundLocalId ?? this.refundLocalId),
      customerLocalId: customerLocalId ?? this.customerLocalId,
      payeeAccountId: payeeAccountId ?? this.payeeAccountId,
      amount: amount ?? this.amount,
      time: time ?? this.time,
      state: state ?? this.state,
    );
  }
}

import 'package:decimal/decimal.dart';

class SupplyEntity {
  const SupplyEntity({
    this.id,
    this.operationType,
    this.userId,
    this.supplierId,
    this.editTime,
    this.amount,
    this.paymentType,
    this.accountId,
    this.comment,
    this.payment,
    this.consignmentAmount,
    this.paidAmount,
    this.state,
    this.status,
    this.msg,
  });

  final int? id;

  final int? operationType;

  final int? userId;

  final int? supplierId;

  final int? editTime;

  final Decimal? amount;

  final int? paymentType;

  final int? accountId;

  final String? comment;

  final Decimal? payment;

  final Decimal? consignmentAmount;

  final Decimal? paidAmount;

  final int? state;

  final int? status;

  final String? msg;

  bool get isFullSupply => paymentType == 0;

  bool get isConsignment => paymentType == 1;

  SupplyEntity copyWith({
    int? id,
    int? operationType,
    int? userId,
    int? supplierId,
    int? editTime,
    Decimal? amount,
    int? paymentType,
    int? accountId,
    String? comment,
    Decimal? payment,
    Decimal? consignmentAmount,
    Decimal? paidAmount,
    int? state,
    int? status,
    String? msg,
  }) {
    return SupplyEntity(
      id: id ?? this.id,
      operationType: operationType ?? this.operationType,
      userId: userId ?? this.userId,
      supplierId: supplierId ?? this.supplierId,
      editTime: editTime ?? this.editTime,
      amount: amount ?? this.amount,
      paymentType: paymentType ?? this.paymentType,
      accountId: accountId ?? this.accountId,
      comment: comment ?? this.comment,
      payment: payment ?? this.payment,
      consignmentAmount: consignmentAmount ?? this.consignmentAmount,
      paidAmount: paidAmount ?? this.paidAmount,
      state: state ?? this.state,
      status: status ?? this.status,
      msg: msg ?? this.msg,
    );
  }
}

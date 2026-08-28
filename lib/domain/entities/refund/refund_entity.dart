import 'package:decimal/decimal.dart';

class RefundEntity {
  const RefundEntity({
    this.localId,
    this.serverId,
    this.saleId,
    this.saleReceiptNo,
    this.salePosId,
    required this.userId,
    required this.amount,
    this.cashbackAmount,
    required this.time,
    this.state,
    this.customerLocalId,
    this.customerServerId,
    this.weightProductRoundType,
    this.discountsRoundType,
    this.isOfd = false,
  });

  final int? localId;

  final int? serverId;

  final int? saleId;

  final int? saleReceiptNo;

  final int? salePosId;

  final int userId;

  final Decimal amount;

  final Decimal? cashbackAmount;

  final int time;

  final int? state;

  final int? customerLocalId;

  final int? customerServerId;

  final int? weightProductRoundType;

  final int? discountsRoundType;

  final bool isOfd;

  bool get hasSaleReference => saleReceiptNo != null && salePosId != null;

  bool get isInProgress => state == 0;

  bool get isSynced => state == 3;

  RefundEntity copyWith({
    int? localId,
    int? serverId,
    int? saleId,
    int? saleReceiptNo,
    int? salePosId,
    int? userId,
    Decimal? amount,
    Decimal? cashbackAmount,
    bool clearCashbackAmount = false,
    int? time,
    int? state,
    int? customerLocalId,
    int? customerServerId,
    int? weightProductRoundType,
    int? discountsRoundType,
    bool? isOfd,
  }) {
    return RefundEntity(
      localId: localId ?? this.localId,
      serverId: serverId ?? this.serverId,
      saleId: saleId ?? this.saleId,
      saleReceiptNo: saleReceiptNo ?? this.saleReceiptNo,
      salePosId: salePosId ?? this.salePosId,
      userId: userId ?? this.userId,
      amount: amount ?? this.amount,
      cashbackAmount: clearCashbackAmount
          ? null
          : (cashbackAmount ?? this.cashbackAmount),
      time: time ?? this.time,
      state: state ?? this.state,
      customerLocalId: customerLocalId ?? this.customerLocalId,
      customerServerId: customerServerId ?? this.customerServerId,
      weightProductRoundType:
          weightProductRoundType ?? this.weightProductRoundType,
      discountsRoundType: discountsRoundType ?? this.discountsRoundType,
      isOfd: isOfd ?? this.isOfd,
    );
  }
}

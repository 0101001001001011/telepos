import 'package:decimal/decimal.dart';

class SaleEntity {
  const SaleEntity({
    required this.receiptNo,
    required this.posId,
    this.saleId,
    required this.userId,
    required this.amount,
    this.change,
    required this.time,
    this.storeId,
    this.customerLocalId,
    this.customerServerId,
    this.loyalCustomerPhone,
    this.isOfd = false,
    this.state,
    this.isWholesale = false,
    this.weightProductRoundType,
    this.discountsRoundType,
    this.customerBin,
    this.orderType,
    this.serviceCharge,
  });

  final int receiptNo;

  final int posId;

  final int? saleId;

  final int userId;

  final Decimal amount;

  final Decimal? change;

  final int time;

  final int? storeId;

  final int? customerLocalId;

  final int? customerServerId;

  final int? loyalCustomerPhone;

  final bool isOfd;

  final int? state;

  final bool isWholesale;

  final int? weightProductRoundType;

  final int? discountsRoundType;

  final String? customerBin;

  final int? orderType;

  final Decimal? serviceCharge;

  bool get isInProgress => state == 0;

  bool get isDeferred => state == 3;

  bool get isSynced => state == 4;

  bool get hasCustomer => customerLocalId != null;

  SaleEntity copyWith({
    int? receiptNo,
    int? posId,
    int? saleId,
    int? userId,
    Decimal? amount,
    Decimal? change,
    bool clearChange = false,
    int? time,
    int? storeId,
    int? customerLocalId,
    bool clearCustomerLocalId = false,
    int? customerServerId,
    int? loyalCustomerPhone,
    bool? isOfd,
    int? state,
    bool? isWholesale,
    int? weightProductRoundType,
    int? discountsRoundType,
    String? customerBin,
    int? orderType,
    Decimal? serviceCharge,
  }) {
    return SaleEntity(
      receiptNo: receiptNo ?? this.receiptNo,
      posId: posId ?? this.posId,
      saleId: saleId ?? this.saleId,
      userId: userId ?? this.userId,
      amount: amount ?? this.amount,
      change: clearChange ? null : (change ?? this.change),
      time: time ?? this.time,
      storeId: storeId ?? this.storeId,
      customerLocalId: clearCustomerLocalId
          ? null
          : (customerLocalId ?? this.customerLocalId),
      customerServerId: customerServerId ?? this.customerServerId,
      loyalCustomerPhone: loyalCustomerPhone ?? this.loyalCustomerPhone,
      isOfd: isOfd ?? this.isOfd,
      state: state ?? this.state,
      isWholesale: isWholesale ?? this.isWholesale,
      weightProductRoundType:
          weightProductRoundType ?? this.weightProductRoundType,
      discountsRoundType: discountsRoundType ?? this.discountsRoundType,
      customerBin: customerBin ?? this.customerBin,
      orderType: orderType ?? this.orderType,
      serviceCharge: serviceCharge ?? this.serviceCharge,
    );
  }
}

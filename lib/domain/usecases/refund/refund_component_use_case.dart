import 'package:decimal/decimal.dart';

abstract class RefundComponentUseCase {
  Future<RefundComponent> get({required int refundLocalId});
}

class RefundComponent {
  const RefundComponent({
    required this.refundLocalId,
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
    required this.products,
    required this.universalProducts,
    required this.payments,
  });

  final int refundLocalId;
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

  final List<RefundComponentProduct> products;

  final List<RefundComponentUniversal> universalProducts;

  final List<RefundComponentPayment> payments;
}

class RefundComponentProduct {
  const RefundComponentProduct({
    required this.id,
    required this.ucode,
    required this.quantity,
    required this.price,
    this.inSalePrice,
    this.inSaleQuantity,
    this.inSalePriceBefore,
    this.marks = const [],
  });

  final int id;
  final int ucode;
  final Decimal quantity;
  final Decimal price;
  final Decimal? inSalePrice;
  final Decimal? inSaleQuantity;
  final Decimal? inSalePriceBefore;
  final List<String> marks;
}

class RefundComponentUniversal {
  const RefundComponentUniversal({
    required this.id,
    required this.quantity,
    required this.price,
    this.priceBefore,
    this.inSalePrice,
    this.inSaleQuantity,
  });

  final int id;
  final Decimal quantity;
  final Decimal price;
  final Decimal? priceBefore;
  final Decimal? inSalePrice;
  final Decimal? inSaleQuantity;
}

class RefundComponentPayment {
  const RefundComponentPayment({
    required this.id,
    required this.payeeAccountId,
    required this.amount,
    required this.time,
  });

  final int id;
  final int payeeAccountId;
  final Decimal amount;
  final int time;
}

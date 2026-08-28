import 'package:decimal/decimal.dart';

abstract class RefundUseCase {
  Future<RefundResult> perform({
    required int refundLocalId,
    required Decimal amount,
    Decimal? cashbackAmount,
    required int userId,
    int? saleReceiptNo,
    int? salePosId,
    int? customerLocalId,
    int? customerServerId,
    required List<RefundProductEntry> products,
  });
}

class RefundProductEntry {
  const RefundProductEntry({
    required this.ucode,
    required this.quantity,
    required this.price,
    this.inSalePrice,
    this.inSaleQuantity,
    this.inSalePriceBefore,
  });

  final int ucode;

  final Decimal quantity;

  final Decimal price;

  final Decimal? inSalePrice;

  final Decimal? inSaleQuantity;

  final Decimal? inSalePriceBefore;
}

class RefundResult {
  const RefundResult({
    required this.refundLocalId,
    required this.amount,
    required this.productCount,
    required this.paymentCount,
  });

  final int refundLocalId;

  final Decimal amount;

  final int productCount;

  final int paymentCount;
}

class InvalidRefundException implements Exception {
  const InvalidRefundException(this.message);
  final String message;

  @override
  String toString() => 'InvalidRefundException: $message';
}

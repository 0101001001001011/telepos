import 'package:decimal/decimal.dart';

abstract class RefundProductService {
  Future<int> add({
    required int refundLocalId,
    required int ucode,
    required Decimal quantity,
    required Decimal price,
    Decimal? inSalePrice,
    Decimal? inSaleQuantity,
    Decimal? inSalePriceBefore,
    List<String> marks = const [],
  });

  Future<int> addUniversalProduct({
    required int refundLocalId,
    required Decimal quantity,
    required Decimal price,
    Decimal? priceBefore,
    Decimal? inSalePrice,
    Decimal? inSaleQuantity,
  });

  Future<List<RefundProductItem>> getFromRefundProducts({
    required int refundLocalId,
  });

  Future<List<RefundUniversalProductItem>> getUniversalProducts({
    required int refundLocalId,
  });

  Future<void> remove({required int refundProductId});

  Future<void> removeUniversal({required int universalProductId});

  Future<void> updateQuantity({
    required int refundProductId,
    required Decimal quantity,
  });
}

class RefundProductItem {
  const RefundProductItem({
    required this.id,
    required this.refundLocalId,
    required this.ucode,
    required this.quantity,
    required this.price,
    this.inSalePrice,
    this.inSaleQuantity,
    this.inSalePriceBefore,
    this.marks = const [],
  });

  final int id;
  final int refundLocalId;
  final int ucode;
  final Decimal quantity;
  final Decimal price;
  final Decimal? inSalePrice;
  final Decimal? inSaleQuantity;
  final Decimal? inSalePriceBefore;
  final List<String> marks;

  Decimal get total => price * quantity;
}

class RefundUniversalProductItem {
  const RefundUniversalProductItem({
    required this.id,
    required this.receiptNo,
    required this.posId,
    required this.refundLocalId,
    required this.quantity,
    required this.price,
    this.priceBefore,
    this.inSalePrice,
    this.inSaleQuantity,
  });

  final int id;
  final int receiptNo;
  final int posId;
  final int refundLocalId;
  final Decimal quantity;
  final Decimal price;
  final Decimal? priceBefore;
  final Decimal? inSalePrice;
  final Decimal? inSaleQuantity;

  Decimal get total => price * quantity;
}

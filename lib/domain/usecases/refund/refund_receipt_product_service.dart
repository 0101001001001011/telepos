import 'package:decimal/decimal.dart';

abstract class RefundReceiptProductService {
  Future<List<RefundReceiptProduct>> getProducts({required int refundLocalId});

  Future<List<RefundReceiptProduct>> getProductsFromSale({
    required int saleReceiptNo,
    required int salePosId,
  });

  Future<RefundReceiptProduct> wrap({required int refundProductId});
}

class RefundReceiptProduct {
  const RefundReceiptProduct({
    required this.id,
    required this.ucode,
    required this.quantity,
    required this.price,
    this.inSalePrice,
    this.inSaleQuantity,
    this.inSalePriceBefore,
    this.marks = const [],
    this.name,
    this.measure,
    this.barcode,
  });

  final int id;
  final int ucode;
  final Decimal quantity;
  final Decimal price;
  final Decimal? inSalePrice;
  final Decimal? inSaleQuantity;
  final Decimal? inSalePriceBefore;
  final List<String> marks;

  final String? name;
  final int? measure;
  final int? barcode;

  Decimal get total => price * quantity;
}

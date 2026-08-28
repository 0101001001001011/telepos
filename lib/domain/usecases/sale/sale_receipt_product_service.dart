import 'package:decimal/decimal.dart';

abstract class SaleReceiptProductService {
  Future<List<ReceiptProductData>> getSaleProducts({
    required int receiptNo,
    required int posId,
    required bool isWholesale,
    required int weightProductRoundType,
    required int discountsRoundType,
    required bool isSaleComplete,
  });

  Future<Decimal?> getMarkUpForCategory(int? categoryId);
}

class ReceiptProductData {
  const ReceiptProductData({
    required this.id,
    required this.ucode,
    required this.productName,
    required this.measure,
    required this.quantity,
    required this.price,
    required this.priceBefore,
    required this.sellingPrice,
    required this.wholesalePrice,
    required this.isWholesale,
    required this.isUniversal,
    required this.isSaleComplete,
    required this.weightProductRoundType,
    required this.discountsRoundType,
    this.barcode,
    this.categoryId,
    this.markUp,
    this.marks = const [],
  });

  final int id;

  final int ucode;

  final String productName;

  final int measure;

  final Decimal quantity;

  final Decimal price;

  final Decimal priceBefore;

  final Decimal sellingPrice;

  final Decimal wholesalePrice;

  final bool isWholesale;

  final bool isUniversal;

  final bool isSaleComplete;

  final int weightProductRoundType;

  final int discountsRoundType;

  final int? barcode;

  final int? categoryId;

  final Decimal? markUp;

  final List<String> marks;

  bool get isWeight => measure != 0;
}

import 'package:decimal/decimal.dart';

class SaleProductEntity {
  const SaleProductEntity({
    this.id,
    this.receiptNo,
    this.posId,
    this.saleId,
    required this.ucode,
    this.barcode,
    this.categoryId,
    required this.quantity,
    required this.price,
    required this.priceBefore,
  });

  final int? id;

  final int? receiptNo;

  final int? posId;

  final int? saleId;

  final int ucode;

  final int? barcode;

  final int? categoryId;

  final Decimal quantity;

  final Decimal price;

  final Decimal priceBefore;

  Decimal get total => quantity * price;

  bool get hasDiscount => price < priceBefore;

  Decimal get discountAmount =>
      hasDiscount ? (priceBefore - price) * quantity : Decimal.zero;

  SaleProductEntity copyWith({
    int? id,
    int? receiptNo,
    int? posId,
    int? saleId,
    int? ucode,
    int? barcode,
    int? categoryId,
    Decimal? quantity,
    Decimal? price,
    Decimal? priceBefore,
  }) {
    return SaleProductEntity(
      id: id ?? this.id,
      receiptNo: receiptNo ?? this.receiptNo,
      posId: posId ?? this.posId,
      saleId: saleId ?? this.saleId,
      ucode: ucode ?? this.ucode,
      barcode: barcode ?? this.barcode,
      categoryId: categoryId ?? this.categoryId,
      quantity: quantity ?? this.quantity,
      price: price ?? this.price,
      priceBefore: priceBefore ?? this.priceBefore,
    );
  }
}

import 'package:decimal/decimal.dart';

class TableOrderItem {
  const TableOrderItem({
    required this.productId,
    required this.name,
    required this.quantity,
    required this.price,
    this.saleProductId,
    this.guestNumber = 0,
    this.barcode,
  });

  final int productId;
  final String name;
  final Decimal quantity;
  final Decimal price;

  final int? saleProductId;

  final int guestNumber;

  final String? barcode;

  Decimal get lineTotal => quantity * price;

  TableOrderItem copyWith({
    int? productId,
    String? name,
    Decimal? quantity,
    Decimal? price,
    int? saleProductId,
    int? guestNumber,
    String? barcode,
  }) {
    return TableOrderItem(
      productId: productId ?? this.productId,
      name: name ?? this.name,
      quantity: quantity ?? this.quantity,
      price: price ?? this.price,
      saleProductId: saleProductId ?? this.saleProductId,
      guestNumber: guestNumber ?? this.guestNumber,
      barcode: barcode ?? this.barcode,
    );
  }
}

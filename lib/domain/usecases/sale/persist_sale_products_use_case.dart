import 'package:decimal/decimal.dart';

abstract class PersistSaleProductsUseCase {
  Future<void> persist({
    required int receiptNo,
    required int posId,
    required List<SaleProductEntry> products,
  });
}

class SaleProductEntry {
  const SaleProductEntry({
    required this.ucode,
    this.barcode,
    this.categoryId,
    required this.quantity,
    required this.price,
    required this.priceBefore,
  });

  final int ucode;

  final int? barcode;

  final int? categoryId;

  final Decimal quantity;

  final Decimal price;

  final Decimal priceBefore;
}

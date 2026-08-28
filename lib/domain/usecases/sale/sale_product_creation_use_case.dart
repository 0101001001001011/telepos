import 'package:decimal/decimal.dart';

abstract class SaleProductCreationUseCase {
  Future<void> create({
    required int receiptNo,
    required int posId,
    required bool isWholesale,
    required int ucode,
    int? barcode,
    int? categoryId,
    required Decimal sellingPrice,
    Decimal? wholesalePrice,
    Decimal? weight,
  });
}

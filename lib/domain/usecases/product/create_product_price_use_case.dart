import 'package:decimal/decimal.dart';

abstract class CreateProductPriceUseCase {
  Future<int> create({
    required int ucode,
    required int barcode,
    required Decimal sellingPrice,
    Decimal? wholesalePrice,
  });

  Future<void> update({
    required int ucode,
    Decimal? sellingPrice,
    Decimal? wholesalePrice,
  });
}

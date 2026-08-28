import 'package:decimal/decimal.dart';
import 'package:telepos/domain/usecases/product/find_product_by_code_use_case.dart';

abstract class CreateProductInfoAndPriceUseCase {
  Future<ProductWithPrice> create({
    int? barcode,
    required String name,
    required Decimal price,
    required int type,
    required int measure,
    int? categoryId,
    Decimal? minPrice,
  });

  Future<ProductWithPrice> createFromGlobal({
    required int globalProductId,
    required Decimal price,
    Decimal? minPrice,
  });
}

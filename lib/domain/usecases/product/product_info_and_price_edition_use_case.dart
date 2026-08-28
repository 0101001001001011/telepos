import 'package:decimal/decimal.dart';

abstract class ProductInfoAndPriceEditionUseCase {
  Future<void> edit({
    required int ucode,
    required int userId,
    String? name,
    Decimal? price,
    Decimal? minPrice,
    int? categoryId,
    int? type,
    int? measure,
    int? vatRate,
    bool vatRateSet = false,
    String? ntin,
    bool? isMarkable,
    String? brand,
    String? manufacturer,
    String? countryOfOrigin,
  });

  Future<void> createEdition(int ucode, {required int userId});
}

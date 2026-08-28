import 'package:decimal/decimal.dart';
import 'package:talker/talker.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/domain/usecases/product/create_product_info_and_price_use_case.dart';
import 'package:telepos/domain/usecases/product/create_product_info_use_case.dart';
import 'package:telepos/domain/usecases/product/create_product_price_use_case.dart';
import 'package:telepos/domain/usecases/product/find_product_by_code_use_case.dart';

class CreateProductInfoAndPriceUseCaseImpl
    implements CreateProductInfoAndPriceUseCase {
  CreateProductInfoAndPriceUseCaseImpl({
    required AppDatabase db,
    required CreateProductInfoUseCase createProductInfoUseCase,
    required CreateProductPriceUseCase createProductPriceUseCase,
    required Talker logger,
  }) : _db = db,
       _createProductInfoUseCase = createProductInfoUseCase,
       _createProductPriceUseCase = createProductPriceUseCase,
       _logger = logger;

  final AppDatabase _db;
  final CreateProductInfoUseCase _createProductInfoUseCase;
  final CreateProductPriceUseCase _createProductPriceUseCase;
  final Talker _logger;

  @override
  Future<ProductWithPrice> create({
    int? barcode,
    required String name,
    required Decimal price,
    required int type,
    required int measure,
    int? categoryId,
    Decimal? minPrice,
  }) async {
    return _db.transaction(() async {
      final productBarcode =
          barcode ?? await _createProductInfoUseCase.generateBarcode();

      final ucode = await _createProductInfoUseCase.create(
        barcode: productBarcode,
        name: name,
        type: type,
        measure: measure,
        categoryId: categoryId,
      );

      await _createProductPriceUseCase.create(
        ucode: ucode,
        barcode: productBarcode,
        sellingPrice: price,
        wholesalePrice: minPrice,
      );

      _logger.info(
        'CreateProductInfoAndPrice: created ucode=$ucode, barcode=$productBarcode',
      );

      return ProductWithPrice(
        ucode: ucode,
        barcode: productBarcode,
        name: name,
        type: type,
        measure: measure,
        categoryId: categoryId,
        price: price,
        minPrice: minPrice,
        isDeleted: false,
      );
    });
  }

  @override
  Future<ProductWithPrice> createFromGlobal({
    required int globalProductId,
    required Decimal price,
    Decimal? minPrice,
  }) async {
    final globalProducts = await (_db.select(
      _db.globalProducts,
    )..where((g) => g.code.equals(globalProductId))).get();

    if (globalProducts.isEmpty) {
      throw StateError('GlobalProduct $globalProductId not found');
    }

    final globalProduct = globalProducts.first;

    return create(
      barcode: globalProduct.code,
      name: globalProduct.name,
      price: price,
      type: 0,
      measure: 0,
      categoryId: globalProduct.categoryId,
      minPrice: minPrice,
    );
  }
}

import 'package:drift/drift.dart';
import 'package:talker/talker.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/domain/usecases/product/create_product_info_use_case.dart';

class CreateProductInfoUseCaseImpl implements CreateProductInfoUseCase {
  CreateProductInfoUseCaseImpl({
    required AppDatabase db,
    required Talker logger,
  }) : _db = db,
       _logger = logger;

  final AppDatabase _db;
  final Talker _logger;

  @override
  Future<int> create({
    int? ucode,
    required int barcode,
    required String name,
    required int type,
    required int measure,
    int? categoryId,
    String? description,
    String? imagePath,
    int? vatRate,
    int? taxCategoryId,
    String? ntin,
    bool isMarkable = false,
    String? brand,
    String? manufacturer,
    String? countryOfOrigin,
  }) async {
    final productUcode = ucode ?? await generateUcode();

    await _db
        .into(_db.productInfos)
        .insert(
          ProductInfosCompanion.insert(
            ucode: Value(productUcode),
            barcode: barcode,
            name: name,
            type: type,
            measure: measure,
            categoryId: Value(categoryId),
            description: Value(description),
            imagePath: Value(imagePath),
            vatRate: Value(vatRate),
            taxCategoryId: Value(taxCategoryId),
            ntin: Value(ntin),
            isMarkable: Value(isMarkable),
            brand: Value(brand),
            manufacturer: Value(manufacturer),
            countryOfOrigin: Value(countryOfOrigin),
            localEditTime: Value(DateTime.now()),
          ),
        );

    _logger.info(
      'CreateProductInfo: created ucode=$productUcode, barcode=$barcode, name=$name',
    );

    return productUcode;
  }

  @override
  Future<int> generateUcode() async {
    final lastProduct = await _db.productInfoDao.findWithMaxUcode();
    if (lastProduct != null && lastProduct.ucode >= 2000000001) {
      return lastProduct.ucode + 1;
    }
    return 2000000001;
  }

  @override
  Future<int> generateBarcode() async {
    final lastProduct = await _db.productInfoDao.findWithMaxBarcode();
    if (lastProduct != null && lastProduct.barcode >= 2000000000001) {
      return lastProduct.barcode + 1;
    }
    return 2000000000001;
  }
}

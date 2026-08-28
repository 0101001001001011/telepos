import 'package:decimal/decimal.dart';
import 'package:talker/talker.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/domain/usecases/product/find_by_barcode_use_case.dart';
import 'package:telepos/domain/usecases/product/find_product_by_code_use_case.dart';

class FindByBarcodeUseCaseImpl implements FindByBarcodeUseCase {
  FindByBarcodeUseCaseImpl({required AppDatabase db, required Talker logger})
    : _db = db,
      _logger = logger;

  final AppDatabase _db;
  final Talker _logger;

  @override
  Future<ProductWithPrice?> find(String barcode) async {
    final numericBarcode = int.tryParse(barcode);
    if (numericBarcode == null) {
      _logger.warning('FindByBarcode: invalid barcode format $barcode');
      return null;
    }

    return findByNumeric(numericBarcode);
  }

  @override
  Future<ProductWithPrice?> findByNumeric(int barcode) async {
    var products =
        await (_db.select(_db.productInfos)
              ..where((p) => p.barcode.equals(barcode))
              ..where((p) => p.isDeleted.equals(false)))
            .get();

    if (products.isEmpty) {
      products = await (_db.select(
        _db.productInfos,
      )..where((p) => p.barcode.equals(barcode))).get();
    }

    if (products.isEmpty) {
      _logger.info('FindByBarcode: not found for barcode=$barcode');
      return null;
    }

    final productInfo = products.first;

    final productPrice = await _db.productPriceDao.findByUcode(
      productInfo.ucode,
    );

    _logger.info(
      'FindByBarcode: found ucode=${productInfo.ucode} for barcode=$barcode',
    );

    final price =
        productPrice?.sellingPrice ??
        productPrice?.wholesalePrice ??
        Decimal.zero;

    return ProductWithPrice(
      ucode: productInfo.ucode,
      barcode: productInfo.barcode,
      name: productInfo.name,
      type: productInfo.type,
      measure: productInfo.measure,
      categoryId: productInfo.categoryId,
      price: price,
      minPrice: productPrice?.wholesalePrice,
      isDeleted: productInfo.isDeleted,
    );
  }
}

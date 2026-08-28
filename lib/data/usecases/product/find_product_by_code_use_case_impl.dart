import 'package:decimal/decimal.dart';
import 'package:talker/talker.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/domain/usecases/product/find_product_by_code_use_case.dart';
import 'package:telepos/domain/usecases/product/find_by_alias_use_case.dart';
import 'package:telepos/domain/usecases/product/find_by_barcode_use_case.dart';

class FindProductByCodeUseCaseImpl implements FindProductByCodeUseCase {
  FindProductByCodeUseCaseImpl({
    required AppDatabase db,
    required FindByAliasUseCase findByAliasUseCase,
    required FindByBarcodeUseCase findByBarcodeUseCase,
    required Talker logger,
  }) : _db = db,
       _findByAliasUseCase = findByAliasUseCase,
       _findByBarcodeUseCase = findByBarcodeUseCase,
       _logger = logger;

  final AppDatabase _db;
  final FindByAliasUseCase _findByAliasUseCase;
  final FindByBarcodeUseCase _findByBarcodeUseCase;
  final Talker _logger;

  @override
  Future<ProductWithPrice?> find(String code) async {
    final ucode = await _findByAliasUseCase.find(code);
    if (ucode != null) {
      return _loadProductWithPrice(ucode);
    }

    final product = await _findByBarcodeUseCase.find(code);
    if (product != null) {
      _logger.info('FindProductByCode: found by barcode $code');
      return product;
    }

    _logger.info('FindProductByCode: not found for code=$code');
    return null;
  }

  Future<ProductWithPrice?> _loadProductWithPrice(int ucode) async {
    final productInfo = await _db.productInfoDao.findByIdAndNotDeleted(ucode);
    if (productInfo == null) {
      _logger.warning(
        'FindProductByCode: productInfo not found for ucode=$ucode',
      );
      return null;
    }

    final productPrice = await _db.productPriceDao.findByUcode(ucode);

    _logger.info('FindProductByCode: found by alias, ucode=$ucode');

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
